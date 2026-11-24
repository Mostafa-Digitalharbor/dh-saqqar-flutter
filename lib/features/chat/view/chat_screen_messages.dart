part of 'chat_screen.dart';

/// Which messages the transcript shows, and whether the agent counts as running.
extension _ChatMessages on _ChatScreenState {
  /// Predicate for "this server message is shown to the user" — drops the
  /// agent's internal plumbing (tool outputs, empty tool-call invocations,
  /// system-injected user payloads, `[agent-control]` directives) while
  /// keeping interactive cards, which ride on exactly the rows those first
  /// two rules drop. Shared by [_allVisibleMessages] (render) and
  /// [_loadedVisibleCount] (paging math) so the two never disagree.
  ///
  /// Lives in `data/message_visibility.dart` so it is testable without
  /// pumping the screen — see the note there.
  /// Count of currently-LOADED visible messages (whole loaded snapshot, not
  /// the rendered window). Uses `context.read` so it's safe to call from
  /// event handlers like [_loadEarlier].
  int _loadedVisibleCount() {
    if (_isNewChat) return _messages.length;
    final snapshot = context.read<ChatCubit>().state.data.dataOrNull;
    if (snapshot == null) return 0;
    // Reuse the adapter memo when it is already keyed to this exact snapshot.
    // Same predicate, same input, so the answer is identical — but this is
    // now called from the scroll handler (every frame while the user is near
    // the top of the transcript), and re-running the filter over the whole
    // message list at 60 Hz is the kind of quiet waste that only shows up on
    // a slow phone.
    if (identical(_visibleMemoSnapshot, snapshot) && _visibleMemo != null) {
      return _visibleMemo!.length;
    }
    final running = snapshot.conversation.isRunning;
    return snapshot.messages
        .where((m) => isVisibleMessage(m, isRunning: running))
        .length;
  }

  /// EVERY loaded visible message (no display window), adapted to the
  /// demo-shaped widgets. Source of truth for the count + in-chat search.
  ///
  /// * **Existing chats** — read from the `ChatCubit` snapshot via
  ///   `context.watch`, so the screen rebuilds on each polling tick.
  /// * **New chats** — the local optimistic list (no cubit yet).
  List<ChatMessage> get _allVisibleMessages {
    if (_isNewChat) return _messages;
    final snapshot = context.watch<ChatCubit>().state.data.dataOrNull;
    if (snapshot == null) return const [];
    final localeTag = Localizations.localeOf(context).toString();
    if (identical(_visibleMemoSnapshot, snapshot) &&
        _visibleMemoLocaleTag == localeTag &&
        _visibleMemo != null) {
      return _visibleMemo!;
    }
    // Closure capture: pass `context` into the adapter so the timestamp
    // resolves through the current locale.
    final running = snapshot.conversation.isRunning;
    final adapted = snapshot.messages
        .where((m) => isVisibleMessage(m, isRunning: running))
        .map((m) => _adaptApiMessage(m, context))
        .toList();
    _visibleMemoSnapshot = snapshot;
    _visibleMemoLocaleTag = localeTag;
    _visibleMemo = adapted;
    return adapted;
  }

  /// The windowed slice actually rendered in the lane — the most-recent
  /// [ChatRevealWindow.limit] visible messages. "Load earlier" grows it.
  List<ChatMessage> get _effectiveMessages {
    final all = _allVisibleMessages;
    // A new chat has no window: its handful of optimistic rows are all there
    // is, and there is nothing older to page back to.
    return _isNewChat ? all : _lane.window.slice(all);
  }

  /// True when the server reports the agent is mid-run for this
  /// conversation. For new chats this falls back to the local timer
  /// (kept for the brief window before the create-then-route handoff).
  ///
  /// Respects [_localStopOverride] so the UI reads "stopped" the instant
  /// the user taps Stop, even though the server-side cancel is
  /// cooperative and may take another poll or two to confirm.
  bool get _effectiveIsThinking {
    // A §6 scan runs entirely server-side and only becomes visible once its
    // posted message lands, which can be several seconds. Reusing the
    // existing working indicator is the honest signal — the alternative is
    // a tap that appears to do nothing, or a second "running" affordance
    // that means the same thing.
    if (_toolRunning) return true;
    if (_localStopOverride) return false;
    if (_isNewChat) return _isThinking;
    // Not just the server's flag: the send response usually still says
    // "not running", so also count the request in flight and the short wait
    // for the run to start — otherwise Stop only appeared a second or two
    // late, or never for a fast task.
    final chat = context.watch<ChatCubit>().state;
    return chat.isRunning || chat.isSending || chat.awaitingReply;
  }
}
