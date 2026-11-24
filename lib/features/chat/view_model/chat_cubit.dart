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
import '../../inbox/data/approval_models.dart';
import '../../../core/state/action_outcome.dart';
import 'chat_state.dart';
part 'chat_cubit_adopt.dart';
part 'chat_cubit_polling.dart';
part 'chat_cubit_older.dart';
part 'chat_cubit_internals.dart';

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
class ChatCubit extends Cubit<ChatState>
    with ActionOutcomeCubit<ChatState>
    implements QuietBloc {
  /// `emit` for the part-file extensions, which cannot call the `@protected`
  /// original.
  void _emit(ChatState s) => emit(s);

  ChatCubit({
    required this.conversationId,
    required ConversationsRepository repository,
  }) : _repo = repository,
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

  /// Raw rows fetched on the first paint.
  ///
  /// Sized to cover the view's opening window of 50 VISIBLE messages, at the
  /// ~2.5 raw rows each one costs ([_rawRowsPerVisible]). It used to be 40,
  /// which is about sixteen bubbles — the chat opened, the user scrolled once,
  /// and it was already paging. Bounded either way: the alternative is the
  /// entire transcript, which on a 5,000-message conversation is seconds of
  /// decode before anything paints.
  ///
  /// Safe to raise only because [load] now decodes off the UI isolate. On the
  /// UI thread this many rows would move the cost from "a page the user is
  /// scrolling toward" to "the frame the chat first appears on", which is the
  /// most expensive place in the app to spend it.
  static const _initialLimit = 125;

  /// DEFAULT page size for a backwards step, in RAW rows, used when the
  /// caller has no opinion. A caller that knows how many messages it is
  /// about to reveal passes `rows:` and gets a page sized by [_requestRows].
  ///
  /// Every fetch returns one page of history that gets PREPENDED to what we
  /// already hold — the size varies, the one-page-per-step shape does not.
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

  /// Hard ceiling the server enforces on `?limit=`.
  ///
  /// Named because exceeding it does not error — it silently returns 500 rows,
  /// and the "did we get a full page?" test then reads a short page as *no
  /// more history*. That is what stranded 4,840 messages of a 5,340-message
  /// conversation before cursor paging landed, so anything computing a limit
  /// clamps here rather than trusting its own arithmetic.
  static const _serverRowCeiling = 500;

  /// Roughly how many raw rows it takes to surface one visible message.
  ///
  /// From the same live sample as [_olderPageSize]: 200 raw rows were 89
  /// tool / 94 assistant / 17 user, and consecutive assistant rows collapse
  /// into a single "thinking" pill. Call it two and a half raw rows per row
  /// the user actually sees. Approximate on purpose — it only has to be
  /// close enough that a page covers the reveal it was fetched for, and
  /// over-fetching costs one request either way.
  static const _rawRowsPerVisible = 2.5;

  /// How many raw rows to ask for when the view wants [visible] more
  /// messages, or the default page when it has no opinion.
  ///
  /// The view's reveal step grows as the user travels back through a long
  /// transcript (50, then 100, 200, 400), and a fixed 100-row page stops
  /// covering it after the second step. When that happens the bank runs dry
  /// mid-scroll and the next reveal has to fetch synchronously — the lane
  /// stops, which is the exact failure the page-ahead exists to prevent.
  static int _requestRows(int? visible) {
    if (visible == null) return _olderPageSize;
    final wanted = (visible * _rawRowsPerVisible).ceil();
    if (wanted < _olderPageSize) return _olderPageSize;
    return wanted > _serverRowCeiling ? _serverRowCeiling : wanted;
  }

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

  /// The last message id when the latest send returned — a newer assistant
  /// row after it means the reply already landed, so Stop is no longer due.
  String? _idAtSend;

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
      emit(
        state.copyWith(
          data: DataSuccess(existing),
          hasMoreOlder: _hasMoreFrom(existing),
        ),
      );
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
        emit(
          state.copyWith(
            data: DataSuccess(disk),
            hasMoreOlder: _hasMoreFrom(disk),
          ),
        );
      }
    }
    try {
      // Off the UI isolate. The initial page carries enough rows to fill
      // the chat's opening window, and decoding that much JSON on the UI
      // thread is a visible hitch on exactly the frame the user is watching
      // — the chat painting for the first time. Paging has decoded off-
      // isolate since cursor paging landed; this is the same call for the
      // same reason, and it also picks up the `ok: false` envelope check
      // that the plain-text response type hides from `ErrorInterceptor`.
      final snapshot = await _repo.getSnapshotOffIsolate(
        conversationId,
        limit: _initialLimit,
      );
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
      emit(
        state.copyWith(
          data: DataFailure<ConversationSnapshot>(
            error: ApiErrorMapper.toFailure(e),
            previous: state.data.dataOrNull,
          ),
          actionFailure: ChatActionFailure(
            action: ChatAction.load,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
    }
  }

  /// Manual refresh — the polling tick's code path, asked WITHOUT `?since=`.
  ///
  /// Every caller is a user action that changed something the message stream
  /// does not carry: an approval decided, an environment bound, a credential
  /// toggled. A delta answers "what messages are newer than this cursor",
  /// which is the one question none of them asked — so this used to confirm a
  /// state change by fetching the feed least likely to describe it, and on a
  /// deployment whose deltas travel light the approval card could still be on
  /// screen after the user had already approved it.
  ///
  /// The result merges through [_mergeSnapshot] like any other full snapshot,
  /// so a shorter window can't shrink the transcript the user has paged into.
  Future<void> refresh() => _pollOnce(full: true);

  /// PATCH the per-conversation `auto_approve` flag on the server and
  /// reflect the new value in our snapshot optimistically. Same shape
  /// the web uses, so flipping the switch on either device shows up on
  /// the other after the next poll.
  /// Returns false when the server refused and the toggle was rolled back,
  /// so the view can explain why the switch snapped back.
  Future<bool> setAutoApprove(bool value) =>
      _patchConversationFlag(autoApprove: value);

  /// PATCH the per-conversation `task_prep` flag, on the same terms as
  /// [setAutoApprove] — including **when the current value is null**.
  ///
  /// This doc used to say the opposite ("only call this when the server
  /// actually owns the flag"), and the caller obeyed it. The backend ships the
  /// field nullable with every existing row reset to `null`, so "wait for a
  /// non-null value before writing one" is a deadlock: the app can never give
  /// the field its first value, and only the web ever could. Sending `null →
  /// true` is precisely the PATCH that ends it.
  Future<bool> setTaskPrep(bool value) =>
      _patchConversationFlag(taskPrep: value);

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

  /// Merges a delta snapshot into the cubit state. The contract per
  /// SAQQAR_MOBILE_API.md §4.3 is:
  ///   * **messages**: APPEND when `delta=true`, REPLACE when `delta=false`.
  ///   * Everything else (conversation flags, approvals, artifacts,
  ///     pending actions, available + disabled credentials, run
  ///     progress): always REPLACE in full — even on delta responses.
  ///
  /// "REPLACE in full" is conditioned on the response having actually
  /// SPOKEN about the field — see [_approvalsFor].

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
  Future<void> loadOlder({int? rows}) => _pageOlder(silent: false, rows: rows);

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
  Future<void> prefetchOlder({int? rows}) =>
      _pageOlder(silent: true, rows: rows);

  // ── Sending ─────────────────────────────────────────────────────────

  /// POST `/conversations/<id>/messages/` with the current composer
  /// text + any staged attachments. The server returns a snapshot which
  /// we adopt directly (it's a full one — `delta=false`).
  ///
  /// 409 means the agent's still mid-task; the caller can show a
  /// hint or call [stopGeneration] first.
  Future<bool> sendMessage({
    required String content,
    bool taskPrep = true,
    String? model,
  }) async {
    if (state.isSending) return false;
    final attachmentIds = state.stagedAttachments.map((a) => a.id).toList();
    emit(state.copyWith(isSending: true, clearActionFailure: true));
    try {
      final snapshot = await _repo.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentIds: attachmentIds,
        taskPrep: taskPrep,
        model: model,
      );
      emit(
        state.copyWith(
          data: DataSuccess(snapshot),
          stagedAttachments: const [],
          clearStagedAttachments: true,
          isSending: false,
          awaitingReply: true,
          actionToast: ChatToast.messageSent,
        ),
      );
      _idAtSend = snapshot.messages.lastOrNull?.id;
      _repo.cacheSnapshot(conversationId, snapshot);
      // Immediately bump the polling cadence to "running" speed since
      // the agent is now processing the message we just sent — even though
      // this very snapshot usually still says `is_running: false`.
      _replyGraceLeft = _replyGraceTicks;
      _schedulePoll();
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'sendMessage failed', error: e, stackTrace: st);
      emit(
        state.copyWith(
          isSending: false,
          actionFailure: ChatActionFailure(
            action: ChatAction.send,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
      return false;
    }
  }

  /// Cooperative cancel — the server flips `stop_requested=true`;
  /// the agent worker exits between tool rounds. Idempotent.
  Future<bool> stopGeneration() async {
    if (state.isStopping) return false;
    emit(
      state.copyWith(
        isStopping: true,
        awaitingReply: false,
        clearActionFailure: true,
      ),
    );
    try {
      await _repo.stop(conversationId);
      // The user has cancelled the turn they were waiting on, so the
      // post-send fast-poll grace no longer has anything to wait for.
      _replyGraceLeft = 0;
      // Next poll will pick up the flipped flag — no explicit state
      // mutation here.
      emit(
        state.copyWith(
          isStopping: false,
          actionToast: ChatToast.generationStopped,
        ),
      );
      // Fire-and-forget — we don't need to await the next snapshot to
      // return success; the polling loop will keep state fresh.
      unawaited(_pollOnce());
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'stopGeneration failed', error: e, stackTrace: st);
      emit(
        state.copyWith(
          isStopping: false,
          actionFailure: ChatActionFailure(
            action: ChatAction.stop,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
      return false;
    }
  }

  /// Restarts a run stuck at `conversation.needs_resume == true &&
  /// !is_running` — a genuine dead end the server has already confirmed has
  /// nothing else waiting on the user. POSTs an empty body, then merges the
  /// full snapshot it returns exactly like a poll response — the server's
  /// tool state, approvals and messages all come back fresh, so a plain
  /// `emit(DataSuccess(...))` would risk dropping whatever `_mergeSnapshot`
  /// otherwise reconciles.
  ///
  /// No success/failure toast by design (unlike [stopGeneration]) — the web
  /// behaviour this mirrors just re-enables the button for another tap. The
  /// stored [ChatActionFailure] is still surfaced, though: the chat screen
  /// reads it back inline on the Resume banner itself rather than as a
  /// toast, so a failure is never silent, just not a pop-up.
  Future<bool> resumeRun() async {
    if (state.isResuming) return false;
    emit(state.copyWith(isResuming: true, clearActionFailure: true));
    try {
      final snapshot = await _repo.resume(conversationId);
      if (_disposed) return false;
      _mergeSnapshot(snapshot);
      emit(state.copyWith(isResuming: false));
      // Same reasoning as `sendMessage`: the run has restarted server-side
      // even though this snapshot may still read `is_running: false` for a
      // beat, so force the fast poll cadence rather than waiting for the
      // next idle-interval tick to notice.
      _replyGraceLeft = _replyGraceTicks;
      _schedulePoll();
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'resumeRun failed', error: e, stackTrace: st);
      if (_disposed) return false;
      emit(
        state.copyWith(
          isResuming: false,
          actionFailure: ChatActionFailure(
            action: ChatAction.resume,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
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
      emit(
        state.copyWith(
          stagedAttachments: [...state.stagedAttachments, ...uploaded],
          isUploading: false,
        ),
      );
      for (final a in uploaded) {
        if (a.status == AttachmentStatus.pending) {
          _startAttachmentStatusPoll(a.id);
        }
      }
      return true;
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'uploadAttachments failed',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          isUploading: false,
          actionFailure: ChatActionFailure(
            action: ChatAction.uploadAttachment,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
      return false;
    }
  }

  /// Removes a staged attachment locally (no server call — the
  /// attachment row stays on the server, just isn't included in the
  /// next sendMessage's attachment_ids).
  void removeStagedAttachment(String attachmentId) {
    _attachmentTimers.remove(attachmentId)?.cancel();
    emit(
      state.copyWith(
        stagedAttachments: state.stagedAttachments
            .where((a) => a.id != attachmentId)
            .toList(),
      ),
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
      emit(
        state.copyWith(
          data: DataSuccess(snapshot),
          actionToast: ChatToast.pendingActionDismissed,
        ),
      );
      return true;
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'dismissPendingAction failed',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          actionFailure: ChatActionFailure(
            action: ChatAction.dismissPendingAction,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
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
      AppLogger.warn(
        _tag,
        'setActiveCredential failed',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          actionFailure: ChatActionFailure(
            action: ChatAction.setActiveCredential,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
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
    emit(
      state.copyWith(
        data: DataSuccess(previous.copyWith(disabledCredentials: nextDisabled)),
      ),
    );
    try {
      await _repo.toggleCredential(
        id: conversationId,
        name: name,
        enabled: enabled,
      );
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, 'toggleCredential failed', error: e, stackTrace: st);
      // Rollback.
      emit(
        state.copyWith(
          data: DataSuccess(previous),
          actionFailure: ChatActionFailure(
            action: ChatAction.toggleCredential,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
      return false;
    }
  }

  // ── Sharing ─────────────────────────────────────────────────────────

  Future<bool> shareConversation() async {
    try {
      final result = await _repo.share(conversationId);
      emit(
        state.copyWith(
          lastShareUrl: result.url,
          actionToast: ChatToast.shareLinkCopied,
        ),
      );
      return true;
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'shareConversation failed',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          actionFailure: ChatActionFailure(
            action: ChatAction.share,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
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
      emit(
        state.copyWith(
          actionFailure: ChatActionFailure(
            action: ChatAction.revokeShare,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
      return false;
    }
  }

  // ── One-shot message acknowledgement ────────────────────────────────

  @override
  Object? get currentActionFailure => state.actionFailure;

  @override
  Object? get currentActionToast => state.actionToast;

  @override
  ChatState clearedActionFailure() => state.copyWith(clearActionFailure: true);

  @override
  ChatState clearedActionToast() => state.copyWith(clearActionToast: true);

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
