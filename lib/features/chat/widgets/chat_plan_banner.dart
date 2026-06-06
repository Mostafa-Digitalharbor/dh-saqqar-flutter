import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../billing/data/plan_models.dart';

/// Chat banner for plan/quota state (Gap A near-limit + Gap B exceeded):
///
///   * [exceededWindow] set → red, non-dismissable "limit reached" card with
///     an upgrade CTA. The assistant message already explains it in prose;
///     this adds the actionable path.
///   * else a window ≥80% (<100%) → amber "approaching your limit" banner.
///   * else renders nothing.
///
/// Stateless and self-deciding — the chat screen always mounts it above the
/// composer and passes the latest [plan] + [exceededWindow].
class ChatPlanBanner extends StatelessWidget {
  const ChatPlanBanner({
    super.key,
    required this.plan,
    required this.exceededWindow,
    required this.onUpgrade,
  });

  final PlanSnapshot? plan;
  final QuotaWindow? exceededWindow;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;

    if (exceededWindow != null) {
      final word = tr.planWindowWord(exceededWindow!.wire);
      return _Banner(
        color: s.danger,
        icon: AppIcons.warning,
        title: tr.quotaExceededTitle,
        body: tr.quotaExceededBody(word),
        action: GhostButton(
          label: tr.quotaUpgradeCta,
          icon: AppIcons.sparkles,
          onPressed: onUpgrade,
        ),
      );
    }

    // Near-limit — only for non-exempt plans with a window in the 80–99% band.
    final near = plan?.exempt == true ? null : plan?.nearLimitWindow;
    if (near != null) {
      final wire = identical(near, plan!.day)
          ? 'day'
          : identical(near, plan!.week)
              ? 'week'
              : 'month';
      return _Banner(
        color: s.warning,
        icon: AppIcons.warning,
        title: tr.planNearLimitTitle,
        body: tr.planNearLimitBody(tr.planWindowWord(wire), near.pct),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: context.text.bodySmall?.copyWith(color: s.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: action!),
          ],
        ],
      ),
    );
  }
}
