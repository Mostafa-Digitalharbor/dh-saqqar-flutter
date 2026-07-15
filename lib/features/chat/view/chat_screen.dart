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
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/network/view_model/connectivity_cubit.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
// Dead with the conversation menu — the rail drawer renders counts as
// tab-label suffixes, not as mini chips on a sheet item.
// import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../billing/view_model/plan_cubit.dart';
import '../../demo/saqqar_demo_data.dart';
import '../view_model/deep_think_cubit.dart';
import '../data/live_env_ack_service.dart';
import '../data/transcribe_api.dart';
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
import '../../share/intake/share_intake_service.dart';
import '../../vault/data/projects_api.dart';
import '../../vault/view_model/vault_cubit.dart';
import '../../vault/widgets/project_detail_sheet.dart';
import '../view_model/chat_cubit.dart';
import '../view_model/chat_state.dart';
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

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver {
  // -------- State --------

  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  late List<DemoMessage> _messages;

  /// Snapshot of the messages currently rendered in the lane — cached each
  /// build so the AppBar's in-conversation search sheet can read them from
  /// a button callback (where `context.watch` isn't valid).
  List<DemoMessage> _searchableMessages = const [];

  /// In-memory cache of the last scroll offset per conversation id so
  /// jumping out (Conversations tab, another chat) and back lands the
  /// user exactly where they were reading instead of slamming back to
  /// the latest message.
  ///
  /// A `null` value is the "was at bottom" sentinel — we save null when
  /// the user is at / near the latest message, so re-entering a chat
  /// they were actively following keeps auto-scrolling to bottom on the
  /// next visit (which is what "stay on the latest" should mean), not
  /// freezing them at the old maxScrollExtent.
  ///
  /// Survives in-session navigation only — wiped on app restart, which
  /// is the right semantics: a cold start should feel fresh.
  static final Map<String, double?> _savedScrollOffsets = {};

  /// Guards [_restoreScrollIfNeeded] so the restore only fires on the
  /// first frame after the message list has actual children. Without
  /// this, the post-frame callback would re-jump on every state emit.
  bool _hasRestoredScroll = false;

  /// Active environment id for this conversation. Null means "no env picked
  /// yet" — the chat blocks Send until the user picks one, matching the
  /// web's `state.conversation.environment === null` guard.
  String? _environmentId;

  /// Full set of environments bound to this conversation (primary included).
  /// A conversation can carry more than one — mirrors the web's multi-select
  /// environment dropdown. For existing chats the server snapshot is the
  /// source of truth (see [_activeEnvironmentIds]); this local copy holds the
  /// new-chat selection until the first send binds it server-side.
  List<String> _environmentIds = const <String>[];

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

  /// Currently staged attachments. Non-empty when the user has picked
  /// one or more files via the paperclip OR received a share-intent
  /// hand-off from another app. Each entry renders as its own chip in
  /// the composer and Send becomes enabled even on empty text.
  ///
  /// Stays in sync with [_pendingFiles] by index — `_attachments[i]` is
  /// the display metadata for `_pendingFiles[i]`. The two lists exist
  /// because chips only need the metadata, but uploads need the actual
  /// `File` on disk and the deferred-upload path in
  /// `_sendAsNewConversation` doesn't have the `File` handy from the
  /// chip alone.
  final List<DemoAttachment> _attachments = [];
  final List<File> _pendingFiles = [];

  bool _showScrollDown = false;
  bool _isThinking = false;

  /// True while the "Use My Database" one-click (Gap H) is in flight —
  /// drives the spinner on the env-hint banner button.
  bool _bindingDefaultEnv = false;

  /// Optimistic flag flipped the moment the user taps Stop. Cleared once
  /// the cancel propagates (today: end of the thinking timer; later: when
  /// the server confirms `is_running=false`). While true, the Stop button
  /// renders as a spinner and is non-interactive so the user can't tap it
  /// twice.
  bool _stopping = false;

  /// UI-only "I pressed Stop and I want the chat to LOOK stopped right
  /// now" override. Stop on the backend is cooperative — the agent
  /// finishes its current tool round before exiting — so [_effectiveIsThinking]
  /// would otherwise keep returning true for a couple of polls after the
  /// tap. Testers (2026-05-23) reported that as "the Stop button does
  /// nothing", so we flip this flag immediately and ignore the server's
  /// `isRunning` until either (a) a new snapshot confirms the stop, or
  /// (b) the user fires another Send.
  bool _localStopOverride = false;

  // ── Voice recording state ───────────────────────────────────────────
  // Per SAQQAR_MOBILE_VOICE.md: the composer text field is replaced
  // with a recording overlay (waveform + timer + stop / discard) while
  // [_recording] is true. After stop, [_transcribing] is true until
  // `/api/v1/transcribe/` returns — the overlay shows "Transcribing…"
  // during that window. Hard-stop after 120 s via [_recordingHardStop].
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _recording = false;
  bool _transcribing = false;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTimer;
  Timer? _recordingHardStop;
  String? _recordingPath;

  /// Text of the most recent message sent on this chat. Captured inside
  /// [_send] *before* the composer is cleared so [_stopGeneration] can
  /// restore it — testers asked for "if I tap Stop, give me back what I
  /// just typed so I can edit and resend".
  String? _lastSentText;

  /// Wall-clock of the last send. Used as a grace window in the run-state
  /// sync: for a few seconds after a send we keep the optimistic "running"
  /// marker even though the snapshot still reads `is_running=false` (the
  /// server hasn't observed the new turn yet). Without this, the sync would
  /// clear the marker one frame after send — before the run ever starts —
  /// and the Chats list would never show "Saqqar is working".
  DateTime? _lastSendAt;

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

  // Report progress is now read live from the snapshot's
  // `conversation.runProgress` (see [_liveRunProgress]) — no client-side
  // timer/simulation. The old `_runProgress` / `_progressTimer` /
  // `_thinkingTimer` / `_loadingTimer` fields drove a fabricated progress
  // bar and were removed in the de-fabrication pass.

  bool get _isNewChat => widget.conversationId == UiStrings.newConversationId;

  // _isUnknownChat removed: the demo seed lookup was producing false
  // "Conversation not found" errors for conversations created on the
  // web (real UUIDs aren't in the seed). Truly missing conversations
  // surface as a 404 from the snapshot API now — DataStateView handles
  // the error rendering uniformly.

  /// How many visible messages the lane currently shows. The chat opens on
  /// the most-recent [_visibleStep]; the "Load earlier" button grows this by
  /// [_visibleStep] each tap (revealing 10 older messages at a time) until
  /// the whole transcript is on screen. Display-only — the cubit still holds
  /// every loaded message; this just windows what we render.
  static const _visibleStep = 10;
  int _visibleLimit = _visibleStep;

  /// Predicate for "this server message is shown to the user" — drops the
  /// agent's internal plumbing (tool outputs, empty tool-call invocations,
  /// system-injected user payloads, `[agent-control]` directives). Shared by
  /// [_allVisibleMessages] (render) and [_loadedVisibleCount] (paging math)
  /// so the two never disagree on what counts as a visible message.
  bool _isVisibleMessage(api.Message m) {
    if (m.role == api.MessageRole.tool) return false;
    if (m.role == api.MessageRole.assistant && m.content.trim().isEmpty) {
      return false;
    }
    if (m.role == api.MessageRole.user && _isSystemUserPayload(m.content)) {
      return false;
    }
    if (_isAgentControlPayload(m.content)) return false;
    return true;
  }

  /// Count of currently-LOADED visible messages (whole loaded snapshot, not
  /// the rendered window). Uses `context.read` so it's safe to call from
  /// event handlers like [_loadEarlier].
  int _loadedVisibleCount() {
    if (_isNewChat) return _messages.length;
    final snapshot = context.read<ChatCubit>().state.data.dataOrNull;
    if (snapshot == null) return 0;
    return snapshot.messages.where(_isVisibleMessage).length;
  }

  // Memo for [_allVisibleMessages]. The adaptation (filter + map to
  // `DemoMessage` + per-row intl date formatting) is a pure function of the
  // snapshot object and the locale, but the getter is invoked ~4× per
  // build() (count, effective-slice, message-list, search) — so without a
  // cache the whole transcript is re-adapted four times every frame, and
  // every frame is a 1.5 s poll tick. Keyed on `identical(snapshot)` so it's
  // provably correct: a new snapshot object (the only thing the cubit emits
  // on a real change) misses the cache and recomputes; repeated calls within
  // one build hit it. `_visibleLocaleTag` invalidates on a language switch
  // so timestamps re-localize.
  Object? _visibleMemoSnapshot;
  String? _visibleMemoLocaleTag;
  List<DemoMessage>? _visibleMemo;

  /// EVERY loaded visible message (no display window), adapted to the
  /// demo-shaped widgets. Source of truth for the count + in-chat search.
  ///
  /// * **Existing chats** — read from the `ChatCubit` snapshot via
  ///   `context.watch`, so the screen rebuilds on each polling tick.
  /// * **New chats** — the local optimistic list (no cubit yet).
  List<DemoMessage> get _allVisibleMessages {
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
    final adapted = snapshot.messages
        .where(_isVisibleMessage)
        .map((m) => _adaptApiMessage(m, context))
        .toList();
    _visibleMemoSnapshot = snapshot;
    _visibleMemoLocaleTag = localeTag;
    _visibleMemo = adapted;
    return adapted;
  }

  /// The windowed slice actually rendered in the lane — the most-recent
  /// [_visibleLimit] visible messages. "Load earlier" grows the window.
  List<DemoMessage> get _effectiveMessages {
    final all = _allVisibleMessages;
    if (_isNewChat || all.length <= _visibleLimit) return all;
    return all.sublist(all.length - _visibleLimit);
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
  ///
  /// Respects [_localStopOverride] so the UI reads "stopped" the instant
  /// the user taps Stop, even though the server-side cancel is
  /// cooperative and may take another poll or two to confirm.
  bool get _effectiveIsThinking {
    if (_localStopOverride) return false;
    if (_isNewChat) return _isThinking;
    final snapshot =
        context.watch<ChatCubit>().state.data.dataOrNull;
    return snapshot?.conversation.isRunning ?? false;
  }

  /// Inert placeholder used ONLY as a last-resort title fallback in the
  /// rename dialog when the live title isn't in the list cubit yet. Carries
  /// no data — real chats always source their title from ConversationsCubit
  /// / the snapshot (see `_renameConversation`, `_effectiveChatTitle`).
  DemoConversation get _conversation => DemoConversation(
        id: UiStrings.newConversationId,
        title: context.tr.startConversation,
        preview: context.tr.liveAccessNote,
        updatedLabel: context.tr.now,
        messageCount: 0,
        activeCredential: UiStrings.none,
      );

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
    // No bound env resolved from the snapshot or the vault → truly none.
    return null;
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

  /// Full set of environment ids bound to this conversation, feeding the
  /// header's multi-select pill (primary + "+N"). For existing chats the
  /// server snapshot's `environments` list wins; for new chats the local
  /// selection stands in until the first send binds it.
  ///
  /// Falls back to the singular primary when the server hasn't yet echoed a
  /// plural list (older backends / first render) so the pill never loses the
  /// one env the gate already knows about.
  List<String> get _activeEnvironmentIds {
    if (!_isNewChat) {
      final snapshot = context.watch<ChatCubit>().state.data.dataOrNull;
      final conv = snapshot?.conversation;
      if (conv != null) {
        if (conv.environments.isNotEmpty) {
          return conv.environments.map((e) => e.id).toList();
        }
        final primary = conv.environment?.id;
        if (primary != null) return [primary];
      }
    }
    return _environmentIds;
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
      _environmentIds = const <String>[];
    });
    try {
      await context.read<ConversationsRepository>().patch(
            id: widget.conversationId,
            environmentId: '',
            environmentIds: const <String>[],
          );
      if (!mounted) return;
      // Refresh the snapshot so the new env=null surfaces immediately.
      await context.read<ChatCubit>().refresh();
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Handler for the environment multi-select pill.
  ///
  /// Receives the full set of checked environment ids from
  /// [EnvironmentMultiSelectSheet]. An empty list clears all bindings.
  ///
  /// A "primary" env is still needed — it drives project coherence and the
  /// send-gate ([_activeEnvironmentId]). We keep the current primary if it's
  /// still in the set, otherwise fall back to the first selected env.
  ///
  /// New chat → stash locally; the first send creates the conv with this set
  /// bound. Existing chat → PATCH `environment_id` (primary) +
  /// `environment_ids` (full set); the snapshot refresh reconciles.
  Future<void> _handleEnvironmentsChanged(List<String> ids) async {
    final vault = context.read<VaultCubit>().state.data.dataOrNull;
    // Read (never watch) the current primary here — this runs from a tap
    // handler, outside build, where `context.watch` throws. Mirrors the
    // snapshot-then-local fallback of [_activeEnvironmentId].
    String? currentPrimary;
    if (!_isNewChat) {
      currentPrimary = context
          .read<ChatCubit>()
          .state
          .data
          .dataOrNull
          ?.conversation
          .environment
          ?.id;
    }
    currentPrimary ??= _environmentId;
    final String primary = ids.isEmpty
        ? ''
        : (currentPrimary != null && ids.contains(currentPrimary)
            ? currentPrimary
            : ids.first);
    final primaryEnv = primary.isEmpty ? null : vault?.environmentById(primary);

    void applyLocal() {
      setState(() {
        _environmentIds = List<String>.from(ids);
        _environmentId = primary.isEmpty ? null : primary;
        if (primaryEnv != null) {
          _projectId = primaryEnv.projectId;
          if (primaryEnv.autoApprove) _autoApprove = true;
        }
      });
    }

    if (_isNewChat) {
      applyLocal();
      if (ids.isNotEmpty) _toast(context.tr.envMultiUpdated);
      return;
    }
    // Existing chat — reflect locally for instant feedback, then PATCH the
    // server. The snapshot refresh reconciles if the server rejected.
    applyLocal();
    try {
      await context.read<ConversationsRepository>().patch(
            id: widget.conversationId,
            environmentId: primary,
            environmentIds: ids,
          );
      if (!mounted) return;
      await context.read<ChatCubit>().refresh();
      if (!mounted) return;
      _toast(context.tr.envMultiUpdated);
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

  /// Fired by [ChatHeaderControls] when a brand-new account (zero projects)
  /// taps the project slot's "Use My Database" CTA.
  ///
  /// One-click onboarding: ensure a default project + production environment
  /// exist server-side (`POST /projects/default/`), refresh the Vault so the
  /// dropdowns populate, then select the new env locally so the user can
  /// start chatting immediately. Prompts for credentials when the new env
  /// can't reach Odoo yet. Reuses the Gap H default-env plumbing.
  Future<void> _handleCreateProjectRequested() async {
    if (_bindingDefaultEnv) return;
    final tr = context.tr;
    final ok = await ConfirmDialog.show(
      context,
      title: tr.useMyDatabaseTitle,
      body: tr.envHintBody,
      confirmLabel: tr.envHintUseMyDatabase,
      icon: AppIcons.database,
    );
    if (!ok || !mounted) return;
    setState(() => _bindingDefaultEnv = true);
    try {
      final env = await context.read<ProjectsApi>().defaultProject();
      if (!mounted) return;
      // Refresh the Vault so the freshly-created project + env appear in the
      // header dropdowns (and the rest of the app).
      await context.read<VaultCubit>().refresh();
      if (!mounted) return;
      setState(() {
        _projectId = env.projectId;
        _environmentId = env.id;
      });
      _toast(
        env.hasXmlrpc
            ? tr.envHintBound
            : tr.envHintNeedsCredentials,
      );
    } catch (e) {
      if (!mounted) return;
      // Surface the server's actual reason (e.g. "Odoo connection failed:
      // invalid credentials") after the friendly action label, instead of a
      // bare "couldn't set up" — so the user knows WHAT to fix.
      _toast(ApiErrorMapper.message(context, e, actionContext: tr.envHintFailed));
    } finally {
      if (mounted) setState(() => _bindingDefaultEnv = false);
    }
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

    // Existing chats resolve their bound env from the server snapshot (see
    // `_resolveEnv`); new chats from the local vault picker. No demo seed.
    _scroll.addListener(_onScrollChanged);
    // Listen for app foreground / background transitions so the chat
    // poll timer pauses when the user minimises the app — without this,
    // a chat sitting in a paused process keeps firing GET requests
    // every 1.5 s (running) / 15 s (idle), draining battery and data.
    WidgetsBinding.instance.addObserver(this);
    // If we arrived here via a share-intent hand-off, drain the staged
    // files into the composer the instant the screen mounts. Deferred to
    // the first post-frame callback because the upload path (existing
    // chats) reads from `context.read<ChatCubit>()`, which only resolves
    // once the BlocProvider above us has built its child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consumeShareIntake();
    });
    // Also subscribe to the service for the **same-chat case**: when
    // the user is already inside chat A and the destination sheet
    // routes the share to chat A, `context.go('/chats/A')` is a no-op
    // (same route → no initState → no post-frame drain). The listener
    // catches the `deliverTo()` notification the bootstrap fires right
    // before navigation and we drain inline. `_consumeShareIntake`
    // gates on `_targetChatId == widget.conversationId` via
    // [ShareIntakeService.take], so other chat screens that happen to
    // be listening (e.g. an unmounted-soon previous chat) don't snatch
    // the batch.
    _shareIntakeService = context.read<ShareIntakeService>();
    _shareIntakeService!.addListener(_onShareIntakeChanged);
    // Loading skeleton state now comes from the cubit's DataLoading
    // (see the build method) — no local timer needed.
  }

  /// Reference held so [dispose] can detach the listener even after
  /// [context] is gone. `late final` would be nicer but the field is
  /// nullable so we can use `?.` in dispose without races.
  ShareIntakeService? _shareIntakeService;

  /// Fires whenever the share intake service mutates. We only care about
  /// the "files were just committed to THIS chat" event — the gate
  /// inside [_consumeShareIntake] (`service.take(widget.conversationId)`)
  /// turns every other notification into a no-op.
  void _onShareIntakeChanged() {
    if (!mounted) return;
    final service = _shareIntakeService;
    if (service == null) return;
    if (!service.hasStaged) return;
    if (service.targetChatId != widget.conversationId) return;
    _consumeShareIntake();
  }

  /// Drains [ShareIntakeService] into [_attachments] / [_pendingFiles]
  /// when the user has just picked this chat as the destination for an
  /// Android share intent. No-op for the common case where the screen
  /// was opened normally (paperclip, tab nav, deep link).
  Future<void> _consumeShareIntake() async {
    final service = context.read<ShareIntakeService>();
    if (!service.hasStaged) return;
    // Gate on the bootstrap's `_targetChatId` — when set, only the
    // chat the user picked drains the batch. When unset (cold-start
    // path, no destination sheet involved), the first chat to land
    // gets the files.
    final files = service.take(widget.conversationId);
    if (files.isEmpty) return;

    // Build the chips synchronously — `lengthSync` instead of the
    // async `length()` means the setState below lands in the SAME
    // microtask as the deliverTo notification, before any rebuild can
    // intervene. The async version used to lose the setState when the
    // bootstrap's `context.go` happened to recreate the chat page
    // mid-await (2026-05-23 tester report: file only showed up after
    // exiting + re-entering the chat).
    final chips = <DemoAttachment>[];
    final keptFiles = <File>[];
    for (final f in files) {
      final name = f.path.split(RegExp(r'[\\/]')).last;
      final ext = name.contains('.') ? name.split('.').last : '';
      int size;
      try {
        size = f.lengthSync();
      } catch (_) {
        // Some content-URIs don't expose length until they're streamed —
        // fall back to 0 and let the chip subtitle read "0 B" rather
        // than blocking the whole batch on one unreadable entry.
        size = 0;
      }
      chips.add(DemoAttachment(
        name: name,
        kind: _kindForExtension(ext),
        size: _formatBytes(size),
        imageUrl: _isImageExt(ext) ? f.path : null,
      ));
      keptFiles.add(f);
    }
    if (!mounted || keptFiles.isEmpty) return;

    setState(() {
      _attachments.addAll(chips);
      _pendingFiles.addAll(keptFiles);
    });

    // Mirror the paperclip flow: existing chats eagerly upload so the
    // attachment ids are on the server by the time the user hits Send.
    // New chats defer to `_sendAsNewConversation` (no conversation id
    // exists yet to bind the upload to).
    if (!_isNewChat) {
      final cubit = context.read<ChatCubit>();
      final ok = await cubit.uploadAttachments(keptFiles);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          for (final f in keptFiles) {
            final idx = _pendingFiles.indexOf(f);
            if (idx >= 0) {
              _pendingFiles.removeAt(idx);
              if (idx < _attachments.length) _attachments.removeAt(idx);
            }
          }
        });
        _surfaceActionFailure();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareIntakeService?.removeListener(_onShareIntakeChanged);
    _recordingTimer?.cancel();
    _recordingHardStop?.cancel();
    // Don't await — the recorder's stop() returns a Future but the
    // State is going away anyway; the temp file will be GC'd by the
    // OS the next time it cleans the temp dir.
    unawaited(_audioRecorder.cancel());
    unawaited(_audioRecorder.dispose());
    _scroll.removeListener(_onScrollChanged);
    _persistScrollOffset();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Voice recording lifecycle ───────────────────────────────────────

  /// Mic-tap entry point wired through [ChatComposer.onStartRecording].
  /// Owns the permission prompt, recorder setup, timer + hard-stop
  /// scheduling. Bail out if a recording is already in flight (the UI
  /// disables the mic, but defensive).
  /// Resolves microphone access before recording, returning true only when the
  /// mic is granted. Ordering is deliberate for App Store review (guideline
  /// 5.1.1(iv)): the system permission dialog is shown FIRST via `request()`;
  /// the user is never sent to Settings before that dialog has appeared. A
  /// Settings shortcut is offered ONLY once the permission is *permanently*
  /// denied, and only as an optional toast action the user chooses to tap.
  Future<bool> _ensureMicPermission() async {
    final current = await Permission.microphone.status;
    if (!mounted) return false;
    if (current.isGranted) return true;

    // Already permanently denied (or restricted by device policy): the OS will
    // not surface the dialog again, so recording can't proceed without a manual
    // change. Offer — never force — a Settings shortcut.
    if (current.isPermanentlyDenied || current.isRestricted) {
      _micPermissionToast(offerSettings: true);
      return false;
    }

    // notDetermined / denied-but-askable: show the native prompt now. This is
    // the user's first sight of anything permission-related.
    final result = await Permission.microphone.request();
    if (!mounted) return false;
    if (result.isGranted) return true;

    // Denied at the prompt. Offer the Settings shortcut only if the OS now
    // marks it permanent; otherwise keep the message gentle with no Settings
    // mention (the user can simply tap the mic again to get the prompt back).
    _micPermissionToast(offerSettings: result.isPermanentlyDenied);
    return false;
  }

  /// Localised "mic access needed" toast. When [offerSettings] is true it
  /// carries an optional, user-initiated "Open Settings" action — the only
  /// place in the app that ever calls `openAppSettings()`.
  void _micPermissionToast({required bool offerSettings}) {
    AppToast.show(
      context,
      message: offerSettings
          ? context.tr.voicePermissionOpenSettings
          : context.tr.voicePermissionDenied,
      action: offerSettings
          ? ToastAction(
              label: context.tr.openSettings,
              onPressed: openAppSettings,
            )
          : null,
    );
  }

  Future<void> _startRecording() async {
    if (_recording || _transcribing) return;
    // Permission gate. Ordering matters for App Store review (guideline
    // 5.1.1(iv)): the native OS prompt must be the FIRST permission-related
    // thing the user ever sees — we never route them to Settings before it.
    if (!await _ensureMicPermission()) return;
    // m4a + AAC + mono + 16 kHz + 32 kbps — see SAQQAR_MOBILE_VOICE.md §3.
    // Output file lives under the OS temp dir; we delete it after the
    // transcribe upload (or on discard).
    final tmp = await getTemporaryDirectory();
    final path =
        '${tmp.path}/saqqar-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      final isSupported = await _audioRecorder.hasPermission();
      if (!isSupported) {
        if (!mounted) return;
        _toast(context.tr.micUnavailable);
        return;
      }
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 32000,
        ),
        path: path,
      );
    } catch (e, st) {
      AppLogger.warn('VoiceRecording', 'start failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      _toast(context.tr.micUnavailable);
      return;
    }
    if (!mounted) {
      // Race: widget left the tree mid-permission. Stop + delete.
      await _audioRecorder.cancel();
      return;
    }
    setState(() {
      _recording = true;
      _recordingElapsed = Duration.zero;
      _recordingPath = path;
    });
    // 100 ms tick gives smooth mm:ss readout without burning frames.
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _recordingElapsed += const Duration(milliseconds: 100);
      });
    });
    // Hard cap at 120 s per spec. Auto-stop, surface the toast, then
    // fall through into the same transcribe path the tap-stop uses.
    _recordingHardStop = Timer(const Duration(seconds: 120), () {
      if (!mounted || !_recording) return;
      _toast(context.tr.voiceMaxLength);
      unawaited(_stopRecording());
    });
  }

  /// Tapped on the stop pill (or fired by [_recordingHardStop] at 120 s).
  /// Stops the recorder, flips to the "transcribing" state, uploads the
  /// audio file, and appends the returned text to the composer.
  Future<void> _stopRecording() async {
    if (!_recording) return;
    _recordingTimer?.cancel();
    _recordingHardStop?.cancel();
    final path = await _audioRecorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    final localPath = path ?? _recordingPath;
    if (localPath == null) {
      setState(() => _transcribing = false);
      _toast(context.tr.transcribeFailed);
      return;
    }
    final file = File(localPath);
    try {
      final transcript = await context.read<TranscribeApi>().transcribe(
            audio: file,
          );
      if (!mounted) return;
      if (transcript.isEmpty) {
        _toast(context.tr.transcribeEmpty);
      } else {
        // Append (don't replace) — preserves whatever the user already
        // typed before tapping mic. Caret jumps to the end so the user
        // can keep typing if they want.
        final existing = _composer.text;
        final joiner = existing.isEmpty || existing.endsWith(' ') ? '' : ' ';
        final next = '$existing$joiner$transcript';
        _composer.text = next;
        _composer.selection = TextSelection.collapsed(offset: next.length);
        // Restore focus so the keyboard stays up and the user can edit.
        _composerFocus.requestFocus();
      }
    } catch (e, st) {
      AppLogger.warn('VoiceRecording', 'transcribe failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      // Gap C — a 403 from /transcribe/ means voice is locked on the
      // caller's plan (the mic is normally hidden, but a stale snapshot or
      // a race can still let one request through). Map it to a friendly
      // "voice is a Pro feature" hint rather than the generic forbidden copy.
      final failure = ApiErrorMapper.toFailure(e);
      _toast(failure is ForbiddenFailure
          ? context.tr.voiceLockedPro
          : ApiErrorMapper.message(context, e));
    } finally {
      // Best-effort cleanup of the temp file (we either consumed it or
      // the upload failed — either way it's not useful anymore). Sync
      // check + async delete dodges the `avoid_slow_async_io` lint
      // without changing the semantics.
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _transcribing = false;
          _recordingPath = null;
          _recordingElapsed = Duration.zero;
        });
      }
    }
  }

  /// Tapped on the discard X. Drops the audio buffer without uploading
  /// and returns to idle. Disabled inside [RecordingOverlay] once
  /// transcription has started (the bytes are already in flight).
  Future<void> _discardRecording() async {
    if (!_recording) return;
    _recordingTimer?.cancel();
    _recordingHardStop?.cancel();
    await _audioRecorder.cancel();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingElapsed = Duration.zero;
      _recordingPath = null;
    });
    // Best-effort delete of whatever the recorder may have flushed.
    final path = _recordingPath;
    if (path != null) {
      try {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isNewChat) return;
    // ChatCubit owns the poll timer; pause it when the OS reports the
    // app left the foreground, resume on return. `paused` covers the
    // common "user swiped home" case; `inactive` is the transitional
    // state on iOS (phone call overlay, control center pull-down) and
    // also worth pausing for — polling resumes the moment the app is
    // visible again. `detached` means the process is being torn down,
    // so no work to do here.
    final cubit = context.read<ChatCubit>();
    switch (state) {
      case AppLifecycleState.resumed:
        cubit.resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        cubit.pause();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Snapshots the current scroll state to [_savedScrollOffsets] so the
  /// next time the user opens this conversation we can land them where
  /// they were instead of at the bottom. Stores `null` when they were
  /// at the latest message — see the field's doc for why.
  void _persistScrollOffset() {
    if (_isNewChat) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final atBottom = position.extentAfter < 32;
    _savedScrollOffsets[widget.conversationId] =
        atBottom ? null : position.pixels;
  }

  /// Jumps to the last-seen offset for this conversation (or to the
  /// latest message when there's nothing saved / the user left while
  /// pinned to bottom). One-shot: guarded by [_hasRestoredScroll] so
  /// it only fires on the first frame after messages render — every
  /// subsequent poll / state emit is a no-op.
  void _restoreScrollIfNeeded() {
    if (_hasRestoredScroll || _isNewChat) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) return;
    _hasRestoredScroll = true;
    final saved = _savedScrollOffsets[widget.conversationId];
    if (saved == null) {
      _scroll.jumpTo(position.maxScrollExtent);
      return;
    }
    _scroll.jumpTo(saved.clamp(0.0, position.maxScrollExtent));
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

  /// Reveals the previous [_visibleStep] (10) messages, driven by the
  /// explicit "Load earlier messages" header button.
  ///
  /// Two-tier so it's instant AND reliable:
  ///   * If the loaded snapshot still has older messages we haven't shown
  ///     yet, just grow the render window — instant, no network.
  ///   * Otherwise (window has caught up to everything loaded) pull the FULL
  ///     transcript once via [ChatCubit.loadOlder] (decoded off the UI
  ///     isolate), then reveal the next 10. After that every tap is instant.
  ///
  /// Always advances by exactly [_visibleStep] visible messages — the list
  /// keeps offset 0 so the button stays at the top for the next tap.
  Future<void> _loadEarlier() async {
    if (_isNewChat) return;
    final cubit = context.read<ChatCubit>();
    final loadedBefore = _loadedVisibleCount();
    final shownBefore =
        loadedBefore < _visibleLimit ? loadedBefore : _visibleLimit;
    // Everything loaded is already on screen — fetch more from the server.
    if (shownBefore >= loadedBefore && cubit.state.hasMoreOlder) {
      await cubit.loadOlder();
      if (!mounted) return;
    }
    setState(() => _visibleLimit = shownBefore + _visibleStep);
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

  /// Re-entrancy guard for [_send]. A fast double-tap (or Enter + tap) can
  /// fire the handler twice before the first pass clears the composer /
  /// morphs Send into Stop — which would POST the same message twice. Set
  /// synchronously at the top of [_send] so the second call bails instantly.
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    _sending = true;
    try {
      await _sendInternal();
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendInternal() async {
    final text = _composer.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

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

    // Deep-think source of truth depends on the chat lifecycle:
    //   * Existing chat → the conversation snapshot's `deep_think`
    //     (server is canonical, so a web-side flip lands here on the
    //     next poll). Fall back to the local cubit only when we don't
    //     have a snapshot yet (very first paint).
    //   * New chat → no conversation row exists, so the local cubit
    //     is the only state. We PATCH the new conv with this value
    //     below so its server default matches.
    final localDeepThink = context.read<DeepThinkCubit>().state;
    final deepThink = _isNewChat
        ? localDeepThink
        : (context
                .read<ChatCubit>()
                .state
                .data
                .dataOrNull
                ?.conversation
                .deepThink ??
            localDeepThink);

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
    // Snapshot the staged batch count BEFORE clearing so the success
    // toast below can read "Sent · 3 files attached" — testers asked
    // for explicit feedback that the picker output didn't vanish into
    // the void when they hit Send (2026-05-23).
    final stagedCount = _attachments.length;
    // Stash the outgoing text BEFORE clearing the composer so
    // [_stopGeneration] can restore it if the user changes their mind
    // mid-reply. Also clears any stale Stop override from a prior round
    // — a fresh send means the user is committing again.
    _lastSentText = text;
    _localStopOverride = false;
    _composer.clear();
    setState(() {
      _attachments.clear();
      _pendingFiles.clear();
    });
    _lastSendAt = DateTime.now();
    context.read<RunningAgentsCubit>().markRunning(widget.conversationId);
    final ok = await context.read<ChatCubit>().sendMessage(
          content: text.isEmpty ? context.tr.attachedFilesForReview : text,
          deepThink: deepThink,
        );
    if (!mounted) return;
    if (ok) {
      _scrollToBottomSoft();
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
    // Snapshot copies — we'll restore them onto the screen state if any of
    // the create / upload / send steps below blow up, so the user doesn't
    // lose a multi-file batch they painstakingly attached.
    final pendingFiles = List<File>.from(_pendingFiles);
    final attachmentChips = List<DemoAttachment>.from(_attachments);
    _composer.clear();
    setState(() {
      _attachments.clear();
      _pendingFiles.clear();
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
      // 2) Bind the picked environment AND persist the user's current
      //    deep-think preference onto the new conversation. Without the
      //    `deepThink` PATCH the new row would default to false server-
      //    side, so the next time we poll the snapshot the toggle would
      //    appear OFF even though the user has it ON locally. Pass null
      //    when the user has it off (matches server default; saves a
      //    no-op write) — non-null only when we need to flip it on.
      await repo.patch(
        id: newId,
        environmentId: env.id,
        // Bind the full multi-env set when the user checked more than the
        // primary in the header pill; null (single-env path) leaves just
        // env.id bound, matching the prior behavior.
        environmentIds: _environmentIds.length > 1 ? _environmentIds : null,
        deepThink: deepThink ? true : null,
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
        deepThink: deepThink,
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
      setState(() {
        _isThinking = false;
        // Restore the picked files + chips so the user doesn't have to
        // re-attach after a transient failure (network blip, server
        // 500 between create and send, etc.).
        _attachments
          ..clear()
          ..addAll(attachmentChips);
        _pendingFiles
          ..clear()
          ..addAll(pendingFiles);
      });
      _composer.text = pendingText == context.tr.attachedFilesForReview
          ? ''
          : pendingText;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Maps the server-reported `conversation.run_progress` (if any) onto the
  /// [ChatRunProgressCard]'s [RunProgress] shape so the card reflects the
  /// REAL export progress the backend streams — no client-side simulation.
  ///
  /// Returns null on new chats (no snapshot yet) and whenever the backend
  /// isn't mid-report, so the card only appears while a long-running
  /// Excel / PDF / Word job is actually running.
  RunProgress? get _liveRunProgress {
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
    return RunProgress(
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

  /// Opens the slash-command menu (design parity: composer "/" button →
  /// a glass sheet of common Odoo quick-ops). Picking one seeds the
  /// composer with the command token + a trailing space so the user can
  /// type the argument inline. Representative until the API exposes a
  /// real command registry.
  Future<void> _openSlashCommands() async {
    final tr = context.tr;
    final commands = <(IconData, String, String)>[
      (AppIcons.refresh, '/restart', tr.slashRestartDesc),
      (AppIcons.fileText, '/report', tr.slashReportDesc),
      (AppIcons.refresh, '/sync', tr.slashSyncDesc),
      (AppIcons.terminal, '/logs', tr.slashLogsDesc),
      (AppIcons.database, '/backup', tr.slashBackupDesc),
    ];
    final s = context.saqqar;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: s.cardBg,
                borderRadius: AppRadius.cardR,
                border: Border.all(color: s.cardBorder),
                boxShadow: s.glassShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: s.border)),
                    ),
                    child: Text(
                      tr.commandsHeader,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: s.muted,
                      ),
                    ),
                  ),
                  for (final c in commands)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(c.$2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: s.brandCyan.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.buttonR,
                                ),
                                child: Icon(c.$1,
                                    size: 15, color: s.brandCyan),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                c.$2,
                                style: context.text.titleSmall?.copyWith(
                                  fontFamily: 'JetBrainsMono',
                                  color: s.brandCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c.$3,
                                  style: context.text.bodySmall
                                      ?.copyWith(color: s.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final existing = _composer.text;
    final joiner =
        existing.isEmpty || existing.endsWith(' ') ? '' : ' ';
    final next = '$existing$joiner$picked ';
    _composer.text = next;
    _composer.selection = TextSelection.collapsed(offset: next.length);
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
  /// Drops a single staged attachment by index — clears its composer chip
  /// AND removes the matching cubit-side staged row so the next
  /// `sendMessage` doesn't ship the orphaned id. The screen-level
  /// `_attachments` / `_pendingFiles` lists and the cubit's
  /// `stagedAttachments` are appended to in the same order in
  /// [_pickAttachment], so positional index → cubit id maps 1:1 for any
  /// row whose upload has settled. Rows still mid-upload (or whose upload
  /// failed) haven't reached the cubit yet — we skip the cubit call for
  /// those and just drop the local row.
  void _removeAttachmentAt(int index) {
    if (index < 0 || index >= _attachments.length) return;
    if (!_isNewChat) {
      final cubit = context.read<ChatCubit>();
      final staged = cubit.state.stagedAttachments;
      if (index < staged.length) {
        cubit.removeStagedAttachment(staged[index].id);
      }
    }
    setState(() {
      _attachments.removeAt(index);
      if (index < _pendingFiles.length) {
        _pendingFiles.removeAt(index);
      }
    });
  }

  /// Opens a staged attachment so the user can verify they picked the
  /// right file before tapping Send. Images get a fullscreen
  /// [InteractiveViewer] dialog (pinch to zoom, tap outside to close);
  /// PDFs / Office docs / CSVs hand off to the OS's matching viewer via
  /// `OpenFilex`. Skips silently for indices that don't map to a real
  /// on-disk file (a row mid-upload that hasn't reached `_pendingFiles`
  /// yet — shouldn't happen given our pick flow, but defensive).
  Future<void> _previewAttachmentAt(int index) async {
    if (index < 0 || index >= _pendingFiles.length) return;
    final file = _pendingFiles[index];
    final chip = (index < _attachments.length) ? _attachments[index] : null;
    final isImage = chip?.isImage ?? false;
    if (isImage) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (dialogContext) => _LocalImagePreviewDialog(file: file),
      );
      return;
    }
    final result = await OpenFilex.open(file.path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      _toast(context.tr.defaultApiError);
    }
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
        // Archives (Gap F) — Odoo addon bundles. 500 MB cap (vs 25 MB for
        // the rest), enforced per-file below to match the server.
        'zip', 'tar', 'gz', 'tgz',
      ],
      withData: false,
      // Multi-select shipped in 1.0.2 after testers asked for "أرفق أكتر
      // من ملف لنفس الشات". The composer renders one chip per file and
      // Send batches them into a single multipart upload.
      allowMultiple: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final newChips = <DemoAttachment>[];
    final newFiles = <File>[];
    final tooLarge = <String>[];
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null || path.isEmpty) continue;
      // Kind-aware size cap (Gap F): archives up to 500 MB (addon zips),
      // everything else 25 MB. Matches the server, which 413s over the cap.
      final capMb = _isArchiveExt(picked.extension) ? 500 : 25;
      if (picked.size > capMb * 1024 * 1024) {
        tooLarge.add(picked.name);
        continue;
      }
      newChips.add(DemoAttachment(
        name: picked.name,
        kind: _kindForExtension(picked.extension),
        size: _formatBytes(picked.size),
        imageUrl: _isImageExt(picked.extension) ? picked.path : null,
      ));
      newFiles.add(File(path));
    }
    if (tooLarge.isNotEmpty) {
      // Name the cap of the first rejected file; the rest were skipped too.
      final firstExt = result.files
          .firstWhere((f) => f.name == tooLarge.first)
          .extension;
      _toast(context.tr.attachmentTooLarge(
        tooLarge.first,
        _isArchiveExt(firstExt) ? 500 : 25,
      ));
    }
    if (newFiles.isEmpty) return;

    // UI metadata for the composer chips — keeps the visual confirmation
    // instant even if the upload below is still in flight.
    setState(() {
      _attachments.addAll(newChips);
      _pendingFiles.addAll(newFiles);
    });

    // Existing chats own a [ChatCubit] — stage the uploads immediately
    // so the attachment ids are already on the server by the time the
    // user hits Send. New chats can't upload yet (no conversation id)
    // — _sendAsNewConversation does the deferred upload after it
    // creates the conversation.
    if (!_isNewChat) {
      final cubit = context.read<ChatCubit>();
      final ok = await cubit.uploadAttachments(newFiles);
      if (!mounted) return;
      if (!ok) {
        // Upload failed — drop just the chips we added this round so any
        // previously-staged batch the user might still want stays put.
        setState(() {
          for (final f in newFiles) {
            final idx = _pendingFiles.indexOf(f);
            if (idx >= 0) {
              _pendingFiles.removeAt(idx);
              if (idx < _attachments.length) _attachments.removeAt(idx);
            }
          }
        });
        _surfaceActionFailure();
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
    if (['zip', 'tar', 'gz', 'tgz'].contains(e)) return 'ZIP';
    return e.toUpperCase().padRight(3, ' ').trimRight();
  }

  bool _isImageExt(String? ext) =>
      ['png', 'jpg', 'jpeg', 'gif', 'webp']
          .contains((ext ?? '').toLowerCase());

  /// Archive extensions get the 500 MB cap (Odoo addon bundles); everything
  /// else stays at 25 MB. Mirrors the server's per-kind limit (Gap F).
  bool _isArchiveExt(String? ext) =>
      ['zip', 'tar', 'gz', 'tgz'].contains((ext ?? '').toLowerCase());

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
    // ── Optimistic UI flip ──────────────────────────────────────────
    // Hide the typing row + flip the Send button back from Stop the
    // INSTANT the user taps, then restore their last message into the
    // composer so they can edit + resend without retyping. Both happen
    // synchronously inside setState so the next frame already reads as
    // "not thinking".
    final restoreText = _lastSentText;
    setState(() {
      _localStopOverride = true;
      if (restoreText != null && restoreText.isNotEmpty &&
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
      setState(() {
        _isThinking = false;
        _stopping = false;
      });
    }
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
                  icon: AppIcons.backIos,
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
    // Watch the share intake service so this chat rebuilds whenever the
    // bootstrap notifies (stage / deliverTo / take). When the
    // bootstrap has just committed a batch to THIS chat — e.g. the
    // user shared from WhatsApp and picked "current chat" from the
    // destination sheet — schedule a post-frame consume so the staged
    // files land in `_attachments` without requiring the user to
    // leave + re-enter the chat. The post-frame defer is critical:
    // calling `_consumeShareIntake` inline would cause a setState
    // during build, which Flutter forbids. `take()` inside the
    // consumer empties the service so the next build won't re-trigger.
    final shareIntake = context.watch<ShareIntakeService>();
    if (shareIntake.hasStaged &&
        shareIntake.targetChatId == widget.conversationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _consumeShareIntake();
      });
    }
    // Source of truth for the per-conversation toggles:
    //   * Existing chat → live from the snapshot (server is canonical,
    //     so flipping from the web shows up here on the next poll).
    //   * New chat (no cubit yet) → local state until the conversation
    //     gets created; carried forward into the first send.
    final chatSnapshot = _isNewChat
        ? null
        : context.watch<ChatCubit>().state.data.dataOrNull;
    final snapshotConv = chatSnapshot?.conversation;
    // Server blocked this turn for being over a usage cap (Gap B). Drives
    // the quota banner + a disabled composer until the window resets.
    final quotaWindow = chatSnapshot?.quotaExceeded;
    final deepThink = snapshotConv?.deepThink ??
        context.watch<DeepThinkCubit>().state;
    final autoApprove = snapshotConv?.autoApprove ?? _autoApprove;

    // Mirror the server-authoritative `deep_think` back into the local
    // [DeepThinkCubit] AFTER the current frame so a flip on the web
    // (which lands via snapshot poll) also updates the persisted
    // preference. Without this, opening a NEW chat after a web-side
    // flip would still seed from the stale local value. Idempotent
    // inside the cubit's `set` — safe to fire on every rebuild.
    final serverDeepThink = snapshotConv?.deepThink;
    if (serverDeepThink != null && !_isNewChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<DeepThinkCubit>().set(serverDeepThink);
      });
    }

    // Surface the latest plan / quota / feature snapshot app-wide (Gap A)
    // so the account usage card, plan badge, and feature gating all read one
    // source of truth. Deferred a frame for the same reason as deep-think.
    final planSnapshot = snapshotConv?.plan;
    if (planSnapshot != null && !_isNewChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PlanCubit>().update(planSnapshot);
      });
    }

    // Mirror the SERVER's run state into the cross-app RunningAgentsCubit so
    // the Chats list shows the live "Saqqar is working" indicator for the
    // WHOLE generation (not just the ~1 s send request). markRunning/markIdle
    // no-op when already in the target state, so firing every build is cheap.
    if (!_isNewChat) {
      final running = snapshotConv?.isRunning ?? false;
      final convId = widget.conversationId;
      // Grace window: within ~12 s of a send, keep the optimistic marker even
      // if the snapshot still reads not-running — the server hasn't picked up
      // the new turn yet, and clearing here would race the run to false before
      // it ever flips true.
      final sentAt = _lastSendAt;
      final inGrace = sentAt != null &&
          DateTime.now().difference(sentAt) < const Duration(seconds: 12);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final agents = context.read<RunningAgentsCubit>();
        if (running) {
          agents.markRunning(convId);
        } else if (!inGrace) {
          agents.markIdle(convId);
        }
      });
    }

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
        // Slightly taller than Material's default (56 dp) so the
        // subtitle row inside [ChatAppBarTitle] can wrap to a second
        // line on tiny phones (320–360 px) when the env name + all
        // three flag badges (LIVE / READ-ONLY / AUTO) are present at
        // once. On a roomy screen the AppBar still renders at the
        // same effective height because the wrap stays on one line.
        toolbarHeight: 64,
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
          // Search-in-conversation — the design's header search affordance.
          // Opens a self-contained search sheet over the loaded messages;
          // disabled on the brand-new (unsaved) chat where there's nothing
          // to search yet.
          IconButton(
            icon: const Icon(AppIcons.search),
            tooltip: context.tr.searchInConversation,
            onPressed: _isNewChat ? null : _openConversationSearch,
          ),
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
              selectedEnvironmentIds: _activeEnvironmentIds,
              onProjectChanged: _handleProjectChanged,
              onEnvironmentsChanged: _handleEnvironmentsChanged,
              onCreateEnvironmentRequested: _handleCreateEnvironmentRequested,
              onCreateProjectRequested: _handleCreateProjectRequested,
            ),
            // (Context/usage meter removed: the snapshot API exposes no token
            // accounting, so the figures it showed were fabricated. Re-add it
            // wired to a real usage field when the backend surfaces one.)
            const OfflineBanner(),
            // Long-running report progress — Excel / PDF / Word generation.
            // Rendered above the message list (not inside the typing row)
            // because the user's eye needs to find the percentage fast,
            // and the typing row sits at the message tail where new
            // messages can push it off-screen. Fed by the REAL
            // `conversation.run_progress` snapshot field via
            // [_liveRunProgress]; hidden whenever the backend isn't
            // mid-report.
            if (_liveRunProgress case final progress?)
              ChatRunProgressCard(progress: progress),
            Expanded(
              child: Stack(
                children: [
                  if (_loadingMessages)
                    _buildSkeletonList()
                  else if (_effectiveMessages.isEmpty)
                    EmptyChatSuggestions(onSuggestionTap: _seedSuggestion)
                  else
                    // Pull-down on the message list triggers a fresh
                    // snapshot fetch + restarts the poll cadence — gives
                    // the user an explicit "fetch latest now" gesture
                    // instead of waiting on the 1.5 s / 15 s polling
                    // tick. Skips for new chats (no cubit) and the
                    // skeleton / empty branches since there's nothing
                    // to refresh in those states.
                    RefreshIndicator(
                      onRefresh: _refreshSnapshot,
                      color: context.saqqar.brandCyan,
                      child: _buildMessageList(),
                    ),
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
            //
            // Env-hint banner (Gap H) — when the server flags the chat as
            // needing an environment and none is bound yet, offer the
            // one-click "Use My Database" default-env bind above the composer.
            if (!_isNewChat &&
                (snapshotConv?.needsEnvironment ?? false) &&
                _resolveEnv() == null)
              ChatEnvHintBanner(
                busy: _bindingDefaultEnv,
                onUseMyDatabase: _useMyDatabase,
              ),
            // Plan/quota banner (Gap A near-limit + Gap B exceeded). Sits
            // directly above the composer so the upgrade CTA is next to the
            // (now disabled) send affordance.
            ChatPlanBanner(
              plan: context.watch<PlanCubit>().state,
              exceededWindow: quotaWindow,
              onUpgrade: _showUpgradeSheet,
            ),
            // Quick-action suggestion chips — seed the composer with a
            // common Odoo operation. Hidden while recording / transcribing
            // and on a brand-new empty chat (the welcome grid covers that).
            ChatSuggestionStrip(
              visible: !_recording &&
                  !_transcribing &&
                  _effectiveMessages.isNotEmpty,
              onSelect: _seedSuggestion,
            ),
            ChatComposer(
              controller: _composer,
              focusNode: _composerFocus,
              attachments: _attachments,
              onAttach: _pickAttachment,
              onSlash: _openSlashCommands,
              onRemoveAttachment: _removeAttachmentAt,
              onPreviewAttachment: _previewAttachmentAt,
              // Block send when offline OR over a usage cap (Gap B). The
              // quota banner above explains why send is disabled. The
              // *empty-composer* gate (disable Send until there's text or an
              // attachment) lives inside ChatComposer so it can watch the
              // controller without rebuilding the whole screen — and so the
              // mic stays enabled while the field is empty.
              onSend: (online && quotaWindow == null) ? _send : null,
              // Hide the mic when voice is locked on the plan (Gap C).
              // Null plan → permissive (don't hide a feature we haven't
              // confirmed is locked).
              voiceEnabled:
                  context.watch<PlanCubit>().state?.feature('voice') ?? true,
              // Voice recording — overlay replaces the text field while
              // [_recording] / [_transcribing] is true.
              recording: _recording,
              transcribing: _transcribing,
              recordingElapsed: _recordingElapsed,
              onStartRecording: _startRecording,
              onStopRecording: _stopRecording,
              onDiscardRecording: _discardRecording,
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
              // Tapping the wordmark closes the drawer and jumps home
              // (the chats list). Same close-then-go pattern as the
              // other drawer actions.
              onGoHome: () {
                setState(() => _sidebarOpen = false);
                context.go(RouteNames.chatsPath);
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
      title: _approvalTitleForApi(a),
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

  /// Friendly approval title (Gap E). For Odoo writes with a server-resolved
  /// model label, reads "Create 6 × Manufacturing Order" in the active
  /// locale; otherwise a localized action-type title. Replaces the old
  /// English-only [_approvalTitleFor].
  String _approvalTitleForApi(api.Approval a) {
    final tr = context.tr;
    final label = a.modelLabel(isArabic: tr.isArabic);
    if (label != null) {
      final verb = tr.approvalOperationVerb(a.payload['operation']?.toString());
      return tr.approvalModelTitle(verb, a.recordCount, label);
    }
    return tr.approvalActionTitle(a.actionType.wire);
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

  /// Opens the in-conversation search sheet (the design's header search
  /// affordance). Filters the currently-loaded messages by substring match
  /// and lists the hits with a highlighted snippet. Self-contained — it does
  /// not touch the fragile message-list rendering.
  Future<void> _openConversationSearch() async {
    final messages = _searchableMessages;
    final s = context.saqqar;
    // Owned here (not inside the sheet builder) so it can be disposed when
    // the sheet closes — an earlier revision created it inside `builder` and
    // never disposed it, leaking one TextEditingController per search-open
    // for the app's lifetime.
    final controller = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: s.surface,
        builder: (sheetContext) {
          return Padding(
          padding: EdgeInsets.only(
            // Scoped accessor — wholesale `MediaQuery.of` would rebuild this
            // sheet on every unrelated MediaQuery change (text scale,
            // brightness, padding) when only the keyboard inset matters.
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  final q = controller.text.trim().toLowerCase();
                  final hits = q.isEmpty
                      ? const <DemoMessage>[]
                      : messages
                          .where((m) => m.content.toLowerCase().contains(q))
                          .toList()
                          .reversed
                          .toList();
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: s.surface3,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Icon(AppIcons.search, size: 18, color: s.muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                autofocus: true,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: context.tr.searchInConversation,
                                ),
                              ),
                            ),
                            if (q.isNotEmpty)
                              Text(
                                '${hits.length}',
                                style: context.text.labelMedium
                                    ?.copyWith(color: s.muted),
                              ),
                          ],
                        ),
                      ),
                      Divider(color: s.border, height: 1),
                      Expanded(
                        child: q.isEmpty
                            ? Center(
                                child: Text(
                                  context.tr.searchMessagesHint,
                                  style: context.text.bodyMedium
                                      ?.copyWith(color: s.muted),
                                ),
                              )
                            : hits.isEmpty
                                ? Center(
                                    child: Text(
                                      context.tr.noResults,
                                      style: context.text.bodyMedium
                                          ?.copyWith(color: s.muted),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    itemCount: hits.length,
                                    separatorBuilder: (_, __) => Divider(
                                      color: s.border,
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                    itemBuilder: (context, i) {
                                      final m = hits[i];
                                      return ListTile(
                                        leading: Icon(AppIcons.message,
                                            size: 18, color: s.brandCyan),
                                        title: Text(
                                          m.content.trim(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.text.bodyMedium,
                                        ),
                                        subtitle: Text(
                                          m.time,
                                          style: context.text.labelSmall
                                              ?.copyWith(color: s.muted),
                                        ),
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildMessageList() {
    // Compute the full visible list ONCE (it subscribes via `context.watch`,
    // so cubit ticks rebuild the screen), then window it to the most-recent
    // [_visibleLimit] for rendering. `all.length` drives whether the "Load
    // earlier" button still has buffered messages to reveal.
    final all = _allVisibleMessages;
    final messages = all.length <= _visibleLimit
        ? all
        : all.sublist(all.length - _visibleLimit);
    // Cache for the AppBar search sheet (read outside build) — searches the
    // WHOLE loaded transcript, not just the rendered window.
    _searchableMessages = all;
    final hasThinking = _effectiveIsThinking;
    // Group consecutive assistant messages into "turns" so we can show
    // a single collapsed "Saqqar thinking · N steps · Xs" pill instead
    // of N separate intermediate bubbles. Final reply in each turn
    // stays expanded as a normal message. Web parity per user request.
    final timeline = _buildTimeline(messages);

    // "Load earlier messages" header — the FIRST list item, shown whenever
    // there are older messages to reveal: either still buffered in the
    // loaded snapshot (`_visibleLimit < all.length`) or fetchable from the
    // server (`hasMoreOlder`). A real list item (not a scroll trigger) so
    // it's reachable even when the rendered window is too short to scroll.
    final showLoadEarlier = !_isNewChat &&
        timeline.isNotEmpty &&
        (_visibleLimit < all.length ||
            context.watch<ChatCubit>().state.hasMoreOlder);
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
    final firstApprovalIndex =
        headerCount + timeline.length + (hasThinking ? 1 : 0);
    final totalCount = headerCount +
        timeline.length +
        (hasThinking ? 1 : 0) +
        pendingApprovals.length +
        1;

    // Schedule a one-shot restore for the first frame in which the
    // ListView has measurable content. _restoreScrollIfNeeded guards
    // itself with `_hasRestoredScroll`, so subsequent poll-driven
    // builds skip the post-frame work entirely.
    if (!_hasRestoredScroll && totalCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreScrollIfNeeded();
      });
    }

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
        // "Load earlier messages" header — the first item when there's
        // older history to page in.
        if (headerCount == 1 && index == 0) {
          return ResponsiveContent(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: _LoadEarlierButton(onLoad: _loadEarlier),
          );
        }

        // Trailing spacer.
        if (index == totalCount - 1) return const SizedBox(height: 16);

        // Inline approval cards (immediately after thinking row /
        // after the last real message).
        if (index >= firstApprovalIndex &&
            index < firstApprovalIndex + pendingApprovals.length) {
          final approvalIdx = index - firstApprovalIndex;
          final approval = pendingApprovals[approvalIdx];
          return ResponsiveContent(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
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
        // grouped agent turn (thinking pill + final reply). Subtract the
        // header offset so the index maps back onto the timeline list.
        final entryIdx = index - headerCount;
        final entry = timeline[entryIdx];
        final previousEntry = entryIdx == 0 ? null : timeline[entryIdx - 1];
        final entryAnchor = entry.firstMessage;
        final previousLast = previousEntry?.lastMessage;

        // Date separator above the first message of a new calendar day.
        final showDateSeparator = entryAnchor.createdAt != null &&
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
        );

        if (!showDateSeparator) return entryWidget;
        return Column(
          children: [
            ChatDateSeparator(date: entryAnchor.createdAt!),
            entryWidget,
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
          key: message.id.isEmpty ? null : ValueKey('msg-${message.id}'),
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
          key: finalReply.id.isEmpty
              ? null
              : ValueKey('msg-${finalReply.id}'),
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

  // -------- Toasts --------

  void _sheetToast(BuildContext sheetContext, String message) {
    Navigator.of(sheetContext).pop();
    _toast(message);
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }

  /// Surfaces a failed chat mutation as a two-line error toast — the action
  /// label ("Couldn't send your message") over the mapped, localized cause
  /// ("No internet connection") — then consumes the one-shot failure so it
  /// never re-fires on a later rebuild. Falls back to the generic message
  /// only when there's no classified failure on the cubit (or no cubit yet,
  /// for a brand-new chat).
  void _surfaceActionFailure() {
    if (_isNewChat) {
      _toast(context.tr.defaultApiError);
      return;
    }
    final cubit = context.read<ChatCubit>();
    final failure = cubit.state.actionFailure;
    if (failure == null) {
      _toast(context.tr.defaultApiError);
      return;
    }
    AppToast.show(
      context,
      title: _chatActionLabel(failure.action),
      message: ApiErrorMapper.message(context, failure.failure),
      variant: ToastVariant.error,
    );
    cubit.consumeActionFailure();
  }

  /// Localized "what failed" label per [ChatAction].
  String _chatActionLabel(ChatAction action) {
    final tr = context.tr;
    return switch (action) {
      ChatAction.send => tr.chatActionSendFailed,
      ChatAction.uploadAttachment => tr.chatActionUploadFailed,
      ChatAction.stop => tr.chatActionStopFailed,
      ChatAction.share => tr.chatActionShareFailed,
      ChatAction.setActiveCredential ||
      ChatAction.toggleCredential =>
        tr.chatActionCredentialFailed,
      ChatAction.dismissPendingAction => tr.chatActionDismissFailed,
      ChatAction.load || ChatAction.patch => tr.defaultApiError,
    };
  }

  /// Upgrade CTA target (Gap B) — opens the pricing screen (Gap L) with the
  /// live tiers. Self-serve checkout isn't built yet, so the pricing screen's
  /// own per-tier CTA is "Contact us" until a payment provider is signed.
  void _showUpgradeSheet() {
    context.pushNamed(RouteNames.pricing);
  }

  /// Pull-to-refresh handler bound to the message list. Triggers an
  /// out-of-band [ChatCubit.load] so the user gets the freshest snapshot
  /// the instant they ask, instead of waiting on the 1.5 s (running)
  /// or 15 s (idle) polling tick. Awaits the future so the
  /// [RefreshIndicator] spinner stays visible until the snapshot lands.
  /// No-op for new chats — there's no cubit yet to refresh against.
  Future<void> _refreshSnapshot() async {
    if (_isNewChat) return;
    await context.read<ChatCubit>().load();
  }

  /// Gap H — "Use My Database" one-click. Ensures a default project +
  /// production environment exist server-side, binds the env to this
  /// conversation, then refreshes the snapshot so the hint banner clears.
  /// Prompts for credentials when the new env can't reach Odoo yet.
  Future<void> _useMyDatabase() async {
    if (_isNewChat || _bindingDefaultEnv) return;
    setState(() => _bindingDefaultEnv = true);
    try {
      final env = await context.read<ProjectsApi>().defaultProject();
      if (!mounted) return;
      await context.read<ConversationsRepository>().patch(
            id: widget.conversationId,
            environmentId: env.id,
          );
      if (!mounted) return;
      await _refreshSnapshot();
      if (!mounted) return;
      _toast(
        env.hasXmlrpc
            ? context.tr.envHintBound
            : context.tr.envHintNeedsCredentials,
      );
    } catch (_) {
      if (!mounted) return;
      _toast(context.tr.envHintFailed);
    } finally {
      if (mounted) setState(() => _bindingDefaultEnv = false);
    }
  }

  /// "Sent · N file(s) attached" — picks the right pluralized string
  /// and substitutes the count. Lives next to [_toast] so both
  /// `_send` and `_sendAsNewConversation` can share it without
  /// duplicating the localization shape.
  String _sentWithFilesLabel(int count) {
    final tr = context.tr;
    if (count <= 1) return tr.sentToastOneFile;
    return tr.sentToastManyFiles.replaceFirst('{count}', count.toString());
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

/// "Load earlier messages" header pill at the top of the message list.
///
/// A real list item (not a scroll trigger / overlay) so it's reachable even
/// when the loaded slice is too short to scroll — the case that left a long
/// chat stuck on its last few visible bubbles. Tapping it pages in the
/// previous batch via [ChatCubit.loadOlder]; while a page is in flight it
/// swaps to a spinner. Rebuilds only on the `isLoadingOlder` flag so the
/// 1.5 s poll cadence doesn't churn it.
class _LoadEarlierButton extends StatelessWidget {
  const _LoadEarlierButton({required this.onLoad});

  final Future<void> Function() onLoad;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (prev, next) => prev.isLoadingOlder != next.isLoadingOlder,
      builder: (context, state) {
        final s = context.saqqar;
        final loading = state.isLoadingOlder;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.pillR,
              onTap: loading ? null : onLoad,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: s.cardBg,
                  borderRadius: AppRadius.pillR,
                  border: Border.all(color: s.cardBorder),
                  boxShadow: s.glassShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(s.brandCyan),
                        ),
                      )
                    else
                      Icon(Icons.keyboard_arrow_up_rounded,
                          size: 18, color: s.brandCyan),
                    const SizedBox(width: 8),
                    Text(
                      loading ? tr.chatLoadingEarlier : tr.chatLoadEarlier,
                      style: context.text.labelMedium?.copyWith(
                        color: loading ? s.muted : s.brandCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    id: m.id,
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

/// Fullscreen preview for a locally-staged image attachment. Backed by
/// [InteractiveViewer] so the user can pinch-to-zoom (up to 4×) and
/// swipe-to-pan the picture. A subtle `×` button in the top-end corner
/// closes the dialog explicitly; tapping the dim background does the
/// same. Used by [_ChatScreenState._previewAttachmentAt] for the
/// "tap a staged image to see what I just attached" feedback testers
/// asked for on 2026-05-23.
class _LocalImagePreviewDialog extends StatelessWidget {
  const _LocalImagePreviewDialog({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                maxScale: 4,
                minScale: 1,
                child: Center(
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 24,
            end: 16,
            child: SafeArea(
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
