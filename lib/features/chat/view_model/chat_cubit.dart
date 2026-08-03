import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_bloc_observer.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../../conversations/data/attachment_models.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/data/conversations_repository.dart';
import 'chat_state.dart';

/// ViewModel for a single chat screen.
///
/// One instance per conversation route — constructed via `BlocProvider`
/// at the `/chats/:id` page builder so `close()` fires (cancelling the
/// poll timer) when the user navigates away.
///
/// **Polling lifecycle** (SAQQAR_MOBILE_API.md §4):
///   * `is_running = true` → poll every **1.5 s** (snapshot can change
///     between user-visible messages — typing rows, run progress).
///   * `is_running = false` → poll every **15 s** for late-arriving
///     server-side state (someone else's approval, a delayed artifact).
///   * App backgrounded (call [pause]) → stop polling entirely until
///     [resume] is called. Saves battery + bandwidth.
///
/// Marked [QuietBloc] so the BlocObserver doesn't log every 1.5 s state
/// change — the polling tick would spam the dev console.
class ChatCubit extends Cubit<ChatState> implements QuietBloc {
  ChatCubit({
    required this.conversationId,
    required ConversationsRepository repository,
  })  : _repo = repository,
        super(const ChatState());

  static const _tag = 'ChatCubit';
  static const _runningInterval = Duration(milliseconds: 1500);
  static const _idleInterval = Duration(seconds: 15);

  /// How many fast ticks a send buys before we believe the run flag again —
  /// 20 × 1.5 s ≈ 30 s.
  ///
  /// `POST /messages/` answers with the snapshot the server holds the moment
  /// the row is persisted, which can be before a worker has picked the turn
  /// up. Scheduling purely off `is_running` in that response risks putting the
  /// next poll **15 s** away for a reply measured at ~3.4 s on production
  /// (2026-07-29) — the shape of the "reply takes forever, I have to refresh
  /// a few times" report.
  ///
  /// This is a bounded safety net, not a claim about how the server behaves:
  /// the grace is dropped the instant a snapshot does report `is_running`, so
  /// when the flag is prompt it costs at most one extra tick. What is
  /// measured is the other half — sending again 1.5–3 s later is rejected
  /// `409 the agent is still working` (8 of 30 consecutive turns), so a run
  /// the client cannot see is a real state, and waiting out an idle tick
  /// before looking is the wrong default.
  ///
  /// Counted in ticks rather than wall-clock: the budget is "how many polls
  /// is a send worth", which is what actually bounds the cost, and it stays
  /// deterministic under a virtual clock instead of reading `DateTime.now()`.
  static const _replyGraceTicks = 20;
  static const _attachmentPollInterval = Duration(seconds: 1);
  static const _attachmentPollTimeout = Duration(seconds: 30);

  /// Messages fetched on the first paint. A bounded window keeps the
  /// open-chat path fast — we deserialise + lay out ~40 recent rows
  /// instead of the entire transcript on the UI isolate. Older history
  /// loads on demand via [loadOlder].
  static const _initialLimit = 40;

  /// Page size for each backwards step, in RAW rows. Fixed, not growing:
  /// every fetch returns exactly one page of history that gets PREPENDED to
  /// what we already hold.
  ///
  /// Deliberately larger than [_initialLimit]. Raw rows are not what the user
  /// sees: on a real transcript roughly half are `tool` rows the chat filters
  /// out entirely, and runs of consecutive assistant rows collapse into one
  /// "thinking" pill. Measured on a live conversation, 200 raw rows were
  /// 89 tool / 94 assistant / 17 user — so a 40-row page can surface as few as
  /// two or three visible entries, which isn't enough to fill the lane, let
  /// alone make it scrollable enough to trigger the next page. 100 is still
  /// one request and still well under the server's 500 ceiling.
  static const _olderPageSize = 100;

