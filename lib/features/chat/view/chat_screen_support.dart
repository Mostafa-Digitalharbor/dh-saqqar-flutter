part of 'chat_screen.dart';

/// Drawers, share intake, outward sync, toasts and the small action handlers.
extension _ChatSupport on _ChatScreenState {
  /// Fires whenever the share intake service mutates. We only care about
  /// the "files were just committed to THIS chat" event — the gate
  /// inside [_consumeShareIntake] (`service.take(widget.conversationId)`)
  /// turns every other notification into a no-op.
  void _onShareIntakeChanged() {
    if (!mounted) return;
    final service = _shareIntakeService;
    if (service == null) return;
    if (!service.hasStaged) return;
    if (service.targetChatId != widget.conversationId) return;
    _consumeShareIntake();
  }

  /// Drains [ShareIntakeService] into [_staged]
  /// when the user has just picked this chat as the destination for an
  /// Android share intent. No-op for the common case where the screen
  /// was opened normally (paperclip, tab nav, deep link).
  Future<void> _consumeShareIntake() async {
    final service = context.read<ShareIntakeService>();
    if (!service.hasStaged) return;
    // Gate on the bootstrap's `_targetChatId` — when set, only the
    // chat the user picked drains the batch. When unset (cold-start
    // path, no destination sheet involved), the first chat to land
    // gets the files.
    final files = service.take(widget.conversationId);
    if (files.isEmpty) return;

    // Same caps, same chips, same upload as the paperclip — see
    // [_stageCandidates], which exists because this path used to carry its
    // own copy and shipped with no cap check at all, letting a 200 MB share
    // become a 413 after the upload rather than a message before it.
    //
    // Candidates are built synchronously: `candidateFromFile` uses
    // `lengthSync`, so the `setState` inside `_stageCandidates` lands in the
    // SAME microtask as the deliverTo notification, before any rebuild can
    // intervene. An async version used to lose that setState when the
    // bootstrap's `context.go` happened to recreate the chat page mid-await
    // (2026-05-23 tester report: the file only showed up after exiting and
    // re-entering the chat).
    await _stageCandidates(
      files.map(AttachmentStaging.candidateFromFile),
      // This can run while the screen is mid-teardown, where there is no
      // scaffold left to hang a toast on.
      toastRejections: mounted,
    );
  }

  Widget _sidebarDrawer() {
    if (!_sidebarOpen && _cachedSidebarDrawer == null) {
      return const SizedBox.shrink();
    }
    return _cachedSidebarDrawer ??= ChatSidebarDrawer(
      currentConversationId: widget.conversationId,
      onPickConversation: (String id) {
        _update(() => _sidebarOpen = false);
        if (id != widget.conversationId) {
          context.go(RouteNames.chatPath(id));
        }
      },
      onNewConversation: () {
        _update(() => _sidebarOpen = false);
        context.go(RouteNames.chatPath(UiStrings.routeNewConversation));
      },
      onOpenVault: () {
        _update(() => _sidebarOpen = false);
        context.go(RouteNames.vaultPath);
      },
      // Tapping the wordmark closes the drawer and jumps home (the chats
      // list). Same close-then-go pattern as the other drawer actions.
      onGoHome: () {
        _update(() => _sidebarOpen = false);
        context.go(RouteNames.chatsPath);
      },
      // Close the drawer in-place — flipping the local flag triggers the
      // slide-out animation. Routes don't move.
      onClose: () => _update(() => _sidebarOpen = false),
    );
  }

  Widget _railDrawer() {
    if (!_railOpen && _cachedRailDrawer == null) {
      return const SizedBox.shrink();
    }
    return _cachedRailDrawer = ChatRailDrawer(
      conversationId: widget.conversationId,
      company: _railCompany,
      environment: _railEnvironment,
      onClose: () => _update(() => _railOpen = false),
      onViewApproval: _showApprovalInChat,
    );
  }

