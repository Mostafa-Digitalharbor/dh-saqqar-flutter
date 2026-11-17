import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../auth/view_model/auth_cubit.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/chat_context.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../data/prompt_memory_api.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/network/view_model/connectivity_cubit.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/fade_slide_in.dart';
// Dead with the conversation menu — the rail drawer renders counts as
// tab-label suffixes, not as mini chips on a sheet item.
// import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../billing/data/plan_models.dart' show QuotaWindow;
import '../../billing/view_model/plan_cubit.dart';
import '../../billing/view_model/saqqar_features_cubit.dart';
import '../../data_api/data/odoo_data_api.dart';
import '../data/chat_view_models.dart';
import '../view_model/task_prep_cubit.dart';
import '../view_model/earlier_paging.dart';
import '../data/chat_features.dart';
import '../data/saqqar_tools_api.dart';
import '../data/chat_timeline.dart';
import '../data/interactive_cards.dart';
import '../data/approval_grouping.dart';
import '../data/approval_adapter.dart';
import '../data/message_adapter.dart';
import '../data/message_visibility.dart';
import '../data/live_env_ack_service.dart';
import '../data/transcribe_api.dart';
import '../view_model/running_agents_cubit.dart';
import '../data/tool_status.dart';
import '../widgets/widgets.dart';
import 'attachment_viewer_screen.dart';
import '../view_model/chat_cubit_paging.dart';
import '../widgets/chat_frame.dart';
import '../widgets/chat_load_earlier_header.dart';
import '../../conversations/data/conversation_models.dart' as api;
import '../../conversations/data/conversations_repository.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../inbox/data/approval_models.dart' as api;
import '../../inbox/data/approvals_api.dart';
import '../../share/intake/share_intake_service.dart';
import '../../vault/data/projects_api.dart';
import '../../vault/view_model/vault_cubit.dart';
import '../view_model/chat_cubit.dart';
import '../view_model/chat_reveal_window.dart';
import '../view_model/chat_scroll_coordinator.dart';
import '../view_model/task_wording_controller.dart';
import '../view_model/staged_file.dart';
import '../view_model/chat_state.dart';
import '../data/attachment_source_picker.dart';
import '../data/mic_permission_gate.dart';
import '../view_model/attachment_staging.dart';
import '../view_model/voice_note_recorder.dart';

export '../view_model/chat_cubit_paging.dart';
part 'chat_screen_messages.dart';
part 'chat_screen_support.dart';
part 'chat_screen_voice.dart';
part 'chat_screen_layout.dart';
part 'chat_screen_send.dart';
part 'chat_screen_tools.dart';
part 'chat_screen_attachments.dart';
part 'chat_screen_environment.dart';
part 'chat_screen_list.dart';
part 'chat_screen_timeline.dart';
part 'chat_screen_header.dart';
part 'chat_screen_slash.dart';
part 'chat_screen_tools_sheet.dart';

