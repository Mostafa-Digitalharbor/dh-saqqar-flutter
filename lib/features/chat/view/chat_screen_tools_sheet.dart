part of 'chat_screen.dart';

/// The Saqqar tools sheet and the Odoo tool runner behind it.
extension _ChatToolsSheet on _ChatScreenState {
  /// Opens the Saqqar tools sheet — the composer's `+` menu (§1).
  ///
  /// Rows that are already whole mobile screens (Apps, Projects) route to
  /// them; the rest reuse the handlers the composer used to expose directly.
  Future<void> _openToolsSheet({
    required ChatFeatures features,
    required bool taskPrep,
    required bool autoApprove,
  }) async {
    final picked = await SaqqarToolsSheet.show(
      context,
      features: features,
      taskPrep: taskPrep,
      autoApprove: autoApprove,
      onTaskPrepChanged: _setTaskPrep,
      onAutoApproveChanged: _setAutoApprove,
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case SaqqarTool.uploadFile:
        await _pickAttachment();
      case SaqqarTool.commands:
        await _openSlashCommands();
      // §6 — real endpoints (web team, 2026-08-06). Each runs a READ-ONLY
      // scan server-side and posts its report into this conversation, so the
      // result arrives through the ordinary poll.
      //
      // These deliberately skip the live-database warning that `_sendComposed`
      // applies. That prompt exists for WRITES; the three scans cannot write,
      // and putting a "this is production" confirmation in front of a
      // read-only report would train the user to dismiss the one warning that
      // matters. Every other guard still holds server-side: an unbound
      // environment 400s, an unreachable Odoo 502s, and both surface as a
      // toast in the user's language.
      case SaqqarTool.healthRadar:
        await _runOdooTool(
          (api, id, lang) => api.runHealthRadar(conversationId: id, lang: lang),
        );
      case SaqqarTool.whatIf:
        await _runOdooTool(
          (api, id, lang) => api.runWhatIfIntro(conversationId: id, lang: lang),
        );
      case SaqqarTool.businessPulse:
        await _runOdooTool(
          (api, id, lang) =>
              api.runBusinessPulse(conversationId: id, lang: lang),
        );
      case SaqqarTool.promptBank:
        // Reuses the app's own starter prompts — the same list the empty-chat
        // grid offers — so the row seeds real wording rather than inventing a
        // catalogue the backend never sent.
        await _openPromptBank();
      case SaqqarTool.myDatabase:
        await _openEnvironmentPicker();
      case SaqqarTool.apps:
        // PUSH, for the same reason `voiceSupport` below does — and this one
        // was a genuine trap, reported by the user: `go` REPLACES the
        // location, and `/apps` is a top-level route that sits OUTSIDE the
        // tab shell. So opening Saqqar Apps from a chat destroyed the chat's
        // route and landed on a screen with no back button (nothing to pop)
        // and no bottom navigation (outside the shell). The only way out was
        // to kill the app.
        //
        // `credentialVault` below can stay `go` because `/vault` IS a shell
        // tab: the bottom bar is still there, so there is always a way out.
        // That difference is the whole rule — `go` only to a tab, `push` for
        // anything above one.
        unawaited(context.pushNamed(RouteNames.apps));
      case SaqqarTool.credentialVault:
        context.go(RouteNames.vaultPath);
      case SaqqarTool.voiceSupport:
        // PUSH, not go. `go` replaces the location, so opening support from a
        // conversation would destroy that conversation's route and leave the
        // user with no way back to the chat they were describing a problem
        // about. The Account screen reaches its detail screens the same way.
        // Unawaited: the future completes when the user pops back, and
        // awaiting it here would hold the tools-sheet handler open for the
        // whole visit.
        //
        // Carries this conversation's bound database, so a ticket filed from
        // here is created in the Odoo the user was actually asking about
        // rather than whichever environment the account happens to list
        // first. `read`, not the `_activeEnvironmentId` getter — that one
        // watches, and this runs from a callback rather than build.
        final envId =
            context
                .read<ChatCubit>()
                .state
                .data
                .dataOrNull
                ?.conversation
                .environment
                ?.id ??
            _environmentId;
        unawaited(
          context.pushNamed(
            RouteNames.voiceSupport,
            queryParameters: {
              if (envId != null && envId.isNotEmpty)
                RouteNames.voiceSupportEnvQuery: envId,
            },
          ),
        );
    }
  }

  /// Runs one of the three §6 read-only Odoo scans.
  ///
  /// The report is not in the response — the server posts it into the
  /// conversation as an assistant message — so success is reported by
  /// refreshing the snapshot and letting the message appear, exactly as it
  /// would for any other agent output. No local "running" copy is invented:
  /// the thinking indicator the snapshot already drives is the honest one.
  Future<void> _runOdooTool(
    Future<void> Function(
      SaqqarToolsApi api,
      String conversationId,
      String lang,
    )
    run,
  ) async {
    // A tool needs a conversation to post into, and a brand-new chat has no
    // id on the server yet. The rows are reachable from the new-chat composer,
    // so this is a real state rather than a defensive impossibility.
    if (_isNewChat) {
      _toast(context.tr.toolsNeedsConversation);
      return;
    }
    // Re-entry guard: the sheet closes on tap but reopens with the row still
    // there, so a second tap during a slow scan would run it twice and post
    // two reports into the same conversation.
    if (_toolRunning) return;
    final api = context.read<SaqqarToolsApi>();
    final lang = Localizations.localeOf(context).languageCode;
    _update(() => _toolRunning = true);
    try {
      await run(api, widget.conversationId, lang);
      if (!mounted) return;
      await context.read<ChatCubit>().refresh();
    } catch (e) {
      if (!mounted) return;
      // Carries the server's own Arabic string for the two states that
      // actually happen here — no environment bound (400) and Odoo
      // unreachable (502).
      _toast(ApiErrorMapper.message(context, e));
    } finally {
      if (mounted) _update(() => _toolRunning = false);
    }
  }
}
