import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../billing/data/billing_visibility.dart';
import '../../billing/data/plan_copy.dart';
import '../../billing/data/plan_tier_models.dart';
import '../../billing/data/plans_api.dart';
import '../../billing/view_model/plan_cubit.dart';
import '../../billing/widgets/plan_feature_line.dart';
import 'plan_badge.dart';
import '../../../core/theme/app_sizes.dart';

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
          const SizedBox(height: AppSpacing.s8),
          Text(
            message,
            style: context.text.bodySmall?.copyWith(color: s.muted),
          ),
          const SizedBox(height: AppSpacing.s12),
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
    // The same copy the pricing catalogue draws, so the two screens describe
    // one plan the same way. What used to be here — the daily and monthly
    // token caps quoted in "ST" — was the card describing the API instead of
    // the product: the figures were real, but "ST" is a unit that appears
    // nowhere on saqqaar.com and answers nothing a customer asked.
    //
    // Both screens now read it off the tier the server sent, so "the same
    // copy" is a fact rather than a convention two files have to keep.
    final tagline = PlanCopy.translate(tr, tier.tagline);
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
              if (tier.showBadge)
                PlanBadge(
                  name: PlanCopy.nameFor(
                    tr,
                    slug: tier.slug,
                    fallback: tier.name,
                  ),
                ),
            ],
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              tagline,
              style: context.text.bodySmall
                  ?.copyWith(color: context.saqqar.muted),
            ),
          ],
          if (tier.featuresText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s10),
            for (final bullet in tier.featuresText)
              PlanFeatureLine(label: PlanCopy.translate(tr, bullet)),
          ],
          // Upgrade CTA → pricing catalogue. Hidden while sales are web-only;
          // the current plan and what it includes stay (informational).
          if (showPaidUpsell) ...[
            const SizedBox(height: AppSpacing.s14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GhostButton(
                label: tr.quotaUpgradeCta,
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
