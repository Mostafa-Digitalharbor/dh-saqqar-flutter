import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/chip_strip.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/notifications_store.dart';

/// Notification type filter for the inbox chip row.
enum _NotifFilter { all, approvals, tasks, reports }

/// In-app notifications inbox — every push the user received, kept so they can
/// review notifications the OS shade has since cleared. Opened from the header
/// bell. Filter by type, grouped by day, swipe a row to dismiss, tap to open
/// its conversation.
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  _NotifFilter _filter = _NotifFilter.all;

  @override
  void initState() {
    super.initState();
    // Pull in anything the FCM background isolate wrote while we were away,
    // then mark everything read now that the user is looking at the inbox.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<NotificationsStore>()..reload();
      store.markAllRead();
    });
  }

  bool _matches(_NotifFilter f, AppNotification n) => switch (f) {
        _NotifFilter.all => true,
        _NotifFilter.approvals => n.type == 'approval_required',
        _NotifFilter.tasks => n.type == 'run_complete',
        _NotifFilter.reports => n.type == 'artifact_ready',
      };

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final store = context.watch<NotificationsStore>();
    final all = store.items;
    final items = all.where((n) => _matches(_filter, n)).toList();

    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(
        title: Text(tr.notifications),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: tr.notificationsClear,
              icon: const Icon(AppIcons.trash),
              onPressed: () => context.read<NotificationsStore>().clear(),
            ),
        ],
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            if (all.isNotEmpty) _FilterRow(
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: AppIcons.bell,
                        title: tr.notificationsEmptyTitle,
                        body: tr.notificationsEmptyBody,
                      ),
                    )
                  : _GroupedList(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

/// Type-filter chip row.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final _NotifFilter selected;
  final ValueChanged<_NotifFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final entries = <(_NotifFilter, String)>[
      (_NotifFilter.all, tr.notifFilterAll),
      (_NotifFilter.approvals, tr.notifFilterApprovals),
      (_NotifFilter.tasks, tr.notifFilterTasks),
      (_NotifFilter.reports, tr.notifFilterReports),
    ];
    // Sizes to the chips rather than pinning `height: 52`, which clipped
    // Arabic descenders at large text scales with no overflow warning.
    return ChipStrip(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      children: [
        for (final (value, label) in entries)
          _FilterChip(
            label: label,
            selected: value == selected,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.pillR,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? s.brandCyan.withValues(alpha: 0.16)
                : s.cardBg,
            borderRadius: AppRadius.pillR,
            border: Border.all(
              color: selected
                  ? s.brandCyan.withValues(alpha: 0.45)
                  : s.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: selected ? s.brandCyan : s.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// The list, split into Today / Yesterday / Earlier sections.
class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // Build [header, item, item, header, item, …] rows preserving order
    // (items are already newest-first).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String bucket(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(today)) return tr.notifGroupToday;
      if (!day.isBefore(yesterday)) return tr.notifGroupYesterday;
      return tr.notifGroupEarlier;
    }

    final rows = <Widget>[];
    String? lastBucket;
    for (final n in items) {
      final b = bucket(n.receivedAt);
      if (b != lastBucket) {
        rows.add(_SectionHeader(label: b));
        lastBucket = b;
      }
      rows.add(_DismissibleTile(item: n));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: rows,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 14, 4, 6),
      child: Text(
        label,
        style: context.text.labelMedium?.copyWith(
          color: s.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DismissibleTile extends StatelessWidget {
  const _DismissibleTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('notif-${item.id}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) =>
            context.read<NotificationsStore>().remove(item.id),
        background: _swipeBg(context, AlignmentDirectional.centerStart),
        secondaryBackground: _swipeBg(context, AlignmentDirectional.centerEnd),
        child: _NotificationTile(item: item),
      ),
    );
  }

  Widget _swipeBg(BuildContext context, AlignmentGeometry align) {
    final s = context.saqqar;
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: s.danger.withValues(alpha: 0.14),
        borderRadius: AppRadius.cardR,
      ),
      child: Icon(AppIcons.trash, color: s.danger, size: 20),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  ({IconData icon, Color color}) _accent(BuildContext context) {
    final s = context.saqqar;
    return switch (item.type) {
      'approval_required' => (icon: AppIcons.shieldAlert, color: s.warning),
      'artifact_ready' => (icon: AppIcons.fileText, color: s.brandCyan),
      'quota_warning' => (icon: AppIcons.shieldAlert, color: s.danger),
      _ => (icon: AppIcons.bell, color: s.brandCyan),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = _accent(context);
    final convId = item.conversationId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.cardR,
        onTap: convId == null || convId.isEmpty
            ? null
            : () => context.go(RouteNames.chatPath(convId)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.read
                ? s.cardBg
                : Color.alphaBlend(
                    accent.color.withValues(alpha: 0.06), s.cardBg),
            borderRadius: AppRadius.cardR,
            border: Border.all(
              color: item.read
                  ? s.cardBorder
                  : accent.color.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColoredIconBox(icon: accent.icon, color: accent.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppDateFormat.relative(context, item.receivedAt),
                          style:
                              context.text.labelSmall?.copyWith(color: s.muted),
                        ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: s.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
