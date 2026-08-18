import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/title_trailing_row.dart';
import '../../billing/data/billing_visibility.dart';
import '../../billing/data/plan_copy.dart';
import '../../billing/data/plan_models.dart';
import '../../billing/view_model/plan_cubit.dart';
import 'plan_badge.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';

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
              // Free accounts get no badge (PlanBadge's contract) — naming the
              // only tier that exists implies a paid one you could buy, which
              // is what App Review asked us about. The slug fallback is gone
              // too: it leaked the wire value ("free") when name came back
              // empty, which is exactly the case that must render nothing.
              //
              // `plan_name` is English on the wire, so it goes through
              // [PlanCopy.nameFor] like every other plan-name site.
              if (plan.showBadge)
                PlanBadge(
                  name: PlanCopy.nameFor(
                    context.tr,
                    slug: plan.slug,
                    fallback: plan.name,
                  ),
                ),
            ],
          ),
          // Subscription line — cycle, state, and when the period renews.
          // New in API_MOBILE_SUBSCRIPTION.md §1; the app had no way to answer
          // "when does this renew?" before it.
          //
          // Deliberately NOT a countdown. Saqqar billing is prepaid: access is
          // the token balance plus the window caps, so nothing is cut off on
          // `expires_at`. Presenting it as a deadline would be a lie the user
          // acts on.
          if (_subscriptionLine(context, plan) case final line?) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(
              line,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          if (plan.exempt)
            Text(
              context.tr.planExemptLabel,
              style: context.text.bodyMedium?.copyWith(color: s.success),
            )
          else ...[
            _UsageRow(label: context.tr.planWindowDay, window: plan.day),
            const SizedBox(height: AppSpacing.s14),
            _UsageRow(label: context.tr.planWindowWeek, window: plan.week),
            const SizedBox(height: AppSpacing.s14),
            _UsageRow(label: context.tr.planWindowMonth, window: plan.month),
          ],
          // Upgrade CTA → pricing catalogue. Hidden while sales are web-only;
          // the usage bars above stay (informational).
          if (showPaidUpsell) ...[
            const SizedBox(height: AppSpacing.s14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhostButton(
                label: context.tr.quotaUpgradeCta,
                icon: AppIcons.sparkles,
                minHeight: AppControlSizes.buttonMin,
                onPressed: () => context.pushNamed(RouteNames.pricing),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Annual · Renews on 4 Mar 2027", or whichever pieces the server sent.
///
/// Returns null when there is nothing true to say — a free or never-paid
/// account gets `status: null, cycle: null, expires_at: null`, and an empty
/// grey line under the title is worse than no line.
String? _subscriptionLine(BuildContext context, PlanSnapshot plan) {
  final tr = context.tr;
  final needsAttention = plan.status.isNotEmpty && plan.status != 'active';

  // A billing cycle with no period end is not information — it's a word.
  // Verified on production 2026-08-04: a staff account reports
  // `cycle: "monthly"` with `expires_at: null` and nothing ever purchased, so
  // rendering the cycle alone would tell that user they're on a monthly
  // billing cycle they have never been billed for.
  if (plan.expiresAt == null && !needsAttention) return null;

  return <String>[
    if (plan.cycle.isNotEmpty) tr.planCycleLabel(plan.cycle),
    // Only surfaced when it is NOT the happy path. "Active" next to a plan
    // badge is noise; "Payment overdue" is the whole message.
    if (needsAttention) tr.planStatusLabel(plan.status),
    if (plan.expiresAt != null)
      tr.planRenewsOn(AppDateFormat.date(context, plan.expiresAt!)),
  ].join(' · ');
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
        // `TitleTrailingRow`, not a bare `Row`, for the reason that widget
        // documents: a Row lays its NON-flexible children out first, against
        // an unbounded constraint, and hands `Expanded` whatever is left —
        // clamped at zero. This row had exactly that shape, and the count is
        // the wide half in Arabic ("24.5 ألف / 100 ألف" spells out the
        // thousands where English writes "K"), so at 320 px × 1.4× text the
        // count measured wider than the whole lane and the row overflowed by
        // 15 px with the label collapsed to nothing.
        //
        // The cap is raised to 0.6 rather than the default 0.45 because here
        // the trailing half is the DATA and the leading half is a fixed,
        // short label ("Today" / "هذا الشهر"). Truncating a number to protect
        // a word the user already knows is the wrong trade; this way the
        // label ellipsizes first and only in the tightest cell.
        TitleTrailingRow(
          trailingMaxFraction: AppFractions.trailingMax,
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
          trailing: Text(
            context.tr.planUsageLine(
              compactCount(window.used, context.tr),
              compactCount(window.cap, context.tr),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: context.text.labelMedium?.copyWith(
              color: s.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        ClipRRect(
          borderRadius: AppRadius.pillR,
          child: LinearProgressIndicator(
            value: window.fraction,
            minHeight: AppControlSizes.meterThick,
            backgroundColor: s.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          context.tr.planPctUsed(window.pct),
          style: context.text.labelSmall?.copyWith(color: s.muted),
        ),
      ],
    );
  }
}
