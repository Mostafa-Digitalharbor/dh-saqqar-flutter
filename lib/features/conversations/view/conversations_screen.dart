import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/data_state_refreshable_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../inbox/view_model/approvals_cubit.dart';
import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import '../view_model/conversations_state.dart';
import '../widgets/rename_conversation_dialog.dart';
import '../widgets/swipe_archive_background.dart';
import '../widgets/widgets.dart';

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

class _ConversationsScreenState extends State<ConversationsScreen> {
  static const _pageSize = 30;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _query = '';
  /// Whether the "Archived conversations" collapsible card is open.
  /// Reset to false after every archive/unarchive action so the user
  /// always lands back on the active list — the archived section is a
  /// drawer, not a persistent view.
  bool _archivedExpanded = false;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final cubit = context.read<ConversationsCubit>();
    if (cubit.state.data.isIdle) cubit.load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Pagination ──────────────────────────────────────────────────────

  void _onScroll() {
    final data = context.read<ConversationsCubit>().state.data.dataOrNull;
    if (data == null) return;
    final filtered = _filter(data);
    if (!_scrollController.hasClients || filtered.length <= _pageSize) return;
    final pageCount = _pageCountFor(filtered.length);
    if (_scrollController.position.extentAfter <= 120 &&
        _pageIndex < pageCount - 1) {
      _goToPage(_pageIndex + 1);
    }
  }

  void _resetPagination() => _pageIndex = 0;

  void _goToPage(int pageIndex) {
    final data = context.read<ConversationsCubit>().state.data.dataOrNull;
    final pageCount =
        data == null ? 1 : _pageCountFor(_filter(data).length);
    final next = pageIndex.clamp(0, pageCount - 1);
    if (next == _pageIndex) return;
    setState(() => _pageIndex = next);
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
      duration: const Duration(milliseconds: 380),
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
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.lastMessagePreview.toLowerCase().contains(q);
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
        await cubit.deleteConversation(c.id);
      case ConversationAction.share:
        // Share goes through ChatRepository (per-chat share/revoke).
        // The chat screen owns the share UI; row-level share is deferred.
        AppToast.show(context, message: context.tr.comingSoonToast);
    }
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
    for (final entry in rows.asMap().entries) {
      final c = entry.value;
      final group = _dateGroupKey(context, c);
      if (group != currentGroup) {
        if (currentGroup != null) widgets.add(const SizedBox(height: 16));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionHeader(title: group),
          ),
        );
        currentGroup = group;
      }
      widgets.add(
        FadeSlideIn(
          // Two keys are nested here on purpose. The outer `ValueKey`
          // identifies the FadeSlideIn slot in its parent Column so the
          // intro animation only fires for genuinely new rows. The
          // inner `Dismissible` needs its OWN unique key because the
          // Dismissible widget tracks gesture state per-key and asserts
          // on duplicates.
          key: ValueKey('fade-${c.id}'),
          index: entry.key,
          child: Dismissible(
            key: ValueKey('dismiss-${c.id}'),
            // Swipe in either horizontal direction archives /
            // unarchives. We don't want one of the two directions to
            // accidentally `delete` — that would punish a misread
            // gesture. Both edges resolve to the same action.
            direction: DismissDirection.horizontal,
            background: SwipeArchiveBackground(
              alignment: AlignmentDirectional.centerStart,
              archived: c.isArchived,
            ),
            secondaryBackground: SwipeArchiveBackground(
              alignment: AlignmentDirectional.centerEnd,
              archived: c.isArchived,
            ),
            // Return false so Dismissible doesn't actually unmount the
            // row — the cubit's optimistic update already drives the
            // visual state (archived rows move to the Archived bucket
            // or back to the active list). Returning true would cause
            // a duplicate animation + a "key reused" assert on the next
            // emit. The action callback fires regardless.
            confirmDismiss: (_) async {
              onRowActionFromBuild(c, ConversationAction.archive);
              return false;
            },
            child: ConversationCard(
              conversation: c,
              onTap: () => context.go(RouteNames.chatPath(c.id)),
              onAction: (action) => _handleRowAction(c, action),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
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
      builder: (context, state) {
        final pendingCount = context.select<ApprovalsCubit, int>(
          (cubit) => cubit.state.pendingCount,
        );
        final data = state.data.dataOrNull;
        final totalCount = data == null ? 0 : _filter(data).length;
        final subtitleText = pendingCount > 0
            ? '$totalCount ${context.tr.conversations} · '
                '$pendingCount ${context.tr.pending}'
            : '$totalCount ${context.tr.conversations}';

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
            const SizedBox(width: 6),
          ],
          floatingActionButton: GradientFab(
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
                  SizedBox(height: 10),
                  ConversationCardSkeleton(),
                  SizedBox(height: 10),
                  ConversationCardSkeleton(),
                  SizedBox(height: 10),
                  ConversationCardSkeleton(),
                  SizedBox(height: 10),
                  ConversationCardSkeleton(),
                ],
              ),
              onData: (context, data) => _ConversationsBody(
                data: data,
                query: _query,
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

    return Column(
      children: [
        SearchAndFiltersBar<Never>(
          controller: searchController,
          hintText: context.tr.searchConversations,
          query: query,
          onQueryChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
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
          const SizedBox(height: 12),
        ],
        if (filtered.length > pageSize) ...[
          PaginationBar(
            page: pageIndex + 1,
            pageCount: pageCount,
            visibleCount: paged.length,
            totalCount: filtered.length,
            itemLabel: context.tr.conversations,
            onPrevious: pageIndex == 0 ? null : () => onGoToPage(pageIndex - 1),
            onNext: pageIndex >= pageCount - 1
                ? null
                : () => onGoToPage(pageIndex + 1),
          ),
          const SizedBox(height: 12),
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
        else if (filtered.isNotEmpty)
          Column(
            key: ValueKey('conversation-list-$query-${paged.length}'),
            children: buildGroupedRows(paged),
          ),
      ],
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(AppIcons.archive, size: 18, color: s.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${context.tr.archived} (${archived.length})',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      turns: expanded ? 0.5 : 0,
                      child: Icon(
                        AppIcons.chevronDown,
                        size: 20,
                        color: s.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                      const SizedBox(height: 8),
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
