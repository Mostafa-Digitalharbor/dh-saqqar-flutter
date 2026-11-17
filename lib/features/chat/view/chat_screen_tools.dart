part of 'chat_screen.dart';

/// Composer tools: auto-approve, task prep, the tools sheet, slash commands and task wording.
extension _ChatTools on _ChatScreenState {
  /// Flips the per-conversation auto-approve flag and confirms it in words.
  ///
  /// Extracted from the composer's inline handler so the tools sheet (§1) can
  /// drive the exact same path — the sheet's toggle and the composer's are
  /// the same setting, and a second copy of this logic is how two surfaces
  /// end up disagreeing about whether a refused PATCH rolls back.
  void _setAutoApprove(bool value) {
    // Optimistic local mirror so the switch animates before the snapshot
    // poll catches up.
    _update(() => _autoApprove = value);
    if (!_isNewChat) {
      // Awaited (inside `_applyToggle`) so a refused PATCH surfaces. Fire-
      // and-forget here meant the switch visibly snapped back with no
      // explanation, and left a stale `ChatAction.patch` failure on the
      // state that a later, unrelated error would surface under the wrong
      // label.
      _applyToggle(() => context.read<ChatCubit>().setAutoApprove(value));
    }
    _toast(value ? context.tr.autoApproveOn : context.tr.autoApproveOff);
  }

  /// Flips Task prep and confirms it in words.
  ///
  /// PATCHes on every flip of an existing chat, on exactly the same terms as
  /// [_setAutoApprove], and writes the device preference too so a chat the
  /// server has no opinion about still has a value to fall back on.
  ///
  /// **This used to PATCH only when `conversation.task_prep` was already
  /// non-null**, and that condition was a deadlock. The backend shipped the
  /// field nullable with **every existing row reset to `null`**
  /// (`BACKEND_FIXES_RESPONSE_2.md` §1), so:
  ///
  ///   `task_prep` is null → the app refuses to PATCH → the value stays null
  ///   → the app refuses to PATCH …
  ///
  /// The app could therefore never be the one to give the field its first
  /// value. Only the **web** could, and once it had, mobile started syncing —
  /// which is why this looked intermittent rather than broken. Auto-approve
  /// sits in the same row with no such guard and synced every time, and two
  /// adjacent switches behaving differently is exactly what the user reported,
  /// twice.
  ///
  /// Confirmed on a real device against production on 2026-08-12: the live
  /// snapshot carries `"auto_approve": false, "task_prep": null`, so the guard
  /// was false on every conversation in the account.
  ///
  /// The guard was right when it was written — the server then had no such key
  /// and "never hand it one" was the correct posture. It stopped being right
  /// the day the field shipped. Reading is unchanged and still prefers the
  /// server's value when it has one (see the `taskPrep` line in `build`); only
  /// the write is unconditional now.
  void _setTaskPrep(bool value) {
    if (_isNewChat) {
      // Nothing exists server-side to PATCH yet, so the device preference is
      // the only place the choice can live — and it is exactly what the first
      // send carries (`_sendAsNewConversation(taskPrep: …)`).
      context.read<TaskPrepCubit>().set(value);
    } else {
      // An existing chat writes ONLY that conversation, and deliberately does
      // NOT touch the device preference.
      //
      // Writing both is what made a flip in one chat turn the toggle on in
      // every other one, which the user reported: the read below is
      // `conversation.taskPrep ?? deviceDefault`, so raising the device
      // default re-renders every chat the server still has no opinion about —
      // i.e. every chat nobody has flipped yet. A per-conversation setting
      // that moves its neighbours is not per-conversation.
      //
      // Awaited inside `_applyToggle` for the same reason auto-approve is: a
      // refused PATCH has to surface, or the switch snaps back with no
      // explanation and leaves a stale failure on the state.
      _applyToggle(() => context.read<ChatCubit>().setTaskPrep(value));
    }
    _toast(value ? context.tr.taskPrepOn : context.tr.taskPrepOff);
  }

