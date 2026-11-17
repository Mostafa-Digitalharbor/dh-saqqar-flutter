part of 'conversations_screen.dart';

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
    required this.view,
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

  /// The list, already sliced. Passed as a VALUE, not as the callbacks that
  /// produce it — handing down `filter`/`archived` meant this widget re-ran
  /// the same derivation its parent had just run.
  final ChatsListView view;
  final Future<void> Function(ConversationSummary, ConversationAction)
  onRowAction;

  @override
  Widget build(BuildContext context) {
    final filtered = view.active;
    final archivedRows = view.archived;
    final pageCount = view.pageCount(pageSize);
    final paged = view.page(pageIndex, pageSize);
    // Counted in the same pass that produced the rows, so the chip badge and
    // what tapping it reveals cannot disagree.
    final pendingTotal = view.pendingCount;

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
    final fg = active ? AppColors.onBrand : s.muted;
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
          border: Border.all(color: active ? Colors.transparent : s.border),
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
                constraints: const BoxConstraints(
                  minWidth: AppControlSizes.badgeMinWide,
                ),
                height: AppControlSizes.badgeHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.onBrand.withValues(alpha: AppAlphas.a25)
                      : (warn
                            ? s.warning.withValues(alpha: AppAlphas.a20)
                            : s.surface3),
                  borderRadius: AppRadius.pillR,
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    height: AppLineHeights.heading,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppColors.onBrand
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
  final Future<void> Function(ConversationSummary, ConversationAction)
  onRowAction;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2.withValues(
          alpha: context.alpha(AppAlphaPairs.panelPlain),
        ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s14,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.archive,
                    size: AppIconSizes.regular,
                    color: s.muted,
                  ),
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
                              onTap: () =>
                                  context.go(RouteNames.chatPath(c.id)),
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
