part of 'chat_cubit.dart';

/// Conversation-flag PATCHes and attachment status polling.
extension _ChatInternals on ChatCubit {
  Future<bool> _patchConversationFlag({
    bool? autoApprove,
    bool? taskPrep,
  }) async {
    final current = state.data.dataOrNull;
    if (current == null) return false;
    // Optimistic: paint the new value in the snapshot before the
    // server round-trip lands so the toggle responds instantly.
    final optimistic = current.copyWith(
      conversation: current.conversation.copyWith(
        autoApprove: autoApprove ?? current.conversation.autoApprove,
        taskPrep: taskPrep ?? current.conversation.taskPrep,
      ),
    );
    _emit(state.copyWith(data: DataSuccess(optimistic)));
    try {
      final patched = await _repo.patch(
        id: conversationId,
        autoApprove: autoApprove,
        taskPrep: taskPrep,
      );
      // Log the echoed conversation so a divergence between what we
      // sent and what the server kept is visible during sync issues.
      AppLogger.info(
        ChatCubit._tag,
        'PATCH echoed conversation: autoApprove=${patched.autoApprove}, '
        'taskPrep=${patched.taskPrep}',
      );
      // Pull the canonical snapshot so any server-side coercion (e.g.
      // the server normalising auto_approve when the env is read_only)
      // wins over the optimistic value.
      await _pollOnce();
      return true;
    } catch (e, st) {
      AppLogger.warn(
        ChatCubit._tag,
        '_patchConversationFlag(autoApprove=$autoApprove, '
        'taskPrep=$taskPrep) failed',
        error: e,
        stackTrace: st,
      );
      // Rollback the optimistic change.
      _emit(state.copyWith(data: DataSuccess(current)));
      _emit(
        state.copyWith(
          actionFailure: ChatActionFailure(
            action: ChatAction.patch,
            failure: ApiErrorMapper.toFailure(e),
          ),
        ),
      );
      return false;
    }
  }

  /// Polls one attachment's `/status/` endpoint until it flips out of
  /// `pending`. Caps at [ChatCubit._attachmentPollTimeout] — beyond that, the
  /// user gets a "taking longer than expected" hint and can still send.
  void _startAttachmentStatusPoll(String attachmentId) {
    _attachmentTimers[attachmentId]?.cancel();
    final deadline = DateTime.now().add(ChatCubit._attachmentPollTimeout);
    _attachmentTimers[attachmentId] = Timer.periodic(
      ChatCubit._attachmentPollInterval,
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
          _emit(
            state.copyWith(
              stagedAttachments: [
                for (final a in state.stagedAttachments)
                  if (a.id == attachmentId) fresh else a,
              ],
            ),
          );
          if (fresh.status != AttachmentStatus.pending) {
            timer.cancel();
            _attachmentTimers.remove(attachmentId);
            if (fresh.status == AttachmentStatus.ready) {
              _emit(state.copyWith(actionToast: ChatToast.attachmentReady));
            }
          }
        } catch (e, st) {
          AppLogger.warn(
            ChatCubit._tag,
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
}
