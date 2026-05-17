import 'dart:async';

import 'package:file_picker/file_picker.dart';
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
import '../state/deep_think_controller.dart';
import '../state/live_env_ack.dart';
import '../state/running_agents_controller.dart';
import '../state/tool_status.dart';
import '../widgets/widgets.dart';
import '../../conversations/state/conversations_controller.dart';
import '../../conversations/widgets/rename_conversation_dialog.dart';

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

  /// The currently staged attachment (single — multi-file shipping isn't
  /// in scope yet). When non-null the composer renders its chip above
  /// the pill and Send becomes enabled even on an empty text field.
  DemoAttachment? _attachment;

  bool _showScrollDown = false;
  bool _isThinking = false;

  /// Optimistic flag flipped the moment the user taps Stop. Cleared once
  /// the cancel propagates (today: end of the thinking timer; later: when
  /// the server confirms `is_running=false`). While true, the Stop button
  /// renders as a spinner and is non-interactive so the user can't tap it
  /// twice.
  bool _stopping = false;

  bool _loadingMessages = false;

  /// Live progress for a long-running report tool. Non-null while the
  /// backend reports `run_progress.phase = building_report | rendering_report`;
  /// cleared once the artifact lands. Drives the [ChatRunProgressCard]
  /// rendered above the message list.
  RunProgress? _runProgress;
  Timer? _progressTimer;

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
    _progressTimer?.cancel();
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
    if (text.isEmpty && _attachment == null) return;

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

    final predictedTool = guessToolFromPrompt(text);
    final isReportTool = predictedTool == ToolNames.generateExcelReport ||
        predictedTool == ToolNames.generatePdfReport ||
        predictedTool == ToolNames.generateWordReport;

    setState(() {
      _messages.add(
        DemoMessage(
          role: DemoMessageRole.user,
          content: text.isEmpty ? context.tr.attachedFilesForReview : text,
          time: context.tr.now,
          attachments:
              _attachment == null ? const [] : [_attachment!],
        ),
      );
      _composer.clear();
      _attachment = null;
      _isThinking = true;
      _runProgress = null;
    });

    // Tell the cross-tab agent indicator that this conversation just
    // entered "running" state — drives the pulse dot in the AppBar
    // brand row from anywhere in the app.
    ref
        .read(runningAgentsControllerProvider.notifier)
        .markRunning(widget.conversationId);

    _scrollToBottomSoft();

    if (isReportTool) {
      _startReportProgressSimulation(predictedTool!);
    }

    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(
      isReportTool
          ? const Duration(milliseconds: 4200)
          : const Duration(milliseconds: 1400),
      () {
        if (!mounted) return;
        _progressTimer?.cancel();
        ref
            .read(runningAgentsControllerProvider.notifier)
            .markIdle(widget.conversationId);
        setState(() {
          _isThinking = false;
          _runProgress = null;
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
      },
    );
  }

  /// Ticks a fake [RunProgress] through `building_report` → `rendering_report`
  /// so the [ChatRunProgressCard] gets meaningful demo data. Replace with
  /// real `conversation.run_progress` reads when the polling layer lands.
  void _startReportProgressSimulation(String toolName) {
    final fileName = switch (toolName) {
      ToolNames.generatePdfReport ||
      ToolNames.generatePdfDocument =>
        'report.pdf',
      ToolNames.generateWordReport ||
      ToolNames.generateWordDocument =>
        'report.docx',
      _ => 'report.xlsx',
    };
    const total = 1247;
    var current = 0;
    setState(() {
      _runProgress = RunProgress(
        phase: RunProgressPhase.fetching,
        current: current,
        total: total,
        fileName: fileName,
      );
    });
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 220), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      current = (current + 92).clamp(0, total);
      if (current < total) {
        setState(() {
          _runProgress = RunProgress(
            phase: RunProgressPhase.fetching,
            current: current,
            total: total,
            fileName: fileName,
          );
        });
      } else {
        t.cancel();
        setState(() {
          _runProgress = RunProgress(
            phase: RunProgressPhase.rendering,
            rows: total,
            fileName: fileName,
          );
        });
      }
    });
  }

  void _seedSuggestion(String prompt) {
    _composer.text = prompt;
    _composer.selection = TextSelection.collapsed(offset: prompt.length);
  }

  /// Opens the native file picker rooted in the device's Photos / Files
  /// app. Accepts the same set the web composer does — images, PDFs,
  /// Office docs, CSV/TSV — so the agent's later inspection has the
  /// same surface to work with on mobile + web.
  ///
  /// The picker returns a [PlatformFile]; we keep just the metadata
  /// (name, size, kind, optional thumbnail path) locally because the
  /// chat surfaces only need that to render the chip. Bytes / actual
  /// upload land when `/api/conversations/{id}/attachments/` ships.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'png', 'jpg', 'jpeg', 'gif', 'webp',
        'pdf',
        'csv', 'tsv',
        'xlsx', 'xls', 'xlsm',
        'docx', 'doc',
      ],
      withData: false,
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    setState(() {
      _attachment = DemoAttachment(
        name: picked.name,
        kind: _kindForExtension(picked.extension),
        size: _formatBytes(picked.size),
        imageUrl: _isImageExt(picked.extension) ? picked.path : null,
      );
    });
  }

  /// Maps a file extension to one of the [DemoAttachment.kind] tokens
  /// the chat bubble + attachment chip already know how to render.
  String _kindForExtension(String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(e)) return 'Image';
    if (e == 'pdf') return 'PDF';
    if (['xlsx', 'xls', 'xlsm'].contains(e)) return 'XLSX';
    if (['csv', 'tsv'].contains(e)) return 'CSV';
    if (['docx', 'doc'].contains(e)) return 'DOCX';
    return e.toUpperCase().padRight(3, ' ').trimRight();
  }

  bool _isImageExt(String? ext) =>
      ['png', 'jpg', 'jpeg', 'gif', 'webp']
          .contains((ext ?? '').toLowerCase());

  /// Human-readable file size — "184 KB" / "2.4 MB". Used in the
  /// attachment chip subtitle so the user gets a sense of upload cost
  /// before tapping Send.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }

  /// Opens the schema-driven credential request as a keyboard-aware
  /// ModalBottomSheet. Replaces the inline render (max 45 % of the screen,
  /// fought with the on-screen keyboard) with a sheet that takes up to
  /// 95 % of the screen and dismisses via swipe-down — closer to how
  /// users expect "fill this form" surfaces to behave on mobile.
  Future<void> _openCredentialRequestSheet(DemoCredentialKind initial) async {
    final result = await InlineCredentialRequest.show(
      context,
      initialKind: initial,
    );
    if (!mounted || result == null) return;
    switch (result.kind) {
      case InlineCredentialResultKind.provided:
        _toast(
          result.memorize
              ? context.tr.inlineCredentialMemorized
              : context.tr.inlineCredentialSession,
        );
      case InlineCredentialResultKind.providedContinuing:
        // "Save and continue" — the agent resumes immediately so the
        // toast tells the user the run picked back up. Once streaming
        // lands, this branch also kicks the conversation back into
        // running state without waiting for a fresh user message.
        _toast(context.tr.credentialSavedContinuing);
      case InlineCredentialResultKind.pickSaved:
        await _openEnvironmentPicker();
      case InlineCredentialResultKind.cancelled:
        break;
    }
  }

  /// Opens the rename dialog seeded with the conversation's effective
  /// title (post-rename overlay). On Save, commits via the controller
  /// so the AppBar title, conversation list row, and any other watcher
  /// update in one frame.
  Future<void> _renameConversation() async {
    final conv = _conversation;
    final current =
        ref.read(conversationTitleProvider(conv));
    final next = await RenameConversationDialog.show(
      context,
      initial: current,
    );
    if (next == null || !mounted) return;
    ref.read(conversationsControllerProvider.notifier).renameConversation(
          id: widget.conversationId,
          name: next,
        );
    _toast(context.tr.conversationRenamedToast);
  }

  /// Toggles the conversation's pinned state. Pinned chats float to the
  /// top of the Chats list (see `orderedConversationsProvider`).
  void _togglePin() {
    final wasPinned = ref
        .read(conversationsControllerProvider.notifier)
        .isPinned(widget.conversationId);
    ref
        .read(conversationsControllerProvider.notifier)
        .togglePin(widget.conversationId);
    _toast(
      wasPinned
          ? context.tr.conversationUnpinnedToast
          : context.tr.conversationPinnedToast,
    );
  }

  /// Cancels the in-flight assistant reply. Two-phase so the user gets
  /// instant feedback even if the server cancel takes a beat:
  ///   1. Optimistic flip — `_stopping = true` swaps the Stop button to a
  ///      spinner and locks subsequent taps.
  ///   2. ~250 ms later (mocking the round-trip), the thinking timer is
  ///      killed and `_isThinking` clears, returning the composer to its
  ///      idle Send state.
  /// Web parity for the `state.stopping` optimistic flag in chat-v2.
  Future<void> _stopGeneration() async {
    if (!_isThinking || _stopping) return;
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    setState(() => _stopping = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    ref
        .read(runningAgentsControllerProvider.notifier)
        .markIdle(widget.conversationId);
    setState(() {
      _isThinking = false;
      _stopping = false;
    });
    _toast(context.tr.generationStopped);
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
    final deepThink = ref.watch(deepThinkControllerProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatAppBarTitle(
          conversation: conversation,
          activeCredentialLabel: _environmentLabel,
          autoApprove: _autoApprove,
          onCredentialTap: _openEnvironmentPicker,
          // Pencil next to the title opens the rename dialog. Hidden on
          // the placeholder "new chat" since renaming a non-existent
          // conversation makes no sense.
          onRenameTap: _isNewChat ? null : _renameConversation,
          // Surface the agent's live state in the AppBar so the user can
          // scroll anywhere in the chat without losing the "Saqqar is
          // working" signal. Pulses for ~1.4 s per cycle while in flight.
          agentBusy: _isThinking,
        ),
        actions: [
          // Chat-level toggles moved here on 2026-05-16 — used to live in
          // the header strip but squeezed the dropdowns on small phones.
          ChatAppBarToggles(
            deepThink: deepThink,
            autoApprove: _autoApprove,
            onDeepThinkChanged: (value) {
              ref.read(deepThinkControllerProvider.notifier).set(value);
              _toast(
                value ? context.tr.deepThinkOn : context.tr.deepThinkOff,
              );
            },
            onAutoApproveChanged: (value) {
              setState(() => _autoApprove = value);
              _toast(
                value ? context.tr.autoApproveOn : context.tr.autoApproveOff,
              );
            },
          ),
          const SizedBox(width: 4),
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
            // Header strip — Project + Environment dropdowns only. The
            // toggles (Deep think + Auto-approve) moved to the AppBar
            // actions; see ChatAppBarToggles above.
            ChatHeaderControls(
              projectId: _projectId,
              environmentId: _environmentId,
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
            ),
            const OfflineBanner(),
            // Long-running report progress — Excel / PDF / Word generation.
            // Rendered above the message list (not inside the typing row)
            // because the user's eye needs to find the percentage fast,
            // and the typing row sits at the message tail where new
            // messages can push it off-screen.
            if (_runProgress != null)
              ChatRunProgressCard(progress: _runProgress!),
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
              attachment: _attachment,
              onAttach: _pickAttachment,
              onRemoveAttachment: () => setState(() => _attachment = null),
              onSend: online ? _send : null,
              // Render Stop instead of Send while the agent is "running"
              // (today: while the local thinking timer is in flight; later:
              // while `conversation.is_running` is true on the backend).
              onStop: _isThinking ? _stopGeneration : null,
              stopping: _stopping,
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
  String _contextualActivityLabel(DemoMessage? lastMessage) {
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
        final activityCount =
            demoServerActivityForConversation(widget.conversationId).length;
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
            // Activity — server-shell command outputs from THIS chat.
            // Mirrors the web's Activity tab in the Inbox drawer. Hidden
            // (trailing chip null) when no shell commands have run, since
            // surfacing a 0 count adds noise.
            ChatSheetItem(
              icon: AppIcons.terminal,
              color: s.brandCyan,
              title: sheetContext.tr.serverActivity,
              trailing: activityCount == 0
                  ? null
                  : MiniChip('$activityCount', color: s.brandCyan),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openServerActivity();
              },
            ),
            const SizedBox(height: 4),
            Divider(color: s.border),
            const SizedBox(height: 4),
            // Share / Archive remain backend-bound — kept as "Soon"
            // pending API. Rename + Pin are now local-only operations
            // (handled by the conversations controller) so they ship
            // alongside the AppBar pencil and the row pin/unpin.
            ChatSheetItem(
              icon: AppIcons.share,
              title: sheetContext.tr.shareLink,
              comingSoon: true,
              onTap: () =>
                  _sheetToast(sheetContext, sheetContext.tr.comingSoonToast),
            ),
            Builder(
              builder: (_) {
                final pinned = ref
                    .watch(conversationsControllerProvider)
                    .isPinned(widget.conversationId);
                return ChatSheetItem(
                  icon: pinned ? AppIcons.shieldCheck : AppIcons.bolt,
                  color: pinned ? s.brandCyan : null,
                  title: pinned
                      ? sheetContext.tr.unpinConversation
                      : sheetContext.tr.pinConversation,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _togglePin();
                  },
                );
              },
            ),
            ChatSheetItem(
              icon: AppIcons.edit,
              title: sheetContext.tr.rename,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameConversation();
              },
            ),
            ChatSheetItem(
              icon: AppIcons.archive,
              title: sheetContext.tr.archive,
              comingSoon: true,
              onTap: () =>
                  _sheetToast(sheetContext, sheetContext.tr.comingSoonToast),
            ),
            ChatSheetItem(
              icon: AppIcons.trash,
              color: s.danger,
              title: sheetContext.tr.delete,
              comingSoon: true,
              onTap: () =>
                  _sheetToast(sheetContext, sheetContext.tr.comingSoonToast),
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
                                _openCredentialRequestSheet(
                                  action.requestsCredential!,
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

  /// Opens the server-activity sheet — one [ServerActivityCard] per
  /// `run_server_command` invocation in this conversation. The latest
  /// failing card auto-expands so the user lands directly on what they
  /// most likely came to look at.
  void _openServerActivity() {
    final activity =
        demoServerActivityForConversation(widget.conversationId);
    final lastFailingId = activity.reversed
        .firstWhere(
          (a) => a.failed,
          orElse: () =>
              const DemoServerActivity(id: '', conversationId: '', command: '', createdLabel: ''),
        )
        .id;
    _openListSheet(
      title: context.tr.serverActivity,
      children: activity.isEmpty
          ? [ChatSheetEmpty(text: context.tr.noServerActivity)]
          : [
              for (final a in activity)
                ServerActivityCard(
                  activity: a,
                  initiallyExpanded: a.id == lastFailingId,
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
