import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/fig/fig.dart';
import '../data/billing_visibility.dart';
import '../data/plan_copy.dart';
import '../data/plan_tier_models.dart';
import '../data/plans_api.dart';
import '../data/web_checkout.dart';
import '../view_model/plan_cubit.dart';
import '../widgets/plan_feature_line.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../core/theme/app_colors.dart';

/// Pricing screen (Gap L) — renders the live tiers from `GET /api/v1/plans/`,
/// marks the caller's current tier, and hands off to saqqaar.com to subscribe.
///
/// **The app never takes a payment.** Paymob is live on the website; tapping a
/// tier opens `/pricing/?plan=<slug>` in the external browser. When the
/// subscription goes through, the next `/usage/` poll brings the new plan back
/// — there is no payment state to track on this side. See [WebCheckout] for
/// why the hand-off is a URL rather than a checkout round-trip, and
/// [showPaidUpsell] for the store-policy switch that hides all of it.
///
/// Mirrors saqqaar.com/pricing: the same five tiers in the same order, the
/// same monthly/annual switch, the same VAT note. A user who compares the two
/// should not have to wonder whether they're looking at the same product.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen>
    with WidgetsBindingObserver {
  late Future<PlansResponse> _future;

  /// Annual by default, matching the website's own default. It is also the
  /// cheaper of the two per month, so defaulting to monthly would quote every
  /// tier at up to double its best price.
  bool _annual = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = context.read<PlansApi>().list();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the browser is the only signal we get that a
    // subscription may have completed — there is no callback and the app
    // holds no payment reference. Re-reading `/plans/` moves the "Current
    // plan" ring onto the tier they just bought; without it the screen still
    // offers to sell them the plan they are now on.
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    if (!mounted) return;
    // A BLOCK body, not an arrow. `setState(() => _future = …)` returns the
    // value of the assignment — which here is a `Future` — and `setState`
    // asserts against exactly that, because a closure returning a Future is
    // almost always someone doing async work inside it.
    //
    // Here the assignment was correct and only the *shape* was wrong, so the
    // screen still reloaded. What it also did was throw on every resume in
    // debug and profile, and — once Sentry's error bridge was wired — report
    // itself as an app error. Caught on a real device coming back from the
    // browser, which is the one path this method exists for.
    setState(() {
      _future = context.read<PlansApi>().list();
    });
  }

  /// Which button is mid-hand-off, so it can show a spinner. Holds the tier
  /// slug, or `''` for the footer "manage on the web" button — no tier has an
  /// empty slug, so the two can't collide. Resolving the login hand-off is a
  /// round-trip; a button that looks inert for a few hundred milliseconds gets
  /// tapped twice.
  String? _opening;

  /// Opens saqqaar.com — a tier's page for [slug], or the plain catalogue when
  /// it's empty. **This is the only thing the app does about payment.** It
  /// mints a one-time login hand-off so the browser lands signed in, launches
  /// it, and stops. No order, no reference, no state to reconcile.
  Future<void> _openWeb(String slug) async {
    if (_opening != null) return;
    setState(() => _opening = slug);
    final result = await WebCheckout.open(context.read<Dio>(), slug: slug);
    if (!mounted) return;
    setState(() => _opening = null);

    final tr = context.tr;
    final target = result.target;

    // Four outcomes, four different things worth saying. The one that used to
    // be silent — "we couldn't sign you in, so the page will ask you to" — is
    // the one that made this look broken: you tap Subscribe as a signed-in
    // user and land on a login form with no explanation.
    // Tone is decided in the same branch as the wording: three of these are
    // real failures, one is a heads-up. Deriving it afterwards would mean
    // re-testing the same conditions and risking the two drifting apart.
    final String? message;
    final ToastVariant variant;
    if (target.blocking) {
      // Never launched: no connection, or the session ended. The failure text
      // is the real reason, so use it rather than a generic line.
      message = ApiErrorMapper.messageForLocale(tr, target.failure);
      variant = ToastVariant.error;
    } else if (!result.launched) {
      message = tr.pricingOpenFailed;
      variant = ToastVariant.error;
    } else if (target.failure != null) {
      // Opened, but on the plain page AND something actually went wrong.
      message =
          '${ApiErrorMapper.messageForLocale(tr, target.failure)} '
          '${tr.pricingWebSignInNote}';
      variant = ToastVariant.error;
    } else if (!target.signedIn) {
      // Opened on the plain page because the server offers no hand-off. Not
      // an error — just a heads-up so the sign-in form isn't a surprise.
      message = tr.pricingWebSignInNote;
      variant = ToastVariant.info;
    } else {
      message = null;
      variant = ToastVariant.info;
    }

    if (message != null) {
      AppToast.show(
        context,
        message: message,
        variant: variant,
        duration: AppDurations.toastDwellError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: SafeArea(
            bottom: false,
            child: FutureBuilder<PlansResponse>(
              future: _future,
              builder: (context, snap) {
                final header = FigPageHeader(
                  eyebrow: context.tr.figBilling,
                  title: tr.pricingTitle,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(RouteNames.homePath),
                );
                if (snap.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: [
                      header,
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  return Column(
                    children: [
                      header,
                      Expanded(
                        child: AppErrorState(
                          title: context.tr.pricingLoadError,
                          message: ApiErrorMapper.message(context, snap.error),
                          onRetry: _reload,
                        ),
                      ),
                    ],
                  );
                }
                final data = snap.data!;
                final current =
                    data.currentPlan ?? context.read<PlanCubit>().state?.slug;
                final currentSort = current == null
                    ? null
                    : data.plans
                          .where((p) => p.slug == current)
                          .map((p) => p.sort)
                          .firstOrNull;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.s32),
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.s14),
                    if (showPaidUpsell) ...[
                      Center(
                        child: _CycleSwitch(
                          annual: _annual,
                          onChanged: (v) => setState(() => _annual = v),
                        ),
                      ),
                      if (data.vat.addedAtCheckout)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s8),
                          child: Text(
                            tr.pricingVatNote(data.vat.rateLabel),
                            textAlign: TextAlign.center,
                            style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.muted),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.s14),
                    ] else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.s14),
                        child: Text(
                          tr.pricingSubtitle,
                          style: Fig.t(context, size: AppFontSizes.microCaps, color: Fig.muted),
                        ),
                      ),
                    for (final tier in data.plans) ...[
                      _PlanTierCard(
                        tier: tier,
                        annual: _annual,
                        vat: data.vat,
                        isCurrent: tier.slug == current,
                        sellable:
                            currentSort == null || tier.sort > currentSort,
                        opening: _opening == tier.slug,
                        onSubscribe: () => _openWeb(tier.slug),
                      ),
                      const SizedBox(height: AppSpacing.s14),
                    ],
                    if (showPaidUpsell) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                        ),
                        child: FigButton(
                          label: tr.pricingManageCta,
                          secondary: true,
                          height: 48,
                          fontSize: AppFontSizes.dense,
                          loading: _opening == '',
                          onPressed: () => _openWeb(''),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s14),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                      ),
                      child: Text(
                        showPaidUpsell
                            ? tr.pricingWebNote
                            : tr.pricingManagedOnWeb,
                        textAlign: TextAlign.center,
                        style: Fig.t(
                          context,
                          size: FigMetrics.fontFig11,
                          color: Fig.muted,
                          height: AppLineHeights.compact,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Monthly / Annually pill switch.
class _CycleSwitch extends StatelessWidget {
  const _CycleSwitch({required this.annual, required this.onChanged});

  final bool annual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    Widget seg(String label, bool active, VoidCallback onTap) => Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.control,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Fig.blue : AppColors.figCFFE5E8F2,
            borderRadius: BorderRadius.circular(FigMetrics.radFig21),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Fig.t(
              context,
              size: AppFontSizes.dense,
              color: active ? AppColors.figWhite : Fig.muted,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.figWhite,
        borderRadius: BorderRadius.circular(AppRadius.heroPlate),
        border: Border.all(color: Fig.blueStrong, width: AppBorderWidths.thick),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(tr.pricingCycleMonthly, !annual, () => onChanged(false)),
          const SizedBox(width: AppSpacing.s4),
          seg(tr.pricingCycleAnnual, annual, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _PlanTierCard extends StatelessWidget {
  const _PlanTierCard({
    required this.tier,
    required this.annual,
    required this.vat,
    required this.isCurrent,
    required this.sellable,
    required this.opening,
    required this.onSubscribe,
  });

  final PlanTier tier;
  final bool annual;
  final VatPolicy vat;
  final bool isCurrent;
  final bool sellable;
  final bool opening;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final name = PlanCopy.nameFor(
      tr,
      slug: tier.slug,
      fallback: tier.name.isEmpty ? tier.slug : tier.name,
    );
    final tagline = PlanCopy.translate(tr, tier.tagline);
    final intro = PlanCopy.translate(tr, tier.featuresIntro);
    final canBuy = showPaidUpsell && sellable && !isCurrent && !tier.isFree;
    final price = tier.isFree
        ? tr.pricingZero
        : tr.priceAmount(
            annual ? tier.priceAnnualCents : tier.priceMonthlyCents,
          );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.figWhite,
        borderRadius: BorderRadius.circular(AppRadius.navBar),
        border: isCurrent ? Border.all(color: Fig.blue, width: AppBorderWidths.medium) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (tier.mostPopular)
            Positioned(
              top: AppSpacing.sn60,
              right: AppSpacing.sn40,
              child: Container(
                width: FigMetrics.size220, height: FigMetrics.size220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Fig.blueStrong, AppColors.figC00FFFFFF],
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s20, AppSpacing.s20, AppSpacing.s18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: Fig.t(
                              context,
                              size: AppFontSizes.markdownH2,
                              color: AppColors.figCFF555B70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tier.mostPopular) ...[
                          const SizedBox(width: AppSpacing.s8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s9,
                              vertical: AppSpacing.s3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.figCFFE7EEFF,
                              borderRadius: BorderRadius.circular(AppRadius.small),
                            ),
                            child: Text(
                              tr.pricingMostPopular,
                              style: Fig.t(context, size: FigMetrics.fontFig10, color: Fig.blue),
                            ),
                          ),
                        ],
                        if (isCurrent) ...[
                          const SizedBox(width: AppSpacing.s8),
                          Text(
                            tr.pricingCurrent,
                            style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.blue),
                          ),
                        ],
                      ],
                    ),
                    if (tagline.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        tagline,
                        style: Fig.t(context, size: AppFontSizes.microCaps, color: Fig.mutedLight),
                      ),
                    ],
                    if (showPaidUpsell) ...[
                      const SizedBox(height: AppSpacing.s22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              price,
                              style: Fig.t(
                                context,
                                size: FigMetrics.fontFig46,
                                weight: FontWeight.w800,
                                color: AppColors.figCFF0B0B1A,
                                height: AppLineHeights.flush,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!tier.isFree) ...[
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              context.tr.figPerMonth,
                              style: Fig.t(
                                context,
                                size: AppFontSizes.microCaps,
                                color: Fig.mutedDim,
                              ),
                            ),
                            if (vat.addedAtCheckout) ...[
                              const SizedBox(width: AppSpacing.s6),
                              Text(
                                tr.pricePlusVat,
                                style: Fig.t(
                                  context,
                                  size: AppFontSizes.microCaps,
                                  color: Fig.mutedDim,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s18),
                      Text(
                        tier.isFree
                            ? PlanCopy.translate(tr, tier.priceNote)
                            : tr.priceBothCycles(
                                annualCentsPerMonth: tier.priceAnnualCents,
                                monthlyCents: tier.priceMonthlyCents,
                              ),
                        style: Fig.t(
                          context,
                          size: AppFontSizes.metaLine,
                          color: Fig.mutedGrey,
                          height: AppLineHeights.reading,
                        ),
                      ),
                    ],
                    if (canBuy) ...[
                      const SizedBox(height: AppSpacing.s18),
                      GestureDetector(
                        onTap: opening ? null : onSubscribe,
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tier.mostPopular
                                ? null
                                : AppColors.figCFFF1F2F6,
                            gradient: tier.mostPopular
                                ? Fig.primaryGradient
                                : null,
                            borderRadius: BorderRadius.circular(FigMetrics.radFig23),
                          ),
                          child: opening
                              ? const SizedBox(
                                  width: FigMetrics.size18, height: FigMetrics.size18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppStrokeWidths.spinnerThin,
                                  ),
                                )
                              : Text(
                                  tr.pricingWebCta,
                                  style: Fig.t(
                                    context,
                                    size: AppFontSizes.dense,
                                    color: tier.mostPopular
                                        ? AppColors.figWhite
                                        : Fig.ink,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (tier.featuresText.isNotEmpty) ...[
                const Divider(height: AppBorderWidths.hairline, color: AppColors.figCFFEDEEF3),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s20, AppSpacing.s18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.figFeatures,
                        style: Fig.t(
                          context,
                          size: FigMetrics.fontFig11,
                          color: Fig.mutedGrey,
                          letterSpacing: AppLetterSpacing.label,
                        ),
                      ),
                      if (intro.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s10),
                        Text(
                          intro,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.metaLine,
                            color: AppColors.figCFFB0B4C2,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s6),
                      for (final bullet in tier.featuresText)
                        PlanFeatureLine(label: PlanCopy.translate(tr, bullet)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
