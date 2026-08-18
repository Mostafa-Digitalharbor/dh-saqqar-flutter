import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/billing_visibility.dart';
import '../data/plan_copy.dart';
import '../data/plan_tier_models.dart';
import '../data/plans_api.dart';
import '../data/web_checkout.dart';
import '../view_model/plan_cubit.dart';
import '../widgets/plan_feature_line.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';

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
      message = '${ApiErrorMapper.messageForLocale(tr, target.failure)} '
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
    return Scaffold(
      appBar: AppBar(title: Text(tr.pricingTitle)),
      body: AmbientBackground(
        child: FutureBuilder<PlansResponse>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              // Name the cause, not just the symptom. This screen used to say
              // "Couldn't load plans" and drop `snap.error` on the floor, so a
              // user offline, rate-limited, or hitting a 500 read the same
              // sentence and had no idea which of those to act on — on the one
              // screen where the next step is spending money.
              return AppErrorState(
                title: context.tr.pricingLoadError,
                message: ApiErrorMapper.message(context, snap.error),
                onRetry: _reload,
              );
            }
            final data = snap.data!;
            // Prefer the server's current_plan; fall back to the live
            // conversation snapshot's plan slug when anonymous on this call.
            final current = data.currentPlan ??
                context.read<PlanCubit>().state?.slug;
            // Rank of the tier the user is on, by the server's own `sort`.
            // Null when we can't tell — in which case nothing is suppressed,
            // because guessing wrong here hides a plan someone wants to buy.
            final currentSort = current == null
                ? null
                : data.plans
                    .where((p) => p.slug == current)
                    .map((p) => p.sort)
                    .firstOrNull;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s32,
              ),
              children: [
                Text(
                  tr.pricingSubtitle,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.saqqar.muted,
                    height: AppLineHeights.compact,
                  ),
                ),
                if (showPaidUpsell) ...[
                  const SizedBox(height: AppSpacing.s16),
                  _CycleSwitch(
                    annual: _annual,
                    onChanged: (v) => setState(() => _annual = v),
                  ),
                  // Rate and applicability both come from the response's `vat`
                  // object. The note used to be a fixed sentence with "15%"
                  // written into it, which would have gone on claiming 15%
                  // through any rate change, and would have kept claiming tax
                  // applied at all in a market where it doesn't.
                  if (data.vat.addedAtCheckout) ...[
                    const SizedBox(height: AppSpacing.s10),
                    Text(
                      tr.pricingVatNote(data.vat.rateLabel),
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.saqqar.muted),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.s18),
                for (final tier in data.plans) ...[
                  _PlanTierCard(
                    tier: tier,
                    annual: _annual,
                    vat: data.vat,
                    isCurrent: tier.slug == current,
                    // Don't offer to sell a tier at or below the one they're
                    // on. A Business customer was being shown "Subscribe on
                    // the web" on Starter, Solo and Professional — a tap that
                    // would take their money for a downgrade the server has
                    // no path to apply (QA 2026-08-02, P1). The card still
                    // renders: seeing what the cheaper tiers include is fine,
                    // being sold one is not.
                    sellable: currentSort == null || tier.sort > currentSort,
                    opening: _opening == tier.slug,
                    onSubscribe: () => _openWeb(tier.slug),
                  ),
                  const SizedBox(height: AppSpacing.s14),
                ],
                // The one entry point that is always here.
                //
                // Every other route to saqqaar.com hangs off a tier card, and
                // those disappear on the tier you're on and everything below
                // it. A Business customer — the top tier — therefore had no
                // way to reach their own billing page from the app at all
                // (QA 2026-08-04). Renewals, cancellations, receipts and card
                // changes all live on the web, so "manage" has to exist
                // independently of whether there is anything left to sell.
                //
                // Opens the plain `/pricing/` (empty slug → no `?plan=`),
                // signed in via the hand-off.
                if (showPaidUpsell) ...[
                  const SizedBox(height: AppSpacing.s4),
                  GhostButton(
                    label: tr.pricingManageCta,
                    icon: AppIcons.open,
                    expand: true,
                    loading: _opening == '',
                    onPressed: () => _openWeb(''),
                  ),
                  const SizedBox(height: AppSpacing.s14),
                ],
                const SizedBox(height: AppSpacing.s4),
                Text(
                  // With the purchase surface off this is the only thing that
                  // tells the user where their plan lives. Plain text, no
                  // link, no button — the same shape as the sign-up screen's
                  // "Registration is available on saqqaar.com", which is
                  // already shipped and already through App Review.
                  showPaidUpsell ? tr.pricingWebNote : tr.pricingManagedOnWeb,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.saqqar.muted,
                    height: AppLineHeights.reading,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Monthly / Annual segmented switch, mirroring the website's.
class _CycleSwitch extends StatelessWidget {
  const _CycleSwitch({required this.annual, required this.onChanged});

  final bool annual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: s.cardBorder.withValues(alpha: AppAlphas.a35),
          borderRadius: AppRadius.pillR,
        ),
        // `Wrap`, not `Row`. A Row hands its non-flex children unbounded
        // width, so the two chips grew past a 320 px screen — 126 px past it
        // in English — and nothing could ellipsize because ellipsis only
        // engages against a bound. Wrap both bounds the chips (so the note
        // inside one can reflow) and stacks them when they genuinely cannot
        // share a line. It is `Wrap` rather than `Flexible` for the same
        // reason the conversation-card counts were: truncating "save up to
        // 50%" to "save up t…" misstates an offer, which is worse than
        // spending a second line on it.
        //
        // This was invisible until 2026-08-06 because the sweep's plans
        // fixture threw while parsing, so every viewport was only ever
        // rendering this screen's error state.
        child: Wrap(
          alignment: WrapAlignment.center,
          runSpacing: AppSpacing.s4,
          children: [
            _CycleChip(
              label: tr.pricingCycleMonthly,
              selected: !annual,
              onTap: () => onChanged(false),
            ),
            _CycleChip(
              label: tr.pricingCycleAnnual,
              // The saving is the reason anyone taps this, so it rides on the
              // chip rather than sitting in a footnote nobody reads.
              note: tr.pricingCycleAnnualSave,
              selected: annual,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String label;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s9,
          ),
          decoration: BoxDecoration(
            color: selected ? s.brandCyan : Colors.transparent,
            borderRadius: AppRadius.pillR,
          ),
          // Wrap again, one level down: at 1.3× text the annual chip alone is
          // wider than a 320 px screen, so stacking the two chips is not
          // enough — the label and its note have to be able to take a line
          // each as well.
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s6,
            children: [
              Text(
                label,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.onBrand : s.text,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: context.text.labelSmall?.copyWith(
                    color: selected
                        ? AppColors.onBrand.withValues(alpha: AppAlphas.a85)
                        : s.muted,
                  ),
                ),
            ],
          ),
        ),
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

  /// Decides whether the "+ VAT" rider rides beside the figure. Server-sent,
  /// not assumed.
  final VatPolicy vat;

  final bool isCurrent;

  /// Whether this tier is an *upgrade* from the caller's current one. False
  /// suppresses the Subscribe button without hiding the card.
  final bool sellable;

  final bool opening;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;

    // Every string below is the SERVER's, put through the Arabic map on the
    // way to the screen. Nothing about this tier is written down on this side
    // any more: a tier the backend adds tomorrow arrives fully described, and
    // a wording change on saqqaar.com reaches this card without a release.
    //
    // `translate` returns its input unchanged when there is no Arabic for it,
    // so an untranslated bullet shows the server's English rather than a gap.
    final name = PlanCopy.nameFor(
      tr,
      slug: tier.slug,
      // The wire name is English-only; the localized one is what wins, and
      // this is the floor under it.
      fallback: tier.name.isEmpty ? tier.slug : tier.name,
    );
    final tagline = PlanCopy.translate(tr, tier.tagline);
    final intro = PlanCopy.translate(tr, tier.featuresIntro);

    return GlassCard(
      // Pricing sits on a flat opaque AmbientBackground and renders one card
      // per tier — the backdrop blur has no visible subject, so dropping it
      // removes N stacked saveLayers with pixel-identical output.
      blur: false,
      // Highlight the caller's current tier with a cyan ring.
      borderColor: isCurrent ? s.brandCyan : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The website floats this badge on the card's top edge. On a
          // single-column phone layout there is no edge to float over, so it
          // leads the card instead — same signal, same place in the reading
          // order.
          if (tier.mostPopular) ...[
            _Pill(
              label: tr.pricingMostPopular,
              color: s.brandCyan,
              filled: true,
            ),
            const SizedBox(height: AppSpacing.s10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (isCurrent)
                _Pill(label: tr.pricingCurrent, color: s.brandCyan),
            ],
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              tagline,
              style: context.text.bodyMedium?.copyWith(color: s.muted),
            ),
          ],
          // Price block. Gated so the same screen can still be shipped as a
          // pure feature comparison if a store objects to the prices — the
          // bullet list below is what actually differentiates the tiers, and
          // it reads fine without a number attached.
          if (showPaidUpsell) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  // "$0", not the word "Free" — the free tier is *named*
                  // Free, so the word under its own title read as a rendering
                  // bug. A figure also lines the column up with the paid
                  // tiers above and below.
                  tier.isFree
                      ? tr.pricingZero
                      : tr.priceAmount(
                          annual ? tier.priceAnnualCents : tier.priceMonthlyCents,
                        ),
                  style: context.text.headlineSmall?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!tier.isFree && vat.addedAtCheckout) ...[
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    tr.pricePlusVat,
                    style: context.text.bodySmall?.copyWith(color: s.muted),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              // Both cycles, always — the figure above only ever shows one of
              // them, and the switch that reveals the other is off-card.
              //
              // The paid tiers compose this line locally rather than printing
              // the server's `price_note`. Not a mirror: every number in it is
              // interpolated from the very cents this row carries, so it can't
              // disagree with the server — but it CAN be written right-to-left.
              // The server's string is English-only and reads as
              // "billed monthly ($24/yr).$2/mo" once the bidi algorithm has
              // had it, which is the same content and unreadable.
              //
              // The free tier has no figures to reorder, so its note is the
              // server's own — translated, and blank if the server sends none.
              tier.isFree
                  ? PlanCopy.translate(tr, tier.priceNote)
                  : tr.priceBothCycles(
                      annualCentsPerMonth: tier.priceAnnualCents,
                      monthlyCents: tier.priceMonthlyCents,
                    ),
              style: context.text.bodySmall?.copyWith(
                color: s.muted,
                height: AppLineHeights.reading,
              ),
            ),
          ],
          if (tier.featuresText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s14),
            Divider(height: AppBorderWidths.hairline, thickness: AppBorderWidths.hairline, color: s.cardBorder),
            const SizedBox(height: AppSpacing.s14),
            // "Everything in Solo, plus:" — the ladder that makes a bullet
            // list of four items mean "four *more* than the tier below".
            // Absent on the entry tier, whose list is absolute. Sent as a
            // whole sentence, so nothing here reconstructs it from a slug.
            if (intro.isNotEmpty) ...[
              Text(
                intro,
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            for (final bullet in tier.featuresText)
              PlanFeatureLine(label: PlanCopy.translate(tr, bullet)),
          ],
          // Subscribe → saqqaar.com. Not shown on the tier you already have
          // (nothing to buy) or on Free (nothing to charge). `AppIcons.open`
          // is the external-link glyph: the button leaves the app, and the
          // icon is the only thing that says so before the tap — which is why
          // this keeps its own label instead of the website's "Choose Solo".
          if (showPaidUpsell && sellable && !isCurrent && !tier.isFree) ...[
            const SizedBox(height: AppSpacing.s16),
            PrimaryButton(
              label: tr.pricingWebCta,
              icon: AppIcons.open,
              expand: true,
              loading: opening,
              onPressed: onSubscribe,
            ),
          ],
        ],
      ),
    );
  }
}

/// The small rounded label used for "Most popular" and "Current plan".
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;

  /// Solid fill with white text, for the badge the website uses to push a
  /// tier. The outlined form marks state rather than making a claim.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: AppAlphas.a12),
        borderRadius: AppRadius.pillR,
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: AppAlphas.a35)),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: filled ? AppColors.onBrand : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// The private `_ErrorState` that lived here is gone — it was `AppErrorState`
// minus the icon, minus the cause and minus the reason the retry might work.
// `_FeatureLine` left too, to `../widgets/plan_feature_line.dart` — the
// account's current-plan card renders the same bullets and the two must not
// drift.
