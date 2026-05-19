// Several handlers (_togglePin, _openActionCenter, _openArtifacts,
// _openServerActivity, _sheetToast) became unreachable when the chat ⋯
// menu was retired in favour of the rail drawer (brief §4.1/§4.3). They
// remain in the file as ready-to-rewire fallbacks for surfaces the brief
// doesn't cover yet (e.g. a Pin action). Suppress the lint here rather
// than delete code we may resurrect within the same milestone.
// ignore_for_file: unused_element

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/network/view_model/connectivity_cubit.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
// Dead with the conversation menu — the rail drawer renders counts as
// tab-label suffixes, not as mini chips on a sheet item.
// import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../inbox/view_model/approvals_cubit.dart';
import '../view_model/deep_think_cubit.dart';
import '../data/live_env_ack_service.dart';
import '../view_model/running_agents_cubit.dart';
import '../data/tool_status.dart';
import '../widgets/widgets.dart';
import '../../conversations/data/attachment_models.dart' as api;
import '../../conversations/data/conversation_models.dart' as api;
import '../../conversations/data/conversations_repository.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../conversations/widgets/rename_conversation_dialog.dart';
import '../../inbox/data/approval_models.dart' as api;
import '../../inbox/data/approvals_api.dart';
import '../../vault/view_model/vault_cubit.dart';
import '../../vault/widgets/project_detail_sheet.dart';
import '../view_model/chat_cubit.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// The chat screen. Owns the conversation state (messages, active credential,
/// auto-approve toggle, composer text), wires the typing/scroll FSM, and
/// orchestrates the chat widgets and sheets.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // -------- State --------

  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
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

  /// Spec §10 — drawer open/close state lives here so the chat owns the
  /// slide animation + scrim. Drops the Material `Scaffold.drawer` /
  /// `endDrawer` plumbing entirely.
  bool _sidebarOpen = false;
  bool _railOpen = false;

  /// The currently staged attachment (single — multi-file shipping isn't
  /// in scope yet). When non-null the composer renders its chip above
  /// the pill and Send becomes enabled even on an empty text field.
  DemoAttachment? _attachment;

  /// The actual file on disk for the currently-staged attachment.
  /// Separate from [_attachment] (which is just display metadata) so
  /// `_sendAsNewConversation` can perform the deferred upload after
  /// it has a `conversation_id` to bind the upload to.
  File? _pendingFile;

  bool _showScrollDown = false;
  bool _isThinking = false;

  /// Optimistic flag flipped the moment the user taps Stop. Cleared once
  /// the cancel propagates (today: end of the thinking timer; later: when
  /// the server confirms `is_running=false`). While true, the Stop button
  /// renders as a spinner and is non-interactive so the user can't tap it
  /// twice.
  bool _stopping = false;

  /// True while the chat snapshot is being fetched for the first time
  /// (no previous data to show). New chats never enter this branch —
  /// they jump straight into the empty welcome state.
  ///
  /// For existing chats, derived live from ChatCubit:
  /// `state.data is DataLoading` AND no previous data carried over.
  /// Drops the local timer that used to fake a load duration.
  bool get _loadingMessages {
    if (_isNewChat) return false;
    final dataState = context.watch<ChatCubit>().state.data;
    return dataState.isLoading && dataState.dataOrNull == null;
  }

  /// Live progress for a long-running report tool. Non-null while the
  /// backend reports `run_progress.phase = building_report | rendering_report`;
  /// cleared once the artifact lands. Drives the [ChatRunProgressCard]
  /// rendered above the message list.
  RunProgress? _runProgress;
  Timer? _progressTimer;

  Timer? _thinkingTimer;
  Timer? _loadingTimer;

  bool get _isNewChat => widget.conversationId == UiStrings.newConversationId;

  // _isUnknownChat removed: the demo seed lookup was producing false
  // "Conversation not found" errors for conversations created on the
  // web (real UUIDs aren't in the seed). Truly missing conversations
  // surface as a 404 from the snapshot API now — DataStateView handles
  // the error rendering uniformly.

  /// Source of truth for the rendered message list.
  ///
  /// * **Existing chats** (real UUID) — read from the `ChatCubit`
  ///   snapshot via `context.watch`, adapted to the demo-shaped widgets.
  ///   Subscribing here means the screen rebuilds automatically on
  ///   every snapshot tick from the polling loop.
  ///
  /// * **New chats** (sentinel id) — there's no cubit yet, fall back
  ///   to the local optimistic list. Only used briefly before the
  ///   create-then-route handoff in `_send()`.
  List<DemoMessage> get _effectiveMessages {
    if (_isNewChat) return _messages;
    final snapshot =
        context.watch<ChatCubit>().state.data.dataOrNull;
    if (snapshot == null) return const [];
    // Filter what the chat lane actually shows the user:
    //
    //   * Drop `tool` messages — raw JSON outputs the agent consumed
    //     internally (describe_odoo_model results, SQL rows, etc.).
    //     The adjacent `assistant` message already explains what the
    //     tool returned in plain language.
    //   * Drop `assistant` messages with empty content — those are
    //     pure tool-call invocations (the agent is just dispatching a
    //     tool, no human-readable reply yet). Rendering them shows up
    //     as a blank bubble with just a timestamp.
    //   * Drop `user` messages whose content is clearly a system
    //     payload, not human typing — approval acknowledgements
    //     ("approve" / "approved" / "reject" / "rejected"), raw JSON
    //     blobs the server persists when a button-tap is logged as a
    //     turn, etc. The end user didn't type these and shouldn't see
    //     them surface as their own messages.
    //   * Drop any message whose content carries the `[agent-control]`
    //     marker — server-side directives that drive the agent to
    //     execute an approved action (e.g. "Approval '<id>'
    //     [agent-control] ... is approved. Execute the approved Odoo
    //     write..."). On the web these stay hidden; we match that.
    final visible = snapshot.messages.where((m) {
      if (m.role == api.MessageRole.tool) return false;
      if (m.role == api.MessageRole.assistant &&
          m.content.trim().isEmpty) {
        return false;
      }
      if (m.role == api.MessageRole.user &&
          _isSystemUserPayload(m.content)) {
        return false;
      }
      if (_isAgentControlPayload(m.content)) return false;
      return true;
    });
    // Closure capture: pass `context` into the adapter so the
    // timestamp resolves through the current locale.
    return visible.map((m) => _adaptApiMessage(m, context)).toList();
  }

  /// Heuristic for "this user message wasn't actually typed by the
  /// user — it's a system-injected payload (approval ack, button-tap
  /// echo, raw JSON envelope) that leaked into the conversation as a
  /// `user` row server-side". The server doesn't currently mark these
  /// distinctly, so we sniff the content.
  ///
  /// Tight on purpose — only filters obvious payloads (single-word
  /// approve/reject keywords or JSON blobs). Anything that looks like
  /// real prose passes through, including short replies like "تمام"
  /// or "yes" (those are 3+ chars and not in the keyword list).
  static const _approvalKeywords = {
    'approve',
    'approved',
    'reject',
    'rejected',
    'accept',
    'accepted',
    'deny',
    'denied',
  };

  bool _isSystemUserPayload(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return true;
    // Single-word approval acks ("approve" / "rejected" etc.) — these
    // come from clicking the inline approval card, not from typing.
    if (_approvalKeywords.contains(trimmed.toLowerCase())) return true;
    // JSON-shaped payload — a raw envelope the server persisted as a
    // user message. Real users don't type JSON.
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return true;
    }
    return false;
  }

  /// Detects the server-side "approval granted, now go execute"
  /// directives the agent receives after a user accepts an approval.
  /// They carry the literal `[agent-control]` marker and start with
  /// `Approval '<id>' ...` so we match either signal — the marker is
  /// the authoritative one, the prefix is the cheap early-exit.
  bool _isAgentControlPayload(String content) {
    if (content.isEmpty) return false;
    if (content.contains('[agent-control]')) return true;
    final trimmed = content.trimLeft();
    if (trimmed.startsWith("Approval '") &&
        trimmed.contains('is approved')) {
      return true;
    }
    return false;
  }

  /// True when the server reports the agent is mid-run for this
  /// conversation. For new chats this falls back to the local timer
  /// (kept for the brief window before the create-then-route handoff).
  bool get _effectiveIsThinking {
    if (_isNewChat) return _isThinking;
    final snapshot =
        context.watch<ChatCubit>().state.data.dataOrNull;
    return snapshot?.conversation.isRunning ?? false;
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

  /// Resolves the currently-bound environment for this chat.
  ///
  /// Resolution order:
  ///   1. **Existing chat** (non-new) → read from the snapshot's
  ///      `conversation.environment`. This is the SERVER's source of
  ///      truth — survives across sends, restarts, and re-routes. The
  ///      local `_environmentId` is irrelevant once a conversation
  ///      exists on the backend.
  ///   2. **New chat** (sentinel id) → look up the locally-selected
  ///      env (`_environmentId`) inside `VaultCubit.data`. Used until
  ///      the first send creates the conversation + binds the env
  ///      server-side, at which point the router pushes the user to
  ///      `/chats/<newId>` and resolution flips to path (1).
  ///   3. **Legacy demo fallback** — for the original seeded demo
  ///      conversations that still carry hardcoded env ids.
  ///
  /// Returns null only when truly no env is bound (rare — happens on a
  /// fresh "new chat" before the user picks one).
  _ResolvedEnv? _resolveEnv() {
    // 1) Snapshot-bound env wins for existing chats.
    if (!_isNewChat) {
      final snapshot = context.read<ChatCubit>().state.data.dataOrNull;
      final env = snapshot?.conversation.environment;
      if (env != null) {
        final project = snapshot?.conversation.project;
        return _ResolvedEnv(
          id: env.id,
          name: env.name,
          isLive: env.isLive,
          readOnly: env.readOnly,
          projectId: env.projectId,
          projectName: project?.name ?? '',
        );
      }
    }
    // 2) Vault lookup for the locally-picked env on new chats.
    final id = _environmentId;
    if (id == null) return null;
    final vault = context.read<VaultCubit>().state.data.dataOrNull;
    if (vault != null) {
      final env = vault.environmentById(id);
      if (env != null) {
        final project = vault.projectById(env.projectId);
        return _ResolvedEnv(
          id: env.id,
          name: env.name,
          isLive: env.isLive,
          readOnly: env.readOnly,
          projectId: env.projectId,
          projectName: project?.name ?? '',
        );
      }
    }
    // 3) Demo fallback (only reachable from legacy seeded chats).
    final demo = demoEnvironmentById(id);
    if (demo == null) return null;
    final demoProject = demoProjectById(demo.projectId);
    return _ResolvedEnv(
      id: demo.id,
      name: demoEnvironmentLabel(demo),
      isLive: demo.isLive,
      readOnly: demo.readOnly,
      projectId: demo.projectId,
      projectName: demoProject?.name ?? '',
    );
  }

  /// Title shown in the AppBar subtitle and the picker chip. Falls back
  /// to the localized "No environment" copy when nothing has been picked.
  String get _environmentLabel {
    final env = _resolveEnv();
    if (env == null) return context.tr.noEnvironmentPicked;
    return env.name;
  }

  /// Resolved conversation title rendered in the AppBar.
  ///
  /// Resolution order — first non-empty wins:
  ///   1. **Snapshot** — `ChatCubit.state.data.conversation.title`. Live
  ///      truth from the server; reflects renames done on any device.
  ///   2. **Conversations list** — `ConversationsCubit.byId(id).title`.
  ///      Useful between snapshot ticks (e.g. first paint after a route
  ///      push, before the snapshot poll has resolved).
  ///   3. **Empty string** — the AppBar widget renders the localized
  ///      "Untitled conversation" placeholder for blanks, so we never
  ///      surface the old "Start a conversation" copy here.
  ///
  /// New chats get the localized "Start a conversation" label since no
  /// server-side conversation exists yet.
  String get _effectiveChatTitle {
    if (_isNewChat) return context.tr.startConversation;
    final fromSnapshot = context
        .watch<ChatCubit>()
        .state
        .data
        .dataOrNull
        ?.conversation
        .title;
    if (fromSnapshot != null && fromSnapshot.trim().isNotEmpty) {
      return fromSnapshot;
    }
    final fromList = context
        .watch<ConversationsCubit>()
        .state
        .data
        .dataOrNull
        ?.byId(widget.conversationId)
        ?.title;
    return (fromList != null && fromList.trim().isNotEmpty) ? fromList : '';
  }

  /// Currently-bound environment id reflected in the header dropdowns.
  ///
  /// For existing chats the source of truth is the server-side binding
  /// (snapshot.conversation.environment) — that way the dropdown stays
  /// correct after sends / restarts / navigations. For new chats the
  /// local picker selection wins until the first send creates the
  /// conversation and binds the env server-side.
  ///
  /// Uses `context.watch` so the screen rebuilds when the snapshot
  /// emits a new env (e.g. another device PATCHed the conversation).
  String? get _activeEnvironmentId {
    if (!_isNewChat) {
      final snapshot = context.watch<ChatCubit>().state.data.dataOrNull;
      final fromSnap = snapshot?.conversation.environment?.id;
      if (fromSnap != null) return fromSnap;
    }
    return _environmentId;
  }

  /// Currently-bound project id — derived from the same source the env
  /// resolves to, so the two dropdowns stay coherent (picking a project
  /// without an env in it is meaningless).
  String? get _activeProjectId {
    if (!_isNewChat) {
      final snapshot = context.watch<ChatCubit>().state.data.dataOrNull;
      final fromSnap = snapshot?.conversation.environment?.projectId;
      if (fromSnap != null) return fromSnap;
    }
    return _projectId;
  }

  /// Handler for the project dropdown.
  ///
  /// New chat → stash the selection locally, clear env (user must pick
  /// an env inside the new project).
  ///
  /// Existing chat → projects aren't directly bound to a conversation;
  /// the env is. Changing the project means picking a different env;
  /// we clear the current env binding so the env dropdown re-populates,
  /// and PATCH `environment_id: null` to release the server binding.
  /// The user then picks a new env from the same dropdown.
  Future<void> _handleProjectChanged(String? value) async {
    if (_isNewChat) {
      setState(() {
        _projectId = value;
        _environmentId = null;
      });
      return;
    }
    setState(() {
      _projectId = value;
      _environmentId = null;
    });
    try {
      await context.read<ConversationsRepository>().patch(
            id: widget.conversationId,
            environmentId: '',
          );
      if (!mounted) return;
      // Refresh the snapshot so the new env=null surfaces immediately.
      await context.read<ChatCubit>().refresh();
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Handler for the environment dropdown.
  ///
  /// New chat → stash locally; the first send creates the conv with
  /// this env bound.
  ///
  /// Existing chat → PATCH `environment_id` on the server. The chat
  /// cubit's polling picks up the new env via snapshot — the dropdown
  /// updates from there, not from this local write.
  Future<void> _handleEnvironmentChanged(String? value) async {
    final vault = context.read<VaultCubit>().state.data.dataOrNull;
    final env = value == null ? null : vault?.environmentById(value);
    if (_isNewChat) {
      setState(() {
        _environmentId = value;
        if (env != null) {
          _projectId = env.projectId;
          if (env.autoApprove) _autoApprove = true;
        }
      });
      if (value != null) _toast(context.tr.environmentSetForChat);
      return;
    }
    // Existing chat — PATCH on the server. Update local state as well
    // so the dropdown reflects the change instantly; the snapshot
    // refresh will reconcile if the server rejected.
    setState(() {
      _environmentId = value;
      if (env != null) {
        _projectId = env.projectId;
        if (env.autoApprove) _autoApprove = true;
      }
    });
    try {
      await context.read<ConversationsRepository>().patch(
            id: widget.conversationId,
            environmentId: value ?? '',
          );
      if (!mounted) return;
      await context.read<ChatCubit>().refresh();
      if (!mounted) return;
      if (value != null) _toast(context.tr.environmentSetForChat);
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Fired by [ChatHeaderControls] when the user taps the env slot
  /// while the selected project has no environments yet.
  ///
  /// Flow: confirm dialog → on confirm, open the same
  /// [ProjectDetailSheet] the Vault tab uses for env management. The
  /// sheet writes through [VaultCubit] on save, so the chat header's
  /// env dropdown picks up the new env automatically the moment the
  /// sheet pops — no manual refresh needed.
  Future<void> _handleCreateEnvironmentRequested(String projectId) async {
    final tr = context.tr;
    final ok = await ConfirmDialog.show(
      context,
      title: tr.createEnvironmentConfirmTitle,
      body: tr.createEnvironmentConfirmBody,
      confirmLabel: tr.createEnvironmentCta,
      icon: AppIcons.plus,
    );
    if (!ok || !mounted) return;
    await ProjectDetailSheet.show(context, existingProjectId: projectId);
  }

  // -------- Lifecycle --------

  @override
  void initState() {
    super.initState();
    // Existing chats source messages from the ChatCubit snapshot via
    // `_effectiveMessages`, so the local list stays empty. New chats
    // keep it empty too (no demo seed) — the empty state surface
    // (EmptyChatSuggestions) renders until the create-then-route flow
    // hands off to a real cubit.
    _messages = <DemoMessage>[];

    // Resolve initial env id from the demo lookup as a fallback (for
    // legacy seeded conversations). Real conversations from the API
    // surface their bound env via the snapshot — see `_resolveEnv`.
    for (final item in demoConversations) {
      if (item.id == widget.conversationId) {
        final env = demoEnvironmentForConversation(item);
        _environmentId = env?.id;
        _projectId = env?.projectId;
        break;
      }
    }
    _scroll.addListener(_onScrollChanged);
    // Loading skeleton state now comes from the cubit's DataLoading
    // (see the build method) — no local timer needed.
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _loadingTimer?.cancel();
    _progressTimer?.cancel();
    _scroll.removeListener(_onScrollChanged);
    _composer.dispose();
    _composerFocus.dispose();
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
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutQuart,
    );
  }

  void _scrollToBottomSoft() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  // -------- Sending --------

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty && _attachment == null) return;

    // Block sends until the user picks an environment — the agent has no
    // credentials to work against otherwise. Resolves real env first
    // (header dropdowns now feed UUIDs from VaultCubit) before falling
    // back to demo env lookup for legacy seeded conversations.
    final env = _resolveEnv();
    if (env == null) {
      _toast(context.tr.pickEnvironmentToStart);
      await _openEnvironmentPicker();
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

    final deepThink = context.read<DeepThinkCubit>().state;

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
      await _sendAsNewConversation(text: text, env: env, deepThink: deepThink);
      return;
    }

    // ── Existing chat path ───────────────────────────────────────────
    // ChatCubit owns the snapshot + polling; sendMessage adopts the
    // server's fresh snapshot on success, and the polling loop keeps
    // state alive while the agent processes.
    _composer.clear();
    setState(() {
      _attachment = null;
      _pendingFile = null;
    });
    context.read<RunningAgentsCubit>().markRunning(widget.conversationId);
    final ok = await context.read<ChatCubit>().sendMessage(
          content: text.isEmpty ? context.tr.attachedFilesForReview : text,
          deepThink: deepThink,
        );
    if (!mounted) return;
    if (ok) {
      _scrollToBottomSoft();
    } else {
      // Roll back the composer so the user doesn't lose their text on a
      // network failure. ChatCubit already populated `actionFailure`
      // which the (future) BlocListener will surface as a toast.
      _composer.text = text;
      _toast(context.tr.defaultApiError);
    }
    // Idle marker — polling will keep the real isRunning flag accurate.
    context.read<RunningAgentsCubit>().markIdle(widget.conversationId);
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
    required bool deepThink,
  }) async {
    final repo = context.read<ConversationsRepository>();
    final conversationsCubit = context.read<ConversationsCubit>();
    // Snapshot the composer text + the pending attachment file BEFORE
    // we clear local state — the upload below needs the File on disk,
    // and rolling back on failure needs the chip metadata to restore.
    final pendingText = text.isEmpty
        ? context.tr.attachedFilesForReview
        : text;
    final pendingFile = _pendingFile;
    final attachmentChip = _attachment;
    _composer.clear();
    setState(() {
      _attachment = null;
      _pendingFile = null;
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
      // 2) Bind the picked environment. The server may reject (e.g.
      //    the env doesn't belong to this user) — surface as an error.
      await repo.patch(id: newId, environmentId: env.id);
      if (!mounted) return;
      // 2.5) Upload any deferred attachment now that we have a
      //      conversation id. Skipped when there's nothing to upload.
      //      Failures here are surfaced — the user typed/picked
      //      something on purpose, silently dropping it is worse than
      //      a clear error.
      final attachmentIds = <String>[];
      if (pendingFile != null) {
        final uploaded = await repo.uploadAttachments(
          conversationId: newId,
          files: [pendingFile],
        );
        attachmentIds.addAll(uploaded.map((a) => a.id));
        if (!mounted) return;
      }
      // 3) Send the message — first message in the brand-new conv.
      await repo.sendMessage(
        conversationId: newId,
        content: pendingText,
        attachmentIds: attachmentIds,
        deepThink: deepThink,
      );
      if (!mounted) return;
      // 4) Refresh the conversations list so the row appears.
      //    Fire-and-forget — the list refreshes itself when the user
      //    swipes back to the Chats tab anyway.
      unawaited(conversationsCubit.refresh());
      // 5) Hand off to the real chat route. The router will build a
      //    ChatCubit for the new id which load()s the fresh snapshot.
      context.go(RouteNames.chatPath(newId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        // Restore the picked file + chip so the user doesn't have to
        // re-attach after a transient failure (network blip, server
        // 500 between create and send, etc.).
        _attachment = attachmentChip;
        _pendingFile = pendingFile;
      });
      _composer.text = pendingText == context.tr.attachedFilesForReview
          ? ''
          : pendingText;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Used to compute the demo-thinking timer for the new-chat
  /// optimistic UI. Kept here so the rewritten `_send` stays terse.
  void _runLegacyThinkingTimer({
    required String reply,
    required String? replyToolName,
    required bool isReportTool,
  }) {
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(
      isReportTool
          ? const Duration(milliseconds: 4200)
          : const Duration(milliseconds: 1400),
      () {
        if (!mounted) return;
        _progressTimer?.cancel();
        context
            .read<RunningAgentsCubit>()
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
    // Focus the composer so the user can edit or hit Send without an
    // extra tap — matches the empty-chat suggestion-grid contract.
    _composerFocus.requestFocus();
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
  /// Drops the currently-staged attachment — clears the composer chip
  /// AND removes it from the cubit's `stagedAttachments` so the next
  /// `sendMessage` doesn't ship the orphaned id. New chats never have
  /// a cubit yet, so we just clear local state in that case.
  void _removeAttachment() {
    if (!_isNewChat) {
      // The cubit indexes staged attachments by their server-side id.
      // We don't carry that id at the screen level (the chip only has
      // display metadata), so clear the whole staged list — only one
      // attachment ever rides at a time today.
      final cubit = context.read<ChatCubit>();
      for (final a in cubit.state.stagedAttachments) {
        cubit.removeStagedAttachment(a.id);
      }
    }
    setState(() {
      _attachment = null;
      _pendingFile = null;
    });
  }

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
    final path = picked.path;
    if (path == null || path.isEmpty) return;

    // UI metadata for the composer chip — keeps the visual confirmation
    // instant even if the upload below is still in flight.
    setState(() {
      _attachment = DemoAttachment(
        name: picked.name,
        kind: _kindForExtension(picked.extension),
        size: _formatBytes(picked.size),
        imageUrl: _isImageExt(picked.extension) ? picked.path : null,
      );
      _pendingFile = File(path);
    });

    // Existing chats own a [ChatCubit] — stage the upload immediately
    // so the attachment id is already on the server by the time the
    // user hits Send. New chats can't upload yet (no conversation id)
    // — _sendAsNewConversation does the deferred upload after it
    // creates the conversation.
    if (!_isNewChat) {
      final cubit = context.read<ChatCubit>();
      final ok = await cubit.uploadAttachments([File(path)]);
      if (!mounted) return;
      if (!ok) {
        // Upload failed — clear the local chip so the user knows the
        // attachment didn't make it onto the message.
        setState(() {
          _attachment = null;
          _pendingFile = null;
        });
        _toast(context.tr.defaultApiError);
      }
    }
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

  // Bell trigger is inlined below as a private widget so the AppBar
  // `actions` slot stays terse.

  /// Opens the rename dialog seeded with the conversation's effective
  /// title (post-rename overlay). On Save, commits via the controller
  /// so the AppBar title, conversation list row, and any other watcher
  /// update in one frame.
  Future<void> _renameConversation() async {
    final conv = _conversation;
    // Live title comes from the list cubit when known; falls back to
    // the local conv title for the "new chat" sentinel that doesn't
    // exist in the list yet.
    final live = context
        .read<ConversationsCubit>()
        .state
        .data
        .dataOrNull
        ?.byId(widget.conversationId)
        ?.title;
    final current = live ?? conv.title;
    final next = await RenameConversationDialog.show(
      context,
      initial: current,
    );
    if (next == null || !mounted) return;
    await context.read<ConversationsCubit>().renameConversation(
          id: widget.conversationId,
          name: next,
        );
    if (!mounted) return;
    _toast(context.tr.conversationRenamedToast);
  }

  /// Toggles the conversation's pinned state. Pinned chats float to the
  /// top of the Chats list (see `orderedConversationsProvider`).
  void _togglePin() {
    final cubit = context.read<ConversationsCubit>();
    final wasPinned = cubit.isPinned(widget.conversationId);
    cubit.togglePin(widget.conversationId);
    _toast(
      wasPinned
          ? context.tr.conversationUnpinnedToast
          : context.tr.conversationPinnedToast,
    );
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
    if (!_isNewChat) {
      await context.read<ChatCubit>().stopGeneration();
      if (mounted) _toast(context.tr.generationStopped);
      return;
    }
    // Legacy new-chat path (cancels the local fake timer).
    if (!_isThinking || _stopping) return;
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    setState(() => _stopping = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    context.read<RunningAgentsCubit>().markIdle(widget.conversationId);
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
    // `_conversation` (demo lookup) was previously read here for the
    // AppBar title; the AppBar now sources its title via the
    // snapshot-first `_effectiveChatTitle` getter, so the local is
    // dead. Kept the helper around because legacy code paths still
    // reach for `_conversation.title` in places not yet migrated.
    final online = context.watch<ConnectivityCubit>().state;
    // Source of truth for the per-conversation toggles:
    //   * Existing chat → live from the snapshot (server is canonical,
    //     so flipping from the web shows up here on the next poll).
    //   * New chat (no cubit yet) → local state until the conversation
    //     gets created; carried forward into the first send.
    final snapshotConv = _isNewChat
        ? null
        : context
            .watch<ChatCubit>()
            .state
            .data
            .dataOrNull
            ?.conversation;
    final deepThink = snapshotConv?.deepThink ??
        context.watch<DeepThinkCubit>().state;
    final autoApprove = snapshotConv?.autoApprove ?? _autoApprove;

    // Brief §4.1 mobile header — hamburger left + title middle + bell
    // right with a pending-approvals badge. Badge count reads from the
    // live snapshot (existing chats) so it reflects the server's truth
    // and shrinks as the user approves/rejects from the rail drawer.
    // New chats have no snapshot yet — badge stays 0.
    final pendingForChat = _isNewChat
        ? 0
        : (context
                .watch<ChatCubit>()
                .state
                .data
                .dataOrNull
                ?.approvals
                .where((a) => a.status == api.ApprovalStatus.pending)
                .length ??
            0);

    // Spec §10 — both drawers live as siblings of the main content in a
    // Stack so we own the slide animation, scrim opacity, and tap-out
    // close behaviour. Material's `Scaffold.drawer` / `endDrawer` were
    // dropped explicitly (different slide curve + scrim treatment).
    final anyDrawerOpen = _sidebarOpen || _railOpen;
    final screenW = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenW * 0.86 > 320.0 ? 320.0 : screenW * 0.86;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Hamburger on the start side — toggles the custom sidebar
        // state. We don't use `Scaffold.openDrawer` anymore.
        leading: IconButton(
          icon: const Icon(AppIcons.menu),
          tooltip: context.tr.openConversations,
          onPressed: () => setState(() {
            _sidebarOpen = true;
            _railOpen = false;
          }),
        ),
        title: ChatAppBarTitle(
          // Resolved-title getter prefers the live snapshot, then the
          // conversations list, then falls back to the localized
          // "Untitled" placeholder. The widget itself never reaches
          // back into demo data.
          title: _effectiveChatTitle,
          activeCredentialLabel: _environmentLabel,
          autoApprove: _autoApprove,
          // Render the env-flag badges when the bound env carries
          // either flag. Read via `_resolveEnv()` so the source of
          // truth is the snapshot for existing chats and VaultCubit
          // for the new-chat pre-create picker.
          envIsLive: _resolveEnv()?.isLive ?? false,
          envReadOnly: _resolveEnv()?.readOnly ?? false,
          onCredentialTap: _openEnvironmentPicker,
          // Pencil next to the title opens the rename dialog. Hidden on
          // the placeholder "new chat" since renaming a non-existent
          // conversation makes no sense.
          onRenameTap: _isNewChat ? null : _renameConversation,
          // Surface the agent's live state in the AppBar so the user can
          // scroll anywhere in the chat without losing the "Saqqar is
          // working" signal. Pulses for ~1.4 s per cycle while in flight.
          agentBusy: _effectiveIsThinking,
        ),
        actions: [
          // Bell — toggles the custom rail state (Stack-based, not
          // Scaffold.endDrawer). Closes the sidebar if it was open
          // so we never show both drawers at once.
          _InboxBellTrigger(
            badgeCount: pendingForChat,
            onTap: () => setState(() {
              _railOpen = true;
              _sidebarOpen = false;
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Main chat content ─────────────────────────────────────
          AmbientBackground(
            child: Column(
              children: [
                // Brief §4.1 — the project / environment dropdowns are
            // replaced on mobile by a compact env-badges strip. Tapping
            // it opens the env picker sheet so the user still has one
            // tap to switch context, but the chrome stays minimal.
            // Restored 2026-05-17 — env-badges strip replaced with the
            // two-dropdown row (Project + Environment) per request.
            // Picking a project clears the env so the user re-confirms
            // which env within the new project they want to talk to.
            ChatHeaderControls(
              // Reflect the snapshot-bound env for existing chats so
              // the dropdown shows the SERVER's truth (survives mounts,
              // restarts, route navigations). For new chats, fall back
              // to the local picker selection.
              projectId: _activeProjectId,
              environmentId: _activeEnvironmentId,
              onProjectChanged: _handleProjectChanged,
              onEnvironmentChanged: _handleEnvironmentChanged,
              onCreateEnvironmentRequested: _handleCreateEnvironmentRequested,
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
                  else if (_effectiveMessages.isEmpty)
                    EmptyChatSuggestions(onSuggestionTap: _seedSuggestion)
                  else
                    _buildMessageList(),
                  PositionedDirectional(
                    end: 16,
                    bottom: 12,
                    child: ChatScrollDownButton(
                      visible:
                          _showScrollDown && _effectiveMessages.isNotEmpty,
                      onTap: _scrollToBottom,
                    ),
                  ),
                ],
              ),
            ),
            // PendingApprovalsBanner above the composer was retired
            // on 2026-05-17 — pending approvals now render inline as
            // ChatApprovalCard inside the message list (see
            // _buildMessageList), scrolling with the rest of the chat
            // so they no longer hog the composer space.
            ChatComposer(
              controller: _composer,
              focusNode: _composerFocus,
              attachment: _attachment,
              onAttach: _pickAttachment,
              onRemoveAttachment: _removeAttachment,
              onSend: online ? _send : null,
              deepThink: deepThink,
              autoApprove: autoApprove,
              onDeepThinkChanged: (value) {
                // New chats keep the local cubit until the
                // conversation exists; existing chats PATCH the
                // per-conversation flag so the web sees the change
                // on its next poll and vice versa.
                context.read<DeepThinkCubit>().set(value);
                if (!_isNewChat) {
                  context.read<ChatCubit>().setDeepThink(value);
                }
                _toast(
                  value ? context.tr.deepThinkOn : context.tr.deepThinkOff,
                );
              },
              onAutoApproveChanged: (value) {
                if (_isNewChat) {
                  setState(() => _autoApprove = value);
                } else {
                  // Optimistic local mirror so the switch animates
                  // before the snapshot poll catches up.
                  setState(() => _autoApprove = value);
                  context.read<ChatCubit>().setAutoApprove(value);
                }
                _toast(
                  value
                      ? context.tr.autoApproveOn
                      : context.tr.autoApproveOff,
                );
              },
              // Render Stop instead of Send while the agent is running.
              // For existing chats, the source of truth is the cubit's
              // snapshot (`conversation.is_running`); for new chats it
              // still comes from the local timer until the first send
              // creates the conversation + routes.
              onStop: _effectiveIsThinking ? _stopGeneration : null,
              stopping: _isNewChat
                  ? _stopping
                  : context
                      .watch<ChatCubit>()
                      .state
                      .isStopping,
            ),
          ],
        ),
      ),
          // ── Scrim (covers main content when any drawer is open) ──
          // Black 55 % per spec §10.1. Tap to close both drawers.
          IgnorePointer(
            ignoring: !anyDrawerOpen,
            child: AnimatedOpacity(
              opacity: anyDrawerOpen ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _sidebarOpen = false;
                  _railOpen = false;
                }),
                child: Container(color: Colors.black.withValues(alpha: 0.55)),
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
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: ChatSidebarDrawer(
              currentConversationId: widget.conversationId,
              onPickConversation: (String id) {
                setState(() => _sidebarOpen = false);
                if (id != widget.conversationId) {
                  context.go(RouteNames.chatPath(id));
                }
              },
              onNewConversation: () {
                setState(() => _sidebarOpen = false);
                context.go(
                  RouteNames.chatPath(UiStrings.routeNewConversation),
                );
              },
              onOpenVault: () {
                setState(() => _sidebarOpen = false);
                context.go(RouteNames.vaultPath);
              },
              // Close the drawer in-place — flipping the local flag
              // triggers the slide-out animation. Routes don't move.
              onClose: () => setState(() => _sidebarOpen = false),
            ),
          ),
          // ── Rail (end-side, slides in from right in LTR, left in
          // RTL) — holds Approvals + Artifacts + Activity tabs ──
          AnimatedPositionedDirectional(
            end: _railOpen ? 0 : -drawerWidth,
            top: 0,
            bottom: 0,
            width: drawerWidth,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: ChatRailDrawer(
              conversationId: widget.conversationId,
              onClose: () => setState(() => _railOpen = false),
            ),
          ),
        ],
      ),
    );
  }

  // -------- Inline approval actions --------

  /// POSTs the decide call against the real `/approvals/<id>/decision/`
  /// endpoint and refreshes the chat snapshot so the approved/rejected
  /// row drops off the screen instantly (rather than waiting for the
  /// next 1.5 s poll). Errors surface as a toast.
  Future<void> _decideApprovalInline(
    api.Approval approval,
    bool approved,
  ) async {
    final tr = context.tr;
    try {
      await context
          .read<ApprovalsApi>()
          .decide(id: approval.id, approved: approved);
      if (!mounted) return;
      await context.read<ChatCubit>().refresh();
      if (!mounted) return;
      _toast(approved ? tr.approvalGrantedExecuting : tr.approvalRejected);
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// One-way bridge: real `api.Approval` → demo-shaped `DemoApproval`
  /// so the existing `ChatApprovalCard` widget keeps working until it
  /// migrates to the real model. Mirrors the rail drawer's adapter.
  DemoApproval _adaptApiApproval(api.Approval a) {
    return DemoApproval(
      id: a.id,
      title: _approvalTitleFor(a.actionType),
      prompt: a.prompt,
      actionType: a.actionType.wire,
      risk: _riskFor(a.actionType),
      status: switch (a.status) {
        api.ApprovalStatus.pending => DemoApprovalStatus.pending,
        api.ApprovalStatus.approved => DemoApprovalStatus.approved,
        api.ApprovalStatus.rejected => DemoApprovalStatus.rejected,
      },
      payload: {
        for (final entry in a.payload.entries)
          entry.key: entry.value.toString(),
      },
    );
  }

  String _approvalTitleFor(api.ApprovalActionType t) {
    return switch (t) {
      api.ApprovalActionType.credentialStorage => 'Credential storage',
      api.ApprovalActionType.credentialUsage => 'Credential usage',
      api.ApprovalActionType.serverCommand => 'Server command',
      api.ApprovalActionType.odooWrite => 'Odoo write',
      api.ApprovalActionType.reportExport => 'Report export',
      api.ApprovalActionType.unknown => 'Approval',
    };
  }

  String _riskFor(api.ApprovalActionType t) {
    return switch (t) {
      api.ApprovalActionType.credentialStorage => 'medium',
      api.ApprovalActionType.credentialUsage => 'medium',
      api.ApprovalActionType.reportExport => 'low',
      _ => 'high',
    };
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
    // Snapshot the message list ONCE per build — `_effectiveMessages`
    // subscribes via `context.watch`, so cubit ticks rebuild the
    // screen; we want a single stable list for index math inside the
    // itemBuilder closure below.
    final messages = _effectiveMessages;
    final hasThinking = _effectiveIsThinking;
    // Group consecutive assistant messages into "turns" so we can show
    // a single collapsed "Saqqar thinking · N steps · Xs" pill instead
    // of N separate intermediate bubbles. Final reply in each turn
    // stays expanded as a normal message. Web parity per user request.
    final timeline = _buildTimeline(messages);
    final thinkingIndex = timeline.length;

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
    final firstApprovalIndex = timeline.length + (hasThinking ? 1 : 0);
    final totalCount = timeline.length +
        (hasThinking ? 1 : 0) +
        pendingApprovals.length +
        1;

    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      itemCount: totalCount,
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
      // Pre-render ~1.5 screenfuls of off-screen bubbles so flick-
      // scrolling never hits a blank gap while the builder catches up.
      // Bumped from the default 250 dp — chat bubbles are taller than
      // average list rows because of the markdown body.
      cacheExtent: 1500,
      itemBuilder: (context, index) {
        // Trailing spacer.
        if (index == totalCount - 1) return const SizedBox(height: 16);

        // Inline approval cards (immediately after thinking row /
        // after the last real message).
        if (index >= firstApprovalIndex &&
            index < firstApprovalIndex + pendingApprovals.length) {
          final approval = pendingApprovals[index - firstApprovalIndex];
          return ResponsiveContent(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: FadeSlideIn(
              duration: const Duration(milliseconds: 220),
              offset: const Offset(0, 6),
              child: ChatApprovalCard(
                approval: _adaptApiApproval(approval),
                onApprove: () => _decideApprovalInline(approval, true),
                onReject: () => _decideApprovalInline(approval, false),
              ),
            ),
          );
        }

        // Typing indicator slot — sits after the last timeline entry.
        if (hasThinking && index == thinkingIndex) {
          final previousMessage = timeline.isEmpty
              ? null
              : timeline.last.lastMessage;
          final firstOfGroup = previousMessage == null ||
              previousMessage.role != DemoMessageRole.assistant;
          return ResponsiveContent(
            maxWidth: 760,
            padding: EdgeInsets.fromLTRB(14, firstOfGroup ? 14 : 2, 14, 0),
            child: ChatTypingRow(
              firstOfGroup: firstOfGroup,
              statusLabel: _contextualActivityLabel(previousMessage),
            ),
          );
        }

        // Timeline entry — either a single message bubble or a
        // grouped agent turn (thinking pill + final reply).
        final entry = timeline[index];
        final previousEntry = index == 0 ? null : timeline[index - 1];
        final entryAnchor = entry.firstMessage;
        final previousLast = previousEntry?.lastMessage;

        // Date separator above the first message of a new calendar day.
        final showDateSeparator = entryAnchor.createdAt != null &&
            ChatDateSeparator.needs(
              previousLast?.createdAt,
              entryAnchor.createdAt!,
            );

        final animated = FadeSlideIn(
          duration: const Duration(milliseconds: 220),
          offset: const Offset(0, 6),
          child: _buildTimelineEntry(
            entry,
            showDateSeparator: showDateSeparator,
            previousLast: previousLast,
          ),
        );

        if (!showDateSeparator) return animated;
        return Column(
          children: [
            ChatDateSeparator(date: entryAnchor.createdAt!),
            animated,
          ],
        );
      },
    );
  }

  /// Renders one [_TimelineEntry] as either a plain [MessageRow] or a
  /// [ChatThinkingPill] + the final reply. Keeps the bubble-grouping
  /// (`isFirstOfGroup` / `isLastOfGroup`) heuristics out of the
  /// itemBuilder closure so the index math up top stays readable.
  Widget _buildTimelineEntry(
    _TimelineEntry entry, {
    required bool showDateSeparator,
    required DemoMessage? previousLast,
  }) {
    if (entry is _SingleMessageEntry) {
      final message = entry.message;
      final isFirstOfGroup = previousLast == null ||
          previousLast.role != message.role;
      return ResponsiveContent(
        maxWidth: 760,
        padding: EdgeInsets.fromLTRB(
          14,
          isFirstOfGroup && !showDateSeparator ? 14 : 2,
          14,
          6,
        ),
        child: MessageRow(
          message: message,
          isFirstOfGroup: isFirstOfGroup,
          isLastOfGroup: true,
        ),
      );
    }
    final turn = entry as _AgentTurnEntry;
    final finalReply = turn.finalReply;
    final pillThenReply = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatThinkingPill(
          steps: turn.thinkingSteps,
          totalDuration: turn.duration,
        ),
        const SizedBox(height: 6),
        MessageRow(
          message: finalReply,
          isFirstOfGroup: true,
          isLastOfGroup: true,
        ),
      ],
    );
    return ResponsiveContent(
      maxWidth: 760,
      padding: EdgeInsets.fromLTRB(14, showDateSeparator ? 2 : 14, 14, 6),
      child: pillThenReply,
    );
  }

  /// Walks the flat message list and bundles each user-→-agent round
  /// into a [_TimelineEntry]. Runs of 2+ consecutive assistant messages
  /// collapse into one [_AgentTurnEntry] (everything before the last
  /// becomes "thinking steps"; the last stays as the final reply).
  /// Single user messages and lone assistant replies map straight to
  /// [_SingleMessageEntry] so unchanged turns render exactly as before.
  List<_TimelineEntry> _buildTimeline(List<DemoMessage> messages) {
    final out = <_TimelineEntry>[];
    var i = 0;
    while (i < messages.length) {
      final m = messages[i];
      if (m.role != DemoMessageRole.assistant) {
        out.add(_SingleMessageEntry(m));
        i++;
        continue;
      }
      // Collect a run of consecutive assistant messages.
      var j = i;
      while (j < messages.length &&
          messages[j].role == DemoMessageRole.assistant) {
        j++;
      }
      final run = messages.sublist(i, j);
      if (run.length == 1) {
        out.add(_SingleMessageEntry(run.first));
      } else {
        out.add(_AgentTurnEntry(
          thinkingSteps: run.sublist(0, run.length - 1),
          finalReply: run.last,
        ));
      }
      i = j;
    }
    return out;
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

  /// Previously opened a bottom-sheet env picker fed by demo data. The
  /// header dropdowns (Project + Environment) are now the single
  /// source of truth — sourced from `VaultCubit.data` (real API) for
  /// existing chats, and snapshot-bound on the server for sends. The
  /// sheet's demo data was confusing users (it showed envs they didn't
  /// own).
  ///
  /// This stub stays so the existing call sites
  /// (`onCredentialTap`, send-with-no-env) compile without a wider
  /// refactor — it just nudges the user to the dropdowns instead of
  /// popping the demo sheet.
  Future<void> _openEnvironmentPicker() async {
    _toast(context.tr.pickEnvironmentToStart);
  }

  // The `_openConversationMenu` sheet was retired on 2026-05-17 — the
  // brief §4.1/§4.3 moved its surfaces (Action Center, Approvals,
  // Artifacts, Activity, Share, Pin, Rename, Archive, Delete) into the
  // chat's rail drawer (bell trigger) so the chat header only carries
  // the hamburger + title + bell. The individual handlers it used to
  // dispatch to (`_openActionCenter`, `_openArtifacts`,
  // `_openServerActivity`, `_renameConversation`, `_togglePin`) are still
  // alive — they're now invoked from inside the drawer instead.

  void _openActionCenter() {
    final approvalsState = context.read<ApprovalsCubit>().state;
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
                                context
                                    .read<ApprovalsCubit>()
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
                            context
                                .read<ApprovalsCubit>()
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
    final approvalsState = context.read<ApprovalsCubit>().state;
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
                    final cubit = context.read<ApprovalsCubit>();
                    if (approval.isGrouped) {
                      cubit.approveAllInGroup(approval);
                    } else {
                      cubit.decide(
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
                    context
                        .read<ApprovalsCubit>()
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

/// Bell icon in the chat AppBar's end slot — opens the rail drawer
/// (Approvals + Artifacts + Activity tabs). The amber pip in the
/// top-end corner shows the pending-approvals count for this
/// conversation so the user knows there's something waiting even
/// before opening the drawer.
class _InboxBellTrigger extends StatelessWidget {
  const _InboxBellTrigger({required this.badgeCount, required this.onTap});

  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: s.border, width: 1),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Material(
        color: Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(AppIcons.bell, color: s.text, size: 20),
                if (badgeCount > 0)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.warning,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: s.surface, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adapts a server-shaped [api.Message] into the demo-shaped
/// [DemoMessage] the existing chat widgets still consume.
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
DemoMessage _adaptApiMessage(api.Message m, BuildContext context) {
  return DemoMessage(
    role: switch (m.role) {
      api.MessageRole.user => DemoMessageRole.user,
      // Tool + system messages render in the assistant lane; the chat
      // widgets don't visually distinguish those today.
      api.MessageRole.assistant ||
      api.MessageRole.tool ||
      api.MessageRole.system =>
        DemoMessageRole.assistant,
    },
    content: m.content,
    // Web-parity full timestamp under the bubble. The chat row also
    // renders a date separator above the first message of a new
    // calendar day; both reference `createdAt` so they stay in sync.
    time: AppDateFormat.fullDateTime(context, m.createdAt),
    createdAt: m.createdAt,
    toolName: (m.toolName ?? '').isEmpty ? null : m.toolName,
    attachments: m.attachments.map(_adaptApiAttachment).toList(),
  );
}

DemoAttachment _adaptApiAttachment(api.Attachment a) {
  return DemoAttachment(
    name: a.originalName,
    kind: a.kind.toUpperCase(),
    size: _humanSize(a.sizeBytes),
    imageUrl: a.kind == 'image' ? a.absoluteUrl : null,
    // Carry the server-side id + absolute URL so the AttachmentChip
    // tap handler can download + open the file via [ArtifactDownloader].
    serverId: a.id,
    downloadUrl: a.absoluteUrl,
  );
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}

/// Source-agnostic env reference resolved by [_ChatScreenState._resolveEnv].
///
/// Built from either:
///   * A real [Environment] looked up via `VaultCubit` (the common case
///     once Phase 4 ships — header dropdowns feed real UUIDs), OR
///   * A `DemoEnvironment` for legacy seeded chats that still carry
///     hardcoded ids.
///
/// Kept as a flat record-shaped class so the send flow doesn't have to
/// import either source-of-truth type.
class _ResolvedEnv {
  const _ResolvedEnv({
    required this.id,
    required this.name,
    required this.isLive,
    required this.readOnly,
    required this.projectId,
    required this.projectName,
  });

  final String id;
  final String name;
  final bool isLive;
  final bool readOnly;
  final String projectId;
  final String projectName;
}

// ─────────────────────────────────────────────────────────────────────────
// Chat timeline entries
// ─────────────────────────────────────────────────────────────────────────

/// One renderable slot in the chat list. The flat `messages` list gets
/// reshaped into this sealed family by [_ChatScreenState._buildTimeline]
/// so consecutive agent steps can be folded into a single "Saqqar
/// thinking" pill above the final reply (web parity, per user request).
sealed class _TimelineEntry {
  const _TimelineEntry();

  /// First message in this entry — used for date-separator anchoring
  /// (calendar-day boundary against the previous entry).
  DemoMessage get firstMessage;

  /// Last message in this entry — used for the "previous role" check
  /// when the next entry starts a new group.
  DemoMessage get lastMessage;
}

/// A solo bubble — either a user message or a lone assistant reply
/// that had no thinking steps preceding it.
class _SingleMessageEntry extends _TimelineEntry {
  const _SingleMessageEntry(this.message);

  final DemoMessage message;

  @override
  DemoMessage get firstMessage => message;

  @override
  DemoMessage get lastMessage => message;
}

/// A multi-step agent turn: all intermediate "thinking" assistant
/// messages collapsed into a pill, plus the final reply that gets
/// rendered as a normal bubble below it.
class _AgentTurnEntry extends _TimelineEntry {
  const _AgentTurnEntry({
    required this.thinkingSteps,
    required this.finalReply,
  });

  final List<DemoMessage> thinkingSteps;
  final DemoMessage finalReply;

  @override
  DemoMessage get firstMessage =>
      thinkingSteps.isEmpty ? finalReply : thinkingSteps.first;

  @override
  DemoMessage get lastMessage => finalReply;

  /// Wall-clock duration the agent spent on this turn — first thinking
  /// step's `createdAt` → final reply's `createdAt`. Returns null when
  /// either side is missing a timestamp (older cached messages) so the
  /// pill can hide the `· 14s` segment cleanly.
  Duration? get duration {
    if (thinkingSteps.isEmpty) return null;
    final start = thinkingSteps.first.createdAt;
    final end = finalReply.createdAt;
    if (start == null || end == null) return null;
    final delta = end.difference(start);
    return delta.isNegative ? null : delta;
  }
}
