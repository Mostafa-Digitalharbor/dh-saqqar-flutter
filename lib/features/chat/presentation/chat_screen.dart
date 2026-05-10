import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/animations/typing_dots.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../inbox/state/approvals_controller.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  late List<DemoMessage> _messages;
  late String _activeCredential;
  bool _autoApprove = false;
  bool _hasAttachment = false;
  bool _showScrollDown = false;
  bool _isThinking = false;
  Timer? _thinkingTimer;

  bool get _isNewChat => widget.conversationId == UiStrings.newConversationId;

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

  @override
  void initState() {
    super.initState();
    _messages = _isNewChat ? <DemoMessage>[] : List.of(demoMessages);
    String? initialCredential;
    for (final item in demoConversations) {
      if (item.id == widget.conversationId) {
        initialCredential = item.activeCredential;
        break;
      }
    }
    _activeCredential = initialCredential ?? demoCredentials.first.name;
    _scroll.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _scroll.removeListener(_onScrollChanged);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

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

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty && !_hasAttachment) return;

    final reply = context.tr.assistantPlan(_activeCredential);
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

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _ChatAppBarTitle(
          conversation: conversation,
          showSubtitle: _messages.isNotEmpty,
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
            Expanded(
              child: Stack(
                children: [
                  _messages.isEmpty
                      ? _ChatWelcome(
                          onSuggestion: _seedSuggestion,
                          onPickCredential: _openCredentialPicker,
                          activeCredentialLabel: _activeCredentialLabel,
                        )
                      : _buildMessageList(),
                  PositionedDirectional(
                    end: 16,
                    bottom: 12,
                    child: _ScrollDownButton(
                      visible: _showScrollDown && _messages.isNotEmpty,
                      onTap: _scrollToBottom,
                    ),
                  ),
                ],
              ),
            ),
            _StatusStrip(
              activeCredentialLabel: _activeCredentialLabel,
              autoApprove: _autoApprove,
              onCredentialTap: _openCredentialPicker,
              onAutoApproveChanged: (value) {
                setState(() => _autoApprove = value);
                _toast(
                  value ? context.tr.autoApproveOn : context.tr.autoApproveOff,
                );
              },
            ),
            _Composer(
              controller: _composer,
              hasAttachment: _hasAttachment,
              onAttach: () => setState(() => _hasAttachment = !_hasAttachment),
              onSend: _send,
            ),
          ],
        ),
      ),
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
            child: _TypingRow(firstOfGroup: firstOfGroup),
          );
        }

        final message = _messages[index];
        final previous = index == 0 ? null : _messages[index - 1];
        final next = index == _messages.length - 1 ? null : _messages[index + 1];
        final isFirstOfGroup =
            previous == null || previous.role != message.role;
        // If a typing bubble follows this message, treat it as continuing the
        // assistant's group so the avatar/time logic stays consistent.
        final nextRole = next?.role ??
            (hasThinking ? DemoMessageRole.assistant : null);
        final isLastOfGroup = nextRole != message.role;

        return ResponsiveContent(
          maxWidth: 760,
          padding: EdgeInsets.fromLTRB(
            14,
            isFirstOfGroup ? 14 : 2,
            14,
            isLastOfGroup ? 6 : 0,
          ),
          child: _MessageRow(
            message: message,
            isFirstOfGroup: isFirstOfGroup,
            isLastOfGroup: isLastOfGroup,
          ),
        );
      },
    );
  }

  String get _activeCredentialLabel {
    if (_activeCredential == UiStrings.none) {
      return context.tr.credentialNone;
    }
    for (final credential in demoCredentials) {
      if (credential.name == _activeCredential) return credential.label;
    }
    return _activeCredential;
  }

  void _seedSuggestion(String prompt) {
    _composer.text = prompt;
    _composer.selection = TextSelection.collapsed(offset: prompt.length);
  }

  void _openCredentialPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final s = context.saqqar;
        return _ChatSheet(
          title: context.tr.activeCredential,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: s.muted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppIcons.close, size: 18, color: s.muted),
              ),
              title: Text(
                context.tr.credentialNone,
                style: context.text.titleSmall?.copyWith(color: s.muted),
              ),
              subtitle: Text(
                context.tr.credentialNoneHint,
                style: context.text.bodySmall?.copyWith(color: s.muted),
              ),
              trailing: _activeCredential == UiStrings.none
                  ? Icon(AppIcons.check, color: s.brandCyan)
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _activeCredential = UiStrings.none);
                _toast(context.tr.activeCredentialUpdated);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(color: s.border, height: 1),
            ),
            for (final credential in demoCredentials)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: s.brandCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    demoCredentialKindIcon(credential.kind),
                    size: 18,
                    color: s.brandCyan,
                  ),
                ),
                title: Text(credential.label),
                subtitle: Text(
                  '${credential.name} · ${demoCredentialKindLabel(credential.kind)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: credential.name == _activeCredential
                    ? Icon(AppIcons.check, color: s.brandCyan)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _activeCredential = credential.name);
                  _toast(context.tr.activeCredentialUpdated);
                },
              ),
          ],
        );
      },
    );
  }

  void _openConversationMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final s = context.saqqar;
        final approvalsState = ref.read(approvalsControllerProvider);
        final openActions = approvalsState.openActionsCount;
        final pendingApprovals = approvalsState.pendingCount;
        return _ChatSheet(
          title: context.tr.more,
          children: [
            _SheetItem(
              icon: AppIcons.bolt,
              color: s.brandCyan,
              title: context.tr.actionCenter,
              trailing: openActions == 0
                  ? null
                  : MiniChip('$openActions'),
              onTap: () {
                Navigator.of(context).pop();
                _openActionCenter();
              },
            ),
            _SheetItem(
              icon: AppIcons.shieldCheck,
              color: s.warning,
              title: context.tr.pendingApprovals,
              trailing: pendingApprovals == 0
                  ? null
                  : MiniChip('$pendingApprovals', color: s.warning),
              onTap: () {
                Navigator.of(context).pop();
                _openApprovals();
              },
            ),
            _SheetItem(
              icon: AppIcons.fileDown,
              color: s.brandPurple,
              title: context.tr.artifacts,
              trailing: MiniChip(
                '${demoArtifacts.length}',
                color: s.brandPurple,
              ),
              onTap: () {
                Navigator.of(context).pop();
                _openArtifacts();
              },
            ),
            const SizedBox(height: 4),
            Divider(color: s.border),
            const SizedBox(height: 4),
            _SheetItem(
              icon: AppIcons.share,
              title: context.tr.shareLink,
              onTap: () => _sheetToast(context, context.tr.publicLinkCopied),
            ),
            _SheetItem(
              icon: AppIcons.edit,
              title: context.tr.rename,
              onTap: () => _sheetToast(context, context.tr.renameConversation),
            ),
            _SheetItem(
              icon: AppIcons.archive,
              title: context.tr.archive,
              onTap: () => _sheetToast(context, context.tr.archivedToast),
            ),
            _SheetItem(
              icon: AppIcons.trash,
              color: s.danger,
              title: context.tr.delete,
              onTap: () =>
                  _sheetToast(context, context.tr.deleteNeedsConfirmation),
            ),
          ],
        );
      },
    );
  }

  Widget _sheetEmpty(BuildContext context, String text) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: s.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: s.success.withValues(alpha: 0.24)),
            ),
            child: Icon(AppIcons.success, color: s.success, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: s.muted),
          ),
        ],
      ),
    );
  }

  void _openActionCenter() {
    final approvalsState = ref.read(approvalsControllerProvider);
    final openActions = demoPendingActions
        .where((a) => !approvalsState.isDismissed(a))
        .toList();
    _openListSheet(
      title: context.tr.actionCenter,
      children: openActions.isEmpty
          ? [_sheetEmpty(context, context.tr.noAgentActionsTitle)]
          : [
              for (final action in openActions)
                _ActionCard(
                  title: action.title,
                  body: action.body,
                  icon: action.icon,
                  color: action.color,
                  trailing: GhostButton(
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
    final pending = demoApprovals
        .where(
          (a) => approvalsState.statusFor(a) == DemoApprovalStatus.pending,
        )
        .toList();
    _openListSheet(
      title: context.tr.pendingApprovals,
      children: pending.isEmpty
          ? [_sheetEmpty(context, context.tr.noPendingApprovalsTitle)]
          : [
              for (final approval in pending)
                _ApprovalCard(
                  approval: approval,
                  onApprove: () {
                    ref
                        .read(approvalsControllerProvider.notifier)
                        .decide(approval.id, DemoApprovalStatus.approved);
                    Navigator.of(context).pop();
                    _toast(context.tr.approvalGrantedExecuting);
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

  void _openArtifacts() => _openListSheet(
    title: context.tr.artifacts,
    children: [
      for (final artifact in demoArtifacts)
        _ArtifactTile(
          artifact: artifact,
          onOpen: () => _toast(context.tr.opening(artifact.name)),
        ),
    ],
  );

  void _openListSheet({required String title, required List<Widget> children}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ChatSheet(
        title: title,
        children: children
            .expand((child) => [child, const SizedBox(height: 10)])
            .toList(),
      ),
    );
  }

  void _sheetToast(BuildContext sheetContext, String message) {
    Navigator.of(sheetContext).pop();
    _toast(message);
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }
}

// ============================================================================
// AppBar
// ============================================================================

class _ChatAppBarTitle extends StatelessWidget {
  const _ChatAppBarTitle({
    required this.conversation,
    required this.showSubtitle,
  });

  final DemoConversation conversation;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.vivid,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(AppIcons.sparkles, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.1,
                  ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: s.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr.live,
                        style: context.text.labelSmall?.copyWith(
                          color: s.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Welcome / empty state
// ============================================================================

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome({
    required this.onSuggestion,
    required this.onPickCredential,
    required this.activeCredentialLabel,
  });

  final ValueChanged<String> onSuggestion;
  final VoidCallback onPickCredential;
  final String activeCredentialLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final suggestions = [
      _Suggestion(
        icon: AppIcons.database,
        text: 'Show me how many users are in Odoo right now.',
        accent: s.brandCyan,
      ),
      _Suggestion(
        icon: AppIcons.fileDown,
        text: 'Export active internal users as Excel.',
        accent: s.success,
      ),
      _Suggestion(
        icon: AppIcons.terminal,
        text: 'Tail the Odoo server log for the last 100 lines.',
        accent: s.brandPurple,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.vivid,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              AppIcons.sparkles,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr.startConversation,
          textAlign: TextAlign.center,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr.liveAccessNote,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: s.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onPickCredential,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: s.brandCyan.withValues(alpha: 0.10),
                  border: Border.all(
                    color: s.brandCyan.withValues(alpha: 0.30),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.key, size: 14, color: s.brandCyan),
                    const SizedBox(width: 8),
                    Text(
                      activeCredentialLabel,
                      style: context.text.labelMedium?.copyWith(
                        color: s.brandCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(AppIcons.chevronDown, size: 14, color: s.brandCyan),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (final suggestion in suggestions) ...[
          _SuggestionTile(
            suggestion: suggestion,
            onTap: () => onSuggestion(suggestion.text),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Suggestion {
  const _Suggestion({
    required this.icon,
    required this.text,
    required this.accent,
  });
  final IconData icon;
  final String text;
  final Color accent;
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final _Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.90),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: suggestion.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: suggestion.accent.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  suggestion.icon,
                  size: 18,
                  color: suggestion.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion.text,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.text,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 18, color: s.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Status strip (above composer)
// ============================================================================

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.activeCredentialLabel,
    required this.autoApprove,
    required this.onCredentialTap,
    required this.onAutoApproveChanged,
  });

  final String activeCredentialLabel;
  final bool autoApprove;
  final VoidCallback onCredentialTap;
  final ValueChanged<bool> onAutoApproveChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return ResponsiveContent(
      maxWidth: 980,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: _CredentialChip(
              label: activeCredentialLabel,
              onTap: onCredentialTap,
            ),
          ),
          const SizedBox(width: 8),
          _AutoApproveSwitch(
            value: autoApprove,
            color: autoApprove ? s.brandCyan : s.muted,
            onChanged: onAutoApproveChanged,
          ),
        ],
      ),
    );
  }
}

class _CredentialChip extends StatelessWidget {
  const _CredentialChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.brandCyan.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.key, size: 13, color: s.brandCyan),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(AppIcons.chevronDown, size: 13, color: s.brandCyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoApproveSwitch extends StatelessWidget {
  const _AutoApproveSwitch({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr.autoApproveSubtitle,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 34,
            padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 4, 0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: value ? 0.14 : 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.26)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.shieldCheck, size: 13, color: color),
                const SizedBox(width: 6),
                Text(
                  context.tr.autoApprove,
                  style: context.text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _MiniSwitch(value: value, color: color),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.color});

  final bool value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const trackW = 28.0;
    const trackH = 16.0;
    return Container(
      width: trackW,
      height: trackH,
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.85) : context.saqqar.surface3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: trackH - 4,
            height: trackH - 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Scroll-to-bottom button
// ============================================================================

// ============================================================================
// Typing indicator
// ============================================================================

class _TypingRow extends StatelessWidget {
  const _TypingRow({required this.firstOfGroup});

  final bool firstOfGroup;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    final avatarSlot = SizedBox(
      width: 32,
      child: firstOfGroup
          ? const _ChatAvatar(isUser: false)
          : const SizedBox.shrink(),
    );
    const gap = SizedBox(width: 10);

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: s.border),
      ),
      child: TypingDots(color: s.muted, dotSize: 7),
    );

    final isRtl = context.isRtl;
    final children = isRtl ? [bubble, gap, avatarSlot] : [avatarSlot, gap, bubble];

    return Row(
      mainAxisAlignment: isRtl
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }
}

class _ScrollDownButton extends StatelessWidget {
  const _ScrollDownButton({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.3),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.surface.withValues(
                    alpha: context.isDark ? 0.94 : 0.98,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: s.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF020617,
                      ).withValues(alpha: context.isDark ? 0.30 : 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  AppIcons.chevronDown,
                  size: 20,
                  color: s.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Message rendering
// ============================================================================

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
  });

  final DemoMessage message;
  final bool isFirstOfGroup;
  final bool isLastOfGroup;

  bool get _isUser => message.role == DemoMessageRole.user;
  bool get _isTool => message.role == DemoMessageRole.tool;

  @override
  Widget build(BuildContext context) {
    if (_isTool) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 42),
        child: _ToolActivityCard(message: message),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final factor = constraints.maxWidth < 480 ? 0.86 : 0.78;
        final bubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * factor),
          child: _BubblePlate(
            isUser: _isUser,
            message: message,
            showTime: isLastOfGroup,
          ),
        );

        final avatarSlot = SizedBox(
          width: 32,
          child: isFirstOfGroup
              ? _ChatAvatar(isUser: _isUser)
              : const SizedBox.shrink(),
        );
        final gap = const SizedBox(width: 10);
        final userOnLeft = context.isRtl;

        final children = _isUser
            ? (userOnLeft ? [avatarSlot, gap, bubble] : [bubble, gap, avatarSlot])
            : (context.isRtl ? [bubble, gap, avatarSlot] : [avatarSlot, gap, bubble]);

        return Row(
          mainAxisAlignment: _isUser
              ? (userOnLeft ? MainAxisAlignment.start : MainAxisAlignment.end)
              : (context.isRtl
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: children,
        );
      },
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.isUser});

  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser ? null : AppGradients.vivid,
        color: isUser ? s.surface2 : null,
        border: Border.all(
          color: isUser ? s.border : Colors.white.withValues(alpha: 0.16),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        isUser ? AppIcons.user : AppIcons.sparkles,
        size: 15,
        color: isUser ? s.muted : Colors.white,
      ),
    );
  }
}

class _BubblePlate extends StatelessWidget {
  const _BubblePlate({
    required this.isUser,
    required this.message,
    required this.showTime,
  });

  final bool isUser;
  final DemoMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _copyMessage(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              gradient: isUser ? AppGradients.userBubble : null,
              color: isUser ? null : s.surface2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUser ? s.brandCyan.withValues(alpha: 0.38) : s.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.toolName != null && !isUser) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.bolt, size: 11, color: s.muted),
                      const SizedBox(width: 4),
                      Text(
                        message.toolName!,
                        style: context.text.labelSmall?.copyWith(
                          color: s.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                SelectableText(
                  message.content,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.text,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
                for (final attachment in message.attachments) ...[
                  const SizedBox(height: 8),
                  _AttachmentChip(attachment: attachment),
                ],
              ],
            ),
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              message.time,
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: context.tr.copiedToClipboard,
      variant: ToastVariant.success,
    );
  }
}

