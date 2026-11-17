part of 'chat_screen.dart';

/// The chat screen's layout, in pieces: the transcript area, the band above the
/// composer and the two slide-in drawers. `build` wires them together.
extension _ChatLayout on _ChatScreenState {
  /// The transcript: skeleton, empty welcome or the message list, with the
  /// scroll-to-newest button floating over it.
  Widget _transcriptArea(BuildContext context, int pendingForChat) {
    return Stack(
      children: [
        if (_loadingMessages)
          const ChatSkeletonList()
        // `&& pendingForChat == 0`: the inline approval cards live
        // INSIDE the message list, so an empty transcript used to
        // take the list — and every pending approval with it — off
        // the screen, replacing them with suggestion chips.
        //
        // That is not an exotic state. `isVisibleMessage` drops
        // every `tool` row and every empty-content assistant row,
        // which is most of what a run emits, so a turn that goes
        // straight to tool calls and stops at an approval gate has a
        // decision waiting and nothing visible to render it beside.
        // The agent then sits blocked with the one control that
        // could release it never drawn, and the chat inviting the
        // user to start a conversation that is already running.
        //
        // Whether a given turn produced a visible row depends on
        // the task, not the device — which is what makes this look
        // like it works on one phone and not another.
        else if (_effectiveMessages.isEmpty && pendingForChat == 0)
          EmptyChatSuggestions(
            onSuggestionTap: _seedSuggestion,
            userName: context.select<AuthCubit, String>((c) {
              final u = c.state.user;
              if (u == null) return '';
              return u.firstName.trim().isNotEmpty
                  ? u.firstName.trim()
                  : u.displayName;
            }),
          )
        else
          // Pull-down on the message list triggers a fresh
          // snapshot fetch + restarts the poll cadence — gives
          // the user an explicit "fetch latest now" gesture
          // instead of waiting on the 1.5 s / 15 s polling
          // tick. Skips for new chats (no cubit) and the
          // skeleton / empty branches since there's nothing
          // to refresh in those states.
          RefreshIndicator(
            onRefresh: _refreshSnapshot,
            color: context.saqqar.brandCyan,
            child: _buildMessageList(),
          ),
        PositionedDirectional(
          end: AppSpacing.s16,
          bottom: AppSpacing.s12,
          child: ChatScrollDownButton(
            visible: _lane.showScrollDown && _effectiveMessages.isNotEmpty,
            onTap: _lane.scrollToNewest,
          ),
        ),
      ],
    );
  }

