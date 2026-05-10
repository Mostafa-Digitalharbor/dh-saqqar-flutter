import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/feature_intro_card.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/search_and_filters_bar.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../demo/saqqar_demo_data.dart';

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
  bool _showArchived = false;
  int _pageIndex = 0;

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
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final allConversations = _filtered;
    final conversations = _paged;

    return PageScaffold(
      title: context.tr.tabChats,
      controller: _scrollController,
      onRefresh: () async {
        final message = context.tr.conversationsRefreshed;
        await Future<void>.delayed(const Duration(milliseconds: 700));
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
      floatingActionButton: _GradientFab(
        onPressed: _openFreshConversation,
        label: context.tr.newConversation,
      ),
      children: [
        _WorkspaceSummary(onNew: _openFreshConversation),
        const SizedBox(height: 16),
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
          child: allConversations.isEmpty
              ? EmptyState(
                  key: const ValueKey('empty-conversations'),
                  icon: AppIcons.chats,
                  title: context.tr.noConversations,
                  body: context.tr.noConversationsHint,
                )
              : Column(
                  key: ValueKey(
                    'conversation-list-$_query-$_showArchived-${conversations.length}',
                  ),
                  children: [
                    for (final entry in conversations.asMap().entries) ...[
                      FadeSlideIn(
                        key: ValueKey(entry.value.id),
                        index: entry.key,
                        child: _ConversationCard(
                          conversation: entry.value,
                          onTap: () =>
                              context.go(RouteNames.chatPath(entry.value.id)),
                          onAction: (action) => _toast(
                            context,
                            context.tr.actionOnConversation(
                              _conversationActionLabel(context, action),
                              entry.value.title,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _openFreshConversation() {
    context.go(RouteNames.chatPath(UiStrings.routeNewConversation));
  }

  void _toast(BuildContext context, String text) {
    AppToast.show(context, message: text);
  }
}

class _WorkspaceSummary extends StatelessWidget {
  const _WorkspaceSummary({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return FeatureIntroCard(
      title: context.tr.workspaceSummaryTitle,
      body: context.tr.workspaceSummaryBody,
      pills: [
        StatusPill(label: context.tr.liveSystemsOnly, pulsing: true),
        StatusPill(label: context.tr.approvalGated),
      ],
      action: PrimaryButton(
        label: context.tr.newConversation,
        icon: AppIcons.plus,
        expand: true,
        onPressed: onNew,
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 22, 14),
          decoration: BoxDecoration(
            gradient: AppGradients.primaryCta,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: s.brandCyan.withValues(alpha: 0.36),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.plus, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ConversationAction { rename, share, archive, delete }

String _conversationActionLabel(
  BuildContext context,
  _ConversationAction action,
) {
  return switch (action) {
    _ConversationAction.rename => context.tr.rename,
    _ConversationAction.share => context.tr.shareLink,
    _ConversationAction.archive => context.tr.archive,
    _ConversationAction.delete => context.tr.delete,
  };
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
    required this.onAction,
  });

  final DemoConversation conversation;
  final VoidCallback onTap;
  final ValueChanged<_ConversationAction> onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final isArchived = conversation.isArchived;
    final hasCredential = conversation.activeCredential != 'none';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Opacity(
          opacity: isArchived ? 0.7 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            decoration: BoxDecoration(
              color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: s.cardBorder),
              boxShadow: context.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.vivid,
                    boxShadow: [
                      BoxShadow(
                        color: s.brandCyan.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    AppIcons.message,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              conversation.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            conversation.updatedLabel,
                            style: context.text.labelSmall?.copyWith(
                              color: s.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: s.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MetaDot(
                            icon: AppIcons.message,
                            text: '${conversation.messageCount}',
                            color: s.muted,
                          ),
                          if (hasCredential) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: _MetaDot(
                                icon: AppIcons.key,
                                text: conversation.activeCredential,
                                color: s.brandCyan,
                              ),
                            ),
                          ],
                          if (isArchived) ...[
                            const SizedBox(width: 10),
                            MiniChip(context.tr.archived, color: s.warning),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _RowMenu(onAction: onAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.onAction});

  final ValueChanged<_ConversationAction> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ConversationAction>(
      tooltip: context.tr.conversationActions,
      icon: Icon(AppIcons.more, color: context.saqqar.muted, size: 20),
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ConversationAction.rename,
          child: _MenuRow(icon: AppIcons.edit, label: context.tr.rename),
        ),
        PopupMenuItem(
          value: _ConversationAction.share,
          child: _MenuRow(icon: AppIcons.share, label: context.tr.shareLink),
        ),
        PopupMenuItem(
          value: _ConversationAction.archive,
          child: _MenuRow(icon: AppIcons.archive, label: context.tr.archive),
        ),
        PopupMenuItem(
          value: _ConversationAction.delete,
          child: _MenuRow(
            icon: AppIcons.trash,
            label: context.tr.delete,
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.saqqar.danger : context.saqqar.text;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