class _ToolActivityCard extends StatefulWidget {
  const _ToolActivityCard({required this.message});

  final DemoMessage message;

  @override
  State<_ToolActivityCard> createState() => _ToolActivityCardState();
}

class _ToolActivityCardState extends State<_ToolActivityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tool = widget.message.toolName ?? context.tr.roleTool;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.86),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: s.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.bolt, size: 12, color: s.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tool,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.message.time,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      AppIcons.chevronDown,
                      size: 13,
                      color: s.muted,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: s.codePlate,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: s.border),
                  ),
                  child: SelectableText(
                    widget.message.content,
                    style: context.text.bodySmall?.copyWith(
                      fontFamily: UiStrings.monospaceFontFamily,
                      color: s.brandCyan,
                      height: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment});

  final DemoAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(AppIcons.attach, size: 14, color: s.brandCyan),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${attachment.kind} · ${attachment.size}',
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Composer
// ============================================================================

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hasAttachment,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasAttachment;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: s.surface,
          border: Border(top: BorderSide(color: s.border)),
        ),
        child: ResponsiveContent(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAttachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _AttachmentChip(
                            attachment: DemoAttachment(
                              name: UiStrings.demoAttachmentName,
                              kind: UiStrings.demoAttachmentKind,
                              size: UiStrings.demoAttachmentSize,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onAttach,
                        icon: Icon(AppIcons.close, color: s.muted, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: s.surface2,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: s.cardBorder),
                ),
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        onPressed: onAttach,
                        icon: Icon(AppIcons.attach, color: s.muted, size: 20),
                        tooltip: context.tr.attachFiles,
                      ),
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          style: context.text.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: context.tr.composerHint,
                            hintStyle: context.text.bodyMedium?.copyWith(
                              color: s.muted,
                              fontSize: 15,
                            ),
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _SendButton(onPressed: onSend),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr.send,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillR,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.pillR,
          child: Ink(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: AppGradients.primaryCta,
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.send, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Sheets
// ============================================================================

class _ChatSheet extends StatelessWidget {
  const _ChatSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 22 + viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.primaryCta,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final c = color ?? s.text;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 28, child: Icon(icon, size: 19, color: c)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.text.bodyMedium?.copyWith(
                    color: c,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.trailing,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final DemoApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.cardBorder),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: s.warning,
                borderRadius: const BorderRadiusDirectional.horizontal(
                  start: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: s.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: s.warning.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        AppIcons.shieldAlert,
                        color: s.warning,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        approval.title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: s.text,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    MiniChip(approval.risk, color: s.warning),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  approval.prompt,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in approval.payload.entries)
                      MiniChip(context.tr.keyValue(entry.key, entry.value)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: context.tr.reject,
                        icon: AppIcons.close,
                        onPressed: onReject,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: context.tr.approve,
                        icon: AppIcons.check,
                        onPressed: onApprove,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({required this.artifact, required this.onOpen});

  final DemoArtifact artifact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(AppIcons.file, color: s.brandCyan, size: 18),
        ),
        title: Text(artifact.name),
        subtitle: Text(
          context.tr.artifactMeta(
            artifact.kind,
            artifact.size,
            artifact.createdLabel,
          ),
        ),
        trailing: IconButton(
          tooltip: context.tr.download,
          onPressed: onOpen,
          icon: Icon(AppIcons.download, color: s.brandCyan),
        ),
      ),
    );
  }
}
