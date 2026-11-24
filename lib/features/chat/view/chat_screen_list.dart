part of 'chat_screen.dart';

/// The transcript: header, message list, timeline and inline approvals.
extension _ChatTranscript on _ChatScreenState {
  Widget _buildMessageList() {
    // Compute the full visible list ONCE (it subscribes via `context.watch`,
    // so cubit ticks rebuild the screen), then window it to the most-recent
    // current [ChatRevealWindow] for rendering. `all.length` drives whether
    // the "Load earlier" button still has buffered messages to reveal.
    final all = _allVisibleMessages;
    final messages = _lane.window.slice(all);
    // Cache for the AppBar search sheet (read outside build) — searches the
    // WHOLE loaded transcript, not just the rendered window.
    _searchableMessages = all;
    final hasThinking = _effectiveIsThinking;
    // Group consecutive assistant messages into "turns" so we can show
    // a single collapsed "Saqqar thinking · N steps · Xs" pill instead
    // of N separate intermediate bubbles. Final reply in each turn
    // stays expanded as a normal message. Web parity per user request.
    final timeline = _buildTimeline(messages, isRunning: hasThinking);

    // Retry header — the FIRST list item, and shown ONLY when an automatic
    // page has actually failed.
    //
    // It used to render whenever more history existed, which meant that on any
    // long chat the top of the lane permanently read "Load earlier messages".
    // That is a promise the app no longer needs to make: paging is automatic
    // and pages ahead of the user, so an affordance asking them to fetch what
    // is already being fetched is noise at best, and at worst reads as "the
    // chat stopped here" every single time they scroll up. Removed at the
    // product owner's request (2026-07-28) — the header is now purely an error
    // state: a dropped connection or a failing endpoint, where there IS
    // something for the user to do.
    //
    // `_autoLoadEarlierFailed` latches on any failure and clears on the next
    // success, so the pill appears exactly while a retry is worth offering.
    // Rule lives in `earlier_paging.dart` with the rest of the paging policy,
    // and is pinned by `test/earlier_paging_test.dart`.
    final showLoadEarlier = showEarlierRetry(
      isNewChat: _isNewChat,
      hasRenderedMessages: timeline.isNotEmpty,
      lastAttemptFailed: _lane.autoLoadEarlierFailed,
    );
    final headerCount = showLoadEarlier ? 1 : 0;
    final thinkingIndex = headerCount + timeline.length;

    // Pending approvals render inline at the tail of the message list —
    // moved out of the above-composer banner on 2026-05-17 so they
    // scroll like any other message and free the composer space. Each
    // approval becomes its own list item; once the user approves or
    // rejects via the API the snapshot polling drops the row.
    //
    // Source: real `snapshot.approvals` for existing chats (no
    // local-cube overlay anymore — the demo list was producing fake
    // pending rows that didn't exist on the server).
    final List<api.Approval> pendingApprovals = _isNewChat
        ? const []
        : (context
                  .watch<ChatCubit>()
                  .state
                  .data
                  .dataOrNull
                  ?.approvals
                  .where((a) => a.status == api.ApprovalStatus.pending)
                  .toList() ??
              const []);
    // A burst of same-shape writes collapses into one card, exactly as it
    // does on the web — six manufacturing orders are six approvals on the
    // wire but one decision for the user. Singles fall through unchanged, so
    // an ordinary conversation looks identical to before.
    // The newest reply the user can actually read — the only one allowed to
    // carry a Continue button. Steps and empty rows are skipped for the same
    // reason the web skips them (`latestVisibleAssistantMessage`): a button
    // under a tool step would be attached to something the agent did, not to
    // something it said and then stopped after.
    final latestAssistantId = messages
        .lastWhere(
          (m) =>
              m.role == ChatMessageRole.assistant &&
              !m.isAgentStep &&
              m.content.trim().isNotEmpty,
          orElse: () => const ChatMessage(
            role: ChatMessageRole.assistant,
            content: '',
            time: '',
          ),
        )
        .id;

    final approvalGroups = groupApprovalsByShape(pendingApprovals);
    final firstApprovalIndex =
        headerCount + timeline.length + (hasThinking ? 1 : 0);
    final totalCount =
        headerCount +
        timeline.length +
        (hasThinking ? 1 : 0) +
        approvalGroups.length +
        1;

    // Restore / fill / pin, in that order, once the frame has rows — the
    // ordering and every guard live in the coordinator.
    _lane.settleAfterBuild(hasContent: totalCount > 0);

    return NotificationListener<ScrollStartNotification>(
      // `dragDetails != null` filters out programmatic motion: our own
      // corrective `jumpTo`s open a scroll activity too, and arming off one
      // of those would defeat the point of the latch. See
      // [ChatScrollCoordinator.noteUserDrag] for what a drag start means.
      onNotification: (notification) {
        if (notification.dragDetails != null) _lane.noteUserDrag();
        return false;
      },
      child: ListView.builder(
        scrollCacheExtent: const ScrollCacheExtent.pixels(
          AppScrollTuning.cacheExtent,
        ),
        controller: _lane.controller,
        padding: EdgeInsets.zero,
        itemCount: totalCount,
        // ── Why this list is reversed ──────────────────────────────────────
        //
        // `reverse: true` puts scroll offset 0 at the BOTTOM, so index 0 is
        // the newest row and older history grows away from the user. Three
        // things fall out of that, and together they are the difference
        // between paging that feels native and paging that feels homemade:
        //
        //  1. **Opening is free.** A chat rests at the newest message with no
        //     scroll at all — no post-frame `jumpTo`, no estimated extent to
        //     land against, no one-shot restore racing rows that arrive after
        //     it.
        //  2. **Prepending older rows moves nothing.** Older history is
        //     APPENDED at high indices, which is off-screen in the direction
        //     the user is heading. In a forward list the same insert lands at
        //     index 0 and pushes the entire viewport down, which is why this
        //     screen used to carry an anchor-measure / re-measure / `jumpTo`
        //     correction — and why a page landing mid-drag cancelled the
        //     user's gesture.
        //  3. **"Scroll to newest" is `jumpTo(0)`**, not a guess at
        //     `maxScrollExtent` that is itself an estimate while rows below
        //     are unbuilt.
        //
        // The cost is one subtraction per item — [itemBuilder] maps the
        // reversed index back to the logical top-to-bottom order below, so
        // the layout arithmetic reads in the order the list is written.
        reverse: true,
        // Smooth iOS-style scroll on every platform — Android's default
        // `ClampingScrollPhysics` reads as "heavy" / "panicky" the moment
        // you touch the screen. Bouncing physics gives momentum, gentle
        // deceleration, and a soft over-edge cue that matches the
        // conversation tempo. `AlwaysScrollableScrollPhysics` keeps the
        // pull-to-refresh-style drag responsive even when the content
        // fits in one screen (so the user can scroll without the list
        // feeling locked).
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemBuilder: (context, reversedIndex) {
          // Back to logical order: 0 = the retry pill at the very top of the
          // transcript, `totalCount - 1` = the spacer under the newest row.
          // Every index expression below is written in that order because
          // that is the order the reader sees on screen.
          final index = totalCount - 1 - reversedIndex;
          // Retry pill — the first item, and present only while a page has
          // failed. See [ChatLoadEarlierHeader] for why it is an error state only.
          if (headerCount == 1 && index == 0) {
            return ResponsiveContent(
              maxWidth: AppLayoutWidths.chatColumn,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s14,
                AppSpacing.s12,
                AppSpacing.s14,
                AppSpacing.s4,
              ),
              child: ChatLoadEarlierHeader(onRetry: _lane.loadEarlier),
            );
          }

          // Trailing spacer.
          if (index == totalCount - 1) {
            return const SizedBox(height: AppSpacing.s16);
          }

          // Inline approval cards (immediately after thinking row /
          // after the last real message).
          if (index >= firstApprovalIndex &&
              index < firstApprovalIndex + approvalGroups.length) {
            return _approvalRow(approvalGroups, index - firstApprovalIndex);
          }

          // Typing indicator slot — sits after the last timeline entry.
          if (hasThinking && index == thinkingIndex) {
            return _typingRow(timeline);
          }

          // Timeline entry — either a single message bubble or a
          // grouped agent turn (thinking pill + final reply). Subtract the
          // header offset so the index maps back onto the timeline list.
          return _timelineRow(timeline, index - headerCount, latestAssistantId);
        },
      ),
    );
  }

  /// One pending approval (or a collapsed burst of them) at the tail of the
  /// transcript.
  Widget _approvalRow(List<ApprovalGroup> approvalGroups, int approvalIdx) {
    final group = approvalGroups[approvalIdx];
    final approval = group.first;
    // Stable across rebuilds: a GlobalKey minted per build would remount the
    // card every frame.
    final rowKey = _approvalKeys.putIfAbsent(approval.id, GlobalKey.new);
    for (final a in group.approvals) {
      _approvalKeys[a.id] = rowKey;
    }
    return ResponsiveContent(
      key: rowKey,
      maxWidth: AppLayoutWidths.chatColumn,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s8,
        AppSpacing.s14,
        AppSpacing.s4,
      ),
      // ValueKey on approval.id binds the FadeSlideIn state to a
      // specific approval — when 3+ approvals arrive on the same
      // poll tick, Flutter no longer reuses one cached FadeSlideIn
      // for the slot and every card gets its own fresh entrance.
      // Pairing that with `index: approvalIdx` cascades them so
      // they read as "Card 1, then 2, then 3" rather than all
      // popping at once.
      child: FadeSlideIn(
        key: ValueKey('approval-${approval.id}'),
        index: approvalIdx,
        duration: AppDurations.cardIn,
        offset: const Offset(0, AppMotionTravel.riseTight),
        child: group.isGroup
            ? ChatGroupedApprovalCard(
                group: group,
                subtitle: _groupSubtitle(group, context.tr),
                promptOf: (a) => a.prompt.trim().isEmpty
                    ? approvalTitle(a, context.tr)
                    : a.prompt,
                // Both headline buttons carry `scope: "batch"`. That is
                // what makes the count on them true: the server resolves
                // every sibling of this shape, so the card is not firing
                // N requests and hoping they all land.
                onApproveAll: (a) =>
                    _decideApprovalInline(a, true, batchScope: true),
                onRejectAll: (a) =>
                    _decideApprovalInline(a, false, batchScope: true),
                onApproveOne: (a) => _decideApprovalInline(a, true),
                onRejectOne: (a) => _decideApprovalInline(a, false),
              )
            : ChatApprovalCard(
                approval: adaptApiApproval(approval, context.tr),
                onApprove: () => _decideApprovalInline(approval, true),
                onReject: () => _decideApprovalInline(approval, false),
                onApproveAllSimilar: () =>
                    _decideApprovalInline(approval, true, batchScope: true),
              ),
      ),
    );
  }

  /// The typing indicator after the last timeline entry.
  Widget _typingRow(List<TimelineEntry> timeline) {
    final previousMessage = timeline.isEmpty ? null : timeline.last.lastMessage;
    final firstOfGroup =
        previousMessage == null ||
        previousMessage.role != ChatMessageRole.assistant;
    return ResponsiveContent(
      maxWidth: AppLayoutWidths.chatColumn,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s14,
        firstOfGroup ? AppSpacing.s14 : AppSpacing.s2,
        AppSpacing.s14,
        0,
      ),
      child: ChatTypingRow(
        firstOfGroup: firstOfGroup,
        statusLabel: _contextualActivityLabel(previousMessage),
      ),
    );
  }

  /// One timeline entry: the bubble (or grouped agent turn), with a date
  /// separator above the first message of a new day, and the newest row
  /// fading in.
  Widget _timelineRow(
    List<TimelineEntry> timeline,
    int entryIdx,
    String? latestAssistantId,
  ) {
    final entry = timeline[entryIdx];
    final previousEntry = entryIdx == 0 ? null : timeline[entryIdx - 1];
    final entryAnchor = entry.firstMessage;
    final previousLast = previousEntry?.lastMessage;

    // Date separator above the first message of a new calendar day.
    final showDateSeparator =
        entryAnchor.createdAt != null &&
        ChatDateSeparator.needs(
          previousLast?.createdAt,
          entryAnchor.createdAt!,
        );

    // No per-bubble entrance animation here. Wrapping every row in
    // FadeSlideIn meant an `Opacity` (which forces an offscreen
    // `saveLayer`) + two `Transform`s + an AnimationController got
    // re-created and replayed for EVERY message as it scrolled into
    // view — that's what made the lane feel "stiff / frozen" on
    // flick-scroll. Rendering the bubble directly keeps scrolling
    // buttery; the typing row + approval cards still animate (they're
    // few and at the tail, so they don't touch scroll performance).
    final entryWidget = _buildTimelineEntry(
      entry,
      showDateSeparator: showDateSeparator,
      previousLast: previousLast,
      latestAssistantId: latestAssistantId,
    );

    final row = !showDateSeparator
        ? entryWidget
        : Column(
            children: [
              ChatDateSeparator(date: entryAnchor.createdAt!),
              entryWidget,
            ],
          );

    // …with ONE exception: the newest row.
    //
    // A reply landing is the one moment in this screen where something
    // appears while the user is watching it, and having it pop in fully
    // formed is what makes the chat feel mechanical. Fading it up is the
    // difference, and it costs nothing here because there is only ever
    // one of them — the `Opacity` + `Transform` the comment above rules
    // out for every row is affordable for exactly one.
    //
    // Keyed by message id, which is what makes it fire once per arrival
    // rather than once per rebuild: the poll ticks every ~1.5 s, and an
    // unkeyed `FadeSlideIn` here would replay the entrance on each tick.
    // A new id mounts a new element and animates; the same id keeps the
    // element and stays still.
    //
    // Scrolling into history never reaches this branch, so the "stiff on
    // flick-scroll" regression the comment above records cannot come
    // back through it.
    final isNewest = entryIdx == timeline.length - 1;
    if (!isNewest) return row;
    return FadeSlideIn(
      key: ValueKey('newest-${entry.lastMessage.id}'),
      duration: AppDurations.cardIn,
      offset: const Offset(0, AppMotionTravel.riseTight),
      child: row,
    );
  }
}

