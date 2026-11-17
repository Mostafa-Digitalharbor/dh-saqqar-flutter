part of 'chat_screen.dart';

/// Sending: the composed message, the new-conversation hand-off, seeding and stop.
extension _ChatSend on _ChatScreenState {
  Future<void> _send() async {
    if (_sending) return;
    _sending = true;
    try {
      await _sendInternal();
    } finally {
      _sending = false;
    }
  }

  /// Sends text an in-chat interactive card composed (§4).
  ///
  /// Routed through the composer + [_send] rather than straight to the cubit
  /// so a card-driven send passes every gate a typed one does: environment
  /// bound, live-env acknowledged, online, under quota, not mid-run. A card
  /// that POSTed directly would be the one path in the screen able to skip
  /// the live-database warning.
  Future<void> _sendComposed(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _composer.text = trimmed;
    _composer.selection = TextSelection.collapsed(offset: trimmed.length);
    await _send();
  }

  /// "Prepare & review" on a clarify card (§4a) — drops the composed answers
  /// in the composer instead of sending them.
  ///
  /// Separate from [_seedSuggestion] (which the starter-prompt strip uses)
  /// purely so this one can TOAST. Seeding silently is the failure this
  /// exists to avoid: the user taps a button at the top of a card, the text
  /// lands in a composer that may be behind the keyboard or off-screen, and
  /// nothing on screen says the tap did anything.
  void _seedFromCard(String text) {
    _seedSuggestion(text);
    _toast(context.tr.clarifyReadyToReview);
  }

