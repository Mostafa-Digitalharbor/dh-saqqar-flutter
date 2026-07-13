import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../billing/data/billing_visibility.dart';
import '../../billing/data/plan_models.dart';
import '../../billing/view_model/plan_cubit.dart';
import 'plan_badge.dart';

/// Account "Plan & usage" card (Gap A) — mirrors the web `/usage/` view:
/// the plan name as a badge plus three usage bars (day / week / month)
/// showing `used / cap` and the server-computed percentage.
///
/// Reads [PlanCubit]; renders nothing until the first conversation snapshot
/// has populated a plan (the card simply doesn't appear on a cold account
/// open before any chat has been viewed).
class PlanUsageCard extends StatelessWidget {
  const PlanUsageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanCubit>().state;
    if (plan == null) return const SizedBox.shrink();

    final s = context.saqqar;
    return GlassCard(
      // Flat opaque Account backdrop → the backdrop blur has no visible
      // subject; dropping it removes a saveLayer with pixel-identical output.
      blur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.planUsageTitle,
                  style: context.text.titleMedium,
                ),
              ),
              PlanBadge(name: plan.name.isEmpty ? plan.slug : plan.name),
            ],
          ),
          const SizedBox(height: 16),
          if (plan.exempt)
            Text(
              context.tr.planExemptLabel,
              style: context.text.bodyMedium?.copyWith(color: s.success),
            )
          else ...[
            _UsageRow(label: context.tr.planWindowDay, window: plan.day),
            const SizedBox(height: 14),
            _UsageRow(label: context.tr.planWindowWeek, window: plan.week),
            const SizedBox(height: 14),
            _UsageRow(label: context.tr.planWindowMonth, window: plan.month),
          ],
          // Upgrade CTA → pricing catalogue. Hidden on iOS (App Store 3.1.1);
          // the usage bars above stay (informational).
          if (showPaidUpsell) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhostButton(
                label: context.tr.quotaUpgradeCta,
                icon: AppIcons.sparkles,
                minHeight: 40,
                onPressed: () => context.pushNamed(RouteNames.pricing),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.window});

  final String label;
  final UsageWindow window;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Bar tint escalates with pressure: cyan normal → amber near-limit →
    // red over. Reuses the same thresholds as the chat banner / gating.
    final Color color = window.exceeded
        ? s.danger
        : window.nearLimit
            ? s.warning
            : s.brandCyan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.text.labelLarge?.copyWith(color: s.muted),
              ),
            ),
            Text(
              context.tr.planUsageLine(
                compactCount(window.used),
                compactCount(window.cap),
              ),
              style: context.text.labelMedium?.copyWith(
                color: s.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: window.fraction,
            minHeight: 7,
            backgroundColor: s.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr.planPctUsed(window.pct),
          style: context.text.labelSmall?.copyWith(color: s.muted),
        ),
      ],
    );
  }
}