/// The chat screen. Owns the conversation state (messages, active credential,
/// auto-approve toggle, composer text), wires the typing/scroll FSM, and
/// orchestrates the chat widgets and sheets.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  /// `setState` for the part-file extensions, which cannot call the
  /// `@protected` original.
  void _update(VoidCallback fn) => setState(fn);

  // -------- State --------

  final _composer = TextEditingController();

  /// The "shall I structure this first?" offer and its docked card — see
  /// [TaskWordingController], which owns the staleness guard too.
  late final TaskWordingController _wording;
  final _composerFocus = FocusNode();

  /// The transcript's scroll offset, its upward paging and its reveal window
  /// — see [ChatScrollCoordinator], which owns the `ScrollController` too.
  late final ChatScrollCoordinator _lane;

  late List<ChatMessage> _messages;

  /// Snapshot of the messages currently rendered in the lane — cached each
  /// build so the AppBar's in-conversation search sheet can read them from
  /// a button callback (where `context.watch` isn't valid).
  List<ChatMessage> _searchableMessages = const [];

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

  bool _autoApprove = false;

  /// Spec §10 — drawer open/close state lives here so the chat owns the
  /// slide animation + scrim. Drops the Material `Scaffold.drawer` /
  /// `endDrawer` plumbing entirely.
  bool _sidebarOpen = false;
  bool _railOpen = false;

  /// Set once `/transcribe/` answers 403. The plan snapshot can list voice as
  /// available while the endpoint refuses (seen on Free), so the mic is hidden
  /// for the rest of the session instead of failing on every tap.
  bool _voiceLocked = false;

  /// Currently staged files. Non-empty when the user has picked one or more
  /// via the paperclip OR received a share-intent hand-off from another app.
  /// Each entry renders as its own chip in the composer, and Send becomes
  /// enabled even on empty text.
  ///
  /// ONE list, of [StagedFile] — chip and file together. This used to be two
  /// lists "kept in sync by index", which is a rule nothing enforced: see
  /// [StagedFile] for what that cost at each call site.
  final List<StagedFile> _staged = [];

  /// The chips, for the composer. Derived, so it cannot fall out of step
  /// with the files the way a second stored list could.
  List<ChatAttachment> get _attachmentChips => [
    for (final s in _staged) s.chip,
  ];

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

  // ── Voice recording ─────────────────────────────────────────────────
  // Per SAQQAR_MOBILE_VOICE.md the composer text field is replaced with a
  // recording overlay (waveform + timer + stop / discard) while
  // `_voice.isRecording`, then shows "Transcribing…" while
  // `_voice.isTranscribing` until `/api/v1/transcribe/` returns.
  /// Owns the recorder handle, the mm:ss ticker, the 120 s cap and the temp
  /// file. Built in `initState` so its max-length callback can reach `this`.
  late final VoiceNoteRecorder _voice;

  /// Grace window after a send during which the optimistic running
  /// marker is kept even if the snapshot still reads not-running — the
  /// server has not picked up the new turn yet, and clearing here would
  /// race the run to false before it ever flips true.
  static const _sendGraceWindow = Duration(seconds: 12);

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

  // Memo for [_allVisibleMessages]. The adaptation (filter + map to
  // `ChatMessage` + per-row intl date formatting) is a pure function of the
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
  List<ChatMessage>? _visibleMemo;

  /// A §6 Odoo scan is in flight. Server-side work with no local message to
  /// show for it until the report is posted.
  bool _toolRunning = false;

  // -------- Lifecycle --------

  @override
  void initState() {
    super.initState();
    // Existing chats source messages from the ChatCubit snapshot via
    // `_effectiveMessages`, so the local list stays empty. New chats
    // keep it empty too (no demo seed) — the empty state surface
    // (EmptyChatSuggestions) renders until the create-then-route flow
    // hands off to a real cubit.
    _initControllers();

    // Listen for app foreground / background transitions so the chat
    // poll timer pauses when the user minimises the app — without this,
    // a chat sitting in a paused process keeps firing GET requests
    // every 1.5 s (running) / 15 s (idle), draining battery and data.
    WidgetsBinding.instance.addObserver(this);
    _initShareIntake();
    // Loading skeleton state now comes from the cubit's DataLoading
    // (see the build method) — no local timer needed.
  }

  /// Reference held so [dispose] can detach the listener even after
  /// [context] is gone. `late final` would be nicer but the field is
  /// nullable so we can use `?.` in dispose without races.
  ShareIntakeService? _shareIntakeService;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareIntakeService?.removeListener(_onShareIntakeChanged);
    // Cancels its timers and tears down the plugin handle. Not awaited —
    // the State is going away and the temp file is deleted on every path
    // that produced one.
    _voice
      ..removeListener(_onVoiceChanged)
      ..dispose();
    _composer.removeListener(_onComposerTextChanged);
    _composer.dispose();
    _composerFocus.dispose();
    _lane
      ..removeListener(_onLaneChanged)
      ..dispose();
    _wording
      ..removeListener(_onWordingChanged)
      ..dispose();
    super.dispose();
  }

  // ── Voice recording lifecycle ───────────────────────────────────────

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

  // -------- Sending --------

  /// Re-entrancy guard for [_send]. A fast double-tap (or Enter + tap) can
  /// fire the handler twice before the first pass clears the composer /
  /// morphs Send into Stop — which would POST the same message twice. Set
  /// synchronously at the top of [_send] so the second call bails instantly.
  bool _sending = false;

  // Bell trigger is inlined below as a private widget so the AppBar
  // `actions` slot stays terse.

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
  String _railCompany = '';
  String _railEnvironment = '';

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
    final online = context.watch<ConnectivityCubit>().state;
    _consumeShareIntakeWhenStaged(context);
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
    // auto-approve uses one line down.
    //
    // This was written ahead of the field existing, and its comment used to
    // say `taskPrep` was "null on every server today". That stopped being
    // true on 2026-08-12 when the backend shipped the column, and stopped
    // being true in PRACTICE on 2026-08-15, when the web began PATCHing it on
    // every flip (`docs/updates/WEB_TASK_PREP_NOT_SYNCING_RESPONSE.md`). So
    // the server branch is now the live one for any conversation a web user
    // has touched, and `null` means only "nobody has flipped this chat yet".
    //
    // `watch`, not `read`: this is what makes a flip made on the web arrive
    // here. The snapshot poll emits a new state, `build` re-runs, and the
    // toggle follows the server without the user reopening the chat.
    final taskPrep =
        snapshotConv?.taskPrep ?? context.watch<TaskPrepCubit>().state;
    final autoApprove = snapshotConv?.autoApprove ?? _autoApprove;
    final chatFeatures = ChatFeatures(
      context.watch<PlanCubit>().state,
      context.watch<SaqqarFeaturesCubit>().state,
    );

    _scheduleOutwardSync(snapshotConv);

    // Brief §4.1 mobile header — hamburger left + title middle + bell
    // right with a pending-approvals badge. Badge count reads from the
    // live snapshot (existing chats) so it reflects the server's truth
    // and shrinks as the user approves/rejects from the rail drawer.
    // New chats have no snapshot yet — badge stays 0.
    final pendingForChat = _pendingApprovalCount(context);

    // Spec §10 — both drawers live as siblings of the main content in a
    // Stack so we own the slide animation, scrim opacity, and tap-out
    // close behaviour. Material's `Scaffold.drawer` / `endDrawer` were
    // dropped explicitly (different slide curve + scrim treatment).
    final anyDrawerOpen = _sidebarOpen || _railOpen;
    final drawerWidth = _drawerWidth(context);

    final chatEnv = _resolveEnv();
    return Theme(
      data: AppTheme.dark(Localizations.localeOf(context)),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── Main chat content ─────────────────────────────────────
            //
            // `LayoutBuilder` so the bottom band can be capped against the
            // height this body actually has, not the screen's. The two diverge
            // exactly when it matters: opening the keyboard leaves the screen
            // the same size and halves the body.
            ChatFrame(
              header: _chatHeader(
                company: _railCompany = chatEnv?.projectName ?? '',
                environment: _railEnvironment = chatEnv?.name ?? '',
                isLive: chatEnv?.isLive ?? false,
                readOnly: chatEnv?.readOnly ?? false,
                pending: pendingForChat,
              ),
              taskPrep: taskPrep,
              autoApprove: autoApprove,
              onTaskPrep: _setTaskPrep,
              onAutoApprove: _setAutoApprove,
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
                    Expanded(child: _transcriptArea(context, pendingForChat)),
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
                    _bottomChrome(
                      context,
                      bodyConstraints: bodyConstraints,
                      online: online,
                      quotaWindow: quotaWindow,
                      snapshotConv: snapshotConv,
                      taskPrep: taskPrep,
                      autoApprove: autoApprove,
                      chatFeatures: chatFeatures,
                    ),
                  ],
                ),
              ),
            ),
            ..._drawerLayers(
              drawerWidth: drawerWidth,
              anyDrawerOpen: anyDrawerOpen,
            ),
          ],
        ),
      ),
    );
  }

  // -------- Inline approval actions --------

  // -------- Sheets --------

  // -------- Toasts --------

  /// Repaints when the lane changes something the tree draws — the
  /// scroll-down button, the retry pill, the reveal window.
  ///
  /// A `setState` with an empty body on purpose: the coordinator already
  /// holds the new values, and this only marks the frame dirty.
  void _onLaneChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Repaints when the task-wording card or its offer bar changes.
  void _onWordingChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// "Sent · N file(s) attached". Lives next to [_toast] so both `_send` and
  /// `_sendAsNewConversation` can share it. The one-vs-many branch that used
  /// to live here is gone: it was English's plural rule, and Arabic has six
  /// forms — `AppStrings._p` owns the choice now.
  String _sentWithFilesLabel(int count) => context.tr.sentToastFiles(count);
}