  /// "View details" in the rail: close the drawer and bring the request that
  /// needs a decision into view. A request that belongs to another chat opens
  /// that chat instead — its card is not in this transcript.
  void _showApprovalInChat(api.Approval approval) {
    _update(() => _railOpen = false);
    final other = approval.conversation?.id;
    if (other != null && other != widget.conversationId) {
      context.go(RouteNames.chatPath(other));
      return;
    }
    _revealApproval(approval.id);
  }

  /// Scrolls the transcript to the approval's row. The pending cards live at
  /// the tail of the list, so when the row is not built yet the list is first
  /// brought to the tail, then the row is looked up again.
  Future<void> _revealApproval(String id, {int attempt = 0}) async {
    await Future<void>.delayed(AppDurations.sheetIn);
    if (!mounted) return;
    final rowContext = _approvalKeys[id]?.currentContext;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(
        rowContext,
        duration: AppDurations.listFadeIn,
        curve: Curves.easeOutCubic,
        alignment: AppFractions.revealedRowAlignment,
      );
      return;
    }
    if (attempt >= 3) return;
    final controller = _lane.controller;
    if (controller.hasClients) {
      await controller.animateTo(
        0,
        duration: AppDurations.listFadeIn,
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(_revealApproval(id, attempt: attempt + 1));
  }

  /// Pushes what this chat's snapshot knows out to the two app-wide cubits
  /// that other screens read.
  ///
  /// Split out of `build` because it is the one part of it that is not
  /// building anything: `build` derives values and composes widgets, and
  /// these two writes travel in the opposite direction. Both must also be
  /// deferred a frame — calling `emit` on a cubit during `build` is a setState
  /// during build, which Flutter forbids — and burying two
  /// `addPostFrameCallback`s in the middle of a widget tree is how that rule
  /// gets broken by the next person who adds a third.
  ///
  /// Cheap to call on every build: both cubits no-op when already in the
  /// target state, so this costs a post-frame callback and two comparisons.
  void _scheduleOutwardSync(api.Conversation? snapshotConv) {
    if (_isNewChat) return;

    // Surface the latest plan / quota / feature snapshot app-wide (Gap A) so
    // the account usage card, plan badge and feature gating all read one
    // source of truth.
    final planSnapshot = snapshotConv?.plan;
    if (planSnapshot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PlanCubit>().update(planSnapshot);
      });
    }

