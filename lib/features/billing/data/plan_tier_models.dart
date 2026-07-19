import 'package:flutter/foundation.dart';

import 'plan_models.dart';

/// A single pricing tier from `GET /api/v1/plans/` (Gap L). Caps are
/// admin-editable and may change — render them from this object, never
/// hardcode (SAQQAR_MOBILE_API §N).
@immutable
class PlanTier {
  const PlanTier({
    required this.slug,
    required this.name,
    required this.sort,
    required this.priceMonthlyCents,
    required this.priceAnnualCents,
    required this.dailyTokens,
    required this.dailyBurstTokens,
    required this.weeklyTokens,
    required this.monthlyTokens,
    required this.maxProjects,
    required this.maxEnvsPerProject,
    required this.features,
  });

  final String slug;
  final String name;
  final int sort;

  /// Price in cents (USD). `0` = free.
  final int priceMonthlyCents;
  final int priceAnnualCents;

  final int dailyTokens;
  final int dailyBurstTokens;
  final int weeklyTokens;
  final int monthlyTokens;

  /// `null` = unlimited.
  final int? maxProjects;
  final int? maxEnvsPerProject;

  final PlanFeatures features;

  bool get isFree => slug == 'free';

  /// Whether a plan-name badge should render for this tier — mirrors
  /// [PlanSnapshot.showBadge]. Free tiers get none: naming the only tier a
  /// user can have implies a paid one exists to buy. The `name.isNotEmpty`
  /// half keeps an empty server name from falling back to the raw slug.
  bool get showBadge => !isFree && name.isNotEmpty;

  factory PlanTier.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    int? nullableInt(String k) => (json[k] as num?)?.toInt();
    return PlanTier(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sort: i('sort'),
      priceMonthlyCents: i('price_monthly_cents'),
      priceAnnualCents: i('price_annual_cents'),
      dailyTokens: i('daily_tokens'),
      dailyBurstTokens: i('daily_burst_tokens'),
      weeklyTokens: i('weekly_tokens'),
      monthlyTokens: i('monthly_tokens'),
      maxProjects: nullableInt('max_projects'),
      maxEnvsPerProject: nullableInt('max_envs_per_project'),
      features: PlanFeatures.fromJson(
        (json['features'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

/// Full `GET /api/v1/plans/` payload — the ordered tiers plus the caller's
/// current plan slug (null when anonymous).
@immutable
class PlansResponse {
  const PlansResponse({required this.currentPlan, required this.plans});

  final String? currentPlan;
  final List<PlanTier> plans;

  factory PlansResponse.fromJson(Map<String, dynamic> json) {
    final tiers = (json['plans'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(PlanTier.fromJson)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return PlansResponse(
      currentPlan: json['current_plan'] as String?,
      plans: tiers,
    );
  }
}
