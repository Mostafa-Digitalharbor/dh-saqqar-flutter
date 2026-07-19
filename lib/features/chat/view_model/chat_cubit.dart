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
  static const _attachmentPollInterval = Duration(seconds: 1);
  static const _attachmentPollTimeout = Duration(seconds: 30);

  /// Messages fetched on the first paint. A bounded window keeps the
  /// open-chat path fast — we deserialise + lay out ~40 recent rows
  /// instead of the entire transcript on the UI isolate. Older history
  /// loads on demand via [loadOlder] (the "Load earlier" button).
  static const _initialLimit = 40;

  /// How many MORE raw rows each "Load earlier" fetch pulls. We grow the
  /// `limit` instead of relying on `?before=` (unreliable on the backend)
  /// or a no-`limit` "fetch everything" (the server caps that to a default
  /// page, so it loaded nothing past the cap). A bounded step keeps each
  /// fetch reasonable while still reliably revealing older history.
  static const _olderRawStep = 80;

  /// How many raw rows we've asked the server for so far — grows by
  /// [_olderRawStep] each [loadOlder]. Reset to [_initialLimit] on every
  /// fresh [load].
  int _loadedLimit = _initialLimit;

  final String conversationId;
  final ConversationsRepository _repo;

  Timer? _pollTimer;
  bool _paused = false;
  bool _disposed = false;

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
        emit(state.copyWith(
          data: DataSuccess(disk),
          hasMoreOlder: _hasMoreFrom(disk),
        ));
      }
    }
    try {
      final snapshot =
          await _repo.getSnapshot(conversationId, limit: _initialLimit);
      // Fresh bounded load — pagination restarts from this window.
      _loadedLimit = _initialLimit;
      emit(state.copyWith(
        data: DataSuccess(snapshot),
        hasMoreOlder: _hasMoreFrom(snapshot),
      ));
      _repo.cacheSnapshot(conversationId, snapshot);
      _schedulePoll();
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

  /// Whether there's likely older history to page in: a snapshot whose
  /// message list came back SHORTER than the page we asked for means the
  /// whole transcript fit in one window — so the "Load earlier" button is
  /// hidden. A full page implies there may be more. `loadOlder` refines this
  /// once the user actually pages (an empty/duplicate page flips it false).
  bool _hasMoreFrom(ConversationSnapshot snapshot) =>
      snapshot.messages.length >= _initialLimit;

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
    final interval = state.isRunning ? _runningInterval : _idleInterval;
    _pollTimer = Timer(interval, _pollOnce);
  }

  Future<void> _pollOnce() async {
    if (_paused || _disposed) return;
    final cursor = state.data.dataOrNull?.cursor;
    try {
      final snapshot = await _repo.getSnapshot(
        conversationId,
        since: cursor,
      );
      // Surface the per-conversation toggle values the server is
      // sending so a "toggle doesn't sync" report can be pinpointed
      // to either a missing field in the snapshot or a UI binding
      // issue. Logs are intentionally on the conversation flags only
      // (not message payloads) — the polling tick fires every 1.5 s
      // when running, anything heavier would spam the console.
      AppLogger.info(
        _tag,
        'snapshot conversation flags: autoApprove='
            '${snapshot.conversation.autoApprove}, '
            'deepThink=${snapshot.conversation.deepThink}, '
            'ctxDeepThink=${snapshot.conversation.context['deep_think']}',
      );
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
        final preserved = ConversationSnapshot(
          conversation: incoming.conversation,
          messages: current.messages,
          cursor: current.cursor,
          delta: false,
          approvals: incoming.approvals,
          artifacts: incoming.artifacts,
          availableCredentials: incoming.availableCredentials,
          disabledCredentials: incoming.disabledCredentials,
          pendingActions: incoming.pendingActions,
        );
        emit(state.copyWith(data: DataSuccess(preserved)));
        _repo.cacheSnapshot(conversationId, preserved);
        return;
      }
      // First snapshot or full refresh — adopt verbatim.
      emit(state.copyWith(data: DataSuccess(incoming)));
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
    final merged = ConversationSnapshot(
      conversation: incoming.conversation,
      messages: [...current.messages, ...appended],
      cursor: incoming.cursor ?? current.cursor,
      delta: true,
      approvals: incoming.approvals,
      artifacts: incoming.artifacts,
      availableCredentials: incoming.availableCredentials,
      disabledCredentials: incoming.disabledCredentials,
      pendingActions: incoming.pendingActions,
    );
    emit(state.copyWith(data: DataSuccess(merged)));
    // Keep the cache current so re-opening this chat paints the appended
    // rows too, not just the first page from initial load.
    _repo.cacheSnapshot(conversationId, merged);
  }

  /// Pulls the next chunk of OLDER messages by RE-FETCHING the conversation
  /// with a larger `limit` ([_loadedLimit] + [_olderRawStep]) and replacing
  /// the snapshot with that bigger window. The screen then reveals the new
  /// rows 10 visible at a time.
  ///
  /// Why growing-`limit` instead of `?before=` or a no-`limit` full fetch:
  /// both proved unreliable on the backend (`before` echoed the latest
  /// page; no-`limit` got capped to a default page) — so "Load earlier"
  /// sometimes loaded nothing and needed a manual refresh. `limit` is the
  /// one paging knob the initial load already proves works, so growing it
  /// reliably surfaces older history. The decode runs OFF the UI isolate so
  /// even a large window doesn't jank.
  ///
  /// `hasMoreOlder` flips false only when the server returns FEWER rows than
  /// we asked for — i.e. we've genuinely reached the start of the
  /// transcript — so the button never gets stuck "loading nothing".
  ///
  /// No-op while a fetch is already in flight or once the start is reached.
  Future<void> loadOlder() async {
    if (state.isLoadingOlder || !state.hasMoreOlder) return;
    if (state.data.dataOrNull == null) return;
    emit(state.copyWith(isLoadingOlder: true));
    final nextLimit = _loadedLimit + _olderRawStep;
    try {
      final snapshot = await _repo.getSnapshotOffIsolate(
        conversationId,
        limit: nextLimit,
      );
      _loadedLimit = nextLimit;
      emit(state.copyWith(
        data: DataSuccess(snapshot),
        isLoadingOlder: false,
        hasMoreOlder: snapshot.messages.length >= nextLimit,
      ));
      _repo.cacheSnapshot(conversationId, snapshot);
    } catch (e, st) {
      AppLogger.warn(_tag, 'loadOlder failed', error: e, stackTrace: st);
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
      // the agent is now processing the message we just sent.
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
      data: DataSuccess(ConversationSnapshot(
        conversation: previous.conversation,
        messages: previous.messages,
        cursor: previous.cursor,
        delta: previous.delta,
        approvals: previous.approvals,
        artifacts: previous.artifacts,
        availableCredentials: previous.availableCredentials,
        disabledCredentials: nextDisabled,
        pendingActions: previous.pendingActions,
      )),
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
