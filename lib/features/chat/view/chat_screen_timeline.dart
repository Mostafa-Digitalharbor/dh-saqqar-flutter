part of 'chat_screen.dart';

/// The transcript's timeline: entries, grouping, activity label and inline approvals.
extension _ChatTimeline on _ChatScreenState {
  /// Renders one [TimelineEntry] as either a plain [MessageRow] or a
  /// [ChatThinkingPill] + the final reply. Keeps the bubble-grouping
  /// (`isFirstOfGroup` / `isLastOfGroup`) heuristics out of the
  /// itemBuilder closure so the index math up top stays readable.
  Widget _buildTimelineEntry(
    TimelineEntry entry, {
    required bool showDateSeparator,
    required ChatMessage? previousLast,
    required String? latestAssistantId,
  }) {
    if (entry is SingleMessageEntry) {
      final message = entry.message;
      final isFirstOfGroup =
          previousLast == null || previousLast.role != message.role;
      return ResponsiveContent(
        maxWidth: AppLayoutWidths.chatColumn,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s14,
          isFirstOfGroup && !showDateSeparator ? AppSpacing.s14 : AppSpacing.s2,
          AppSpacing.s14,
          AppSpacing.s6,
        ),
        child: MessageRow(
          key: message.id.isEmpty ? null : ValueKey('msg-${message.id}'),
          message: message,
          isFirstOfGroup: isFirstOfGroup,
          isLastOfGroup: true,
          isRunning: _effectiveIsThinking,
          isLatestAssistant:
              message.id.isNotEmpty && message.id == latestAssistantId,
          onCardSend: _sendComposed,
          onCardSeed: _seedFromCard,
          entityLoader: _loadReportEntities,
        ),
      );
    }
    final turn = entry as AgentTurnEntry;
    final finalReply = turn.finalReply;
    final pillThenReply = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatThinkingPill(
          steps: turn.thinkingSteps,
          totalDuration: turn.duration,
        ),
        const SizedBox(height: AppSpacing.s6),
        MessageRow(
          key: finalReply.id.isEmpty ? null : ValueKey('msg-${finalReply.id}'),
          message: finalReply,
          isFirstOfGroup: true,
          isLastOfGroup: true,
          isRunning: _effectiveIsThinking,
          isLatestAssistant:
              finalReply.id.isNotEmpty && finalReply.id == latestAssistantId,
          // `_buildTimeline` never folds a card into an agent turn, so this
          // reply cannot be one today. Wired anyway: if that ever changes,
          // the failure would be a silently inert card, not a crash.
          onCardSend: _sendComposed,
          onCardSeed: _seedFromCard,
          entityLoader: _loadReportEntities,
        ),
      ],
    );
    return ResponsiveContent(
      maxWidth: AppLayoutWidths.chatColumn,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s14,
        showDateSeparator ? AppSpacing.s2 : AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s6,
      ),
      child: pillThenReply,
    );
  }

  /// Bundles each user-→-agent round into a [TimelineEntry].
  ///
  /// Lives in `data/chat_timeline.dart` so the grouping — including the rule
  /// that keeps interactive cards out of the collapsed thinking pill — is
  /// testable without pumping the screen.
  List<TimelineEntry> _buildTimeline(
    List<ChatMessage> messages, {
    required bool isRunning,
  }) => buildChatTimeline(messages, isRunning: isRunning);

  /// Opens the Project → Environment picker. On confirmation, swaps the
  /// active env for this conversation and re-evaluates the live warning
  /// gate (so the user gets a fresh prompt for a new live env).
  /// Picks the localised "Saqqar is doing X" label for the typing row.
  ///
  /// Priority:
  ///   1. The last assistant/tool message's `toolName` (real tool call
  ///      reported by the backend) — passed through
  ///      [pendingStatusForTool] for a 1:1 mapping with the web.
  ///   2. Attachment review — covered inside [pendingStatusForTool].
  ///   3. Heuristic guess from the last user message text — used on the
  ///      very first frame after sending, before the backend has chosen a
  ///      tool. Once the chat is wired to the streaming API the heuristic
  ///      branch will only trigger for the first ~200 ms.
  String _contextualActivityLabel(ChatMessage? lastMessage) {
    if (lastMessage == null) {
      return pendingStatusForTool(context, toolName: null);
    }
    final hasAttachment = lastMessage.attachments.isNotEmpty;
    final reportedTool = lastMessage.toolName;
    if (reportedTool != null && reportedTool.isNotEmpty) {
      return pendingStatusForTool(
        context,
        toolName: reportedTool,
        hasAttachment: hasAttachment,
      );
    }
    final guess = guessToolFromPrompt(lastMessage.content);
    return pendingStatusForTool(
      context,
      toolName: guess,
      hasAttachment: hasAttachment,
    );
  }

  /// POSTs the decide call against the real `/approvals/<id>/decision/`
  /// endpoint and refreshes the chat snapshot so the approved/rejected
  /// row drops off the screen instantly (rather than waiting for the
  /// next 1.5 s poll). Errors surface as a toast.
  Future<void> _decideApprovalInline(
    api.Approval approval,
    bool approved, {
    bool batchScope = false,
  }) async {
    final tr = context.tr;
    try {
      final result = await context.read<ApprovalsApi>().decide(
        id: approval.id,
        approved: approved,
        batchScope: batchScope,
        // The backend refuses a bare approve on a destructive delete with
        // a 400, so this key is what makes the delete resolvable at all.
        // Only on an approve: a reject needs no phrase, and sending one
        // there would be a key the server does not expect on that path.
        confirmPhrase: approved ? approval.confirmPhrase : null,
      );
      if (!mounted) return;
      await context.read<ChatCubit>().refresh();
      if (!mounted) return;
      if (!approved) {
        _toast(tr.approvalRejected);
        return;
      }
      // On a batch, report what the tap actually cleared — the count comes
      // back in the response and exists nowhere else, so this is the only
      // moment the user can be told. Falls through to the ordinary message
      // when the server didn't send one rather than printing "Approved 0".
      final resolved = (result.batch?['resolved_count'] as num?)?.toInt();
      _toast(
        batchScope && resolved != null && resolved > 0
            ? tr.approvalBatchResolved(resolved)
            : tr.approvalGrantedExecuting,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// The line under a grouped card's title.
  ///
  /// The server's own prompt is preferred over the technical shape: "Create a
  /// manufacturing order for 40 × Product A" tells the user what they are
  /// approving, where "create on `mrp.production`" tells them which table it
  /// lands in. Every sibling in a group shares the prompt's shape, so the
  /// first one speaks for all of them; the model id is the fallback for a
  /// server that sent no prompt at all.
  String _groupSubtitle(ApprovalGroup group, AppStrings tr) {
    final prompt = group.first.prompt.trim();
    if (prompt.isNotEmpty) return prompt;
    return tr.operationOnModel(
      group.first.payload['operation']?.toString() ?? '',
      group.first.payload['model']?.toString() ?? '',
    );
  }

  Future<void> _openCompanies() {
    return showCompaniesSheet(
      context,
      selectedEnvId: _activeEnvironmentId,
      onSelect: (env) async {
        await _handleEnvironmentsChanged([env.id]);
      },
    );
  }
}
