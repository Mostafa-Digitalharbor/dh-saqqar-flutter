part of 'conversations_screen.dart';

/// Row actions: share, delete confirmation, archive with undo and the cubit listener.
extension _ConversationActions on _ConversationsScreenState {
  /// Requests a public share link for [c] and hands it to the OS share
  /// sheet (WhatsApp / Telegram / copy-link / …). The link is issued by
  /// `POST /conversations/<id>/share/` — the same token the web share page
  /// (`saqqaar.com/share/<token>/`) consumes. On failure the cubit sets
  /// `actionFailure`, which the screen's BlocListener turns into a toast,
  /// so we just bail here.
  Future<void> _shareConversation(ConversationSummary c) async {
    final cubit = context.read<ConversationsCubit>();
    final url = await cubit.shareConversation(c.id);
    if (!mounted || url == null) return;
    // share_plus 10.x uses the static `Share.share(text, subject:)` API.
    // `subject` is only used as the email subject on the mailto fallback;
    // most share targets ignore it. Falls back to the app name for
    // untitled chats.
    await Share.share(
      url,
      subject: c.title.trim().isEmpty ? context.tr.appName : c.title.trim(),
      // iPad presents the share sheet as a popover and errors out without an
      // anchor. See `sharePositionOrigin`.
      sharePositionOrigin: context.sharePositionOrigin,
    );
  }

  /// Yes/No confirmation before a permanent delete. The confirm button
  /// renders in the danger (red) palette via `destructive: true`, and the
  /// labels reuse the shared confirmYes / confirmNo copy so this reads the
  /// same as the app's other destructive prompts.
  Future<bool> _confirmDelete(ConversationSummary c) {
    return ConfirmDialog.show(
      context,
      title: context.tr.deleteConversationTitle,
      body: context.tr.deleteConversationBody,
      confirmLabel: context.tr.confirmYes,
      cancelLabel: context.tr.confirmNo,
      icon: AppIcons.trash,
      destructive: true,
    );
  }

  Future<void> _handleRowAction(
    ConversationSummary c,
    ConversationAction action,
  ) async {
    final cubit = context.read<ConversationsCubit>();
    switch (action) {
      case ConversationAction.pin:
        cubit.togglePin(c.id);
      case ConversationAction.rename:
        final next = await RenameConversationDialog.show(
          context,
          initial: c.title,
        );
        if (next == null || !mounted) return;
        await cubit.renameConversation(id: c.id, name: next);
      case ConversationAction.archive:
        if (c.isArchived) {
          await cubit.unarchiveConversation(c.id);
          // Collapse the archived drawer so the user lands back on the
          // active list with the newly-restored conversation in it.
          // The list refreshes automatically — cubit emits a new state
          // optimistically the moment the action fires.
          if (mounted && _archivedExpanded) {
            _update(() => _archivedExpanded = false);
          }
        } else {
          await _archiveWithUndo(cubit, c);
        }
      case ConversationAction.delete:
        // Deleting is irreversible, so gate it behind a Yes/No confirm
        // with the destructive (red) confirm button. Applies whether the
        // action came from the row's kebab menu or the swipe-left gesture.
        final confirmed = await _confirmDelete(c);
        if (!confirmed || !mounted) return;
        await cubit.deleteConversation(c.id);
      case ConversationAction.share:
        await _shareConversation(c);
    }
  }

  /// Archives the conversation and surfaces a "Conversation archived"
  /// toast with a one-tap "Show" action that expands the Archived
  /// collapsible card — gives the user an immediate way to find the row
  /// that just disappeared. The card stays collapsed by default so the
  /// main view returns to the active list after the action lands.
  ///
  /// Suppresses the cubit's default archive toast (consumed silently in
  /// [_onCubitChange]) so we don't fire two stacked snackbars.
  Future<void> _archiveWithUndo(
    ConversationsCubit cubit,
    ConversationSummary c,
  ) async {
    await cubit.archiveConversation(c.id);
    if (!mounted) return;
    // Always collapse first — the user's expectation after archiving is
    // "back to my normal list". The toast action below lets them opt
    // into opening the drawer.
    if (_archivedExpanded) {
      _update(() => _archivedExpanded = false);
    }
    AppToast.show(
      context,
      message: context.tr.conversationArchivedToast,
      variant: ToastVariant.success,
      action: ToastAction(
        label: context.tr.showArchivedAction,
        onPressed: () {
          if (!mounted) return;
          _update(() => _archivedExpanded = true);
        },
      ),
    );
  }

  void _onCubitChange(BuildContext context, ConversationsState state) {
    final cubit = context.read<ConversationsCubit>();
    final tr = context.tr;
    if (state.actionFailure != null) {
      final f = state.actionFailure!;
      AppToast.show(
        context,
        title: _actionLabel(tr, f.action),
        message: ApiErrorMapper.message(context, f.failure),
        variant: ToastVariant.error,
      );
      cubit.consumeActionFailure();
    }
    if (state.actionToast != null) {
      // Archive emits its own richer toast (with a "Show" action) from
      // _archiveWithUndo — consume the cubit's plain one silently so we
      // don't stack two snackbars on top of each other.
      if (state.actionToast != ConversationsToast.conversationArchived) {
        AppToast.show(
          context,
          message: _toastMessage(tr, state.actionToast!),
          variant: ToastVariant.success,
        );
      }
      cubit.consumeActionToast();
    }
  }
}