  /// The `?before=` cursor for the next backwards page — the server's
  /// `oldest_cursor` from the oldest page we've loaded so far.
  ///
  /// Replaces the old "re-fetch the whole transcript with a bigger `limit`
  /// each time" strategy, which was wrong in two ways. It re-downloaded
  /// every message already on screen on every step; and because `?limit=` is
  /// capped at **500** server-side, growing it (40 → 120 → … → 520) hit the
  /// ceiling and the "did we get a full page?" test then reported *no more
  /// history*. On a 5,340-message conversation that stranded 4,840 messages
  /// with no way to reach them. Verified against production 2026-07-25.
  String? _oldestCursor;

  /// Whichever backwards page is currently on the wire.
  ///
  /// Shared by [loadOlder] and [prefetchOlder] so a scroll that lands while a
  /// page-ahead is running rides that request instead of issuing a second one
  /// for the same cursor — two in-flight fetches from the same position would
  /// both dedupe to nothing and burn a round trip each.
  Future<void>? _olderPageInFlight;

  /// Whether any backwards page has landed for this conversation.
  ///
  /// Gates the one-shot page-ahead in [load]: before the user has paged at
  /// all, banking the next page is free headroom; afterwards `load()` is a
  /// refresh, and paging back another step on every pull would be the view's
  /// call to make, not a side effect of refreshing.
  bool _hasPagedBack = false;

  final String conversationId;
  final ConversationsRepository _repo;

  Timer? _pollTimer;
  bool _paused = false;
  bool _disposed = false;

  /// Fast ticks still owed to a just-sent turn the server hasn't admitted to
  /// running yet. Reset to [_replyGraceTicks] on a send, zeroed the moment a
  /// snapshot reports `is_running: true` (the normal running cadence takes
  /// over from there). See [_schedulePoll].
  int _replyGraceLeft = 0;

  // Per-attachment status pollers — keyed by attachment id so multiple
  // uploads run independently.
  final _attachmentTimers = <String, Timer>{};

  /// Silently drop any [emit] call that lands after [close] has run.
  ///
  /// The chat cubit is heavily async — every `await _repo.X` opens a
  /// window where the BlocProvider can dispose us (user navigates back
  /// to Conversations, swaps to another chat, kills the app) before
  /// the response lands. Without this guard, the resolved future tries
  /// to `emit(...)` on a closed cubit and Bloc throws
  /// `StateError: Bad state: Cannot emit new states after calling close`
  /// — observed in production via Sentry under SAQQAR-2.
  ///
  /// Overriding `emit` once is the surgical fix that immunises every
  /// call site (~25 in this cubit) without scattering `if (!isClosed)`
  /// guards before each one. Same pattern the bloc docs recommend for
  /// any cubit doing async work.
  @override
  void emit(ChatState state) {
    if (isClosed) return;
    super.emit(state);
  }

  // ── Snapshot loading + polling ──────────────────────────────────────

