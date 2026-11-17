part of 'chat_cubit.dart';

/// Paging in older history.
extension _ChatOlderPages on ChatCubit {
  /// One backwards page, shared by the user-driven and page-ahead paths.
  Future<void> _pageOlder({required bool silent, int? rows}) {
    final inFlight = _olderPageInFlight;
    if (inFlight != null) {
      // A page is already on the wire. Ride it rather than issuing a second
      // request for the same cursor — but if the user is now waiting on what
      // started as a background fetch, promote it to a visible one so the
      // header explains the wait.
      if (!silent && !state.isLoadingOlder) {
        _emit(state.copyWith(isLoadingOlder: true));
      }
      return inFlight;
    }
    if (!state.hasMoreOlder) return Future<void>.value();
    if (state.data.dataOrNull == null) return Future<void>.value();
    final cursor = _oldestCursor;
    if (cursor == null || cursor.isEmpty) {
      // A server too old to send `oldest_cursor`. Stop rather than fall back
      // to growing `limit` — that path is what stranded history in the first
      // place, and every deployment we target sends the cursor.
      AppLogger.warn(
        ChatCubit._tag,
        'loadOlder: no oldest_cursor; paging disabled',
      );
      _emit(state.copyWith(isLoadingOlder: false, hasMoreOlder: false));
      return Future<void>.value();
    }
    if (!silent) _emit(state.copyWith(isLoadingOlder: true));
    final future = _fetchOlderPage(
      cursor: cursor,
      silent: silent,
      rows: rows,
    ).whenComplete(() => _olderPageInFlight = null);
    _olderPageInFlight = future;
    return future;
  }

  Future<void> _fetchOlderPage({
    required String cursor,
    int? rows,
    required bool silent,
  }) async {
    try {
      final page = await _repo.getSnapshotOffIsolate(
        conversationId,
        before: cursor,
        limit: ChatCubit._requestRows(rows),
      );
      // The paging position can move while a page is on the wire — a full
      // refresh adopts the newest window and rewinds the cursor. Landing this
      // page anyway would splice a fragment of old history onto a transcript
      // that no longer joins onto it.
      if (_oldestCursor != cursor) return;
      // Re-read the snapshot rather than closing over the one we started
      // with: a poll may have appended new messages during the fetch, and
      // building from the stale copy would drop them.
      final base = state.data.dataOrNull;
      if (base == null) return;
      // Dedupe defensively: a cursor sitting exactly on a boundary can
      // re-deliver its own row, and a duplicate bubble is worse than a
      // missing one.
      final existingIds = {
        for (final m in base.messages)
          if (m.id.isNotEmpty) m.id,
      };
      final older = [
        for (final m in page.messages)
          if (m.id.isEmpty || !existingIds.contains(m.id)) m,
      ];
      // An empty page means we're at the start whatever the flag says.
      final more = older.isEmpty ? false : page.hasMoreBefore;
      if (older.isNotEmpty) _hasPagedBack = true;
      _oldestCursor = page.oldestCursor ?? _oldestCursor;
      // Keep OUR snapshot as the base — `page` carries only the older window
      // and would otherwise drop the newer messages, approvals and artifacts
      // we already hold.
      final merged = base.copyWith(
        messages: [...older, ...base.messages],
        oldestCursor: _oldestCursor,
        hasMoreBefore: more,
      );
      _emit(
        state.copyWith(
          data: DataSuccess(merged),
          isLoadingOlder: false,
          hasMoreOlder: more,
        ),
      );
      _repo.cacheSnapshot(conversationId, merged);
    } catch (e, st) {
      AppLogger.warn(
        ChatCubit._tag,
        'loadOlder failed',
        error: e,
        stackTrace: st,
      );
      if (silent) {
        // Nobody is waiting on this one. Leaving the bank empty is the whole
        // consequence; the next user-driven step reports the problem.
        _emit(state.copyWith(isLoadingOlder: false));
        return;
      }
      // Records the failure as well as clearing the spinner. Clearing it
      // alone left the user tapping "Load earlier", watching the spinner
      // stop, and seeing no new messages and no reason — indistinguishable
      // from "you've reached the beginning".
      _emit(
        state.copyWith(
          isLoadingOlder: false,
          actionFailure: ChatActionFailure(
            action: ChatAction.load,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
    }
  }
}