  /// Everything between the transcript and the keyboard: banners, suggestions,
  /// task wording and the composer, height-capped against the body.
  Widget _bottomChrome(
    BuildContext context, {
    required BoxConstraints bodyConstraints,
    required bool online,
    required QuotaWindow? quotaWindow,
    required api.Conversation? snapshotConv,
    required bool taskPrep,
    required bool autoApprove,
    required ChatFeatures chatFeatures,
  }) {
    return ChatBottomChrome(
      maxHeight: bodyConstraints.maxHeight * ChatBottomChrome.fractionOfBody,
      children: [
        // Env-hint banner (Gap H) — when the server flags the chat as
        // needing an environment and none is bound yet, offer the
        // one-click "Use My Database" default-env bind above the
        // composer.
        if (!_isNewChat &&
            (snapshotConv?.needsEnvironment ?? false) &&
            _resolveEnv() == null)
          ChatEnvHintBanner(
            busy: _bindingDefaultEnv,
            onUseMyDatabase: _useMyDatabase,
          ),
        // Resume banner (Task 2) — a run that stopped without
        // finishing and with nothing else waiting on the user. The
        // server has already excluded every legitimate pause, so no
        // extra client-side condition is added here on purpose.
        if (!_isNewChat &&
            (snapshotConv?.needsResume ?? false) &&
            !(snapshotConv?.isRunning ?? false))
          ChatResumeBanner(
            busy: context.watch<ChatCubit>().state.isResuming,
            onResume: _resumeRun,
            failureMessage: _resumeFailureMessage(),
          ),
        // Plan/quota banner (Gap A near-limit + Gap B exceeded). Sits
        // directly above the composer so the upgrade CTA is next to
        // the (now disabled) send affordance.
        ChatPlanBanner(
          plan: context.watch<PlanCubit>().state,
          exceededWindow: quotaWindow,
          onUpgrade: _openPricing,
        ),
        // Quick-action suggestion chips — seed the composer with a
        // common Odoo operation. Hidden while recording / transcribing
        // and on a brand-new empty chat (the welcome grid covers that).
        ChatSuggestionStrip(
          visible:
              !_voice.isRecording &&
              !_voice.isTranscribing &&
              _effectiveMessages.isNotEmpty,
          onSelect: _seedSuggestion,
        ),
        // Task wording (web's `promptSuggestions` slot): the card
        // when one is open, otherwise the offer bar, never both —
        // the card IS the answer to what the bar asks.
        if (_wording.isCardOpen)
          TaskWordingCard(
            draft: _wording.draft,
            loading: _wording.loading,
            onUse: _useTaskWording,
            onRun: _runTaskWording,
            onClose: _wording.close,
          )
        else if (_wording.hint case final hint?)
          TaskWordingHintBar(
            onOpen: () => _prepareTaskWording(hint),
            onDismiss: () => _wording.dismissHint(hint),
          ),
        // Inside the band, and last: `reverse: true` rests the scroll
        // at its end, so the composer is the part that stays on screen
        // and the banners above are what scroll away.
        ChatComposer(
          controller: _composer,
          focusNode: _composerFocus,
          attachments: _attachmentChips,
          onAttach: _pickAttachment,
          onTools: () => _openToolsSheet(
            features: chatFeatures,
            taskPrep: taskPrep,
            autoApprove: autoApprove,
          ),
          onRemoveAttachment: _removeAttachmentAt,
          onClearAttachments: _clearAttachments,
          onPreviewAttachment: _previewAttachmentAt,
          // Block send when offline OR over a usage cap (Gap B). The
          // quota banner above explains why send is disabled. The
          // *empty-composer* gate (disable Send until there's text or an
          // attachment) lives inside ChatComposer so it can watch the
          // controller without rebuilding the whole screen — and so the
          // mic stays enabled while the field is empty.
          onSend: (online && quotaWindow == null) ? _send : null,
          // Hide the mic when voice is locked on the plan (Gap C).
          // Null plan → permissive (don't hide a feature we haven't
          // confirmed is locked).
          voiceEnabled:
              !_voiceLocked &&
              (context.watch<PlanCubit>().state?.feature('voice') ?? true),
          // Voice recording — overlay replaces the text field while
          // [_recording] / [_transcribing] is true.
          recording: _voice.isRecording,
          transcribing: _voice.isTranscribing,
          recordingElapsed: _voice.elapsed,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
          onDiscardRecording: _discardRecording,
          taskPrep: taskPrep,
          taskPrepAvailable: chatFeatures.taskPrepAvailable,
          autoApprove: autoApprove,
          onTaskPrepChanged: _setTaskPrep,
          onAutoApproveChanged: _setAutoApprove,
          // Render Stop instead of Send while the agent is running.
          // For existing chats, the source of truth is the cubit's
          // snapshot (`conversation.is_running`); for new chats it
          // still comes from the local timer until the first send
          // creates the conversation + routes.
          // NOT offered while a §6 scan is in flight. The scan reuses the
          // working indicator (honest — something IS running), but it is
          // an HTTP POST to /radar/run/, not a conversation generation:
          // `_stopGeneration` would call stop on a conversation that is
          // not generating, report "generation stopped", and leave the
          // scan running. A Stop button that cannot stop what the user
          // is watching is worse than no Stop button.
          onStop: _effectiveIsThinking && !_toolRunning
              ? _stopGeneration
              : null,
          stopping: _isNewChat
              ? _stopping
              : context.watch<ChatCubit>().state.isStopping,
        ),
      ],
    );
  }

  /// The scrim and the two drawers, as siblings of the main content.
  List<Widget> _drawerLayers({
    required double drawerWidth,
    required bool anyDrawerOpen,
  }) {
    return [
      // ── Scrim (covers main content when any drawer is open) ──
      // Black 55 % per spec §10.1. Tap to close both drawers.
      IgnorePointer(
        ignoring: !anyDrawerOpen,
        child: AnimatedOpacity(
          opacity: anyDrawerOpen ? 1 : 0,
          duration: AppDurations.cardIn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _update(() {
              _sidebarOpen = false;
              _railOpen = false;
            }),
            child: Container(
              color: AppColors.scrimBase.withValues(alpha: AppAlphas.a55),
            ),
          ),
        ),
      ),
      // ── Sidebar (start-side, slides in from left in LTR, right
      // in RTL via AnimatedPositionedDirectional) ──────────────
      AnimatedPositionedDirectional(
        start: _sidebarOpen ? 0 : -drawerWidth,
        top: 0,
        bottom: 0,
        width: drawerWidth,
        duration: AppDurations.sheetIn,
        curve: Curves.easeOutCubic,
        child: _sidebarDrawer(),
      ),
      // ── Rail (end-side, slides in from right in LTR, left in
      // RTL) — holds Approvals + Artifacts + Activity tabs ──
      AnimatedPositionedDirectional(
        end: _railOpen ? 0 : -drawerWidth,
        top: 0,
        bottom: 0,
        width: drawerWidth,
        duration: AppDurations.sheetIn,
        curve: Curves.easeOutCubic,
        child: _railDrawer(),
      ),
    ];
  }
}