  /// Task wording (§7) — hands a rough task to `/api/v1/prompt-memory/` and
  /// docks the structured result above the composer for review.
  ///
  /// This used to offer four hardcoded starter prompts, because when it was
  /// written "the backend exposes no saved-prompt catalogue" was true. The
  /// route exists now and returns two things the app cannot author: the
  /// user's own past tasks, ranked, and an LLM rewrite of whatever rough text
  /// it is given. Gated on the `prompt_bank` feature flag, so the row stays
  /// hidden until the backend says this account has the feature.
  ///
  /// The sheet is pre-filled from [_taskWordingContext] — a half-typed
  /// composer, else the last thing the user said.
  Future<void> _openPromptBank() async {
    final query = await TaskWordingSheet.show(
      context,
      initialQuery: _taskWordingContext(),
    );
    if (query == null || !mounted) return;
    await _prepareTaskWording(query);
  }

  /// What the user is most likely asking to have structured: what they have
  /// already half-typed, else their last message. Mirrors the web's
  /// `latestUserPromptContext`.
  String _taskWordingContext() {
    final typed = _composer.text.trim();
    if (typed.isNotEmpty) return typed;
    // [_searchableMessages], not `_effectiveMessages`: the latter reaches the
    // cubit through `context.watch`, which asserts when called from a button
    // callback rather than during build. This is the same build-time cache the
    // in-conversation search sheet reads for exactly that reason, and it holds
    // the whole loaded transcript rather than the rendered window — so a chat
    // scrolled to the top still finds the last thing the user actually said.
    for (final m in _searchableMessages.reversed) {
      if (m.role == ChatMessageRole.user && m.content.trim().isNotEmpty) {
        return m.content.trim();
      }
    }
    return '';
  }

  /// Opens the dock card immediately in its loading state, then fills in the
  /// draft. Opening first is deliberate: the rewrite takes seconds, and a tap
  /// that produces nothing visible reads as a tap that missed.
  /// Asks [TaskWordingController] for a rewrite and says what came back.
  ///
  /// The three-way outcome is the whole reason this is not a bool: a stale
  /// answer must produce no reaction at all, or a request the user closed
  /// toasts at them seconds later.
  Future<void> _prepareTaskWording(String query) async {
    final outcome = await _wording.prepare(
      query,
      lang: Localizations.localeOf(context).languageCode,
      conversationId: _isNewChat ? null : widget.conversationId,
    );
    if (!mounted) return;
    switch (outcome) {
      case TaskWordingReady():
        _toast(context.tr.promptCardAdded);
      case TaskWordingFailed(:final error):
        _toast(ApiErrorMapper.message(context, error));
      case TaskWordingStale():
        break;
    }
  }

  /// "Approve & use" — the draft goes into the composer, unsent.
  void _useTaskWording(String text) {
    if (!_takeTaskWording(text)) return;
    _toast(context.tr.promptInserted);
  }

  /// "Run this" — seeds and sends in one step.
  void _runTaskWording(String text) {
    if (!_takeTaskWording(text)) return;
    _send();
  }

  /// The half the two buttons share: close the card, remember the text has
  /// been acted on, and seed the composer. Returns false when there is
  /// nothing to take.
  bool _takeTaskWording(String text) {
    if (text.trim().isEmpty) return false;
    _wording
      ..close()
      ..markActedOn(text);
    _seedSuggestion(text);
    return true;
  }

  /// The effective task-prep setting: the conversation's when the server owns
  /// one, the device preference otherwise. Same resolution as the send path
  /// uses — a second rule here is how the toggle and the offer end up
  /// disagreeing about whether the feature is on.
  bool get _taskPrepEnabled {
    final fromServer = _isNewChat
        ? null
        : context
              .read<ChatCubit>()
              .state
              .data
              .dataOrNull
              ?.conversation
              .taskPrep;
    return fromServer ?? context.read<TaskPrepCubit>().state;
  }

  void _onComposerTextChanged() => _onComposerChanged(_composer.text);

  /// Re-evaluates the "shall I structure this?" offer as the user types.
  ///
  /// The toggle is resolved here rather than inside the controller because it
  /// is read off the widget tree, and it has to be the same resolution the
  /// send path uses — a second rule is how the toggle and the offer end up
  /// disagreeing about whether the feature is on.
  void _onComposerChanged(String text) =>
      _wording.refreshHint(text, enabled: _taskPrepEnabled);
}