    // Mirror the SERVER's run state into the cross-app RunningAgentsCubit so
    // the Chats list shows the live "Saqqar is working" indicator for the
    // WHOLE generation, not just the ~1 s send request.
    final running = snapshotConv?.isRunning ?? false;
    final convId = widget.conversationId;
    // Grace window: within ~12 s of a send, keep the optimistic marker even
    // if the snapshot still reads not-running — the server hasn't picked up
    // the new turn yet, and clearing here would race the run to false before
    // it ever flips true.
    final sentAt = _lastSendAt;
    final inGrace =
        sentAt != null &&
        DateTime.now().difference(sentAt) < _ChatScreenState._sendGraceWindow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final agents = context.read<RunningAgentsCubit>();
      if (running) {
        agents.markRunning(convId);
      } else if (!inGrace) {
        agents.markIdle(convId);
      }
    });
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }

  /// Surfaces a failed chat mutation as a two-line error toast — the action
  /// label ("Couldn't send your message") over the mapped, localized cause
  /// ("No internet connection") — then consumes the one-shot failure so it
  /// never re-fires on a later rebuild. Falls back to the generic message
  /// only when there's no classified failure on the cubit (or no cubit yet,
  /// for a brand-new chat).
  /// Runs a conversation-flag PATCH and surfaces the reason if it fails.
  ///
  /// The cubit already rolls the optimistic value back; without this the
  /// user only saw the switch flick back to where it was, with no toast
  /// and no way to tell a refusal from a mis-tap.
  Future<void> _applyToggle(Future<bool> Function() patch) async {
    final ok = await patch();
    if (!ok && mounted) _surfaceActionFailure();
  }

  void _surfaceActionFailure() {
    if (_isNewChat) {
      _toast(context.tr.defaultApiError);
      return;
    }
    final cubit = context.read<ChatCubit>();
    final failure = cubit.state.actionFailure;
    if (failure == null) {
      _toast(context.tr.defaultApiError);
      return;
    }
    AppToast.show(
      context,
      title: _chatActionLabel(failure.action),
      message: ApiErrorMapper.message(context, failure.failure),
      variant: ToastVariant.error,
    );
    cubit.consumeActionFailure();
  }

  /// Localized "what failed" label per [ChatAction].
  String _chatActionLabel(ChatAction action) {
    final tr = context.tr;
    return switch (action) {
      ChatAction.send => tr.chatActionSendFailed,
      ChatAction.uploadAttachment => tr.chatActionUploadFailed,
      ChatAction.stop => tr.chatActionStopFailed,
      ChatAction.share => tr.chatActionShareFailed,
      ChatAction.revokeShare => tr.chatActionRevokeShareFailed,
      ChatAction.setActiveCredential ||
      ChatAction.toggleCredential => tr.chatActionCredentialFailed,
      ChatAction.dismissPendingAction => tr.chatActionDismissFailed,
      // `resume` never actually reaches this switch — the Resume banner
      // deliberately surfaces no toast on failure (spec: the user can just
      // tap again) — but the switch must stay exhaustive over ChatAction.
      ChatAction.load ||
      ChatAction.patch ||
      ChatAction.resume => tr.defaultApiError,
    };
  }

  /// Upgrade CTA target (Gap B) — opens the pricing screen (Gap L) with the
  /// live tiers, where each paid tier hands off to the web checkout on
  /// saqqaar.com. Only reachable when `showPaidUpsell` is on; the banner drops
  /// its CTA entirely otherwise, so this is never a dead end.
  void _openPricing() {
    context.pushNamed(RouteNames.pricing);
  }

  /// Pull-to-refresh handler bound to the message list. Triggers an
  /// out-of-band [ChatCubit.load] so the user gets the freshest snapshot
  /// the instant they ask, instead of waiting on the 1.5 s (running)
  /// or 15 s (idle) polling tick. Awaits the future so the
  /// [RefreshIndicator] spinner stays visible until the snapshot lands.
  /// No-op for new chats — there's no cubit yet to refresh against.
  Future<void> _refreshSnapshot() async {
    if (_isNewChat) return;
    await context.read<ChatCubit>().load();
  }

  /// Task 2 — restarts a run stuck at `needs_resume`. No toast on failure
  /// (per the web behaviour this mirrors — a floating error over the
  /// composer would be jarring for a button the user can just tap again),
  /// but silence alone left a failure indistinguishable from success: the
  /// button would simply re-enable with no clue why nothing happened. So the
  /// reason still surfaces, inline in the banner itself, via
  /// [_resumeFailureMessage] — visible without demanding a dismiss.
  void _resumeRun() {
    if (_isNewChat) return;
    unawaited(context.read<ChatCubit>().resumeRun());
  }

  /// Localized reason the last Resume attempt failed, or null when the last
  /// attempt succeeded (or none has been made yet). Read directly off cubit
  /// state rather than consumed/cleared like a toast: [ChatCubit.resumeRun]
  /// already clears `actionFailure` at the start of the next attempt, so
  /// this naturally disappears the moment the user retries.
  String? _resumeFailureMessage() {
    if (_isNewChat) return null;
    final failure = context.watch<ChatCubit>().state.actionFailure;
    if (failure == null || failure.action != ChatAction.resume) return null;
    return ApiErrorMapper.message(context, failure.failure);
  }

  /// Builds the controllers `initState` used to create inline: the message
  /// list, voice recorder, scroll lane, task-wording controller and the
  /// composer listener.
  void _initControllers() {
    _messages = <ChatMessage>[];
    // The cap fires from inside the recorder; the toast needs a context, so
    // the screen supplies the reaction and the recorder supplies the timing.
    _voice = VoiceNoteRecorder(
      onMaxLengthReached: () {
        if (!mounted) return;
        _toast(context.tr.voiceMaxLength);
        unawaited(_stopRecording());
      },
    )..addListener(_onVoiceChanged);

    // Existing chats resolve their bound env from the server snapshot (see
    // `_resolveEnv`); new chats from the local vault picker. No demo seed.

    // The lane reads two things out of this State and gives back three the
    // build reads. Everything else about paging and offsets is its own.
    _lane = ChatScrollCoordinator(
      conversationId: widget.conversationId,
      isNewChat: _isNewChat,
      loadedVisibleCount: _loadedVisibleCount,
      // Resolved per call, not captured: the cubit comes out of the widget
      // tree and that lookup is only valid while this State is mounted.
      paging: () => ChatCubitPaging(context.read<ChatCubit>()),
      onLoadFailure: _surfaceActionFailure,
    )..addListener(_onLaneChanged);

    _wording = TaskWordingController(api: () => context.read<PromptMemoryApi>())
      ..addListener(_onWordingChanged);

    // The task-wording offer tracks what is being typed. Listening on the
    // controller rather than adding an `onChanged` to ChatComposer keeps the
    // composer unaware of a feature it does not own — and catches text the
    // app itself seeds (a suggestion chip, a shared file's caption), which an
    // onChanged callback would miss.
    _composer.addListener(_onComposerTextChanged);
  }

  /// Drains a share-intent hand-off into the composer, now and whenever the
  /// service notifies.
  void _initShareIntake() {
    // If we arrived here via a share-intent hand-off, drain the staged
    // files into the composer the instant the screen mounts. Deferred to
    // the first post-frame callback because the upload path (existing
    // chats) reads from `context.read<ChatCubit>()`, which only resolves
    // once the BlocProvider above us has built its child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consumeShareIntake();
      // The tools sheet gates on `saqqar_features`, which rides on
      // `/api/v1/usage/` alone — no conversation snapshot carries it. Ask
      // once per session; the cubit no-ops when it already has an answer or
      // a request is in flight, so this stays one round-trip however many
      // chats the user opens.
      if (mounted) {
        unawaited(context.read<SaqqarFeaturesCubit>().ensureLoaded());
      }
    });
    // Also subscribe to the service for the **same-chat case**: when
    // the user is already inside chat A and the destination sheet
    // routes the share to chat A, `context.go('/chats/A')` is a no-op
    // (same route → no initState → no post-frame drain). The listener
    // catches the `deliverTo()` notification the bootstrap fires right
    // before navigation and we drain inline. `_consumeShareIntake`
    // gates on `_targetChatId == widget.conversationId` via
    // [ShareIntakeService.take], so other chat screens that happen to
    // be listening (e.g. an unmounted-soon previous chat) don't snatch
    // the batch.
    _shareIntakeService = context.read<ShareIntakeService>();
    _shareIntakeService!.addListener(_onShareIntakeChanged);
  }

  /// Schedules a post-frame consume when the share service holds a batch for
  /// THIS chat. Called from `build`, hence the deferral (no setState in build).
  void _consumeShareIntakeWhenStaged(BuildContext context) {
    final shareIntake = context.watch<ShareIntakeService>();
    if (shareIntake.hasStaged &&
        shareIntake.targetChatId == widget.conversationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _consumeShareIntake();
      });
    }
  }

  /// Pending approvals on the live snapshot, for the header badge. New chats
  /// have no snapshot yet, so the badge stays 0.
  int _pendingApprovalCount(BuildContext context) {
    return _isNewChat
        ? 0
        : (context
                  .watch<ChatCubit>()
                  .state
                  .data
                  .dataOrNull
                  ?.approvals
                  .where((a) => a.status == api.ApprovalStatus.pending)
                  .length ??
              0);
  }

  /// Width of both slide-in drawers: a fraction of the screen, capped.
  double _drawerWidth(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final drawerWidth =
        screenW * AppFractions.drawer > AppLayoutWidths.drawerCap
        ? AppLayoutWidths.drawerCap
        : screenW * AppFractions.drawer;
    return drawerWidth;
  }
}
