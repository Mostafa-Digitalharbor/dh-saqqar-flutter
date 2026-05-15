import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../inbox/state/approvals_controller.dart';
import '../state/live_env_ack.dart';
import '../widgets/widgets.dart';

/// The chat screen. Owns the conversation state (messages, active credential,
/// auto-approve toggle, composer text), wires the typing/scroll FSM, and
/// orchestrates the chat widgets and sheets.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  // -------- State --------
  static const _initialLoadDelay = Duration(milliseconds: 550);

  final _composer = TextEditingController();
  final _scroll = ScrollController();
  late List<DemoMessage> _messages;

  /// Active environment id for this conversation. Null means "no env picked
  /// yet" — the chat blocks Send until the user picks one, matching the
  /// web's `state.conversation.environment === null` guard.
  String? _environmentId;

  /// Header project selection. Independent of `_environmentId` so the
  /// dropdown can show "Pick a project first" before the user has chosen
  /// either. Derived from the env's `projectId` on init; cleared when the
  /// user picks a different project so the env dropdown re-resolves.
  String? _projectId;

  bool _autoApprove = false;
  bool _hasAttachment = false;
  bool _showScrollDown = false;
  bool _isThinking = false;
  bool _loadingMessages = false;

  /// When non-null, an inline credential-request card appears between the
  /// status strip and the composer. Triggered from the Action Center when
  /// the user taps "Provide" on a `requestsCredential` action.
  DemoCredentialKind? _inlineCredentialKind;
  Timer? _thinkingTimer;
  Timer? _loadingTimer;

  bool get _isNewChat => widget.conversationId == UiStrings.newConversationId;

  /// True when the conversation id doesn't match any seeded chat AND isn't
  /// the new-chat sentinel. The build method renders a 404 fallback in this
  /// case instead of pretending it's a fresh conversation — protects
  /// against deep links pointing at deleted chats.
  bool get _isUnknownChat {
    if (_isNewChat) return false;
    for (final c in demoConversations) {
      if (c.id == widget.conversationId) return false;
    }
    return true;
  }

  DemoConversation get _conversation {
    return demoConversations.firstWhere(
      (item) => item.id == widget.conversationId,
      orElse: () => DemoConversation(
        id: UiStrings.newConversationId,
        title: context.tr.startConversation,
        preview: context.tr.liveAccessNote,
        updatedLabel: context.tr.now,
        messageCount: 0,
        activeCredential: UiStrings.fallbackCredential,
      ),
    );
  }

  DemoEnvironment? get _environment => demoEnvironmentById(_environmentId);

  /// Title shown in the AppBar subtitle and the picker chip. Falls back to
  /// the localized "No environment" copy when nothing has been picked yet.
  String get _environmentLabel {
    final env = _environment;
    if (env == null) return context.tr.noEnvironmentPicked;
    return demoEnvironmentLabel(env);
  }

  // -------- Lifecycle --------

  @override
  void initState() {
    super.initState();
    _messages = _isNewChat ? <DemoMessage>[] : List.of(demoMessages);

    // Resolve initial env id either from the explicit field on the
    // conversation or via the legacy activeCredential lookup. Null is OK —
    // it means "pick one before sending". Project id is derived from the
    // env so the header dropdowns stay in sync.
    for (final item in demoConversations) {
      if (item.id == widget.conversationId) {
        final env = demoEnvironmentForConversation(item);
        _environmentId = env?.id;
        _projectId = env?.projectId;
        break;
      }
    }
    _scroll.addListener(_onScrollChanged);

    // Existing conversations briefly render skeleton bubbles while the real
    // messages "load". New chats jump straight into the welcome state.
    if (!_isNewChat) {
      _loadingMessages = true;
      _loadingTimer = Timer(_initialLoadDelay, () {
        if (!mounted) return;
        setState(() => _loadingMessages = false);
      });
    }
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _loadingTimer?.cancel();
    _scroll.removeListener(_onScrollChanged);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // -------- Scroll handling --------

  void _onScrollChanged() {
    if (!_scroll.hasClients) return;
    // Show the jump button when the user has scrolled away from the latest
    // message by more than ~one screenful.
    final shouldShow = _scroll.position.extentAfter > 240;
    if (shouldShow != _showScrollDown) {
      setState(() => _showScrollDown = shouldShow);
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottomSoft() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -------- Sending --------

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty && !_hasAttachment) return;

    // Block sends until the user picks an environment — the agent has no
    // credentials to work against otherwise.
    final env = _environment;
    if (env == null) {
      _toast(context.tr.pickEnvironmentToStart);
      await _openEnvironmentPicker();
      return;
    }

    // First time the user sends a message to a live env in this
    // conversation, pop the warning. Persist the ack so it doesn't fire
    // every send. Matches the web's localStorage gate.
    if (env.isLive) {
      final ack = ref.read(liveEnvAckProvider);
      final acknowledged = ack.isAcknowledged(
        conversationId: widget.conversationId,
        envId: env.id,
      );
      if (!acknowledged) {
        final project = demoProjectById(env.projectId);
        if (project == null) return;
        final result = await LiveEnvWarningDialog.show(
          context,
          environment: env,
          project: project,
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

    final reply = context.tr.assistantPlan(demoEnvironmentLabel(env));
    final replyToolName = _autoApprove
        ? UiStrings.demoAutoApprovedTool
        : null;

    setState(() {
      _messages.add(
        DemoMessage(
          role: DemoMessageRole.user,
          content: text.isEmpty ? context.tr.attachedFilesForReview : text,
          time: context.tr.now,
          attachments: _hasAttachment
              ? const [
                  DemoAttachment(
                    name: UiStrings.demoAttachmentName,
                    kind: UiStrings.demoAttachmentKind,
                    size: UiStrings.demoAttachmentSize,
                  ),
                ]
              : const [],
        ),
      );
      _composer.clear();
      _hasAttachment = false;
      _isThinking = true;
    });

    _scrollToBottomSoft();

    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(
          DemoMessage(
            role: DemoMessageRole.assistant,
            content: reply,
            time: context.tr.now,
            toolName: replyToolName,
          ),
        );
      });
      _scrollToBottomSoft();
    });
  }

  void _seedSuggestion(String prompt) {
    _composer.text = prompt;
    _composer.selection = TextSelection.collapsed(offset: prompt.length);
  }

  // -------- Build --------

  /// 404 fallback — fires when a deep link or stale push lands the user on
  /// a conversation that no longer exists. Replaces the older silent
  /// "fresh chat" fallback that hid the actual state.
  Widget _buildNotFound(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.conversationNotFoundTitle)),
      body: AmbientBackground(
        child: Center(
          child: ResponsiveContent(
            maxWidth: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.warning, size: 40, color: s.muted),
                const SizedBox(height: 16),
                Text(
                  context.tr.conversationNotFoundTitle,
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.conversationNotFoundBody,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: s.muted),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: context.tr.backToChats,
                  icon: AppIcons.chevronLeft,
                  onPressed: () => context.go(RouteNames.chatsPath),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnknownChat) return _buildNotFound(context);
    final conversation = _conversation;
    final online = ref.watch(connectivityControllerProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatAppBarTitle(
          conversation: conversation,
          activeCredentialLabel: _environmentLabel,
          autoApprove: _autoApprove,
          onCredentialTap: _openEnvironmentPicker,
        ),
        actions: [
          AppIconButton(
            icon: AppIcons.more,
            tooltip: context.tr.more,
            bordered: false,
            onPressed: _openConversationMenu,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // 3-control header strip: Auto-approve | Project | Environment.
            // Web parity — see ChatHeaderControls. Picking a project clears
            // the env so the user always confirms which env within the new
            // project they want to talk to.
            ChatHeaderControls(
              projectId: _projectId,
              environmentId: _environmentId,
              autoApprove: _autoApprove,
              onProjectChanged: (value) {
                setState(() {
                  _projectId = value;
                  _environmentId = null;
                });
              },
              onEnvironmentChanged: (value) {
                setState(() {
                  _environmentId = value;
                  final env = demoEnvironmentById(value);
                  if (env != null) {
                    _projectId = env.projectId;
                    if (env.autoApprove) _autoApprove = true;
                  }
                });
                if (value != null) {
                  _toast(context.tr.environmentSetForChat);
                }
              },
              onAutoApproveChanged: (value) {
                setState(() => _autoApprove = value);
                _toast(
                  value ? context.tr.autoApproveOn : context.tr.autoApproveOff,
                );
              },
            ),
            const OfflineBanner(),
            Expanded(
              child: Stack(
                children: [
                  if (_loadingMessages)
                    _buildSkeletonList()
                  else if (_messages.isEmpty)
                    ChatWelcome(
                      onSuggestion: _seedSuggestion,
                      onPickCredential: _openEnvironmentPicker,
                      activeCredentialLabel: _environmentLabel,
                    )
                  else
                    _buildMessageList(),
                  PositionedDirectional(
                    end: 16,
                    bottom: 12,
                    child: ChatScrollDownButton(
                      visible: _showScrollDown && _messages.isNotEmpty,
                      onTap: _scrollToBottom,
                    ),
                  ),
                ],
              ),
            ),
            if (_inlineCredentialKind != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: ResponsiveContent(
                    maxWidth: 760,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: InlineCredentialRequest(
                      initialKind: _inlineCredentialKind!,
                      onProvide: (_, __) {
                        setState(() => _inlineCredentialKind = null);
                        _toast(context.tr.inlineCredentialProvided);
                      },
                      onPickSaved: () {
                        setState(() => _inlineCredentialKind = null);
                        _openEnvironmentPicker();
                      },
                      onCancel: () =>
                          setState(() => _inlineCredentialKind = null),
                    ),
                  ),
                ),
              ),
            // Inline pending-approvals strip — sits right above the
            // composer so the user can act without leaving the chat.
            // Replaces the old hidden ⋯-menu entry as the primary surface.
            PendingApprovalsBanner(
              conversationId: widget.conversationId,
              onApprove: _approveInline,
              onReject: _rejectInline,
              onReviewMore: _openApprovals,
            ),
            ChatComposer(
              controller: _composer,
              hasAttachment: _hasAttachment,
              onAttach: () => setState(() => _hasAttachment = !_hasAttachment),
              onSend: online ? _send : null,
            ),
          ],
        ),
      ),
    );
  }

  // -------- Inline approval actions --------

  void _approveInline(DemoApproval approval) {
    final controller = ref.read(approvalsControllerProvider.notifier);
    if (approval.isGrouped) {
      controller.approveAllInGroup(approval);
      _toast(
        context.tr.approvalGrantedWithPreapproval(approval.groupedCount ?? 1),
      );
    } else {
      controller.decide(approval.id, DemoApprovalStatus.approved);
      _toast(context.tr.approvalGrantedExecuting);
    }
  }

  void _rejectInline(DemoApproval approval) {
    ref
        .read(approvalsControllerProvider.notifier)
        .decide(approval.id, DemoApprovalStatus.rejected);
    _toast(context.tr.approvalRejected);
  }

  Widget _buildSkeletonList() {
    // Six placeholder bubbles alternating user/assistant, varying widths
    // so it reads like a real conversation in shape.
    const layout = <({bool isUser, double width, int lines})>[
      (isUser: false, width: 220, lines: 2),
      (isUser: true, width: 180, lines: 1),
      (isUser: false, width: 280, lines: 3),
      (isUser: true, width: 200, lines: 1),
      (isUser: false, width: 240, lines: 2),
      (isUser: false, width: 260, lines: 2),
    ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final row in layout)
          ResponsiveContent(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: MessageBubbleSkeleton(
              isUser: row.isUser,
              bubbleWidth: row.width,
              linesCount: row.lines,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMessageList() {
    final hasThinking = _isThinking;
    final thinkingIndex = _messages.length;
    final totalCount = _messages.length + (hasThinking ? 1 : 0) + 1;

    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // Trailing spacer.
        if (index == totalCount - 1) return const SizedBox(height: 16);

        // Typing indicator slot — sits after the last real message.
        if (hasThinking && index == thinkingIndex) {
          final previous = _messages.isEmpty ? null : _messages.last;
          final firstOfGroup =
              previous == null || previous.role != DemoMessageRole.assistant;
          return ResponsiveContent(
            maxWidth: 760,
            padding: EdgeInsets.fromLTRB(14, firstOfGroup ? 14 : 2, 14, 0),
            child: ChatTypingRow(
              firstOfGroup: firstOfGroup,
              statusLabel: _contextualActivityLabel(previous),
            ),
          );
        }

        final message = _messages[index];
        final previous = index == 0 ? null : _messages[index - 1];
        final next = index == _messages.length - 1
            ? null
            : _messages[index + 1];
        final isFirstOfGroup =
            previous == null || previous.role != message.role;
        // If a typing bubble follows this message, treat it as continuing the
        // assistant's group so the avatar/time logic stays consistent.
        final nextRole =
            next?.role ?? (hasThinking ? DemoMessageRole.assistant : null);
        final isLastOfGroup = nextRole != message.role;

        // Date separator above the first message of a new calendar day.
        final showDateSeparator =
            message.createdAt != null &&
            ChatDateSeparator.needs(previous?.createdAt, message.createdAt!);

        final row = ResponsiveContent(
          maxWidth: 760,
          padding: EdgeInsets.fromLTRB(
            14,
            isFirstOfGroup && !showDateSeparator ? 14 : 2,
            14,
            isLastOfGroup ? 6 : 0,
          ),
          child: MessageRow(
            message: message,
            isFirstOfGroup: isFirstOfGroup,
            isLastOfGroup: isLastOfGroup,
          ),
        );

        // Subtle entry: 6 px slide + opacity over 220 ms. FadeSlideIn
        // respects Reduce Motion automatically. Stagger is disabled
        // (index: 0) because in chat we want each new bubble to feel
        // independent, not part of a cascade.
        final animated = FadeSlideIn(
          duration: const Duration(milliseconds: 220),
          offset: const Offset(0, 6),
          child: row,
        );

        if (!showDateSeparator) return animated;
        return Column(
          children: [ChatDateSeparator(date: message.createdAt!), animated],
        );
      },
    );
  }

  // -------- Sheets --------

  /// Opens the Project → Environment picker. On confirmation, swaps the
  /// active env for this conversation and re-evaluates the live warning
  /// gate (so the user gets a fresh prompt for a new live env).
  /// Picks a contextual progress string for the typing indicator based on
  /// the last user message + attachment state. Matches the web's labels:
  /// "Checking Odoo data", "Building Excel report", "Running database
  /// query", "Reading repository files", "Running server command", etc.
  ///
  /// This is a heuristic — once streaming + real tool-call events arrive
  /// from the backend, swap this for the agent's reported activity.
  String _contextualActivityLabel(DemoMessage? lastMessage) {
    if (lastMessage == null) return context.tr.activityCheckingOdoo;
    if (lastMessage.attachments.isNotEmpty) {
      return context.tr.activityReviewingAttachment;
    }
    final text = lastMessage.content.toLowerCase();
    if (text.contains('export') ||
        text.contains('excel') ||
        text.contains('xlsx') ||
        text.contains('csv') ||
        text.contains('تقرير') ||
        text.contains('صدّر')) {
      return context.tr.activityBuildingReport;
    }
    if (text.contains('log') ||
        text.contains('tail') ||
        text.contains('shell') ||
        text.contains('command') ||
        text.contains('سيرفر') ||
        text.contains('سجل')) {
      return context.tr.activityRunningCommand;
    }
    if (text.contains('postgres') ||
        text.contains('sql') ||
        text.contains('database') ||
        text.contains('قاعدة')) {
      return context.tr.activityRunningQuery;
    }
    if (text.contains('repo') ||
        text.contains('github') ||
        text.contains('addons') ||
        text.contains('module')) {
      return context.tr.activityReadingRepo;
    }
    return context.tr.activityCheckingOdoo;
  }

  Future<void> _openEnvironmentPicker() async {
    final picked = await EnvironmentPickerSheet.show(
      context,
      selectedEnvironmentId: _environmentId,
    );
    if (picked == null) return; // user dismissed
    if (!mounted) return;
    setState(() {
      _environmentId = picked.isEmpty ? null : picked;
      // Env-level auto-approve: when the env opts in, the conversation
      // adopts that default. Web mirrors this — picking an env with
      // `auto_approve: true` flips the chat's auto-approve toggle on.
      // User can still flip it off manually after.
      final env = demoEnvironmentById(_environmentId);
      if (env != null && env.autoApprove) {
        _autoApprove = true;
      }
    });
    _toast(context.tr.environmentSetForChat);
  }

  void _openConversationMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final s = sheetContext.saqqar;
        // Per-conversation counts (post-restructure): the chat sheet only
        // surfaces actions / artifacts raised in THIS chat. Pending
        // approvals moved to the inline PendingApprovalsBanner above the
        // composer, so they're no longer a sheet item.
        final openActions =
            ref.read(conversationOpenActionsProvider(widget.conversationId));
        final artifactsCount =
            demoArtifactsForConversation(widget.conversationId).length;
        return ChatSheet(
          title: sheetContext.tr.more,
          children: [
            ChatSheetItem(
              icon: AppIcons.bolt,
              color: s.brandCyan,
              title: sheetContext.tr.actionCenter,
              trailing: openActions == 0 ? null : MiniChip('$openActions'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openActionCenter();
              },
            ),
            // Pending approvals removed from this menu — they now live in
            // the inline PendingApprovalsBanner above the composer where
            // the user is already focused. The "+ X more pending" link in
            // that banner still opens _openApprovals() for the full list.
            ChatSheetItem(
              icon: AppIcons.fileDown,
              color: s.brandPurple,
              title: sheetContext.tr.artifacts,
              trailing: artifactsCount == 0
                  ? null
                  : MiniChip('$artifactsCount', color: s.brandPurple),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openArtifacts();
              },
            ),
            const SizedBox(height: 4),
            Divider(color: s.border),
            const SizedBox(height: 4),
            ChatSheetItem(
              icon: AppIcons.share,
              title: sheetContext.tr.shareLink,
              onTap: () => _sheetToast(
                sheetContext,
                sheetContext.tr.publicLinkCopied,
              ),
            ),
            ChatSheetItem(
              icon: AppIcons.edit,
              title: sheetContext.tr.rename,
              onTap: () => _sheetToast(
                sheetContext,
                sheetContext.tr.renameConversation,
              ),
            ),
            ChatSheetItem(
              icon: AppIcons.archive,
              title: sheetContext.tr.archive,
              onTap: () =>
                  _sheetToast(sheetContext, sheetContext.tr.archivedToast),
            ),
            ChatSheetItem(
              icon: AppIcons.trash,
              color: s.danger,
              title: sheetContext.tr.delete,
              onTap: () => _sheetToast(
                sheetContext,
                sheetContext.tr.deleteNeedsConfirmation,
              ),
            ),
          ],
        );
      },
    );
  }

  void _openActionCenter() {
    final approvalsState = ref.read(approvalsControllerProvider);
    final openActions =
        demoPendingActionsForConversation(widget.conversationId)
            .where((a) => !approvalsState.isDismissed(a))
            .toList();
    _openListSheet(
      title: context.tr.actionCenter,
      children: openActions.isEmpty
          ? [ChatSheetEmpty(text: context.tr.noAgentActionsTitle)]
          : [
              for (final action in openActions)
                ChatActionCard(
                  title: action.title,
                  body: action.body,
                  icon: action.icon,
                  color: action.color,
                  trailing: action.requestsCredential != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GhostButton(
                              label: context.tr.dismiss,
                              minHeight: 38,
                              onPressed: () {
                                ref
                                    .read(approvalsControllerProvider.notifier)
                                    .dismissAction(action.id);
                                Navigator.of(context).pop();
                                _toast(context.tr.actionDismissed);
                              },
                            ),
                            const SizedBox(width: 8),
                            PrimaryButton(
                              label: context.tr.provideCredential,
                              icon: AppIcons.key,
                              minHeight: 38,
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(
                                  () => _inlineCredentialKind =
                                      action.requestsCredential,
                                );
                              },
                            ),
                          ],
                        )
                      : GhostButton(
                          label: context.tr.dismiss,
                          minHeight: 38,
                          onPressed: () {
                            ref
                                .read(approvalsControllerProvider.notifier)
                                .dismissAction(action.id);
                            Navigator.of(context).pop();
                            _toast(context.tr.actionDismissed);
                          },
                        ),
                ),
            ],
    );
  }

  void _openApprovals() {
    final approvalsState = ref.read(approvalsControllerProvider);
    final pending = demoApprovalsForConversation(widget.conversationId)
        .where(
          (a) => approvalsState.statusFor(a) == DemoApprovalStatus.pending,
        )
        .toList();
    _openListSheet(
      title: context.tr.pendingApprovals,
      children: pending.isEmpty
          ? [ChatSheetEmpty(text: context.tr.noPendingApprovalsTitle)]
          : [
              for (final approval in pending)
                ChatApprovalCard(
                  approval: approval,
                  onApprove: () {
                    final controller =
                        ref.read(approvalsControllerProvider.notifier);
                    if (approval.isGrouped) {
                      controller.approveAllInGroup(approval);
                    } else {
                      controller.decide(
                        approval.id,
                        DemoApprovalStatus.approved,
                      );
                    }
                    Navigator.of(context).pop();
                    _toast(
                      approval.isGrouped && approval.sharedShape != null
                          ? context.tr.approvalGrantedWithPreapproval(
                              approval.groupedCount ?? 1,
                            )
                          : context.tr.approvalGrantedExecuting,
                    );
                  },
                  onReject: () {
                    ref
                        .read(approvalsControllerProvider.notifier)
                        .decide(approval.id, DemoApprovalStatus.rejected);
                    Navigator.of(context).pop();
                    _toast(context.tr.approvalRejected);
                  },
                ),
            ],
    );
  }

  void _openArtifacts() {
    final artifacts = demoArtifactsForConversation(widget.conversationId);
    _openListSheet(
      title: context.tr.artifacts,
      children: artifacts.isEmpty
          ? [ChatSheetEmpty(text: context.tr.noExportsTitle)]
          : [
              for (final artifact in artifacts)
                ChatArtifactTile(
                  artifact: artifact,
                  onOpen: () => _toast(context.tr.opening(artifact.name)),
                ),
            ],
    );
  }

  void _openListSheet({
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ChatSheet(
        title: title,
        children: children
            .expand((child) => [child, const SizedBox(height: 10)])
            .toList(),
      ),
    );
  }

  // -------- Toasts --------

  void _sheetToast(BuildContext sheetContext, String message) {
    Navigator.of(sheetContext).pop();
    _toast(message);
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }
}
