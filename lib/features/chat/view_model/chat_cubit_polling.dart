part of 'chat_cubit.dart';

/// Polling: scheduling, one poll round and merging a snapshot into state.
extension _ChatPolling on ChatCubit {
  /// Drops [ChatState.awaitingReply] once something else tells the truth: the
  /// server reports a run, the reply is already in, or the grace has run out.
  void _settleAwaitingReply() {
    if (!state.awaitingReply) return;
    final last = state.data.dataOrNull?.messages.lastOrNull;
    final replied =
        last != null &&
        last.id != _idAtSend &&
        last.role == MessageRole.assistant;
    if (state.isRunning || replied || _replyGraceLeft <= 0) {
      _emit(state.copyWith(awaitingReply: false));
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_paused || _disposed) return;
    _settleAwaitingReply();
    // Once the server admits it's running, that flag is the better signal and
    // the post-send grace has done its job.
    if (state.isRunning) _replyGraceLeft = 0;
    final fast = state.isRunning || _replyGraceLeft > 0;
    // Spending the budget here rather than in `_pollOnce` means a send that
    // never produces a run — dropped server-side, stopped by the user — winds
    // back down to the idle cadence instead of polling at 1.5 s forever.
    if (!state.isRunning && _replyGraceLeft > 0) _replyGraceLeft--;
    _pollTimer = Timer(
      fast ? ChatCubit._runningInterval : ChatCubit._idleInterval,
      _pollOnce,
    );
  }

  /// One snapshot fetch, merged into state.
  ///
  /// [full] drops `?since=` so the server answers with the whole newest
  /// window rather than the rows after our cursor — what [refresh] wants, and
  /// what the 1.5 s tick must never do.
  Future<void> _pollOnce({bool full = false}) async {
    if (_paused || _disposed) return;
    final cursor = full ? null : state.data.dataOrNull?.cursor;
    try {
      final snapshot = await _repo.getSnapshot(
        conversationId,
        since: cursor,
        limit: full ? ChatCubit._initialLimit : null,
      );
      // No per-tick logging here. This runs every 1.5 s while the agent is
      // running; the interpolated message was being BUILT on every tick even
      // in release (arguments are evaluated before `AppLogger.info` can
      // no-op), so a diagnostic left over from a since-fixed toggle-sync bug
      // was costing a string allocation ~40×/min forever. Re-add behind
      // `kDebugMode` if the flags ever need watching again.
      _mergeSnapshot(snapshot);
    } catch (e, st) {
      AppLogger.warn(ChatCubit._tag, 'poll failed', error: e, stackTrace: st);
      // Don't surface a toast for poll failures — they're high-frequency.
      // The next tick will retry. If polling stays broken the user can
      // pull-to-refresh, which calls load() and surfaces the error.
    } finally {
      _schedulePoll();
    }
  }

  void _mergeSnapshot(ConversationSnapshot incoming) {
    final current = state.data.dataOrNull;
    if (current == null || !incoming.delta) {
      // Defensive: a NON-delta poll response that carries FEWER messages
      // than we've already loaded must not shrink the transcript back to a
      // server default page — that would silently throw away the older
      // history the user just paged in (a cause of "Load earlier" seeming
      // to do nothing / needing a refresh). Keep our messages + cursor,
      // adopt the fresh conversation/approvals/etc. from the poll.
      if (current != null &&
          !incoming.delta &&
          incoming.messages.length < current.messages.length) {
        // A window with NO messages at all says nothing about the transcript,
        // so it can't be the newest page and there is nothing to stitch. It
        // reaches the `overlaps` test as `0 < 0` — false — and used to fall
        // through to "adopt verbatim", replacing a loaded conversation with an
        // empty one. Keep every row we hold and take the rest of the snapshot.
        if (incoming.messages.isEmpty) {
          _adoptPreserving(incoming, current, current.messages);
          return;
        }
        final held = {
          for (final m in current.messages)
            if (m.id.isNotEmpty) m.id,
        };
        // Rows in the fresh window that we don't already hold. Keeping the
        // longer transcript must not also mean *discarding the newest page*:
        // on a chat whose cache held 95 rows, the fresh 40-row window was
        // thrown away whole and the screen opened on a nine-minute-old tail
        // until a delta poll healed it up to 15 s later — the "I have to
        // refresh a few times to see the reply" shape, from the open side.
        //
        // Only stitched when the window OVERLAPS what we hold. No shared row
        // means more than a page arrived while we were away, and appending
        // would leave a silent hole in the middle of the transcript; the
        // honest answer there is to adopt the fresh window and let the user
        // page back for the rest.
        final fresh = [
          for (final m in incoming.messages)
            if (m.id.isEmpty || !held.contains(m.id)) m,
        ];
        final overlaps = fresh.length < incoming.messages.length;
        if (overlaps) {
          _adoptPreserving(
            incoming,
            current,
            fresh.isEmpty ? current.messages : [...current.messages, ...fresh],
          );
          return;
        }
      }
      // First snapshot or full refresh — adopt verbatim, and reset the paging
      // position with it: this IS the newest window now.
      _oldestCursor = incoming.oldestCursor;
      final adopted = incoming.carriesApprovals || current == null
          ? incoming
          : incoming.copyWith(
              approvals: current.approvals,
              carriesApprovals: true,
            );
      _emit(
        state.copyWith(
          data: DataSuccess(adopted),
          hasMoreOlder: _hasMoreFrom(adopted),
        ),
      );
      _repo.cacheSnapshot(conversationId, adopted);
      return;
    }
    // Append new messages to the existing list, skipping any row whose id
    // we already hold. The server returns rows newer than `?since=`, but a
    // poll can be IN FLIGHT when `sendMessage`/`stopGeneration` adopts a
    // full snapshot (both reschedule a poll) — that in-flight delta was
    // requested against the OLD cursor, so it re-delivers the just-adopted
    // rows and, without this guard, they'd appear as duplicate bubbles until
    // the next full refresh. Empty ids (defensive fallback for a malformed
    // server row) can't be deduped, so they always append — same as before.
    final existingIds = {
      for (final m in current.messages)
        if (m.id.isNotEmpty) m.id,
    };
    final appended = [
      for (final m in incoming.messages)
        if (m.id.isEmpty || !existingIds.contains(m.id)) m,
    ];
    // Same reasoning as the `preserved` branch above — derive from the
    // incoming snapshot so no server field is dropped on a delta merge.
    //
    // `delta: false` on the RESULT is deliberate. `delta` describes how a
    // payload arrived, not what the conversation is, and the merged object is
    // the client's complete transcript — nothing outside this method ever
    // reads it off stored state (every other reader inspects a freshly
    // fetched response). Leaving it `true` would also make the first merged
    // snapshot unequal to the full one `load()` adopted purely on transport
    // metadata, costing one pointless rebuild on every chat open.
    final merged = incoming.copyWith(
      messages: appended.isEmpty
          ? current.messages
          : [...current.messages, ...appended],
      approvals: _approvalsFor(incoming, current),
      carriesApprovals: true,
      cursor: incoming.cursor ?? current.cursor,
      delta: false,
      // Same reasoning as the `preserved` branch: a delta poll describes the
      // newest rows, not how far back we've paged.
      oldestCursor: current.oldestCursor,
      hasMoreBefore: current.hasMoreBefore,
    );
    _emit(state.copyWith(data: DataSuccess(merged)));
    // Keep the cache current so re-opening this chat paints the appended
    // rows too, not just the first page from initial load.
    _repo.cacheSnapshot(conversationId, merged);
  }
}