/// Adapts a server-shaped [api.Message] into the demo-shaped
/// [ChatMessage] the existing chat widgets still consume.
///
/// Temporary bridge — once the chat widgets (MessageRow, MessageBubble,
/// AttachmentChip, ArtifactPill, ApprovalCard) are migrated to take the
/// real model types directly, delete this and read `snapshot.messages`
/// straight into the list view. Keeps the screen-level migration
/// shippable now without forcing all 20+ chat widgets to change at once.
///
/// Takes [BuildContext] so the timestamp label resolves through
/// [AppDateFormat.fullDateTime] — the user sees "May 18, 2026 at 06:24
/// PM" / "١٨ مايو ٢٠٢٦ في ٠٦:٢٤ م" instead of just the bare HH:mm.
/// Matches the web's per-message timestamp footer.
/// The mapping itself lives in `data/message_adapter.dart` so it is testable
/// without a `BuildContext`; this wrapper only resolves the two things that
/// genuinely need one — the localized timestamp label and the attachment
/// size/kind copy.
ChatMessage _adaptApiMessage(api.Message m, BuildContext context) {
  return adaptApiMessage(
    m,
    time: AppDateFormat.fullDateTime(context, m.createdAt),
    attachments: m.attachments
        .map((a) => adaptApiAttachment(a, context.tr))
        .toList(),
    // A tool row reaches the transcript as one readable line inside the
    // thinking pill. The raw result stays on `toolPayload` for anything that
    // wants it; what the user reads is a sentence.
    stepLabel: isAgentStepMessage(m)
        ? completedStepLabel(
            context,
            toolName: m.toolName,
            resultJson: m.content,
          )
        : null,
  );
}
