import 'package:flutter/foundation.dart';

import 'plan_models.dart';

/// A single pricing tier from `GET /api/v1/plans/` (Gap L). Caps are
/// admin-editable and may change — render them from this object, never
/// hardcode (SAQQAR_MOBILE_API §N).
///
/// **The descriptive half is new (backend fix #6, 2026-08-09).** Until then
/// the endpoint returned the commercial facts and nothing a buyer reads, so
/// the app carried its own copy of the website's wording. It no longer does:
/// [tagline], [mostPopular], [featuresIntro], [featuresText] and [priceNote]
/// come from the same server module the web pricing page renders from, which
/// is what makes the two surfaces incapable of drifting.
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
    this.tagline = '',
    this.mostPopular = false,
    this.featuresIntro = '',
    this.featuresText = const [],
    this.priceNote = '',
  });

  final String slug;
  final String name;
  final int sort;

  /// Price in cents (USD). `0` = free.
  final int priceMonthlyCents;

  /// The **per-month** price when billed annually — not the yearly total.
  /// Confirmed in writing by the backend on 2026-08-09; every figure on the
  /// pricing screen would be wrong by 12× under the other reading.
  final int priceAnnualCents;

  final int dailyTokens;
  final int dailyBurstTokens;
  final int weeklyTokens;
  final int monthlyTokens;

  /// `null` = unlimited.
  final int? maxProjects;
  final int? maxEnvsPerProject;

  /// The **entitlement booleans** (`voice`/`postgres`/`github`/`server_shell`).
  /// Deliberately a different object from [featuresText]: this one gates
  /// behaviour, that one is sales copy. The server names them apart for the
  /// same reason.
  final PlanFeatures features;

  // ── Descriptive copy ────────────────────────────────────────────────

  /// The line under the tier name — "For power users".
  final String tagline;

  /// The website's badge on the tier it pushes hardest.
  final bool mostPopular;

  /// "Everything in Solo, plus:" — the full sentence, sent whole so the app
  /// never reconstructs it from a slug. Empty on the entry tier, whose list
  /// is absolute rather than incremental.
  final String featuresIntro;

  /// The buyer-facing bullets, in the website's order.
  final List<String> featuresText;

  /// The billing-cycle line the website prints under the figure. Computed
  /// server-side from the same cents this row carries, so it cannot disagree
  /// with them. `"Free for everyone"` on the free tier, empty when the server
  /// has nothing to say.
  final String priceNote;

  bool get isFree => slug == 'free';

  /// Whether a plan-name badge should render for this tier — mirrors
  /// [PlanSnapshot.showBadge]. Free tiers get none: naming the only tier a
  /// user can have implies a paid one exists to buy. The `name.isNotEmpty`
  /// half keeps an empty server name from falling back to the raw slug.
  bool get showBadge => !isFree && name.isNotEmpty;

  factory PlanTier.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    int? nullableInt(String k) => (json[k] as num?)?.toInt();
    // The copy fields are all nullable on the wire (`features_intro` is null
    // on Free, `price_note` on a $0 non-Free tier) and this parse feeds the
    // one screen where money changes hands. A cast would throw the whole
    // catalogue away over a single field; an empty string renders as "this
    // tier says nothing here", which is the honest degradation.
    String s(String k) => json[k] is String ? json[k] as String : '';
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
      tagline: s('tagline'),
      mostPopular: json['most_popular'] as bool? ?? false,
      featuresIntro: s('features_intro'),
      // Strings only, and blanks dropped: a null in the list would render as
      // a bullet point with nothing after it.
      featuresText: [
        for (final v in (json['features_text'] as List? ?? const []))
          if (v is String && v.trim().isNotEmpty) v.trim(),
      ],
      priceNote: s('price_note'),
    );
  }
}

/// The tax rider on the catalogue, from the response's `vat` object.
///
/// Replaces a hardcoded "15% VAT is added at checkout" — a rate written into
/// the app is a number that goes stale silently on the one screen where being
/// wrong costs money.
@immutable
class VatPolicy {
  const VatPolicy({
    this.active = false,
    this.includedInPrice = false,
    this.ratePercent = 0,
  });

  final bool active;

  /// When true the figures already contain the tax, so no rider is shown.
  final bool includedInPrice;

  final double ratePercent;

  /// Whether the "+ VAT" rider and the footnote belong on screen: tax applies
  /// and it is *not* already in the price.
  bool get addedAtCheckout => active && !includedInPrice && ratePercent > 0;

  /// `15.0` → "15", `15.5` → "15.5". A rate is quoted the way the website
  /// quotes it; `.0` on a whole percentage reads as false precision.
  String get rateLabel => ratePercent == ratePercent.roundToDouble()
      ? '${ratePercent.round()}'
      : '$ratePercent';

  factory VatPolicy.fromJson(Map<String, dynamic> json) {
    return VatPolicy(
      active: json['active'] as bool? ?? false,
      includedInPrice: json['included_in_price'] as bool? ?? false,
      ratePercent: (json['rate_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Full `GET /api/v1/plans/` payload — the ordered tiers, the caller's current
/// plan slug (null when anonymous), and the VAT policy.
@immutable
class PlansResponse {
  const PlansResponse({
    required this.currentPlan,
    required this.plans,
    this.vat = const VatPolicy(),
  });

  final String? currentPlan;
  final List<PlanTier> plans;
  final VatPolicy vat;

  factory PlansResponse.fromJson(Map<String, dynamic> json) {
    final tiers = (json['plans'] as List? ?? [])
        // `whereType`, not `cast`: `cast` defers the check to iteration and
        // then throws mid-`map`, so one malformed row would empty the price
        // list. Skipping the bad row shows four tiers instead of none.
        .whereType<Map<String, dynamic>>()
        .map(PlanTier.fromJson)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return PlansResponse(
      currentPlan: json['current_plan'] as String?,
      plans: tiers,
      // Absent on a server that predates the 2026-08-09 deploy — which reads
      // as "no rider", i.e. the app stops claiming a rate nobody sent.
      vat: VatPolicy.fromJson(
        (json['vat'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}
