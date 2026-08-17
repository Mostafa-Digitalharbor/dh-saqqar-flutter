import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/data_state_refreshable_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import '../view_model/conversations_state.dart';
import '../widgets/rename_conversation_dialog.dart';
import '../widgets/swipe_archive_background.dart';
import '../widgets/widgets.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Triage segments for the Chats list, mirroring the Saqqar Design System.
/// `all` shows everything; `pending` keeps only conversations with pending
/// approvals (real signal from [ApprovalsCubit]); `live` keeps recently-active
/// conversations (representative — derived from `updatedAt` recency).
enum ChatsFilterMode { all, pending, live }

/// See [ConversationSummary.isLive] — the window itself lives on the model
/// so the card and this screen can't drift apart on what "live" means.
bool conversationIsLive(ConversationSummary c) => c.isLive;

/// Conversations list — search + archive filter + paginated rows, with
/// a gradient FAB to start a fresh chat. Pinned conversations float to
/// the top regardless of recency (resolved via [ConversationsData.ordered]).
///
/// Backed by [ConversationsCubit] (Phase 4): `load()` fires on mount,
/// pull-to-refresh re-fetches, rename/archive/delete hit PATCH/DELETE
/// optimistically. Pinning is local-only — no server endpoint exists.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with WidgetsBindingObserver {
  static const _pageSize = 30;

  /// How often the list silently revalidates so pending-approval counts,
  /// previews, and the "Saqqar is working" state update on their own — no
  /// manual pull-to-refresh needed. Cheap: list + counts only, no per-row
  /// snapshot prefetch (see [ConversationsCubit.poll]).
  static const _pollInterval = Duration(seconds: 20);
  Timer? _pollTimer;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _query = '';
  ChatsFilterMode _filterMode = ChatsFilterMode.all;
  /// Whether the "Archived conversations" collapsible card is open.
  /// Reset to false after every archive/unarchive action so the user
  /// always lands back on the active list — the archived section is a
  /// drawer, not a persistent view.
  bool _archivedExpanded = false;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Always revalidate on mount — NOT gated on `isIdle`, because
    // `hydrateFromCache` leaves the cubit in DataSuccess (the cached list)
    // before the screen ever builds, so an idle-gate would skip the live
    // fetch and the rows would stay stale. `load()` dedupes internally and
    // keeps the cached rows visible while it refreshes. Mirrors VaultScreen.
    context.read<ConversationsCubit>().load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// (Re)starts the silent auto-poll. The list stays mounted beneath an open
  /// chat, so this keeps counts / running-state fresh even while the user is
  /// inside a conversation — the moment they pop back, the list already
  /// reflects the approval they just actioned instead of a stale count.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      context.read<ConversationsCubit>().poll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause polling in the background (no point spending battery/data), and
    // fire an immediate revalidation the instant the app returns so the user
    // never stares at stale rows after switching away and back.
    if (state == AppLifecycleState.resumed) {
      context.read<ConversationsCubit>().poll();
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
    }
  }

  // ── Pagination ──────────────────────────────────────────────────────

  void _resetPagination() => _pageIndex = 0;

  void _goToPage(int pageIndex) {
    final data = context.read<ConversationsCubit>().state.data.dataOrNull;
    final pageCount =
        data == null ? 1 : _pageCountFor(_filter(data).length);
    final next = pageIndex.clamp(0, pageCount - 1);
    if (next == _pageIndex) return;
    setState(() => _pageIndex = next);
    // Paging down used to trigger a project·env enrichment pass for the newly
    // revealed rows. The list endpoint carries both fields directly now, so
    // the rows arrive already tagged and there is nothing to fetch.
    if (!_scrollController.hasClients) return;
    // Soft haptic + a slower-than-default ease so the page swap reads
    // as an intentional "you moved to a new page" rather than the list
    // teleporting to the top. The auto-advance trigger fires when the
    // user is already at the bottom, so the trip back to offset 0 needs
    // the extra runway (380 ms vs the 220 ms motion baseline) to
    // register before the new rows take the user's attention.
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: AppDurations.scrollToTop,
      curve: Curves.easeOutQuart,
    );
  }

  int _pageCountFor(int total) {
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  // ── Filtering ───────────────────────────────────────────────────────

  /// Returns the conversations matching the current search + archive
  /// filters. Computed from [data.ordered] so pinned rows always lead.
  ///
  /// The archive filter is a hard split: when the toggle is off the user
  /// sees only non-archived rows, when it's on they see only archived
  /// rows (never a mix — the previous "show all" behaviour confused
  /// users who expected the toggle to scope the list, not extend it).
  /// Active (non-archived) conversations the main list shows. Archived
  /// rows live inside the dedicated collapsible "Archived" card —
  /// they're never mixed into the main list.
  List<ConversationSummary> _filter(ConversationsData data) {
    final q = _query.trim().toLowerCase();
    return data.ordered.where((c) {
      if (c.isArchived) return false;
      if (q.isNotEmpty &&
          !(c.title.toLowerCase().contains(q) ||
              c.lastMessagePreview.toLowerCase().contains(q))) {
        return false;
      }
      switch (_filterMode) {
        case ChatsFilterMode.all:
          return true;
        case ChatsFilterMode.pending:
          // REAL needs-approval signal — the conversation has at least one
          // pending approval in the flat `/approvals/?status=pending` feed.
          return data.needsApproval(c.id);
        case ChatsFilterMode.live:
          return conversationIsLive(c);
      }
    }).toList();
  }

  /// Archived conversations matching the current search query. Search
  /// applies to both buckets so a query like "invoice" surfaces matches
  /// regardless of where the conversation lives.
  List<ConversationSummary> _archived(ConversationsData data) {
    final q = _query.trim().toLowerCase();
    return data.ordered.where((c) {
      if (!c.isArchived) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.lastMessagePreview.toLowerCase().contains(q);
    }).toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  void _openFreshConversation() {
    context.go(RouteNames.chatPath(UiStrings.routeNewConversation));
  }

  Future<void> _handleRowAction(
    ConversationSummary c,
    ConversationAction action,
  ) async {
    final cubit = context.read<ConversationsCubit>();
    switch (action) {
      case ConversationAction.pin:
        cubit.togglePin(c.id);
      case ConversationAction.rename:
        final next = await RenameConversationDialog.show(
          context,
          initial: c.title,
        );
        if (next == null || !mounted) return;
        await cubit.renameConversation(id: c.id, name: next);
      case ConversationAction.archive:
        if (c.isArchived) {
          await cubit.unarchiveConversation(c.id);
          // Collapse the archived drawer so the user lands back on the
          // active list with the newly-restored conversation in it.
          // The list refreshes automatically — cubit emits a new state
          // optimistically the moment the action fires.
          if (mounted && _archivedExpanded) {
            setState(() => _archivedExpanded = false);
          }
        } else {
          await _archiveWithUndo(cubit, c);
        }
      case ConversationAction.delete:
        // Deleting is irreversible, so gate it behind a Yes/No confirm
        // with the destructive (red) confirm button. Applies whether the
        // action came from the row's kebab menu or the swipe-left gesture.
        final confirmed = await _confirmDelete(c);
        if (!confirmed || !mounted) return;
        await cubit.deleteConversation(c.id);
      case ConversationAction.share:
        await _shareConversation(c);
    }
  }

  /// Requests a public share link for [c] and hands it to the OS share
  /// sheet (WhatsApp / Telegram / copy-link / …). The link is issued by
  /// `POST /conversations/<id>/share/` — the same token the web share page
  /// (`saqqaar.com/share/<token>/`) consumes. On failure the cubit sets
  /// `actionFailure`, which the screen's BlocListener turns into a toast,
  /// so we just bail here.
  Future<void> _shareConversation(ConversationSummary c) async {
    final cubit = context.read<ConversationsCubit>();
    final url = await cubit.shareConversation(c.id);
    if (!mounted || url == null) return;
    // share_plus 10.x uses the static `Share.share(text, subject:)` API.
    // `subject` is only used as the email subject on the mailto fallback;
    // most share targets ignore it. Falls back to the app name for
    // untitled chats.
    await Share.share(
      url,
      subject: c.title.trim().isEmpty ? context.tr.appName : c.title.trim(),
      // iPad presents the share sheet as a popover and errors out without an
      // anchor. See `sharePositionOrigin`.
      sharePositionOrigin: context.sharePositionOrigin,
    );
  }

  /// Yes/No confirmation before a permanent delete. The confirm button
  /// renders in the danger (red) palette via `destructive: true`, and the
  /// labels reuse the shared confirmYes / confirmNo copy so this reads the
  /// same as the app's other destructive prompts.
  Future<bool> _confirmDelete(ConversationSummary c) {
    return ConfirmDialog.show(
      context,
      title: context.tr.deleteConversationTitle,
      body: context.tr.deleteConversationBody,
      confirmLabel: context.tr.confirmYes,
      cancelLabel: context.tr.confirmNo,
      icon: AppIcons.trash,
      destructive: true,
    );
  }

  /// Archives the conversation and surfaces a "Conversation archived"
  /// toast with a one-tap "Show" action that expands the Archived
  /// collapsible card — gives the user an immediate way to find the row
  /// that just disappeared. The card stays collapsed by default so the
  /// main view returns to the active list after the action lands.
  ///
  /// Suppresses the cubit's default archive toast (consumed silently in
  /// [_onCubitChange]) so we don't fire two stacked snackbars.
  Future<void> _archiveWithUndo(
    ConversationsCubit cubit,
    ConversationSummary c,
  ) async {
    await cubit.archiveConversation(c.id);
    if (!mounted) return;
    // Always collapse first — the user's expectation after archiving is
    // "back to my normal list". The toast action below lets them opt
    // into opening the drawer.
    if (_archivedExpanded) {
      setState(() => _archivedExpanded = false);
    }
    AppToast.show(
      context,
      message: context.tr.conversationArchivedToast,
      variant: ToastVariant.success,
      action: ToastAction(
        label: context.tr.showArchivedAction,
        onPressed: () {
          if (!mounted) return;
          setState(() => _archivedExpanded = true);
        },
      ),
    );
  }

  // ── Cubit-driven toast surface ──────────────────────────────────────

  void _onCubitChange(BuildContext context, ConversationsState state) {
    final cubit = context.read<ConversationsCubit>();
    final tr = context.tr;
    if (state.actionFailure != null) {
      final f = state.actionFailure!;
      AppToast.show(
        context,
        title: _actionLabel(tr, f.action),
        message: ApiErrorMapper.message(context, f.failure),
        variant: ToastVariant.error,
      );
      cubit.consumeActionFailure();
    }
    if (state.actionToast != null) {
      // Archive emits its own richer toast (with a "Show" action) from
      // _archiveWithUndo — consume the cubit's plain one silently so we
      // don't stack two snackbars on top of each other.
      if (state.actionToast != ConversationsToast.conversationArchived) {
        AppToast.show(
          context,
          message: _toastMessage(tr, state.actionToast!),
          variant: ToastVariant.success,
        );
      }
      cubit.consumeActionToast();
    }
  }

  // ── Date grouping (locale-aware, real DateTime) ─────────────────────

  /// Bucket a conversation into "Today / Yesterday / Previous 7 days /
  /// Older". Replaces the demo's string-label heuristic with real
  /// DateTime math.
  String _dateGroupKey(BuildContext context, ConversationSummary c) {
    final now = DateTime.now();
    final updated = c.updatedAt;
    final today = DateTime(now.year, now.month, now.day);
    final convDay = DateTime(updated.year, updated.month, updated.day);
    final daysDelta = today.difference(convDay).inDays;
    if (c.isArchived) return context.tr.dateGroupOlder;
    if (daysDelta == 0) return context.tr.dateGroupToday;
    if (daysDelta == 1) return context.tr.dateGroupYesterday;
    if (daysDelta <= 7) return context.tr.dateGroupPrevious7;
    return context.tr.dateGroupOlder;
  }

  /// Routes a row-level action fired from inside [_buildGroupedRows]
  /// (swipe gesture, Dismissible callback) through the shared
  /// [_handleRowAction]. Fire-and-forget — the gesture has already
  /// resolved by the time the async handler chains.
  void onRowActionFromBuild(
    ConversationSummary c,
    ConversationAction action,
  ) {
    _handleRowAction(c, action);
  }

  List<Widget> _buildGroupedRows(List<ConversationSummary> rows) {
    final widgets = <Widget>[];
    String? currentGroup;
    // Real per-conversation meta (pending approvals + files) from the loaded
    // data — passed into each card so the counts are never fabricated.
    final data = context.read<ConversationsCubit>().state.data.dataOrNull;
    // Physical-direction mapping for the swipe gestures. We want "swipe
    // right = archive, swipe left = delete" regardless of locale, so we
    // resolve Flutter's directional [DismissDirection] against the current
    // text direction: startToEnd is a physical-right drag in LTR but a
    // physical-left drag in RTL.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // In LTR the startToEnd (background) edge is the archive/right side; in
    // RTL that same edge is the delete/left side.
    final startToEndIsArchive = !rtl;
    for (final entry in rows.asMap().entries) {
      final c = entry.value;
      final group = _dateGroupKey(context, c);
      if (group != currentGroup) {
        if (currentGroup != null) widgets.add(const SizedBox(height: AppSpacing.s16));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Text(
              group,
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        currentGroup = group;
      }
      widgets.add(
        // Per-row RepaintBoundary: rows live in a plain Column (one sliver
        // child), so without this they share one layer — every card's shadow
        // blur re-rasterizes together on any rebuild, and a poll landing
        // mid-scroll repaints the whole list. Keyed by row id so the boundary
        // element (and the FadeSlideIn under it) is reused across rebuilds,
        // keeping the intro-once behaviour and caching each card's raster.
        RepaintBoundary(
          key: ValueKey('row-${c.id}'),
          child: FadeSlideIn(
            // Two keys are nested here on purpose. The outer `ValueKey`
            // identifies the FadeSlideIn slot so the intro animation only
            // fires for genuinely new rows. The inner `Dismissible` needs its
            // OWN unique key because the Dismissible widget tracks gesture
            // state per-key and asserts on duplicates.
            key: ValueKey('fade-${c.id}'),
            index: entry.key,
            child: Dismissible(
            key: ValueKey('dismiss-${c.id}'),
            // Two distinct horizontal gestures (request 2026-07-06):
            //   • swipe RIGHT → archive / unarchive
            //   • swipe LEFT  → delete (guarded by the Yes/No confirm)
            // The backgrounds are laid out against the resolved text
            // direction so each edge shows the action it will actually
            // trigger.
            direction: DismissDirection.horizontal,
            background: startToEndIsArchive
                ? SwipeArchiveBackground(
                    alignment: AlignmentDirectional.centerStart,
                    archived: c.isArchived,
                  )
                : const SwipeDeleteBackground(
                    alignment: AlignmentDirectional.centerStart,
                  ),
            secondaryBackground: startToEndIsArchive
                ? const SwipeDeleteBackground(
                    alignment: AlignmentDirectional.centerEnd,
                  )
                : SwipeArchiveBackground(
                    alignment: AlignmentDirectional.centerEnd,
                    archived: c.isArchived,
                  ),
            // Return false so Dismissible never unmounts the row itself —
            // archive is driven by the cubit's optimistic update, and
            // delete only proceeds after the confirm dialog resolves.
            // Returning true would double-animate + trip a "key reused"
            // assert on the next emit. The routed action fires regardless.
            confirmDismiss: (direction) async {
              // Physical-right drag = archive; physical-left = delete.
              final swipedRight =
                  (direction == DismissDirection.startToEnd) != rtl;
              if (swipedRight) {
                onRowActionFromBuild(c, ConversationAction.archive);
              } else {
                // Route through the shared handler so the delete confirm
                // dialog (red "Yes") is identical to the kebab-menu path.
                onRowActionFromBuild(c, ConversationAction.delete);
              }
              return false;
            },
            child: ConversationCard(
              conversation: c,
              pendingApprovals: data?.pendingApprovalsFor(c.id) ?? 0,
              filesCount: data?.filesFor(c.id) ?? 0,
              onTap: () => context.go(RouteNames.chatPath(c.id)),
              onAction: (action) => _handleRowAction(c, action),
            ),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.s10));
    }
    return widgets;
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationsCubit, ConversationsState>(
      listenWhen: (a, b) =>
          a.actionFailure != b.actionFailure ||
          a.actionToast != b.actionToast,
      listener: _onCubitChange,
      // The builder derives everything it renders from `state.data` (counts,
      // empty-state, the row list). Gate rebuilds on that alone so a poll that
      // only touches action-toast/failure state — or re-emits an equal data
      // snapshot — doesn't rebuild the whole list mid-scroll. Local filter /
      // search / page changes go through setState, not the cubit, so they
      // still rebuild independently of this predicate.
      buildWhen: (a, b) => a.data != b.data,
      builder: (context, state) {
        final data = state.data.dataOrNull;
        // REAL "needs approval" total — the number of conversations with at
        // least one pending approval (same source as the filter chip badge,
        // the filter, and the per-row pill). Never the demo-backed
        // `ApprovalsCubit.pendingCount`.
        final pendingCount = data == null
            ? 0
            : data.conversations
                .where((c) => !c.isArchived && data.needsApproval(c.id))
                .length;
        final totalCount = data == null ? 0 : _filter(data).length;
        final subtitleText = pendingCount > 0
            ? '$totalCount ${context.tr.conversations} · '
                '$pendingCount ${context.tr.pending}'
            : '$totalCount ${context.tr.conversations}';

        // `ConversationsEmptyState` renders its own prominent "New
        // conversation" CTA, so keeping the FAB up as well stacks two
        // identical buttons on the same screen — the FAB even overlaps the
        // empty-state artwork. Drop the FAB for exactly the case the empty
        // state owns; mirrors its own condition below.
        final showsEmptyState = data != null && data.conversations.isEmpty;

        return PageScaffold(
          title: context.tr.tabChats,
          subtitle: subtitleText,
          controller: _scrollController,
          onRefresh: () => context.read<ConversationsCubit>().refresh(),
          actions: [
            AppIconButton(
              icon: AppIcons.refresh,
              tooltip: context.tr.refreshConversations,
              bordered: false,
              onPressed: () => context.read<ConversationsCubit>().refresh(),
            ),
            const SizedBox(width: AppSpacing.s6),
          ],
          floatingActionButton: showsEmptyState
              ? null
              : GradientFab(
                  onPressed: _openFreshConversation,
                  label: context.tr.newConversation,
                ),
          children: [
            DataStateRefreshableView<ConversationsData>(
              state: state.data,
              onRefresh: () => context.read<ConversationsCubit>().refresh(),
              loadingLabel: context.tr.loading,
              // Skeleton-during-refresh: previous data hides, card-shaped
              // shimmers paint in its place until the new snapshot lands.
              // Far better than a bare spinner — the user keeps spatial
              // intuition for "rows are coming back here".
              keepPreviousOnLoading: false,
              onLoading: (context, _) => const Column(
                key: ValueKey('conversations-skeleton'),
                children: [
                  ConversationCardSkeleton(),
                  SizedBox(height: AppSpacing.s10),
                  ConversationCardSkeleton(),
                  SizedBox(height: AppSpacing.s10),
                  ConversationCardSkeleton(),
                  SizedBox(height: AppSpacing.s10),
                  ConversationCardSkeleton(),
                  SizedBox(height: AppSpacing.s10),
                  ConversationCardSkeleton(),
                ],
              ),
              onData: (context, data) => _ConversationsBody(
                data: data,
                query: _query,
                filterMode: _filterMode,
                onFilterModeChanged: (mode) => setState(() {
                  _filterMode = mode;
                  _resetPagination();
                }),
                archivedExpanded: _archivedExpanded,
                pageIndex: _pageIndex,
                pageSize: _pageSize,
                searchController: _searchController,
                onSearchChanged: (value) => setState(() {
                  _query = value;
                  _resetPagination();
                }),
                onArchivedToggle: () => setState(() {
                  _archivedExpanded = !_archivedExpanded;
                }),
                onGoToPage: _goToPage,
                openFresh: _openFreshConversation,
                buildGroupedRows: _buildGroupedRows,
                filter: _filter,
                archived: _archived,
                pageCountFor: _pageCountFor,
                onRowAction: _handleRowAction,
              ),
            ),
            // Bottom clearance so the floating "New conversation" FAB never
            // covers the last item (the pagination controls / final card)
            // when the list is scrolled to the bottom.
            const SizedBox(height: AppSpacing.s80),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Body — kept separate so the DataState builder closure stays thin and
// the screen-level state class doesn't grow build-method noise.
// ─────────────────────────────────────────────────────────────────────────

class _ConversationsBody extends StatelessWidget {
  const _ConversationsBody({
    required this.data,
    required this.query,
    required this.filterMode,
    required this.onFilterModeChanged,
    required this.archivedExpanded,
    required this.pageIndex,
    required this.pageSize,
    required this.searchController,
    required this.onSearchChanged,
    required this.onArchivedToggle,
    required this.onGoToPage,
    required this.openFresh,
    required this.buildGroupedRows,
    required this.filter,
    required this.archived,
    required this.pageCountFor,
    required this.onRowAction,
  });

  final ConversationsData data;
  final String query;
  final ChatsFilterMode filterMode;
  final ValueChanged<ChatsFilterMode> onFilterModeChanged;
  final bool archivedExpanded;
  final int pageIndex;
  final int pageSize;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onArchivedToggle;
  final ValueChanged<int> onGoToPage;
  final VoidCallback openFresh;
  final List<Widget> Function(List<ConversationSummary>) buildGroupedRows;
  final List<ConversationSummary> Function(ConversationsData) filter;
  final List<ConversationSummary> Function(ConversationsData) archived;
  final int Function(int) pageCountFor;
  final Future<void> Function(
    ConversationSummary,
    ConversationAction,
  ) onRowAction;

  @override
  Widget build(BuildContext context) {
    final filtered = filter(data);
    final archivedRows = archived(data);
    final pageCount = pageCountFor(filtered.length);
    final paged = filtered.skip(pageIndex * pageSize).take(pageSize).toList();

    // REAL "needs approval" total — the number of conversations that have at
    // least one pending approval (same source as the filter + the per-row
    // pill), so the badge always equals what tapping "Needs approval" reveals.
    final pendingTotal = data.conversations
        .where((c) => !c.isArchived && data.needsApproval(c.id))
        .length;

    return Column(
      children: [
        SearchAndFiltersBar<Never>(
          controller: searchController,
          hintText: context.tr.searchConversations,
          query: query,
          onQueryChanged: onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.s14),
        _ChatsFilterChips(
          mode: filterMode,
          onChanged: onFilterModeChanged,
          pendingCount: pendingTotal,
        ),
        const SizedBox(height: AppSpacing.s16),
        // Archived collapsible card. Only mounted when there's at least
        // one archived conversation — otherwise the word "Archived"
        // doesn't appear in the UI at all.
        if (archivedRows.isNotEmpty) ...[
          _ArchivedSection(
            archived: archivedRows,
            expanded: archivedExpanded,
            onToggle: onArchivedToggle,
            onRowAction: onRowAction,
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        if (filtered.isEmpty &&
            archivedRows.isEmpty &&
            data.conversations.isEmpty)
          ConversationsEmptyState(
            key: const ValueKey('empty-conversations'),
            onStart: openFresh,
          )
        else if (filtered.isEmpty && query.isNotEmpty)
          EmptyState(
            key: const ValueKey('empty-search'),
            icon: AppIcons.search,
            title: context.tr.clearSearch,
            body: query,
          )
        else if (filtered.isEmpty)
          // A filter (e.g. "Needs approval") is active but no conversation
          // matches it. Without this branch the list area would render blank.
          EmptyState(
            key: const ValueKey('empty-filter'),
            icon: AppIcons.shieldAlert,
            title: context.tr.noMatches,
          )
        else if (filtered.isNotEmpty)
          Column(
            key: ValueKey('conversation-list-$query-${paged.length}'),
            children: buildGroupedRows(paged),
          ),
        // Page navigation sits at the BOTTOM of the list (moved down on
        // request) so it follows the conversations instead of preceding them.
        if (filtered.length > pageSize) ...[
          const SizedBox(height: AppSpacing.s12),
          PaginationBar(
            page: pageIndex + 1,
            pageCount: pageCount,
            // Cumulative count THROUGH the current page (30 → 60 → 89…),
            // not just this page's rows, so it reads as "how many you've
            // reached out of the total".
            visibleCount: (pageIndex * pageSize) + paged.length,
            totalCount: filtered.length,
            itemLabel: context.tr.conversations,
            onPrevious: pageIndex == 0 ? null : () => onGoToPage(pageIndex - 1),
            onNext: pageIndex >= pageCount - 1
                ? null
                : () => onGoToPage(pageIndex + 1),
            // Jump straight back to the first page. The bar hides this button
            // on page 1 itself (page > 1 guard), so it only shows once the
            // user has paged forward.
            onFirst: () => onGoToPage(0),
          ),
        ],
      ],
    );
  }
}

/// Triage filter chips — All / Needs approval — mirroring the Saqqar Design
/// System's Chats `FilterChips`. Left-aligned pills (not a stretched
/// segmented control): the active chip fills with the primary gradient +
/// cyan-pop glow; "Needs approval" carries a live amber count badge.
class _ChatsFilterChips extends StatelessWidget {
  const _ChatsFilterChips({
    required this.mode,
    required this.onChanged,
    required this.pendingCount,
  });

  final ChatsFilterMode mode;
  final ValueChanged<ChatsFilterMode> onChanged;

  /// Coherent total of conversations-with-pending-approvals (same source as
  /// the rows) so the badge always matches the filtered list.
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            icon: LucideIcons.layoutGrid,
            label: tr.filterAll,
            badge: 0,
            warn: false,
            active: mode == ChatsFilterMode.all,
            onTap: () => onChanged(ChatsFilterMode.all),
          ),
          const SizedBox(width: AppSpacing.s8),
          _FilterChip(
            icon: AppIcons.shieldAlert,
            label: tr.filterNeedsApproval,
            badge: pendingCount,
            warn: true,
            active: mode == ChatsFilterMode.pending,
            onTap: () => onChanged(ChatsFilterMode.pending),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.badge,
    required this.warn,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int badge;
  final bool warn;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final fg = active ? Colors.white : s.muted;
    return TappableSurface(
      radius: AppRadius.pillR,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          gradient: active ? AppGradients.primaryCta : null,
          color: active ? null : s.cardBg,
          borderRadius: AppRadius.pillR,
          border: Border.all(
            color: active ? Colors.transparent : s.border,
          ),
          boxShadow: active ? s.cyanPopShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSizes.compact, color: fg),
            const SizedBox(width: AppSpacing.s7),
            Text(
              label,
              style: context.text.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: AppSpacing.s7),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : (warn
                          ? s.warning.withValues(alpha: 0.20)
                          : s.surface3),
                  borderRadius: AppRadius.pillR,
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : (warn ? s.warning : s.muted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsible card surfaced below the search bar when at least one
/// conversation is archived. Header reads "Archived conversations (N)"
/// with a chevron that rotates 180° on expand; the body slides open via
/// [AnimatedSize] and lists the archived rows so the user can act on
/// them (unarchive, rename, delete) without leaving the screen.
class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({
    required this.archived,
    required this.expanded,
    required this.onToggle,
    required this.onRowAction,
  });

  final List<ConversationSummary> archived;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(
    ConversationSummary,
    ConversationAction,
  ) onRowAction;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.85),
        borderRadius: AppRadius.inputR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TappableSurface(
            radius: AppRadius.inputR,
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s14,
                    vertical: AppSpacing.s12,
                  ),
              child: Row(
                children: [
                  Icon(AppIcons.archive, size: AppIconSizes.regular, color: s.muted),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      '${context.tr.archived} (${archived.length})',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: AppDurations.fast,
                    turns: expanded ? 0.5 : 0,
                    child: Icon(
                      AppIcons.chevronDown,
                      size: AppIconSizes.action,
                      color: s.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.cardIn,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedCrossFade(
              duration: AppDurations.fast,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              // AnimatedCrossFade builds BOTH children every frame. While the
              // section is collapsed we therefore skip building the archived
              // cards entirely (each carries a blurred-shadow card) — they only
              // materialize when the user actually expands the section, and get
              // disposed again on collapse. Was: the full archived list built
              // and rebuilt on every poll even while hidden.
              secondChild: !expanded
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s10,
                        0,
                        AppSpacing.s10,
                        AppSpacing.s10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in archived) ...[
                            ConversationCard(
                              key: ValueKey('archived-${c.id}'),
                              conversation: c,
                              onTap: () => context.go(RouteNames.chatPath(c.id)),
                              onAction: (action) => onRowAction(c, action),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                          ],
                        ],
                      ),
                    ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Localized labels for the cubit's typed action / toast enums.
// ─────────────────────────────────────────────────────────────────────────

String _actionLabel(AppStrings tr, ConversationsAction action) {
  return switch (action) {
    ConversationsAction.load => tr.conversationsActionLoadFailed,
    ConversationsAction.create => tr.conversationsActionCreateFailed,
    ConversationsAction.rename => tr.conversationsActionRenameFailed,
    ConversationsAction.archive => tr.conversationsActionArchiveFailed,
    ConversationsAction.unarchive => tr.conversationsActionUnarchiveFailed,
    ConversationsAction.delete => tr.conversationsActionDeleteFailed,
    ConversationsAction.stop => tr.conversationsActionStopFailed,
    ConversationsAction.share => tr.conversationsActionShareFailed,
  };
}

String _toastMessage(AppStrings tr, ConversationsToast toast) {
  return switch (toast) {
    ConversationsToast.conversationCreated => tr.conversationCreatedToast,
    ConversationsToast.conversationRenamed => tr.conversationRenamedToast,
    ConversationsToast.conversationArchived => tr.conversationArchivedToast,
    ConversationsToast.conversationUnarchived => tr.conversationUnarchivedToast,
    ConversationsToast.conversationDeleted => tr.conversationDeletedToast,
    ConversationsToast.conversationStopped => tr.conversationStoppedToast,
  };
}