  /// Initial load — paints the cached transcript instantly (if any),
  /// then fetches a **bounded** recent window so the open-chat path never
  /// blocks on deserialising the entire history. Subsequent polls use the
  /// delta path via [_pollOnce]; older history loads via [loadOlder].
  Future<void> load() async {
    if (state.data is DataLoading<ConversationSnapshot>) return;
    // Stale-while-revalidate: paint whatever we can show RIGHT NOW — the
    // live snapshot if this is a refresh, else the session cache if we've
    // opened this chat before — and keep it on screen while the fetch
    // runs. Only a truly cold open (nothing to show) falls through to the
    // loading skeleton. This is what kills the "tap a chat → blank
    // skeleton → everything floods in at once" lag: the user reads
    // immediately and the bounded fetch reconciles underneath.
    final existing =
        state.data.dataOrNull ?? _repo.cachedSnapshot(conversationId);
    if (existing != null) {
      _oldestCursor = existing.oldestCursor;
      emit(state.copyWith(
        data: DataSuccess(existing),
        hasMoreOlder: _hasMoreFrom(existing),
      ));
    } else {
      // Show the loading skeleton IMMEDIATELY (synchronously), BEFORE the
      // disk read — otherwise the screen sits on `DataIdle` during the
      // (fast, off-isolate) read and flashes the empty "What should we work
      // on?" welcome. Then swap in the on-disk transcript the moment it
      // decodes; if there's nothing cached, the skeleton just stays until
      // the network lands.
      emit(state.copyWith(data: const DataLoading<ConversationSnapshot>()));
      final disk = await _repo.diskCachedSnapshot(conversationId);
      if (disk != null && state.data.dataOrNull == null) {
        _oldestCursor = disk.oldestCursor;
        emit(state.copyWith(
          data: DataSuccess(disk),
          hasMoreOlder: _hasMoreFrom(disk),
        ));
      }
    }
    try {
      final snapshot =
          await _repo.getSnapshot(conversationId, limit: _initialLimit);
      // Through [_mergeSnapshot], NOT a direct adopt-and-replace.
      //
      // This asks for the newest [_initialLimit] rows. Adopting that verbatim
      // is right on a cold open and destructive afterwards: if the user has
      // already scrolled back through several pages, the reply is a SHORTER
      // window than what we hold, and replacing threw the paged-in history
      // away and reset `_oldestCursor` to the newest page. The next "load
      // earlier" then re-fetched the same first page, deduped it against
      // itself and stood still — so scrolling up past the first page did
      // nothing at all, forever, with no error to show for it.
      //
      // Measured on a live 857-message chat: every automatic page reported
      // `cur=40 page=100 older=100` and the loaded count sat at 52 across six
      // consecutive fetches. `_mergeSnapshot` already encodes the rule (keep
      // the longer transcript, adopt the fresh conversation/approval fields,
      // hold our cursor); this path just wasn't using it.
      _mergeSnapshot(snapshot);
      _schedulePoll();
      // Bank the next page while the user is still reading the first one.
      //
      // Only before any history has been paged in. `load()` also runs for a
      // pull-to-refresh, and prefetching on every one of those would walk
      // another page backwards each time the user tugged the list. Once the
      // user is paging, the view asks for headroom itself — it is the only
      // side that knows how much of what's loaded has actually been revealed.
      if (!_hasPagedBack) unawaited(prefetchOlder());
    } catch (e, st) {
      AppLogger.error(_tag, 'load() failed', error: e, stackTrace: st);
      emit(state.copyWith(
        data: DataFailure<ConversationSnapshot>(
          message: 'Failed to load chat',
          error: ApiErrorMapper.toFailure(e),
          previous: state.data.dataOrNull,
        ),
        actionFailure: ChatActionFailure(
          action: ChatAction.load,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
    }
  }

  /// Whether older history exists, straight from the server's
  /// `has_more_before`.
  ///
  /// This used to be inferred — "did the page come back as full as we asked?"
  /// — which is only a proxy, and it broke at the server's 500-row `limit`
  /// ceiling: a capped response looks identical to "that's the whole
  /// transcript", so paging reported *done* while thousands of messages
  /// remained. The server knows the answer; ask it.
  ///
  /// Falls back to the old heuristic only for a snapshot decoded from an
  /// on-disk cache written before this field existed.
  bool _hasMoreFrom(ConversationSnapshot snapshot) =>
      snapshot.oldestCursor != null
          ? snapshot.hasMoreBefore
          : snapshot.messages.length >= _initialLimit;

  /// Manual refresh — same code path as the polling tick.
  Future<void> refresh() => _pollOnce();

  /// PATCH the per-conversation `auto_approve` flag on the server and
  /// reflect the new value in our snapshot optimistically. Same shape
  /// the web uses, so flipping the switch on either device shows up on
  /// the other after the next poll.
  /// Returns false when the server refused and the toggle was rolled back,
  /// so the view can explain why the switch snapped back.
  Future<bool> setAutoApprove(bool value) =>
      _patchConversationFlag(autoApprove: value);

  /// PATCH the per-conversation `deep_think` flag. Servers that don't
  /// surface the field yet silently ignore the key — the next poll
  /// just returns the previous value and the local UI flips back.
  Future<bool> setDeepThink(bool value) =>
      _patchConversationFlag(deepThink: value);

  Future<bool> _patchConversationFlag({
    bool? autoApprove,
    bool? deepThink,
  }) async {
    final current = state.data.dataOrNull;
    if (current == null) return false;
    // Optimistic: paint the new value in the snapshot before the
    // server round-trip lands so the toggle responds instantly.
    // Also stash `deep_think` into context so a backend that still
    // reads it from the legacy scratchpad (and not the new top-level
    // column) picks the change up. Safe to send both — the new top-
    // level wins server-side when present, the context copy is a
    // belt-and-braces fallback for partial rollouts.
    final mergedContext = deepThink == null
        ? null
        : {
            ...current.conversation.context,
            'deep_think': deepThink,
          };
    final optimistic = current.copyWith(
      conversation: current.conversation.copyWith(
        autoApprove: autoApprove ?? current.conversation.autoApprove,
        deepThink: deepThink ?? current.conversation.deepThink,
        context: mergedContext ?? current.conversation.context,
      ),
    );
    emit(state.copyWith(data: DataSuccess(optimistic)));
    try {
      final patched = await _repo.patch(
        id: conversationId,
        autoApprove: autoApprove,
        deepThink: deepThink,
        context: mergedContext,
      );
      // Log the echoed conversation so a divergence between what we
      // sent and what the server kept is visible during sync issues
      // (e.g. server quietly dropping `deep_think` while accepting
      // `auto_approve`).
      AppLogger.info(
        _tag,
        'PATCH echoed conversation: autoApprove=${patched.autoApprove}, '
            'deepThink=${patched.deepThink}',
      );
      // Pull the canonical snapshot so any server-side coercion (e.g.
      // the server normalising auto_approve when the env is read_only)
      // wins over the optimistic value.
      await _pollOnce();
      return true;
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        '_patchConversationFlag(autoApprove=$autoApprove, '
            'deepThink=$deepThink) failed',
        error: e,
        stackTrace: st,
      );
      // Rollback the optimistic change.
      emit(state.copyWith(data: DataSuccess(current)));
      emit(state.copyWith(
        actionFailure: ChatActionFailure(
          action: ChatAction.patch,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  /// Pause polling — call when the chat goes off-screen (route pop,
  /// app backgrounded). Safe to call multiple times.
  void pause() {
    if (_paused) return;
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    AppLogger.debug(_tag, 'paused');
  }

  /// Resume polling. Fires an immediate poll if more than [_idleInterval]
  /// has passed since the last cursor (otherwise the next scheduled
  /// tick is enough).
  void resume() {
    if (!_paused) return;
    _paused = false;
    AppLogger.debug(_tag, 'resumed');
    _pollOnce();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_paused || _disposed) return;
    // Once the server admits it's running, that flag is the better signal and
    // the post-send grace has done its job.
    if (state.isRunning) _replyGraceLeft = 0;
    final fast = state.isRunning || _replyGraceLeft > 0;
    // Spending the budget here rather than in `_pollOnce` means a send that
    // never produces a run — dropped server-side, stopped by the user — winds
    // back down to the idle cadence instead of polling at 1.5 s forever.
    if (!state.isRunning && _replyGraceLeft > 0) _replyGraceLeft--;
    _pollTimer = Timer(fast ? _runningInterval : _idleInterval, _pollOnce);
  }

  Future<void> _pollOnce() async {
    if (_paused || _disposed) return;
    final cursor = state.data.dataOrNull?.cursor;
    try {
      final snapshot = await _repo.getSnapshot(
        conversationId,
        since: cursor,
      );
      // No per-tick logging here. This runs every 1.5 s while the agent is
      // running; the interpolated message was being BUILT on every tick even
      // in release (arguments are evaluated before `AppLogger.info` can
      // no-op), so a diagnostic left over from a since-fixed toggle-sync bug
      // was costing a string allocation ~40×/min forever. Re-add behind
      // `kDebugMode` if the flags ever need watching again.
      _mergeSnapshot(snapshot);
    } catch (e, st) {
      AppLogger.warn(_tag, 'poll failed', error: e, stackTrace: st);
      // Don't surface a toast for poll failures — they're high-frequency.
      // The next tick will retry. If polling stays broken the user can
      // pull-to-refresh, which calls load() and surfaces the error.
    } finally {
      _schedulePoll();
    }
  }

  /// Merges a delta snapshot into the cubit state. The contract per
  /// SAQQAR_MOBILE_API.md §4.3 is:
  ///   * **messages**: APPEND when `delta=true`, REPLACE when `delta=false`.
  ///   * Everything else (conversation flags, approvals, artifacts,
  ///     pending actions, available + disabled credentials, run
  ///     progress): always REPLACE in full — even on delta responses.
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
          // `copyWith` on the INCOMING snapshot, not a hand-rolled
          // constructor: the hand-rolled version silently dropped every field
          // it didn't happen to list. That's how `quotaExceeded` was being
          // lost — the server blocks a send for being over cap, the quota
          // banner paints, and 1.5 s later the first poll wiped the flag and
          // re-enabled Send. Deriving from `incoming` means a new snapshot
          // field is carried by default and can only be lost deliberately.
          final preserved = incoming.copyWith(
            messages:
                fresh.isEmpty ? current.messages : [...current.messages, ...fresh],
            // Deliberately the OLD cursor even when rows were stitched in: it
            // is the low-water mark of what we've definitely seen, so the next
            // delta re-delivers anything the window missed. Duplicates are
            // deduped on append; a skipped row would never come back.
            cursor: current.cursor,
            delta: false,
            // A poll asks for the DEFAULT window, so its `oldest_cursor` points
            // at the newest page — adopting it would rewind our paging position
            // and make the next "load earlier" re-fetch history we already have.
            // Ours describes how far back the user has actually read.
            oldestCursor: current.oldestCursor,
            hasMoreBefore: current.hasMoreBefore,
          );
          emit(state.copyWith(data: DataSuccess(preserved)));
          _repo.cacheSnapshot(conversationId, preserved);
          return;
        }
      }
      // First snapshot or full refresh — adopt verbatim, and reset the paging
      // position with it: this IS the newest window now.
      _oldestCursor = incoming.oldestCursor;
      emit(state.copyWith(
        data: DataSuccess(incoming),
        hasMoreOlder: _hasMoreFrom(incoming),
      ));
      _repo.cacheSnapshot(conversationId, incoming);
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
      cursor: incoming.cursor ?? current.cursor,
      delta: false,
      // Same reasoning as the `preserved` branch: a delta poll describes the
      // newest rows, not how far back we've paged.
      oldestCursor: current.oldestCursor,
      hasMoreBefore: current.hasMoreBefore,
    );
    emit(state.copyWith(data: DataSuccess(merged)));
    // Keep the cache current so re-opening this chat paints the appended
    // rows too, not just the first page from initial load.
    _repo.cacheSnapshot(conversationId, merged);
  }

  /// Fetches ONE page of older messages via `?before=<oldestCursor>` and
  /// PREPENDS it to the transcript we already hold.
  ///
  /// Each step now costs exactly one page. The previous implementation
  /// re-fetched the whole conversation with an ever-larger `limit` and
  /// replaced the snapshot, so paging back through a long chat re-downloaded
  /// everything already on screen, every time — and stopped dead at the
  /// server's 500-row `limit` ceiling with thousands of messages still
  /// unreachable. See [_oldestCursor].
  ///
  /// `hasMoreOlder` comes straight from the server's `has_more_before`, so
  /// the affordance disappears exactly when the transcript actually starts.
  ///
  /// Decode runs OFF the UI isolate. No-op while a fetch is in flight, once
  /// the start is reached, or if we have no cursor to page from.
  Future<void> loadOlder() => _pageOlder(silent: false);

  /// Fetches the next backwards page **ahead of the user asking for it**, so
  /// that by the time they scroll into it the rows are already in memory and
  /// the reveal is a widen-the-window with no network in it.
  ///
  /// This is the difference between paging that feels instant and paging that
  /// feels broken. On demand, every step costs a full round trip plus a JSON
  /// decode of a 100-row page, and the user spends that time looking at a
  /// spinner at the top of a chat that has visibly stopped — which reads as
  /// "it didn't load" and gets answered with a pull-to-refresh, which (before
  /// this) threw the paged-in history away and made it true.
  ///
  /// Silent by design: no spinner, and a failure is swallowed rather than
  /// raised. Nobody asked for this page, so nothing about it should appear in
  /// the UI; if it fails, the bank is simply empty and the user's next scroll
  /// falls back to [loadOlder], which does surface the error.
  ///
  /// Exactly ONE page of headroom, never a chain — the fetched page is merged
  /// into the transcript rather than parked in a side buffer, so the existing
  /// "reveal what's already loaded" path serves it with no extra machinery,
  /// and the next page is only fetched when the view says the headroom is
  /// running down. Self-chaining here would quietly walk the whole
  /// conversation into memory on a chat the user opened to read one message.
  Future<void> prefetchOlder() => _pageOlder(silent: true);

  /// One backwards page, shared by the user-driven and page-ahead paths.
  Future<void> _pageOlder({required bool silent}) {
    final inFlight = _olderPageInFlight;
    if (inFlight != null) {
      // A page is already on the wire. Ride it rather than issuing a second
      // request for the same cursor — but if the user is now waiting on what
      // started as a background fetch, promote it to a visible one so the
      // header explains the wait.
      if (!silent && !state.isLoadingOlder) {
        emit(state.copyWith(isLoadingOlder: true));
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
      AppLogger.warn(_tag, 'loadOlder: no oldest_cursor; paging disabled');
      emit(state.copyWith(isLoadingOlder: false, hasMoreOlder: false));
      return Future<void>.value();
    }
    if (!silent) emit(state.copyWith(isLoadingOlder: true));
    final future = _fetchOlderPage(cursor: cursor, silent: silent)
        .whenComplete(() => _olderPageInFlight = null);
    _olderPageInFlight = future;
    return future;
  }

  Future<void> _fetchOlderPage({
    required String cursor,
    required bool silent,
  }) async {
    try {
      final page = await _repo.getSnapshotOffIsolate(
        conversationId,
        before: cursor,
        limit: _olderPageSize,
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
      emit(state.copyWith(
        data: DataSuccess(merged),
        isLoadingOlder: false,
        hasMoreOlder: more,
      ));
      _repo.cacheSnapshot(conversationId, merged);
    } catch (e, st) {
      AppLogger.warn(_tag, 'loadOlder failed', error: e, stackTrace: st);
      if (silent) {
        // Nobody is waiting on this one. Leaving the bank empty is the whole
        // consequence; the next user-driven step reports the problem.
        emit(state.copyWith(isLoadingOlder: false));
        return;
      }
      // Records the failure as well as clearing the spinner. Clearing it
      // alone left the user tapping "Load earlier", watching the spinner
      // stop, and seeing no new messages and no reason — indistinguishable
      // from "you've reached the beginning".
      emit(state.copyWith(
        isLoadingOlder: false,
        actionFailure: ChatActionFailure(
          action: ChatAction.load,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
    }
  }

  // ── Sending ─────────────────────────────────────────────────────────

  /// POST `/conversations/<id>/messages/` with the current composer
  /// text + any staged attachments. The server returns a snapshot which
  /// we adopt directly (it's a full one — `delta=false`).
  ///
  /// 409 means the agent's still mid-task; the caller can show a
  /// hint or call [stopGeneration] first.
  Future<bool> sendMessage({
    required String content,
    bool deepThink = false,
    String? model,
  }) async {
    if (state.isSending) return false;
    final attachmentIds =
        state.stagedAttachments.map((a) => a.id).toList();
    emit(state.copyWith(
      isSending: true,
      clearActionFailure: true,
    ));
    try {
      final snapshot = await _repo.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentIds: attachmentIds,
        deepThink: deepThink,
        model: model,
      );
      emit(state.copyWith(
        data: DataSuccess(snapshot),
        stagedAttachments: const [],
        clearStagedAttachments: true,
        isSending: false,
        actionToast: ChatToast.messageSent,
      ));
      _repo.cacheSnapshot(conversationId, snapshot);
      // Immediately bump the polling cadence to "running" speed since
      // the agent is now processing the message we just sent — even though
      // this very snapshot usually still says `is_running: false`.
      _replyGraceLeft = _replyGraceTicks;
      _schedulePoll();
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'sendMessage failed', error: e, stackTrace: st);
      emit(state.copyWith(
        isSending: false,
        actionFailure: ChatActionFailure(
          action: ChatAction.send,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  /// Cooperative cancel — the server flips `stop_requested=true`;
  /// the agent worker exits between tool rounds. Idempotent.
  Future<bool> stopGeneration() async {
    if (state.isStopping) return false;
    emit(state.copyWith(isStopping: true, clearActionFailure: true));
    try {
      await _repo.stop(conversationId);
      // The user has cancelled the turn they were waiting on, so the
      // post-send fast-poll grace no longer has anything to wait for.
      _replyGraceLeft = 0;
      // Next poll will pick up the flipped flag — no explicit state
      // mutation here.
      emit(state.copyWith(
        isStopping: false,
        actionToast: ChatToast.generationStopped,
      ));
      // Fire-and-forget — we don't need to await the next snapshot to
      // return success; the polling loop will keep state fresh.
      unawaited(_pollOnce());
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'stopGeneration failed', error: e, stackTrace: st);
      emit(state.copyWith(
        isStopping: false,
        actionFailure: ChatActionFailure(
          action: ChatAction.stop,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  // ── Attachments ─────────────────────────────────────────────────────

  /// Uploads files via multipart, stages them on the cubit state, and
  /// starts polling each attachment's status endpoint until it flips
  /// to `ready` (or `failed`). The composer's Send button stays
  /// enabled — the agent itself waits for extracted_text per the spec,
  /// so eager-send is safe.
  Future<bool> uploadAttachments(List<File> files) async {
    if (files.isEmpty) return false;
    emit(state.copyWith(isUploading: true, clearActionFailure: true));
    try {
      final uploaded = await _repo.uploadAttachments(
        conversationId: conversationId,
        files: files,
      );
      emit(state.copyWith(
        stagedAttachments: [...state.stagedAttachments, ...uploaded],
        isUploading: false,
      ));
      for (final a in uploaded) {
        if (a.status == AttachmentStatus.pending) {
          _startAttachmentStatusPoll(a.id);
        }
      }
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'uploadAttachments failed',
          error: e, stackTrace: st);
      emit(state.copyWith(
        isUploading: false,
        actionFailure: ChatActionFailure(
          action: ChatAction.uploadAttachment,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  /// Removes a staged attachment locally (no server call — the
  /// attachment row stays on the server, just isn't included in the
  /// next sendMessage's attachment_ids).
  void removeStagedAttachment(String attachmentId) {
    _attachmentTimers.remove(attachmentId)?.cancel();
    emit(state.copyWith(
      stagedAttachments: state.stagedAttachments
          .where((a) => a.id != attachmentId)
          .toList(),
    ));
  }

  /// Polls one attachment's `/status/` endpoint until it flips out of
  /// `pending`. Caps at [_attachmentPollTimeout] — beyond that, the
  /// user gets a "taking longer than expected" hint and can still send.
  void _startAttachmentStatusPoll(String attachmentId) {
    _attachmentTimers[attachmentId]?.cancel();
    final deadline = DateTime.now().add(_attachmentPollTimeout);
    _attachmentTimers[attachmentId] = Timer.periodic(
      _attachmentPollInterval,
      (timer) async {
        if (_disposed) {
          timer.cancel();
          return;
        }
        try {
          final fresh = await _repo.getAttachmentStatus(
            conversationId: conversationId,
            attachmentId: attachmentId,
          );
          // Replace the matching staged row in place.
          emit(state.copyWith(
            stagedAttachments: [
              for (final a in state.stagedAttachments)
                if (a.id == attachmentId) fresh else a,
            ],
          ));
          if (fresh.status != AttachmentStatus.pending) {
            timer.cancel();
            _attachmentTimers.remove(attachmentId);
            if (fresh.status == AttachmentStatus.ready) {
              emit(state.copyWith(actionToast: ChatToast.attachmentReady));
            }
          }
        } catch (e, st) {
          AppLogger.warn(
            _tag,
            'attachment status poll failed (id=$attachmentId)',
            error: e,
            stackTrace: st,
          );
          // Don't tear down the timer on a transient failure — try again
          // next tick. Stop after the deadline.
          if (DateTime.now().isAfter(deadline)) {
            timer.cancel();
            _attachmentTimers.remove(attachmentId);
          }
        }
      },
    );
  }

  // ── Pending actions / credentials ──────────────────────────────────

  Future<bool> dismissPendingAction({
    String? actionType,
    String? credentialName,
    String? credentialKind,
  }) async {
    try {
      final snapshot = await _repo.dismissPendingAction(
        conversationId: conversationId,
        actionType: actionType,
        credentialName: credentialName,
        credentialKind: credentialKind,
      );
      emit(state.copyWith(
        data: DataSuccess(snapshot),
        actionToast: ChatToast.pendingActionDismissed,
      ));
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'dismissPendingAction failed',
          error: e, stackTrace: st);
      emit(state.copyWith(
        actionFailure: ChatActionFailure(
          action: ChatAction.dismissPendingAction,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  Future<bool> setActiveCredential(String? name) async {
    try {
      await _repo.setActiveCredential(id: conversationId, name: name);
      emit(state.copyWith(actionToast: ChatToast.credentialSet));
      await _pollOnce();
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'setActiveCredential failed',
          error: e, stackTrace: st);
      emit(state.copyWith(
        actionFailure: ChatActionFailure(
          action: ChatAction.setActiveCredential,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  Future<bool> toggleCredential({
    required String name,
    required bool enabled,
  }) async {
    final previous = state.data.dataOrNull;
    if (previous == null) return false;
    // Optimistic update: rewrite the disabledCredentials list locally
    // first; rollback in the catch.
    final nextDisabled = enabled
        ? previous.disabledCredentials.where((n) => n != name).toList()
        : [...previous.disabledCredentials, name];
    emit(state.copyWith(
      data: DataSuccess(
        previous.copyWith(disabledCredentials: nextDisabled),
      ),
    ));
    try {
      await _repo.toggleCredential(
        id: conversationId,
        name: name,
        enabled: enabled,
      );
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'toggleCredential failed',
          error: e, stackTrace: st);
      // Rollback.
      emit(state.copyWith(
        data: DataSuccess(previous),
        actionFailure: ChatActionFailure(
          action: ChatAction.toggleCredential,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  // ── Sharing ─────────────────────────────────────────────────────────

  Future<bool> shareConversation() async {
    try {
      final result = await _repo.share(conversationId);
      emit(state.copyWith(
        lastShareUrl: result.url,
        actionToast: ChatToast.shareLinkCopied,
      ));
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'shareConversation failed',
          error: e, stackTrace: st);
      emit(state.copyWith(
        actionFailure: ChatActionFailure(
          action: ChatAction.share,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  /// Revokes the public share link. Returns false when the server refused.
  ///
  /// This one MUST surface. Swallowing it told the user their link was dead
  /// while it stayed live and publicly readable — a silent failure with a
  /// privacy consequence, and the only way to notice was to open the link
  /// again in a browser.
  Future<bool> revokeShare() async {
    try {
      await _repo.revokeShare(conversationId);
      emit(state.copyWith(clearShareUrl: true));
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'revokeShare failed', error: e, stackTrace: st);
      emit(state.copyWith(
        actionFailure: ChatActionFailure(
          action: ChatAction.revokeShare,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  // ── One-shot message acknowledgement ────────────────────────────────

  void consumeActionFailure() {
    if (state.actionFailure == null) return;
    emit(state.copyWith(clearActionFailure: true));
  }

  void consumeActionToast() {
    if (state.actionToast == null) return;
    emit(state.copyWith(clearActionToast: true));
  }

  void consumeShareUrl() {
    if (state.lastShareUrl == null) return;
    emit(state.copyWith(clearShareUrl: true));
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _disposed = true;
    _pollTimer?.cancel();
    for (final t in _attachmentTimers.values) {
      t.cancel();
    }
    _attachmentTimers.clear();
    return super.close();
  }
}
