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

  /// Initial load — fetches the full snapshot (no `?since`). Subsequent
  /// polls use the delta path via [_pollOnce].
  Future<void> load() async {
    if (state.data is DataLoading<ConversationSnapshot>) return;
    emit(state.copyWith(
      data: DataLoading<ConversationSnapshot>(
        previous: state.data.dataOrNull,
      ),
    ));
    try {
      final snapshot = await _repo.getSnapshot(conversationId);
      emit(state.copyWith(data: DataSuccess(snapshot)));
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

  /// Manual refresh — same code path as the polling tick.
  Future<void> refresh() => _pollOnce();

  /// PATCH the per-conversation `auto_approve` flag on the server and
  /// reflect the new value in our snapshot optimistically. Same shape
  /// the web uses, so flipping the switch on either device shows up on
  /// the other after the next poll.
  Future<void> setAutoApprove(bool value) =>
      _patchConversationFlag(autoApprove: value);

  /// PATCH the per-conversation `deep_think` flag. Servers that don't
  /// surface the field yet silently ignore the key — the next poll
  /// just returns the previous value and the local UI flips back.
  Future<void> setDeepThink(bool value) =>
      _patchConversationFlag(deepThink: value);

  Future<void> _patchConversationFlag({
    bool? autoApprove,
    bool? deepThink,
  }) async {
    final current = state.data.dataOrNull;
    if (current == null) return;
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
      // First snapshot or full refresh — adopt verbatim.
      emit(state.copyWith(data: DataSuccess(incoming)));
      return;
    }
    final merged = ConversationSnapshot(
      conversation: incoming.conversation,
      // Append new messages to the existing list. The server only
      // returns rows newer than `?since=`, so duplicates aren't a
      // concern under normal operation.
      messages: [...current.messages, ...incoming.messages],
      cursor: incoming.cursor ?? current.cursor,
      delta: true,
      approvals: incoming.approvals,
      artifacts: incoming.artifacts,
      availableCredentials: incoming.availableCredentials,
      disabledCredentials: incoming.disabledCredentials,
      pendingActions: incoming.pendingActions,
    );
    emit(state.copyWith(data: DataSuccess(merged)));
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

  Future<void> revokeShare() async {
    try {
      await _repo.revokeShare(conversationId);
    } catch (e, st) {
      AppLogger.warn(_tag, 'revokeShare failed', error: e, stackTrace: st);
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
