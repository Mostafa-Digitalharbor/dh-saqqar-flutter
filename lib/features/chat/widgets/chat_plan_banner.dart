import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/accent_banner.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../billing/data/billing_visibility.dart';
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
      // While sales are web-only the banner states the limit and stops there:
      // no "upgrade your plan" nudge, no CTA into the tier catalogue. Nudging
      // toward a purchase the app can't complete is worse than saying nothing,
      // and the window reset is the honest way out either way.
      return AccentBanner(
        color: s.danger,
        icon: AppIcons.warning,
        title: tr.quotaExceededTitle,
        body: showPaidUpsell
            ? tr.quotaExceededBody(word)
            : tr.quotaExceededBodyPlain(word),
        action: showPaidUpsell
            ? GhostButton(
                label: tr.quotaUpgradeCta,
                icon: AppIcons.sparkles,
                onPressed: onUpgrade,
              )
            : null,
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
      return AccentBanner(
        color: s.warning,
        icon: AppIcons.warning,
        title: tr.planNearLimitTitle,
        body: tr.planNearLimitBody(tr.planWindowWord(wire), near.pct),
      );
    }

    return const SizedBox.shrink();
  }
}

