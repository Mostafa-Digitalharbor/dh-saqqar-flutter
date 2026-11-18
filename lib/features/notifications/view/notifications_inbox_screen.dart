import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/route_names.dart';
import '../../../shared/fig/fig.dart';
import '../data/notifications_store.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';

/// In-app notifications inbox, restyled to the Figma "Notification" frames:
/// white page, centred title, grouped rows with a category caption and a
/// purple unread marker. Swipe a row to dismiss; tap to open its chat.
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  /// Which ids were unread when the screen opened — they keep their purple
  /// marker for this visit even though everything is marked read on entry.
  Set<String> _unreadOnEntry = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<NotificationsStore>()..reload();
      setState(() {
        _unreadOnEntry = store.items
            .where((n) => !n.read)
            .map((n) => n.id)
            .toSet();
      });
      store.markAllRead();
    });
  }

  String _category(BuildContext c, AppNotification n) => switch (n.type) {
    'approval_required' => c.tr.figApprovals2,
    'run_complete' => c.tr.figAutomation,
    'artifact_ready' => c.tr.figReports,
    'quota_warning' => c.tr.figUsage,
    _ => c.tr.figInventory2,
  };

  String _ago(BuildContext c, DateTime t) => AppDateFormat.relative(c, t);

  /// Groups newest-first into Today / Earlier today / one section per day.
  List<(String, List<AppNotification>)> _group(
    BuildContext c,
    List<AppNotification> all,
  ) {
    final sorted = [...all]
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final now = DateTime.now();
    final out = <(String, List<AppNotification>)>[];
    void put(String label, AppNotification n) {
      if (out.isEmpty || out.last.$1 != label) out.add((label, []));
      out.last.$2.add(n);
    }

    for (final n in sorted) {
      final sameDay =
          n.receivedAt.year == now.year &&
          n.receivedAt.month == now.month &&
          n.receivedAt.day == now.day;
      if (sameDay) {
        final recent = now.difference(n.receivedAt).inMinutes < 30;
        put(recent ? c.tr.figToday : c.tr.figEarlierToday, n);
      } else {
        put(AppDateFormat.longDate(c, n.receivedAt), n);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotificationsStore>();
    final items = store.items;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.figWhite,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.s8),
                    SizedBox(
                      width: 52,
                      child: FigBackButton(
                        color: AppColors.figBlack,
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go(RouteNames.homePath),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          context.tr.figNotification,
                          style: Fig.t(context, size: AppFontSizes.headlineLarge, color: Fig.inkPlain),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s60),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? _Empty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s8, AppSpacing.s18, AppSpacing.s24),
                        children: [
                          for (final g in _group(context, items)) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.s14,
                                bottom: AppSpacing.s10,
                              ),
                              child: Text(
                                g.$1,
                                style: Fig.t(
                                  context,
                                  size: FigMetrics.fontFig10U5,
                                  color: Fig.mutedLight,
                                ),
                              ),
                            ),
                            for (final n in g.$2)
                              _Row(
                                n: n,
                                category: _category(context, n),
                                ago: _ago(context, n.receivedAt),
                                unread: _unreadOnEntry.contains(n.id),
                                onOpen: () {
                                  final id = n.conversationId;
                                  if (id != null && id.isNotEmpty) {
                                    context.push(RouteNames.chatPath(id));
                                  }
                                },
                                onDismiss: () => store.remove(n.id),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.n,
    required this.category,
    required this.ago,
    required this.unread,
    required this.onOpen,
    required this.onDismiss,
  });

  final AppNotification n;
  final String category;
  final String ago;
  final bool unread;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(n.id),
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: AppColors.figCFFF3F3F5,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.only(right: AppSpacing.s16),
        child: const Icon(LucideIcons.trash2, color: Fig.dangerText, size: AppIconSizes.action),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.only(
            top: AppSpacing.s8,
            bottom: AppSpacing.s14,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.figCFFEEEEF1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      n.title,
                      style: Fig.t(
                        context,
                        size: AppFontSizes.caption,
                        weight: FontWeight.w700,
                        color: Fig.inkPlain,
                      ),
                    ),
                  ),
                  Text(
                    ago,
                    style: Fig.t(context, size: FigMetrics.fontFig9, color: Fig.mutedCool),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                n.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Fig.t(
                  context,
                  size: FigMetrics.fontFig11,
                  color: Fig.mutedLight,
                  height: AppLineHeights.snug,
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: Fig.t(context, size: FigMetrics.fontFig9, color: Fig.mutedCool),
                    ),
                  ),
                  if (unread)
                    Container(
                      width: FigMetrics.size7, height: FigMetrics.size7,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.s40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AssetPaths.emptyMailbox,
              width: 150,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: AppSpacing.s18),
            Text(
              context.tr.figNoNotificationsYet,
              style: Fig.t(context, size: FigMetrics.fontFig21, color: Fig.navy),
            ),
            const SizedBox(height: AppSpacing.s10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s26),
              child: Text(
                context.tr.figNoNotificationsYetWeLlLet,
                textAlign: TextAlign.center,
                style: Fig.t(
                  context,
                  size: AppFontSizes.metaLine,
                  color: AppColors.figCFF656B80,
                  height: AppLineHeights.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
