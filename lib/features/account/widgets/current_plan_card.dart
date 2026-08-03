import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../billing/data/billing_visibility.dart';
import '../../billing/data/plan_tier_models.dart';
import '../../billing/data/plans_api.dart';
import '../../billing/view_model/plan_cubit.dart';
import 'plan_badge.dart';

/// Account "Plan" card shown when live usage isn't available yet (Gap A).
///
/// [PlanUsageCard] only renders once a conversation snapshot has populated
/// [PlanCubit] with the day/week/month usage windows — which means it stays
/// hidden on a fresh Account open before any chat is viewed. This card fills
/// that gap by reading the public `GET /api/v1/plans/` catalogue (which
/// returns `current_plan` for the authed caller) so the user always sees
/// their plan + its limits + a path to pricing, even before opening a chat.
///
/// Note: `/plans/` exposes plan *limits*, not live *usage* — so this card
/// shows the tier caps, not consumed-vs-cap bars. Live usage bars still
/// require the conversation snapshot (or a future `/auth/me/` usage field —
/// see BACKEND_REQUIREMENTS.md).
class CurrentPlanCard extends StatefulWidget {
  const CurrentPlanCard({super.key});

  @override
  State<CurrentPlanCard> createState() => _CurrentPlanCardState();
}

class _CurrentPlanCardState extends State<CurrentPlanCard> {
  late Future<PlansResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PlansApi>().list();
  }

  /// Re-issues the `/plans/` request after a failure.
  void _retry() {
    final f = context.read<PlansApi>().list();
    setState(() {
      _future = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlansResponse>(
      future: _future,
      builder: (context, snap) {
        // Errors MUST be checked before `hasData`. `!snap.hasData` is true
        // for BOTH "still loading" and "failed", so collapsing them into
        // one `SizedBox.shrink()` meant a failed /plans/ call rendered an
        // invisible widget: no spinner, no error, no retry — just a gap
        // where the plan card should be. `usage_screen` was fixed for the
        // same bug; this was the other half of that blank page.
        if (snap.hasError) {
          return _PlanCardError(
            message: ApiErrorMapper.message(context, snap.error),
            onRetry: _retry,
          );
        }
        // Staying invisible while LOADING is still right — this is a
        // secondary card on the account screen, and a spinner that flashes
        // for 200 ms is noisier than the card simply appearing.
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!;
        final slug = data.currentPlan ??
            context.read<PlanCubit>().state?.slug ??
            'free';
        final tier = _tierFor(data.plans, slug);
        if (tier == null) return const SizedBox.shrink();
        return _PlanCardBody(tier: tier);
      },
    );
  }

  PlanTier? _tierFor(List<PlanTier> tiers, String slug) {
    for (final t in tiers) {
      if (t.slug == slug) return t;
    }
    return tiers.isNotEmpty ? tiers.first : null;
  }
}

/// Failure state for the plan card.
///
/// Deliberately the same [GlassCard] shell as [_PlanCardBody] so the card
/// keeps its place in the account layout instead of the section silently
/// collapsing — the user sees that this panel exists and could not load,
/// which is the whole point of not returning `SizedBox.shrink()` here.
class _PlanCardError extends StatelessWidget {
  const _PlanCardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return GlassCard(
      blur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr.planUsageTitle, style: context.text.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            style: context.text.bodySmall?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GhostButton(
              label: context.tr.retry,
              icon: AppIcons.refresh,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCardBody extends StatelessWidget {
  const _PlanCardBody({required this.tier});
  final PlanTier tier;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
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
                child: Text(tr.planUsageTitle, style: context.text.titleMedium),
              ),
              if (tier.showBadge) PlanBadge(name: tier.name),
            ],
          ),
          const SizedBox(height: 14),
          _CapRow(
            label: tr.pricingDailyCap,
            value: '${compactCount(tier.dailyBurstTokens, tr)} ${tr.pricingStUnit}',
          ),
          const SizedBox(height: 6),
          _CapRow(
            label: tr.pricingMonthlyCap,
            value: '${compactCount(tier.monthlyTokens, tr)} ${tr.pricingStUnit}',
          ),
          // Upgrade CTA → pricing catalogue. Hidden while sales are web-only;
          // the current plan + caps above stay (informational).
          if (showPaidUpsell) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhostButton(
                label: tr.quotaUpgradeCta,
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

class _CapRow extends StatelessWidget {
  const _CapRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
        ),
        Text(
          value,
          style: context.text.labelMedium
              ?.copyWith(color: s.text, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
