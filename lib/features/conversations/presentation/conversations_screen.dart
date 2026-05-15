import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../demo/saqqar_demo_data.dart';
import '../widgets/widgets.dart';

/// Conversations list — search + archive filter + paginated rows, with a
/// gradient FAB to start a fresh chat.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  static const _pageSize = 30;
  static const _initialLoadDelay = Duration(milliseconds: 650);

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _query = '';
  bool _showArchived = false;
  int _pageIndex = 0;
  bool _loading = true;
  Timer? _loadingTimer;

  List<DemoConversation> get _filtered {
    final q = _query.trim().toLowerCase();
    return demoConversations.where((conversation) {
      if (!_showArchived && conversation.isArchived) return false;
      if (q.isEmpty) return true;
      return conversation.title.toLowerCase().contains(q) ||
          conversation.preview.toLowerCase().contains(q) ||
          conversation.activeCredential.toLowerCase().contains(q);
    }).toList();
  }

  List<DemoConversation> get _paged {
    final start = _pageIndex * _pageSize;
    return _filtered.skip(start).take(_pageSize).toList();
  }

  int get _pageCount {
    final total = _filtered.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Simulate the initial fetch round-trip so the skeleton briefly shows.
    // Replace with the real API call when the conversations endpoint lands.
    _loadingTimer = Timer(_initialLoadDelay, () {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _filtered.length <= _pageSize) {
      return;
    }
    if (_scrollController.position.extentAfter <= 120 &&
        _pageIndex < _pageCount - 1) {
      _goToPage(_pageIndex + 1);
    }
  }

  void _resetPagination() {
    _pageIndex = 0;
  }

  void _goToPage(int pageIndex) {
    final next = pageIndex.clamp(0, _pageCount - 1);
    if (next == _pageIndex) return;

    setState(() => _pageIndex = next);
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _openFreshConversation() {
    context.go(RouteNames.chatPath(UiStrings.routeNewConversation));
  }

  void _toast(BuildContext context, String text) {
    AppToast.show(context, message: text);
  }

  /// Walks the paged conversations and inserts a [SectionHeader] each time
  /// the date bucket changes ("Today", "Yesterday", "Previous 7 days",
  /// "Older"). Archived conversations always render under "Older". Matches
  /// the web's conversation grouping.
  List<Widget> _buildGroupedRows(List<DemoConversation> rows) {
    final widgets = <Widget>[];
    String? currentGroup;
    for (final entry in rows.asMap().entries) {
      final c = entry.value;
      final group = c.isArchived ? context.tr.dateGroupOlder : _dateGroupKey(c);
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
          key: ValueKey(c.id),
          index: entry.key,
          child: ConversationCard(
            conversation: c,
            onTap: () => context.go(RouteNames.chatPath(c.id)),
            onAction: (action) => _toast(
              context,
              context.tr.actionOnConversation(
                conversationActionLabel(context, action),
                c.title,
              ),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  /// Buckets a conversation into the web's date groups. Reads the existing
  /// pre-computed `updatedLabel` (the API will replace this with a real
  /// timestamp later). Conversations carrying month-day labels (e.g.
  /// "May 9") fall into "Previous 7 days" since the seed only spans this
  /// week; once real timestamps are wired the boundary moves to 7/30 days.
  String _dateGroupKey(DemoConversation c) {
    final l = c.updatedLabel.toLowerCase();
    if (l == 'today' || l == 'now' || l == 'الآن' || l == 'اليوم') {
      return context.tr.dateGroupToday;
    }
    if (l == 'yesterday' || l == 'أمس') {
      return context.tr.dateGroupYesterday;
    }
    if (l == 'older' || l == 'الأقدم') {
      return context.tr.dateGroupOlder;
    }
    return context.tr.dateGroupPrevious7;
  }

  @override
  Widget build(BuildContext context) {
    final allConversations = _filtered;
    final conversations = _paged;

    return PageScaffold(
      title: context.tr.tabChats,
      controller: _scrollController,
      onRefresh: () async {
        // Wipe the list and surface skeletons while the refetch runs, then
        // restore once the (simulated) API returns. Real wiring stays the
        // same shape once the conversations endpoint lands.
        setState(() => _loading = true);
        final message = context.tr.conversationsRefreshed;
        await Future<void>.delayed(const Duration(milliseconds: 750));
        if (!mounted) return;
        setState(() => _loading = false);
        if (!context.mounted) return;
        AppToast.show(context, message: message);
      },
      actions: [
        AppIconButton(
          icon: AppIcons.refresh,
          tooltip: context.tr.refreshConversations,
          bordered: false,
          onPressed: () => _toast(context, context.tr.conversationsRefreshed),
        ),
        const SizedBox(width: 6),
      ],
      floatingActionButton: GradientFab(
        onPressed: _openFreshConversation,
        label: context.tr.newConversation,
      ),
      children: [
        SearchAndFiltersBar<bool>(
          controller: _searchController,
          hintText: context.tr.searchConversations,
          query: _query,
          onQueryChanged: (value) => setState(() {
            _query = value;
            _resetPagination();
          }),
          selectedFilter: _showArchived ? true : null,
          filters: [
            SearchFilterOption(value: true, label: context.tr.archived),
          ],
          onFilterSelected: (_) => setState(() {
            _showArchived = !_showArchived;
            _resetPagination();
          }),
        ),
        const SizedBox(height: 12),
        if (allConversations.length > _pageSize) ...[
          PaginationBar(
            page: _pageIndex + 1,
            pageCount: _pageCount,
            visibleCount: conversations.length,
            totalCount: allConversations.length,
            itemLabel: context.tr.conversations,
            onPrevious: _pageIndex == 0
                ? null
                : () => _goToPage(_pageIndex - 1),
            onNext: _pageIndex >= _pageCount - 1
                ? null
                : () => _goToPage(_pageIndex + 1),
          ),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _loading
              ? const Column(
                  key: ValueKey('conversations-skeleton'),
                  children: [
                    ConversationCardSkeleton(),
                    SizedBox(height: 10),
                    ConversationCardSkeleton(),
                    SizedBox(height: 10),
                    ConversationCardSkeleton(),
                    SizedBox(height: 10),
                    ConversationCardSkeleton(),
                  ],
                )
              : allConversations.isEmpty
              ? ConversationsEmptyState(
                  key: const ValueKey('empty-conversations'),
                  onStart: _openFreshConversation,
                )
              : Column(
                  key: ValueKey(
                    'conversation-list-$_query-$_showArchived'
                    '-${conversations.length}',
                  ),
                  children: _buildGroupedRows(conversations),
                ),
        ),
      ],
    );
  }
}
