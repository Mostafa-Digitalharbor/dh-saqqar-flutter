
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
// `PlatformException` — the camera picker's permission-denied signal.
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/format/byte_size.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
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
import '../../../shared/widgets/fade_slide_in.dart';
// Dead with the conversation menu — the rail drawer renders counts as
// tab-label suffixes, not as mini chips on a sheet item.
// import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../billing/view_model/plan_cubit.dart';
import '../../billing/view_model/saqqar_features_cubit.dart';
import '../../data_api/data/odoo_data_api.dart';
import '../../demo/saqqar_demo_data.dart';
import '../view_model/task_prep_cubit.dart';
import '../view_model/earlier_paging.dart';
import '../data/chat_features.dart';
import '../data/saqqar_tools_api.dart';
import '../data/chat_timeline.dart';
import '../data/interactive_cards.dart';
import '../data/message_adapter.dart';
import '../data/message_visibility.dart';
import '../data/live_env_ack_service.dart';
import '../data/transcribe_api.dart';
import '../view_model/running_agents_cubit.dart';
import '../data/tool_status.dart';
import '../widgets/widgets.dart';
import 'attachment_viewer_screen.dart';
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

  /// How many visible messages the lane currently shows. Display-only — the
  /// cubit holds every loaded message; this just windows what we render.
  ///
  /// The opening window is deliberately larger than the step. A chat used to
  /// open on ten messages, which on a transcript where most rows are `tool`
  /// rows is a screen and a bit: the user is already at the top and paging
  /// before they have read anything. Opening on [_visibleOpening] means the
  /// first screenful is history, not a starting pistol.
  ///
  /// Growing it is cheap. `ListView.builder` only builds what is near the
  /// viewport, so a wider window costs the timeline pass over the extra rows
  /// and no extra layout — the rows above the fold are never built.
  static const _visibleOpening = 20;

  /// How many more messages each reveal uncovers. Sized so one fetched page
  /// (~40 visible rows out of 100 raw) is spent over roughly two reveals
  /// rather than four — every reveal costs the user a separate deliberate
  /// gesture, because the auto-load latch re-arms per drag.
  static const _visibleStep = 25;
  int _visibleLimit = _visibleOpening;

  /// Refill the bank once fewer than this many loaded-but-unrevealed messages
  /// remain.
  ///
  /// Deliberately about two pages, not one. A page yields roughly 40 visible
  /// rows and takes seconds to arrive; at one page of headroom a user scrolling
  /// briskly drains the bank faster than a single in-flight request refills it,
  /// and the lane stops — which is the whole failure this is here to prevent.
  /// Two pages means the next request starts while there is still a page left
  /// to read, so the wait is spent reading rather than watching.
  static const _prefetchHeadroom = 80;

  /// Predicate for "this server message is shown to the user" — drops the
  /// agent's internal plumbing (tool outputs, empty tool-call invocations,
  /// system-injected user payloads, `[agent-control]` directives) while
  /// keeping interactive cards, which ride on exactly the rows those first
  /// two rules drop. Shared by [_allVisibleMessages] (render) and
  /// [_loadedVisibleCount] (paging math) so the two never disagree.
  ///
  /// Lives in `data/message_visibility.dart` so it is testable without
  /// pumping the screen — see the note there.
  bool _isVisibleMessage(api.Message m) => isVisibleMessage(m);

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
    final snapshot =
        context.watch<ChatCubit>().state.data.dataOrNull;
    return snapshot?.conversation.isRunning ?? false;
  }

  /// A §6 Odoo scan is in flight. Server-side work with no local message to
  /// show for it until the report is posted.
  bool _toolRunning = false;

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
      // The tools sheet gates on `saqqar_features`, which rides on
      // `/api/v1/usage/` alone — no conversation snapshot carries it. Ask
      // once per session; the cubit no-ops when it already has an answer or
      // a request is in flight, so this stays one round-trip however many
      // chats the user opens.
      if (mounted) {
        unawaited(context.read<SaqqarFeaturesCubit>().ensureLoaded());
      }
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
        size: humanBytes(size, context.tr),
        imageUrl: _isImageExt(ext) ? f.path : null,
        localPath: f.path,
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
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent <= 0) {
      // Nothing to restore on a lane that doesn't scroll — so the restore is
      // trivially DONE, and saying so matters. `_loadEarlier(auto: true)`
      // refuses to run until this flag is set, and
      // `_fillViewportIfNotScrollable` only fires when the lane can't scroll.
      // Returning early here made those two guards circular: a short lane
      // couldn't auto-load, so it stayed short, so it never auto-loaded.
      // Reproduced on a live 1,282-message conversation whose most recent
      // page was almost entirely `tool` rows — the chat rendered ONE bubble
      // and would not page back.
      _hasRestoredScroll = true;
      return;
    }
    _hasRestoredScroll = true;
    final saved = _savedScrollOffsets[widget.conversationId];
    if (saved == null) {
      _scroll.jumpTo(position.maxScrollExtent);
      return;
    }
    _scroll.jumpTo(saved.clamp(0.0, position.maxScrollExtent));
  }

  // -------- Scroll handling --------

  /// How close to the top of the transcript the user has to get before the
  /// next page starts loading, in logical pixels.
  ///
  /// Deliberately not zero: firing at the very top means the user watches a
  /// spinner. Firing ~600 px early means the rows are usually already in
  /// place by the time they get there, which is what makes the paging feel
  /// like it isn't happening at all. Comfortably inside the list's 1500 px
  /// `cacheExtent`, so the prepended rows are built off-screen too.
  static const _autoLoadEarlierThreshold = 600.0;

  /// Re-entrancy guard for [_loadEarlier].
  ///
  /// Scroll notifications arrive on essentially every frame of a drag, so
  /// without this a single upward flick would queue dozens of overlapping
  /// loads. Held until the post-frame re-anchor has run, not just until the
  /// await returns — the frame in between is exactly when the list is at its
  /// shortest and would re-trigger.
  bool _loadingEarlier = false;

  /// Whether the scroll-driven trigger is allowed to fire. Cleared on each
  /// automatic load and re-armed only once the user leaves the trigger zone —
  /// see [_onScrollChanged] for why that hysteresis is load-bearing.
  bool _autoLoadArmed = true;

  /// Whether the user has taken control of the lane with a real drag.
  ///
  /// Until they do, the chat stays pinned to the newest message — see
  /// [_pinToBottomIfUnscrolled]. Set from a drag start rather than from any
  /// scroll activity, because our own corrective `jumpTo`s are scroll
  /// activity too and would hand control away on the frame we opened.
  bool _userHasScrolled = false;

  /// Consecutive [_fillViewportIfNotScrollable] passes. Bounded because that
  /// check consults `maxScrollExtent`, which on a lazy list is an estimate:
  /// if it reads zero for a frame after a page lands, the fill would ask for
  /// another. Three passes is far more than a viewport ever needs and
  /// terminates regardless. Reset once the list actually scrolls.
  int _viewportFillAttempts = 0;

  /// Set when an automatic load fails. Auto-loading then stands down and the
  /// header falls back to a tap-to-retry pill, so a chat that is offline or
  /// hitting a 500 doesn't re-request on every scroll frame forever. Cleared
  /// on the next successful load.
  bool _autoLoadEarlierFailed = false;

  /// Carried by the one message row whose on-screen position must survive the
  /// next prepend.
  ///
  /// The obvious alternative is to diff scroll *metrics* — remember
  /// `maxScrollExtent`, subtract after the insert, push the offset down by the
  /// difference. That works only as far as `maxScrollExtent` is trustworthy,
  /// and on a lazy `ListView.builder` it is an estimate that firms up as
  /// layout walks into new territory rather than a measurement. Measuring this
  /// row sidesteps the estimate entirely: whatever the sliver decides the
  /// geometry is, the row is where it is.
  ///
  /// The precondition is that the row is actually laid out —
  /// `test/chat_prepend_anchor_test.dart` pins that, and it is why the 600 px
  /// trigger distance and the list's 1500 px `cacheExtent` are a matched pair.
  final GlobalKey _scrollAnchorKey = GlobalKey();

  /// Message id the anchor key is pinned to while a prepend is in flight.
  ///
  /// Normally the key rides the oldest rendered row, which is re-evaluated
  /// every build. That's wrong mid-prepend: the insert makes some *older*
  /// message the new oldest, so an un-pinned key would jump to a different
  /// row between the before- and after-measurements and the correction would
  /// be computed from two different widgets. Pinning holds it on the message
  /// we actually measured. Cleared once the correction has been applied.
  String? _scrollAnchorId;

  void _onScrollChanged() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // Show the jump button when the user has scrolled away from the latest
    // message by more than ~one screenful.
    final shouldShow = position.extentAfter > 240;
    if (shouldShow != _showScrollDown) {
      setState(() => _showScrollDown = shouldShow);
    }

    // Infinite scroll upward: approaching the start of the loaded transcript
    // pulls the next page automatically, matching the web. `extentBefore` is
    // clamped at 0, so an overscroll bounce at the top reads as 0 rather than
    // going negative and skipping the check.
    //
    // Hysteresis, not a bare threshold. The trigger re-arms only once the user
    // has moved back out of the zone, which makes the whole mechanism safe
    // against the one thing that would otherwise runaway: an anchor
    // correction that couldn't be applied (the anchor row wasn't laid out, so
    // there is nothing to measure). Without re-arming, the user would still be
    // sitting inside the threshold afterwards and the next scroll frame would
    // fire again, and again, until the entire transcript had loaded. With it,
    // a failed correction costs one extra page and then waits for the user.
    if (position.extentBefore > _autoLoadEarlierThreshold * 2) {
      _autoLoadArmed = true;
      _viewportFillAttempts = 0;
    }
    if (_autoLoadArmed && position.extentBefore <= _autoLoadEarlierThreshold) {
      _autoLoadArmed = false;
      unawaited(_loadEarlier(auto: true));
    }

    // Top up the bank on approach, not only after a reveal lands.
    //
    // Refilling solely from the reveal has a hole: during one long
    // uninterrupted scroll the reveals are what drain the bank, and if a
    // reveal is itself waiting on a fetch, nothing asks for the page after it.
    // Watching the approach instead means the request goes out while the user
    // is still on their way. Cheap enough for a scroll frame — two integer
    // reads, and it no-ops while a page is in flight.
    if (position.extentBefore <= _autoLoadEarlierThreshold * 4) {
      _topUpPrefetch();
    }
  }

  /// Reveals the previous [_visibleStep] (10) messages.
  ///
  /// Called automatically as the user scrolls toward the top ([auto] true),
  /// and from the header pill when a previous automatic attempt failed.
  ///
  /// Two-tier so it's instant AND reliable:
  ///   * If the loaded snapshot still has older messages we haven't shown
  ///     yet, just grow the render window — instant, no network.
  ///   * Otherwise (window has caught up to everything loaded) pull more from
  ///     the server via [ChatCubit.loadOlder] (decoded off the UI isolate),
  ///     then reveal the next 10.
  Future<void> _loadEarlier({bool auto = false}) async {
    if (_isNewChat) return;

    final cubit = context.read<ChatCubit>();
    final loadedBefore = _loadedVisibleCount();
    final shownBefore =
        loadedBefore < _visibleLimit ? loadedBefore : _visibleLimit;
    // Every guard lives in `decideEarlierPage` so the scroll handler can call
    // this on any frame without the caller having to know the rules — see
    // that function for why they're kept out of the widget.
    final action = decideEarlierPage(
      automatic: auto,
      alreadyLoading: _loadingEarlier,
      scrollRestored: _hasRestoredScroll,
      lastAttemptFailed: _autoLoadEarlierFailed,
      shownCount: shownBefore,
      loadedCount: loadedBefore,
      hasMoreOlder: cubit.state.hasMoreOlder,
    );
    if (action == EarlierPageAction.none) return;
    final needsFetch = action == EarlierPageAction.fetchOlder;

    _loadingEarlier = true;
    // Measure the anchor row BEFORE the prepend. Older rows are inserted above
    // the viewport, so without a correction the content the user was reading
    // slides down the screen by the height of everything added — and, worse
    // for automatic paging, they stay pinned near the top, which satisfies the
    // trigger again and walks the list to the start of the conversation in one
    // gesture.
    final anchorYBefore = _anchorRowY();
    _scrollAnchorId = _anchorRowId();

    if (needsFetch) {
      await cubit.loadOlder();
      if (!mounted) return;
      // Surface a failed fetch instead of silently widening the window
      // over messages that never arrived.
      if (cubit.state.actionFailure != null) {
        // Latch on ANY failure, including a manual retry. If a failed retry
        // cleared the flag the header would drop back to its spinner state
        // and the user would be left watching a load that isn't running,
        // with no way to ask again.
        _loadingEarlier = false;
        setState(() => _autoLoadEarlierFailed = true);
        _surfaceActionFailure();
        return;
      }
    }

    _autoLoadEarlierFailed = false;
    // Reveal once the list has stopped moving — see [_afterScrollSettles].
    // The network fetch above already ran, so by the time the user's flick
    // decays the rows are in hand and appear immediately.
    _afterScrollSettles(() {
      if (!mounted) {
        _loadingEarlier = false;
        return;
      }
      // Re-measure: the anchor may have scrolled since we sampled it, and the
      // correction has to be relative to where it is now.
      final anchorYAtReveal = _anchorRowY() ?? anchorYBefore;
      setState(() => _visibleLimit = shownBefore + _visibleStep);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reanchorAfterPrepend(anchorYAtReveal);
        _scrollAnchorId = null;
        _loadingEarlier = false;
        _fillViewportIfNotScrollable();
        _topUpPrefetch();
      });
    });
  }

  /// Keeps roughly one page of un-rendered history in hand at all times.
  ///
  /// The cubit can't decide this for itself: it knows how much is loaded but
  /// not how much has been revealed, and "loaded" alone would either fetch
  /// forever or never. The view holds both numbers, so it owns the decision
  /// and the cubit just does as it's told.
  ///
  /// Cheap to call on every reveal — [ChatCubit.prefetchOlder] is a no-op
  /// while a page is in flight or once the start of the conversation is
  /// reached, so this settles by itself.
  void _topUpPrefetch() {
    if (_isNewChat) return;
    final cubit = context.read<ChatCubit>();
    if (!cubit.state.hasMoreOlder) return;
    final headroom = _loadedVisibleCount() - _visibleLimit;
    if (headroom >= _prefetchHeadroom) return;
    unawaited(cubit.prefetchOlder());
  }

  /// Runs [action] as soon as the list is not scrolling — immediately when it
  /// is already still.
  ///
  /// Prepending has to be paired with a scroll correction, and the only tool
  /// for that is `ScrollController.jumpTo`, which is **not safe during a
  /// gesture**: `ScrollPositionWithSingleContext.beginActivity` disposes the
  /// active drag, so correcting mid-flick makes the list stop dead under the
  /// user's finger. (`test/chat_prepend_anchor_test.dart` demonstrates it —
  /// the drag stops responding after the jump.)
  ///
  /// So the *fetch* is eager (it is the slow part and the user shouldn't wait
  /// on it) while the *reveal* waits for the scroll to settle. Because the
  /// trigger fires ~600 px before the top, a normal flick has already decayed
  /// by the time the rows land and the paging still reads as instant.
  void _afterScrollSettles(VoidCallback action) {
    if (!_scroll.hasClients) {
      action();
      return;
    }
    final scrolling = _scroll.position.isScrollingNotifier;
    if (!scrolling.value) {
      action();
      return;
    }
    void onSettled() {
      if (scrolling.value) return;
      scrolling.removeListener(onSettled);
      action();
    }

    scrolling.addListener(onSettled);
  }

  /// Id of the message currently carrying [_scrollAnchorKey] — the oldest
  /// rendered row unless a prepend has pinned it.
  String? _anchorRowId() {
    if (_scrollAnchorId != null) return _scrollAnchorId;
    final all = _isNewChat ? _messages : (_visibleMemo ?? const []);
    if (all.isEmpty) return null;
    final windowed =
        all.length <= _visibleLimit ? all : all.sublist(all.length - _visibleLimit);
    return windowed.isEmpty ? null : windowed.first.id;
  }

  /// Vertical position of the anchor row, in the scroll view's own
  /// coordinates. Null when the row isn't laid out — which shouldn't happen
  /// (the anchor is the oldest rendered row and the trigger fires within the
  /// list's 1500 px `cacheExtent` of it) but must not throw if it does.
  double? _anchorRowY() {
    final context = _scrollAnchorKey.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final viewport = _scroll.hasClients
        ? _scroll.position.context.storageContext.findRenderObject()
        : null;
    if (viewport is! RenderBox) return null;
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  /// Restores the reading position after older rows were prepended, by moving
  /// the offset exactly as far as the anchor row moved.
  ///
  /// Measured, not estimated — see [_scrollAnchorKey].
  void _reanchorAfterPrepend(double? anchorYBefore) {
    if (anchorYBefore == null) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final anchorYAfter = _anchorRowY();
    if (anchorYAfter == null) return;
    // The row moved DOWN by `shift`; scrolling down by the same amount puts
    // it back under the user's eye.
    final shift = anchorYAfter - anchorYBefore;
    if (shift.abs() < 0.5) return;
    _scroll.jumpTo(
      (position.pixels + shift).clamp(0.0, position.maxScrollExtent),
    );
  }

  /// Pulls another page when the rendered window doesn't fill the viewport.
  ///
  /// Ten short messages on a tall phone produce a list that cannot scroll —
  /// and a list that cannot scroll never emits a scroll notification, so
  /// [_onScrollChanged] would never fire and the user would be stranded with
  /// no way to reach older history now that the button is gone. Terminates
  /// because each pass either grows the content (making it scrollable) or
  /// exhausts `hasMoreOlder`, which makes [_loadEarlier] return immediately.
  void _fillViewportIfNotScrollable() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent > 0) return;
    // Raised from 3: a page is raw rows, and the visible yield per page can be
    // low enough (see `ChatCubit._olderPageSize`) that three passes still left
    // a lane too short to scroll — and therefore unable to ask for more.
    if (_viewportFillAttempts >= 6) return;
    _viewportFillAttempts++;
    // Bypasses the `_autoLoadArmed` latch on purpose: a list that cannot
    // scroll emits no scroll notifications, so nothing would ever re-arm it.
    _autoLoadArmed = true;
    unawaited(_loadEarlier(auto: true));
  }

  /// Holds a freshly-opened chat on the newest message until the user takes
  /// control of the lane.
  ///
  /// [_restoreScrollIfNeeded] is a one-shot, and on a cold open it fires on
  /// the first frame that has content dimensions — when only a handful of rows
  /// are laid out. `maxScrollExtent` on a lazy list is an *estimate* built
  /// from those rows plus a guess for the rest, so jumping to it there lands
  /// short of the true bottom, and the one-shot never corrects. The chat then
  /// opens on a message from a day earlier with the newest content below the
  /// fold, which reads exactly like "it didn't load" — and the natural
  /// response is a pull-to-refresh, which is how this got reported.
  ///
  /// Reproduced by force-stopping the app: cold open landed on Jul 26 on a
  /// chat whose newest message was Jul 27. Re-opening the same chat warm (the
  /// session cache paints the full window, so the estimate is good) landed
  /// correctly, which is why it looks intermittent.
  ///
  /// Re-pinning every frame until the first drag also gives the right
  /// behaviour for free: a chat the user hasn't touched follows the tail as
  /// new messages land. Skipped when there's a saved offset — returning to a
  /// chat you had scrolled back through should land where you left it.
  void _pinToBottomIfUnscrolled() {
    if (_userHasScrolled || _isNewChat) return;
    if (_savedScrollOffsets[widget.conversationId] != null) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final max = position.maxScrollExtent;
    // A lane too short to scroll has no bottom to pin to; the viewport fill
    // owns that case.
    if (max <= 0) return;
    if ((position.pixels - max).abs() < 1.0) return;
    _scroll.jumpTo(max);
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: AppDurations.scrollToEnd,
      curve: Curves.easeOutQuart,
    );
  }

  void _scrollToBottomSoft() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppDurations.scrollToEndSoft,
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

  /// Sends text an in-chat interactive card composed (§4).
  ///
  /// Routed through the composer + [_send] rather than straight to the cubit
  /// so a card-driven send passes every gate a typed one does: environment
  /// bound, live-env acknowledged, online, under quota, not mid-run. A card
  /// that POSTed directly would be the one path in the screen able to skip
  /// the live-database warning.
  Future<void> _sendComposed(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _composer.text = trimmed;
    _composer.selection = TextSelection.collapsed(offset: trimmed.length);
    await _send();
  }

  /// "Prepare & review" on a clarify card (§4a) — drops the composed answers
  /// in the composer instead of sending them.
  ///
  /// Separate from [_seedSuggestion] (which the starter-prompt strip uses)
  /// purely so this one can TOAST. Seeding silently is the failure this
  /// exists to avoid: the user taps a button at the top of a card, the text
  /// lands in a composer that may be behind the keyboard or off-screen, and
  /// nothing on screen says the tap did anything.
  void _seedFromCard(String text) {
    _seedSuggestion(text);
    _toast(context.tr.clarifyReadyToReview);
  }

  /// Backs the report card's record multi-select (Appendix A.2). Conversation-
  /// scoped, so a brand-new chat (no id yet) has nothing to query.
  Future<ReportEntityPage> _loadReportEntities(
    String entity,
    String query,
  ) async {
    final raw = await context.read<OdooDataApi>().reportEntities({
      'conversation_id': widget.conversationId,
      'entity': entity,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
    return ReportEntityPage.fromJson(raw);
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
      // One toast, not two. This used to toast here AND then `await
      // _openEnvironmentPicker()`, whose body is a stub that fires the very
      // same toast — so tapping send with no environment showed the user the
      // identical message twice and opened nothing.
      _toast(context.tr.pickEnvironmentToStart);
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

    // What to send with THIS message. The server still reads `task_prep` off
    // every message body and gates it itself, so the body is always sent —
    // what changes is where the value comes from: the conversation when the
    // server owns one, the device preference otherwise.
    final taskPrep = (_isNewChat
            ? null
            : context
                .read<ChatCubit>()
                .state
                .data
                .dataOrNull
                ?.conversation
                .taskPrep) ??
        context.read<TaskPrepCubit>().state;

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
      await _sendAsNewConversation(text: text, env: env, taskPrep: taskPrep);
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
          taskPrep: taskPrep,
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
    required bool taskPrep,
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
      // 2) Bind the picked environment. Nothing else to persist here:
      //    task prep travels on the message body (step 3), not on the
      //    conversation row, so a new chat needs no extra flag write.
      await repo.patch(
        id: newId,
        environmentId: env.id,
        // Bind the full multi-env set when the user checked more than the
        // primary in the header pill; null (single-env path) leaves just
        // env.id bound, matching the prior behavior.
        environmentIds: _environmentIds.length > 1 ? _environmentIds : null,
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
        taskPrep: taskPrep,
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

  /// Maps the server-reported `conversation.run_progress` (an
  /// `api.RunProgress`) onto the card's [ChatRunProgress] view-model so the
  /// card reflects the REAL export progress the backend streams — no
  /// client-side simulation.
  ///
  /// Returns null on new chats (no snapshot yet) and whenever the backend
  /// isn't mid-report, so the card only appears while a long-running
  /// Excel / PDF / Word job is actually running.
  ChatRunProgress? get _liveRunProgress {
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
    return ChatRunProgress(
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

  /// Flips the per-conversation auto-approve flag and confirms it in words.
  ///
  /// Extracted from the composer's inline handler so the tools sheet (§1) can
  /// drive the exact same path — the sheet's toggle and the composer's are
  /// the same setting, and a second copy of this logic is how two surfaces
  /// end up disagreeing about whether a refused PATCH rolls back.
  void _setAutoApprove(bool value) {
    // Optimistic local mirror so the switch animates before the snapshot
    // poll catches up.
    setState(() => _autoApprove = value);
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
  /// Writes wherever the setting actually lives:
  ///
  ///   * **The server owns it** (`conversation.task_prep` is non-null) →
  ///     PATCH it, exactly as auto-approve does, so the website sees the
  ///     change. Optimistic with rollback, via `_applyToggle`.
  ///   * **The server owns nothing** (the field is absent — every deployment
  ///     as of 2026-08-10) → write the device preference, which is precisely
  ///     the behaviour that shipped.
  ///
  /// The branch is what lets this ship ahead of the backend: the day the
  /// field appears in the snapshot, the toggle starts syncing on builds
  /// already installed. Until then nothing changes. Writing the local
  /// preference too, in both branches, keeps the fallback warm for chats the
  /// server has no opinion about.
  void _setTaskPrep(bool value) {
    final serverOwnsIt = !_isNewChat &&
        context
                .read<ChatCubit>()
                .state
                .data
                .dataOrNull
                ?.conversation
                .taskPrep !=
            null;

    context.read<TaskPrepCubit>().set(value);
    if (serverOwnsIt) {
      // Awaited inside `_applyToggle` for the same reason auto-approve is:
      // a refused PATCH has to surface, or the switch snaps back with no
      // explanation and leaves a stale failure on the state.
      _applyToggle(() => context.read<ChatCubit>().setTaskPrep(value));
    }
    _toast(value ? context.tr.taskPrepOn : context.tr.taskPrepOff);
  }

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
          (api, id, lang) =>
              api.runHealthRadar(conversationId: id, lang: lang),
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
        unawaited(context.pushNamed(RouteNames.voiceSupport));
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
    Future<void> Function(SaqqarToolsApi api, String conversationId, String lang)
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
    setState(() => _toolRunning = true);
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
      if (mounted) setState(() => _toolRunning = false);
    }
  }

  /// Prompt bank (§7) — a picker of ready-made task wordings that seeds the
  /// composer instead of sending.
  ///
  /// Sourced from the app's OWN starter prompts (the same four the empty-chat
  /// grid and the suggestion strip offer). The backend exposes no saved-prompt
  /// catalogue, and inventing rows here would put wording on screen that no
  /// server ever authored. Gated on the `prompt_bank` feature flag, so the row
  /// stays hidden until the backend says this account has the feature.
  Future<void> _openPromptBank() async {
    final tr = context.tr;
    final prompts = [
      tr.suggestRestartWorker,
      tr.suggestReconciliationReport,
      tr.suggestPendingInvoices,
      tr.suggestSyncInventory,
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ChatSheet(
        title: tr.toolsPromptBank,
        children: [
          for (final p in prompts)
            ListTile(
              leading: Icon(AppIcons.sparkles,
                  size: 18, color: context.saqqar.brandCyan),
              title: Text(p, style: context.text.bodyMedium),
              onTap: () => Navigator.of(sheetContext).pop(p),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    _seedSuggestion(picked);
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
                                  fontFamily: AppTypography.fontMono,
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
  /// right file before tapping Send. Goes through the same in-app
  /// [AttachmentViewerScreen] a sent attachment uses, so the preview a
  /// user gets before Send matches what they get after. Skips silently
  /// for indices that don't map to a real on-disk file (a row mid-upload
  /// that hasn't reached `_pendingFiles` yet — shouldn't happen given our
  /// pick flow, but defensive).
  Future<void> _previewAttachmentAt(int index) async {
    if (index < 0 || index >= _pendingFiles.length) return;
    final file = _pendingFiles[index];
    final chip = (index < _attachments.length) ? _attachments[index] : null;
    await AttachmentViewerScreen.open(
      context,
      file: file,
      // The staged chip carries the display name; fall back to the path's
      // basename so the viewer can still pick a render mode by extension.
      name: chip?.name ?? file.uri.pathSegments.last,
      kindLabel: chip?.kind,
      sizeLabel: chip?.size,
    );
  }

  /// Entry point for the composer's paperclip. Asks *where* the attachment
  /// comes from before opening a picker — one `FileType.custom` dialog that
  /// mixed images with PDFs and archives resolved to the Files browser on
  /// iOS, so attaching a photo meant navigating Files → Photos. Each branch
  /// funnels into [_stagePickedFiles], which owns the size caps, the chips
  /// and the upload, so no source can bypass them.
  Future<void> _pickAttachment() async {
    final source = await AttachmentPickerSourceSheet.show(context);
    if (!mounted || source == null) return;
    switch (source) {
      case AttachmentPickerSource.photos:
        await _pickFromPhotos();
      case AttachmentPickerSource.camera:
        await _pickFromCamera();
      case AttachmentPickerSource.files:
        await _pickFromFiles();
    }
  }

  /// Native photo library (PHPicker on iOS, the photo picker on Android) —
  /// no `allowedExtensions`, because `FileType.image` already restricts the
  /// dialog and pairing the two throws in `file_picker`.
  Future<void> _pickFromPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
      allowMultiple: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    await _stagePickedFiles(result.files);
  }

  /// Single shot straight from the camera. `file_picker` is PHPicker/SAF
  /// backed and can't reach the camera, hence `image_picker` here.
  /// `imageQuality` re-encodes to keep a 12 MP capture under the 25 MB cap.
  Future<void> _pickFromCamera() async {
    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } on PlatformException catch (e, st) {
      AppLogger.warn(
        'ChatAttachments',
        'camera capture failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      // The user declined the permission prompt (or has it off in Settings);
      // anything else is a real device/plugin failure.
      _toast(
        e.code == 'camera_access_denied'
            ? context.tr.attachCameraDenied
            : context.tr.defaultApiError,
      );
      return;
    }
    if (!mounted || shot == null) return;
    final length = await shot.length();
    if (!mounted) return;
    await _stagePickedFiles([
      PlatformFile(name: shot.name, path: shot.path, size: length),
    ]);
  }

  /// Documents: the original allow-list, minus nothing. Images stay in the
  /// list so a user who keeps screenshots in Files can still reach them.
  Future<void> _pickFromFiles() async {
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
    await _stagePickedFiles(result.files);
  }

  /// Shared tail for every attachment source: enforces the per-kind size
  /// cap, builds the composer chips, and stages the upload.
  Future<void> _stagePickedFiles(List<PlatformFile> pickedFiles) async {
    final newChips = <DemoAttachment>[];
    final newFiles = <File>[];
    final tooLarge = <String>[];
    for (final picked in pickedFiles) {
      final path = picked.path;
      if (path == null || path.isEmpty) continue;
      // Kind-aware size cap (Gap F): archives up to 500 MB (addon zips),
      // everything else 25 MB. Matches the server, which 413s over the cap.
      final capMb = _isArchiveExt(picked.extension) ? 500 : 25;
      if (picked.size > capMb * kBytesPerMb) {
        tooLarge.add(picked.name);
        continue;
      }
      newChips.add(DemoAttachment(
        name: picked.name,
        kind: _kindForExtension(picked.extension),
        size: humanBytes(picked.size, context.tr),
        imageUrl: _isImageExt(picked.extension) ? picked.path : null,
        localPath: path,
      ));
      newFiles.add(File(path));
    }
    if (tooLarge.isNotEmpty) {
      // Name the cap of the first rejected file; the rest were skipped too.
      final firstExt = pickedFiles
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
    // "Image" is a category word, so it translates; the rest are format
    // identifiers that read the same in every locale and live in UiStrings.
    if (_isImageExt(e)) return context.tr.fileKindImage;
    if (e == 'pdf') return UiStrings.formatPdf;
    if (['xlsx', 'xls', 'xlsm'].contains(e)) return UiStrings.formatXlsx;
    if (['csv', 'tsv'].contains(e)) return UiStrings.formatCsv;
    if (['docx', 'doc'].contains(e)) return UiStrings.formatDocx;
    if (_isArchiveExt(e)) return UiStrings.formatZip;
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
  // -------- Drawers --------
  //
  // Both drawers live as siblings of the chat content inside the body Stack
  // (spec §10 — we own the slide + scrim, not Material's `Scaffold.drawer`),
  // which means they are part of the chat's widget tree whether or not the
  // user ever opens them. Building them inline cost the screen a full
  // `ChatSidebarDrawer` (a BlocBuilder-driven conversation list) and a full
  // `ChatRailDrawer` (three tabs of approvals / artifacts / activity) on
  // EVERY chat rebuild, for a surface that is off-screen ~99 % of the time.
  //
  // These two helpers fix that in the two ways that matter:
  //
  //   1. **Lazy** — nothing is constructed until the user first opens that
  //      drawer. A session that never taps the hamburger or the bell pays
  //      literally nothing for either.
  //   2. **Stable identity** — the instance is cached in a field, so
  //      subsequent chat rebuilds hand `updateChild` the *same* widget
  //      object and Flutter skips the subtree entirely. The drawers still
  //      update themselves through their own Bloc subscriptions; they just
  //      stop being re-created by a parent that has nothing new to say to
  //      them. Caching also preserves their internal state (the rail's
  //      selected tab, the sidebar's scroll offset) across open/close.
  //
  // Both take only `widget.conversationId` plus callbacks bound to `this`,
  // so nothing they receive can go stale between builds.
  Widget? _cachedSidebarDrawer;
  Widget? _cachedRailDrawer;

  Widget _sidebarDrawer() {
    if (!_sidebarOpen && _cachedSidebarDrawer == null) {
      return const SizedBox.shrink();
    }
    return _cachedSidebarDrawer ??= ChatSidebarDrawer(
      currentConversationId: widget.conversationId,
      onPickConversation: (String id) {
        setState(() => _sidebarOpen = false);
        if (id != widget.conversationId) {
          context.go(RouteNames.chatPath(id));
        }
      },
      onNewConversation: () {
        setState(() => _sidebarOpen = false);
        context.go(RouteNames.chatPath(UiStrings.routeNewConversation));
      },
      onOpenVault: () {
        setState(() => _sidebarOpen = false);
        context.go(RouteNames.vaultPath);
      },
      // Tapping the wordmark closes the drawer and jumps home (the chats
      // list). Same close-then-go pattern as the other drawer actions.
      onGoHome: () {
        setState(() => _sidebarOpen = false);
        context.go(RouteNames.chatsPath);
      },
      // Close the drawer in-place — flipping the local flag triggers the
      // slide-out animation. Routes don't move.
      onClose: () => setState(() => _sidebarOpen = false),
    );
  }

  Widget _railDrawer() {
    if (!_railOpen && _cachedRailDrawer == null) {
      return const SizedBox.shrink();
    }
    return _cachedRailDrawer ??= ChatRailDrawer(
      conversationId: widget.conversationId,
      onClose: () => setState(() => _railOpen = false),
    );
  }

  // `_buildNotFound` used to render a dedicated "conversation not found"
  // Scaffold, reached via an `_isUnknownChat` demo-seed lookup that was
  // removed for producing false negatives on web-created conversations. A
  // genuinely missing conversation now comes back as a 404 from the snapshot
  // API and renders through `DataStateView` like every other failure, so the
  // bespoke screen had no caller left. It was invisible for as long as it was
  // dead because a file-level `ignore_for_file: unused_element` (added for a
  // different, since-deleted set of handlers) suppressed the warning.

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
    // Server value first, device preference second — the same precedence
    // auto-approve uses one line down. `taskPrep` is null on every server
    // that does not own the flag, which is all of them today, so this reads
    // as the local preference exactly like before. See
    // `Conversation.taskPrep` for why it is written this way now rather than
    // when the field lands.
    final taskPrep =
        snapshotConv?.taskPrep ?? context.watch<TaskPrepCubit>().state;
    final autoApprove = snapshotConv?.autoApprove ?? _autoApprove;
    final chatFeatures = ChatFeatures(
      context.watch<PlanCubit>().state,
      context.watch<SaqqarFeaturesCubit>().state,
    );

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
          //
          // `LayoutBuilder` so the bottom band can be capped against the
          // height this body actually has, not the screen's. The two diverge
          // exactly when it matters: opening the keyboard leaves the screen
          // the same size and halves the body.
          AmbientBackground(
            child: LayoutBuilder(
              builder: (context, bodyConstraints) => Column(
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
            // Everything between the transcript and the composer, height-
            // capped. All three are conditional, and when several fire at
            // once on a small screen at large text they used to push the
            // composer clean off the bottom — see [ChatBottomChrome].
            ChatBottomChrome(
              maxHeight: bodyConstraints.maxHeight *
                  ChatBottomChrome.fractionOfBody,
              children: [
                // Env-hint banner (Gap H) — when the server flags the chat as
                // needing an environment and none is bound yet, offer the
                // one-click "Use My Database" default-env bind above the
                // composer.
                if (!_isNewChat &&
                    (snapshotConv?.needsEnvironment ?? false) &&
                    _resolveEnv() == null)
                  ChatEnvHintBanner(
                    busy: _bindingDefaultEnv,
                    onUseMyDatabase: _useMyDatabase,
                  ),
                // Plan/quota banner (Gap A near-limit + Gap B exceeded). Sits
                // directly above the composer so the upgrade CTA is next to
                // the (now disabled) send affordance.
                ChatPlanBanner(
                  plan: context.watch<PlanCubit>().state,
                  exceededWindow: quotaWindow,
                  onUpgrade: _openPricing,
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
                // Inside the band, and last: `reverse: true` rests the scroll
                // at its end, so the composer is the part that stays on screen
                // and the banners above are what scroll away.
                ChatComposer(
              controller: _composer,
              focusNode: _composerFocus,
              attachments: _attachments,
              onAttach: _pickAttachment,
              onTools: () => _openToolsSheet(
                features: chatFeatures,
                taskPrep: taskPrep,
                autoApprove: autoApprove,
              ),
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
              taskPrep: taskPrep,
              taskPrepAvailable: chatFeatures.taskPrepAvailable,
              autoApprove: autoApprove,
              onTaskPrepChanged: _setTaskPrep,
              onAutoApproveChanged: _setAutoApprove,
              // Render Stop instead of Send while the agent is running.
              // For existing chats, the source of truth is the cubit's
              // snapshot (`conversation.is_running`); for new chats it
              // still comes from the local timer until the first send
              // creates the conversation + routes.
              // NOT offered while a §6 scan is in flight. The scan reuses the
              // working indicator (honest — something IS running), but it is
              // an HTTP POST to /radar/run/, not a conversation generation:
              // `_stopGeneration` would call stop on a conversation that is
              // not generating, report "generation stopped", and leave the
              // scan running. A Stop button that cannot stop what the user
              // is watching is worse than no Stop button.
              onStop: _effectiveIsThinking && !_toolRunning
                  ? _stopGeneration
                  : null,
              stopping: _isNewChat
                  ? _stopping
                  : context
                      .watch<ChatCubit>()
                      .state
                      .isStopping,
                ),
              ],
            ),
          ],
        ),
        ),
      ),
          // ── Scrim (covers main content when any drawer is open) ──
          // Black 55 % per spec §10.1. Tap to close both drawers.
          IgnorePointer(
            ignoring: !anyDrawerOpen,
            child: AnimatedOpacity(
              opacity: anyDrawerOpen ? 1 : 0,
              duration: AppDurations.cardIn,
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
            duration: AppDurations.sheetIn,
            curve: Curves.easeOutCubic,
            child: _sidebarDrawer(),
          ),
          // ── Rail (end-side, slides in from right in LTR, left in
          // RTL) — holds Approvals + Artifacts + Activity tabs ──
          AnimatedPositionedDirectional(
            end: _railOpen ? 0 : -drawerWidth,
            top: 0,
            bottom: 0,
            width: drawerWidth,
            duration: AppDurations.sheetIn,
            curve: Curves.easeOutCubic,
            child: _railDrawer(),
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
    bool approved, {
    bool batchScope = false,
  }) async {
    final tr = context.tr;
    try {
      final result = await context.read<ApprovalsApi>().decide(
            id: approval.id,
            approved: approved,
            batchScope: batchScope,
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
      // NULLS ARE DROPPED, not stringified. `entry.value.toString()` on a
      // null yields the literal string "null", and the server sends null for
      // every optional field — so an ordinary email approval (cc, bcc and
      // in_reply_to all null) rendered "Cc: null", "Bcc: null", and a Reply
      // badge on every single mail, because "null" is a non-empty string.
      // An absent field must read as absent.
      payload: {
        for (final entry in a.payload.entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      },
      recordCount: a.recordCount,
      confirmPhrase: a.confirmPhrase,
      batchScoped: a.batchScoped,
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
                          borderRadius: AppRadius.pillR,
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
      lastAttemptFailed: _autoLoadEarlierFailed,
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
    final firstApprovalIndex =
        headerCount + timeline.length + (hasThinking ? 1 : 0);
    final totalCount = headerCount +
        timeline.length +
        (hasThinking ? 1 : 0) +
        pendingApprovals.length +
        1;

    // Which message carries the scroll anchor this build. Normally the oldest
    // rendered row — that's the one closest to where a prepend inserts, so
    // it's guaranteed to still be laid out afterwards. While a prepend is in
    // flight `_scrollAnchorId` pins it to the message we measured BEFORE the
    // insert, because by then `messages.first` is a different (older) row and
    // following it would measure the wrong thing.
    final anchorId = _scrollAnchorId ??
        (messages.isEmpty ? null : messages.first.id);

    // Schedule a one-shot restore for the first frame in which the
    // ListView has measurable content. _restoreScrollIfNeeded guards
    // itself with `_hasRestoredScroll`, so subsequent poll-driven
    // builds skip the post-frame work entirely.
    if (totalCount > 0 && (!_hasRestoredScroll || !_userHasScrolled)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final firstPass = !_hasRestoredScroll;
        _restoreScrollIfNeeded();
        // And immediately check whether the lane is even long enough to
        // scroll. Without this the fill only ever ran as a follow-up to a
        // page the user had already triggered — so a chat that opened SHORT
        // (a recent window that is mostly `tool` rows renders as one or two
        // bubbles) had no scroll to give and no page to follow, and simply
        // sat there. Verified against a live 1,282-message conversation.
        if (firstPass) _fillViewportIfNotScrollable();
        // The restore above is a one-shot against an estimated extent; this
        // keeps the lane on the newest message until the user drags.
        _pinToBottomIfUnscrolled();
      });
    }

    return NotificationListener<ScrollStartNotification>(
      // Re-arm on every fresh finger-down drag.
      //
      // The `extentBefore > threshold * 2` rule in [_onScrollChanged] re-arms
      // by *position*, and position alone has a dead end: once the list is
      // resting at the very top, `extentBefore` is 0 and can never climb back
      // over the re-arm line, so the latch stays down and further upward
      // swipes do nothing at all. Verified on a live 816-message chat — the
      // transcript stopped paging with "Load earlier messages" still showing,
      // and six more swipes produced a pixel-identical screen.
      //
      // A drag start is the other half of the signal: it means the user just
      // asked again, deliberately. It cannot runaway the way a position-based
      // re-arm inside the trigger zone would, because it fires once per
      // gesture rather than once per scroll frame, and `_loadingEarlier`
      // still collapses anything that overlaps an in-flight page.
      //
      // `dragDetails != null` filters out programmatic motion — the
      // `jumpTo` in [_reanchorAfterPrepend] also opens a scroll activity, and
      // arming off our own correction would defeat the point of the latch.
      onNotification: (notification) {
        if (notification.dragDetails != null) {
          _autoLoadArmed = true;
          // The user is driving now; stop holding the lane at the newest
          // message. Deliberately not `setState` — nothing in the tree is
          // built from this, and a rebuild on the first frame of every drag
          // would be a scroll-time cost for no visual change.
          _userHasScrolled = true;
        }
        return false;
      },
      child: ListView.builder(
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
        // Retry pill — the first item, and present only while a page has
        // failed. See [_LoadEarlierHeader] for why it is an error state only.
        if (headerCount == 1 && index == 0) {
          return ResponsiveContent(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: _LoadEarlierHeader(onRetry: _loadEarlier),
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
              duration: AppDurations.cardIn,
              offset: const Offset(0, 6),
              child: ChatApprovalCard(
                approval: _adaptApiApproval(approval),
                onApprove: () => _decideApprovalInline(approval, true),
                onReject: () => _decideApprovalInline(approval, false),
                onApproveAllSimilar: () =>
                    _decideApprovalInline(approval, true, batchScope: true),
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

        final row = !showDateSeparator
            ? entryWidget
            : Column(
                children: [
                  ChatDateSeparator(date: entryAnchor.createdAt!),
                  entryWidget,
                ],
              );

        // Tag the scroll anchor. `_scrollAnchorId` names one specific message
        // whose on-screen position must survive the next prepend; carrying
        // the key on that row is what lets `_reanchorAfterPrepend` measure
        // where it actually moved to. See `_loadEarlier`.
        return entryAnchor.id == anchorId
            ? KeyedSubtree(key: _scrollAnchorKey, child: row)
            : row;
      },
      ),
    );
  }

  /// Renders one [TimelineEntry] as either a plain [MessageRow] or a
  /// [ChatThinkingPill] + the final reply. Keeps the bubble-grouping
  /// (`isFirstOfGroup` / `isLastOfGroup`) heuristics out of the
  /// itemBuilder closure so the index math up top stays readable.
  Widget _buildTimelineEntry(
    TimelineEntry entry, {
    required bool showDateSeparator,
    required DemoMessage? previousLast,
  }) {
    if (entry is SingleMessageEntry) {
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
        const SizedBox(height: 6),
        MessageRow(
          key: finalReply.id.isEmpty
              ? null
              : ValueKey('msg-${finalReply.id}'),
          message: finalReply,
          isFirstOfGroup: true,
          isLastOfGroup: true,
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
      maxWidth: 760,
      padding: EdgeInsets.fromLTRB(14, showDateSeparator ? 2 : 14, 14, 6),
      child: pillThenReply,
    );
  }

  /// Bundles each user-→-agent round into a [TimelineEntry].
  ///
  /// Lives in `data/chat_timeline.dart` so the grouping — including the rule
  /// that keeps interactive cards out of the collapsed thinking pill — is
  /// testable without pumping the screen.
  List<TimelineEntry> _buildTimeline(List<DemoMessage> messages) =>
      buildChatTimeline(messages);

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

  void _toast(String text) {
    AppToast.show(context, message: text);
  }

  /// Surfaces a failed chat mutation as a two-line error toast — the action
  /// label ("Couldn't send your message") over the mapped, localized cause
  /// ("No internet connection") — then consumes the one-shot failure so it
  /// never re-fires on a later rebuild. Falls back to the generic message
  /// only when there's no classified failure on the cubit (or no cubit yet,
  /// for a brand-new chat).
  /// Runs a conversation-flag PATCH and surfaces the reason if it fails.
  ///
  /// The cubit already rolls the optimistic value back; without this the
  /// user only saw the switch flick back to where it was, with no toast
  /// and no way to tell a refusal from a mis-tap.
  Future<void> _applyToggle(Future<bool> Function() patch) async {
    final ok = await patch();
    if (!ok && mounted) _surfaceActionFailure();
  }

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
      ChatAction.revokeShare => tr.chatActionRevokeShareFailed,
      ChatAction.setActiveCredential ||
      ChatAction.toggleCredential =>
        tr.chatActionCredentialFailed,
      ChatAction.dismissPendingAction => tr.chatActionDismissFailed,
      ChatAction.load || ChatAction.patch => tr.defaultApiError,
    };
  }

  /// Upgrade CTA target (Gap B) — opens the pricing screen (Gap L) with the
  /// live tiers, where each paid tier hands off to the web checkout on
  /// saqqaar.com. Only reachable when `showPaidUpsell` is on; the banner drops
  /// its CTA entirely otherwise, so this is never a dead end.
  void _openPricing() {
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
      borderRadius: AppRadius.smallR,
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
                        borderRadius: AppRadius.pillR,
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
/// Tap-to-retry pill shown at the head of the message list — **only** after an
/// automatic page has failed.
///
/// Two earlier versions of this were wrong in opposite directions. First it was
/// a "Load earlier messages" button the user had to tap for every page. Then,
/// once paging became automatic, it became a passive status row that still
/// rendered whenever more history existed — which meant the top of every long
/// chat permanently advertised that there was more to fetch, while the app was
/// already fetching it. Users read that as the transcript having stopped.
///
/// So it is now an error state and nothing else. Auto-loading stands down after
/// a failure rather than hammering a failing endpoint on every scroll frame,
/// which is the one situation the automatic path cannot recover from on its
/// own; this is the way back in. Everything else — including the wait while a
/// page is genuinely in flight — is the app's problem, not the user's, and the
/// page-ahead means that wait is usually already over before they reach it.
class _LoadEarlierHeader extends StatelessWidget {
  const _LoadEarlierHeader({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.pillR,
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: s.cardBg,
              borderRadius: AppRadius.pillR,
              border: Border.all(color: s.cardBorder),
              boxShadow: s.glassShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.refresh, size: 18, color: s.brandCyan),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tr.chatLoadEarlier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: s.brandCyan,
                      fontWeight: FontWeight.w700,
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
/// The mapping itself lives in `data/message_adapter.dart` so it is testable
/// without a `BuildContext`; this wrapper only resolves the two things that
/// genuinely need one — the localized timestamp label and the attachment
/// size/kind copy.
DemoMessage _adaptApiMessage(api.Message m, BuildContext context) {
  return adaptApiMessage(
    m,
    time: AppDateFormat.fullDateTime(context, m.createdAt),
    attachments: m.attachments
        .map((a) => _adaptApiAttachment(a, context.tr))
        .toList(),
  );
}

DemoAttachment _adaptApiAttachment(api.Attachment a, AppStrings tr) {
  return DemoAttachment(
    name: a.originalName,
    kind: a.kind.toUpperCase(),
    size: humanBytes(a.sizeBytes, tr),
    imageUrl: a.kind == 'image' ? a.absoluteUrl : null,
    // Carry the server-side id + absolute URL so the AttachmentChip
    // tap handler can download + open the file via [ArtifactDownloader].
    serverId: a.id,
    downloadUrl: a.absoluteUrl,
  );
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