  /// Backs the report card's record multi-select (Appendix A.2). Conversation-
  /// scoped, so a brand-new chat (no id yet) has nothing to query.
  Future<ReportEntityPage> _loadReportEntities(
    String entity,
    String query,
  ) async {
    final raw = await context.read<OdooDataApi>().reportEntities({
      'conversation_id': widget.conversationId,
      'entity': entity,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
    return ReportEntityPage.fromJson(raw);
  }

  Future<void> _sendInternal() async {
    final text = _composer.text.trim();
    if (text.isEmpty && _staged.isEmpty) return;

    // Block sends until the user picks an environment — the agent has no
    // credentials to work against otherwise. Resolves real env first
    // (header dropdowns now feed UUIDs from VaultCubit) before falling
    // back to demo env lookup for legacy seeded conversations.
    final env = _resolveEnv();
    if (env == null) {
      // One toast, not two. This used to toast here AND then `await
      // _openEnvironmentPicker()`, whose body is a stub that fires the very
      // same toast — so tapping send with no environment showed the user the
      // identical message twice and opened nothing.
      // Drop the keyboard first: the chat scaffold doesn't resize for it, so a
      // floating toast raised while it is open lands underneath and the send
      // looks like it did nothing at all.
      FocusManager.instance.primaryFocus?.unfocus();
      _toast(context.tr.pickEnvironmentToStart);
      return;
    }

    // First time the user sends a message to a live env in this
    // conversation, pop the warning. Persist the ack so it doesn't fire
    // every send. Matches the web's localStorage gate.
    if (env.isLive) {
      final ack = context.read<LiveEnvAckService>();
      final acknowledged = ack.isAcknowledged(
        conversationId: widget.conversationId,
        envId: env.id,
      );
      if (!acknowledged) {
        final result = await LiveEnvWarningDialog.show(
          context,
          environmentName: env.name,
          projectName: env.projectName,
        );
        if (!mounted) return;
        if (result == LiveAckResult.cancel) return;
        if (result == LiveAckResult.confirmGlobal) {
          await ack.acknowledgeGlobally(envId: env.id);
        } else {
          await ack.acknowledgeForConversation(
            conversationId: widget.conversationId,
            envId: env.id,
          );
        }
        if (!mounted) return;
      }
    }

    // What to send with THIS message. The server still reads `task_prep` off
    // every message body and gates it itself, so the body is always sent —
    // what changes is where the value comes from: the conversation when the
    // server owns one, the device preference otherwise.
    final taskPrep =
        (_isNewChat
            ? null
            : context
                  .read<ChatCubit>()
                  .state
                  .data
                  .dataOrNull
                  ?.conversation
                  .taskPrep) ??
        context.read<TaskPrepCubit>().state;

    // ── New chat path ─────────────────────────────────────────────────
    // We don't have a ChatCubit yet (no UUID to scope it to), so this
    // goes through ConversationsRepository directly:
    //   1. POST /conversations/         → returns a fresh UUID
    //   2. PATCH /conversations/<uuid>/ → binds the picked environment
    //   3. POST .../messages/           → fires the user's first turn
    //   4. router push → /chats/<uuid>  → BlocProvider builds ChatCubit,
    //                                     load() pulls the snapshot
    //                                     containing the just-sent
    //                                     message + the assistant reply
    //                                     once it lands.
    if (_isNewChat) {
      await _sendAsNewConversation(text: text, env: env, taskPrep: taskPrep);
      return;
    }

    // ── Existing chat path ───────────────────────────────────────────
    // ChatCubit owns the snapshot + polling; sendMessage adopts the
    // server's fresh snapshot on success, and the polling loop keeps
    // state alive while the agent processes.
    // Snapshot the staged batch count BEFORE clearing so the success
    // toast below can read "Sent · 3 files attached" — testers asked
    // for explicit feedback that the picker output didn't vanish into
    // the void when they hit Send (2026-05-23).
    final stagedCount = _staged.length;
    // Stash the outgoing text BEFORE clearing the composer so
    // [_stopGeneration] can restore it if the user changes their mind
    // mid-reply. Also clears any stale Stop override from a prior round
    // — a fresh send means the user is committing again.
    _lastSentText = text;
    _localStopOverride = false;
    _composer.clear();
    _update(_staged.clear);
    _lastSendAt = DateTime.now();
    context.read<RunningAgentsCubit>().markRunning(widget.conversationId);
    final ok = await context.read<ChatCubit>().sendMessage(
      content: text.isEmpty ? context.tr.attachedFilesForReview : text,
      taskPrep: taskPrep,
    );
    if (!mounted) return;
    if (ok) {
      _lane.scrollToNewestSoft();
      if (stagedCount > 0) {
        _toast(_sentWithFilesLabel(stagedCount));
      }
    } else {
      // Roll back the composer so the user doesn't lose their text on a
      // failure, then surface the real, localized cause (the cubit already
      // classified it onto `actionFailure`).
      _composer.text = text;
      _surfaceActionFailure();
      // The send never started a run — clear the optimistic marker so the
      // Chats list doesn't show a phantom "working" state.
      context.read<RunningAgentsCubit>().markIdle(widget.conversationId);
    }
    // On success we deliberately DON'T mark idle here: the run has only just
    // begun. The snapshot-driven sync in build() flips it back to idle when
    // the server reports `is_running=false`, so the Chats list shows the
    // live "Saqqar is working" indicator for the whole generation.
  }

  /// Drives the create → bind env → first-message → navigate handoff.
  /// Lives outside [_send] so the new-chat branch reads as one method
  /// call; the heavy lifting (multipart of API calls + rollback) is
  /// here.
  ///
  /// On success: the router pushes `/chats/<newId>`, where a fresh
  /// `BlocProvider<ChatCubit>` builds + calls `load()`, pulling the
  /// snapshot containing the message we just sent. The user sees a
  /// seamless transition from "new chat" to "chat with one message".
  ///
  /// On failure: the composer text is preserved (the user doesn't lose
  /// their typing) and a localized toast surfaces via [ApiErrorMapper].
  Future<void> _sendAsNewConversation({
    required String text,
    required _ResolvedEnv env,
    required bool taskPrep,
  }) async {
    final repo = context.read<ConversationsRepository>();
    final conversationsCubit = context.read<ConversationsCubit>();
    // Snapshot the composer text + the pending attachment file BEFORE
    // we clear local state — the upload below needs the File on disk,
    // and rolling back on failure needs the chip metadata to restore.
    final pendingText = text.isEmpty ? context.tr.attachedFilesForReview : text;
    // Snapshot copies — we'll restore them onto the screen state if any of
    // the create / upload / send steps below blow up, so the user doesn't
    // lose a multi-file batch they painstakingly attached.
    final stagedBatch = List<StagedFile>.from(_staged);
    final pendingFiles = [for (final s in stagedBatch) s.file];
    _composer.clear();
    _update(() {
      _staged.clear();
      _isThinking = true;
    });
    try {
      // 1) Create — title seeds from the first ~70 chars of the prompt
      //    (matches the server's auto-derive behavior, just gives us
      //    a deterministic preview while the conv hits the list cubit).
      final title = pendingText.length > 70
          ? pendingText.substring(0, 70)
          : pendingText;
      final newId = await repo.create(title: title);
      if (!mounted) return;
      // 2) Bind the picked environment and persist auto-approve. Task
      //    prep travels on the message body (step 3), not on the
      //    conversation row, but auto_approve has no such channel — it's
      //    PATCH-only, so a toggle flipped before the first send must be
      //    written here or the server processes that first turn (and any
      //    approval it raises) with the default auto_approve=false.
      await repo.patch(
        id: newId,
        environmentId: env.id,
        // Bind the full multi-env set when the user checked more than the
        // primary in the header pill; null (single-env path) leaves just
        // env.id bound, matching the prior behavior.
        environmentIds: _environmentIds.length > 1 ? _environmentIds : null,
        autoApprove: _autoApprove,
      );
      if (!mounted) return;
      // 2.5) Upload any deferred attachment now that we have a
      //      conversation id. Skipped when there's nothing to upload.
      //      Failures here are surfaced — the user typed/picked
      //      something on purpose, silently dropping it is worse than
      //      a clear error.
      final attachmentIds = <String>[];
      if (pendingFiles.isNotEmpty) {
        final uploaded = await repo.uploadAttachments(
          conversationId: newId,
          files: pendingFiles,
        );
        attachmentIds.addAll(uploaded.map((a) => a.id));
        if (!mounted) return;
      }
      // 3) Send the message — first message in the brand-new conv.
      await repo.sendMessage(
        conversationId: newId,
        content: pendingText,
        attachmentIds: attachmentIds,
        taskPrep: taskPrep,
      );
      if (!mounted) return;
      // 4) Refresh the conversations list so the row appears.
      //    Fire-and-forget — the list refreshes itself when the user
      //    swipes back to the Chats tab anyway.
      unawaited(conversationsCubit.refresh());
      // Same "Sent · N files attached" feedback as the existing-chat
      // path. Fires before the route push so the user sees it on top
      // of the conversations list while the new chat screen mounts.
      if (pendingFiles.isNotEmpty) {
        _toast(_sentWithFilesLabel(pendingFiles.length));
      }
      // 5) Hand off to the real chat route. The router will build a
      //    ChatCubit for the new id which load()s the fresh snapshot.
      context.go(RouteNames.chatPath(newId));
    } catch (e) {
      if (!mounted) return;
      _update(() {
        _isThinking = false;
        // Restore the picked files + chips so the user doesn't have to
        // re-attach after a transient failure (network blip, server
        // 500 between create and send, etc.).
        _staged
          ..clear()
          ..addAll(stagedBatch);
      });
      _composer.text = pendingText == context.tr.attachedFilesForReview
          ? ''
          : pendingText;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Maps the server-reported `conversation.run_progress` (an
  /// `api.RunProgress`) onto the card's [ChatRunProgress] view-model so the
  /// card reflects the REAL export progress the backend streams — no
  /// client-side simulation.
  ///
  /// Returns null on new chats (no snapshot yet) and whenever the backend
  /// isn't mid-report, so the card only appears while a long-running
  /// Excel / PDF / Word job is actually running.
  ChatRunProgress? get _liveRunProgress {
    if (_isNewChat) return null;
    final rp = context
        .watch<ChatCubit>()
        .state
        .data
        .dataOrNull
        ?.conversation
        .runProgress;
    if (rp == null) return null;
    // Server phase is a free-form string (`building_report`,
    // `rendering_report`, …). Anything that reads as a render/write stage
    // maps to the indeterminate "rendering" bar; everything else is the
    // determinate "fetching N/M" bar.
    final rendering = rp.phase.toLowerCase().contains('render');
    return ChatRunProgress(
      phase: rendering ? RunProgressPhase.rendering : RunProgressPhase.fetching,
      current: rp.current,
      total: rp.total,
      rows: rp.current ?? rp.total,
      fileName: rp.label,
    );
  }

  void _seedSuggestion(String prompt) {
    _composer.text = prompt;
    _composer.selection = TextSelection.collapsed(offset: prompt.length);
    // Focus the composer so the user can edit or hit Send without an
    // extra tap — matches the empty-chat suggestion-grid contract.
    _composerFocus.requestFocus();
  }

  /// Cancels the in-flight assistant reply. Two paths:
  ///
  ///   * **Existing chat** — delegates to [ChatCubit.stopGeneration],
  ///     which POSTs `/conversations/<id>/stop/` (the server flips
  ///     `stop_requested=true`; the agent exits between tool rounds).
  ///     The optimistic UI (`isStopping` on the cubit state) drives the
  ///     spinner in the Send button; the polling loop picks up the
  ///     resolved `isRunning=false` and the typing row disappears.
  ///
  ///   * **New chat** — there's no server conversation yet, so just
  ///     cancel the local demo timer.
  Future<void> _stopGeneration() async {
    // ── Optimistic UI flip ──────────────────────────────────────────
    // Hide the typing row + flip the Send button back from Stop the
    // INSTANT the user taps, then restore their last message into the
    // composer so they can edit + resend without retyping. Both happen
    // synchronously inside setState so the next frame already reads as
    // "not thinking".
    final restoreText = _lastSentText;
    _update(() {
      _localStopOverride = true;
      if (restoreText != null &&
          restoreText.isNotEmpty &&
          _composer.text.isEmpty) {
        _composer.text = restoreText;
        _composer.selection = TextSelection.collapsed(
          offset: restoreText.length,
        );
      }
    });
    // Keep the running-agents cubit in sync so the conversation list's
    // pulse dot also clears immediately.
    context.read<RunningAgentsCubit>().markIdle(widget.conversationId);

    if (!_isNewChat) {
      // Fire-and-forget the server cancel — we already showed the UI
      // as stopped; if the POST fails we surface the error via the
      // cubit's actionFailure but the user already got their text back.
      unawaited(context.read<ChatCubit>().stopGeneration());
      if (mounted) _toast(context.tr.generationStopped);
      return;
    }
    // New-chat optimistic path: Stop clears the local "thinking" state
    // and returns the user to the composer (the create/send round-trip is
    // fire-and-forget from here).
    if (_isThinking) {
      _update(() {
        _isThinking = false;
        _stopping = false;
      });
    }
    _toast(context.tr.generationStopped);
  }
}
