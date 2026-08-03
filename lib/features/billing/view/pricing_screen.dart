import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/billing_visibility.dart';
import '../data/plan_tier_models.dart';
import '../data/plans_api.dart';
import '../data/web_checkout.dart';
import '../view_model/plan_cubit.dart';
import '../../../core/theme/app_radius.dart';

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
    setState(() => _future = context.read<PlansApi>().list());
  }

  /// Which tier's Subscribe button is mid-hand-off, so it can show a spinner.
  /// Resolving the login hand-off is a round-trip; a button that looks inert
  /// for a few hundred milliseconds gets tapped twice.
  String? _opening;

  Future<void> _subscribe(PlanTier tier) async {
    if (_opening != null) return;
    setState(() => _opening = tier.slug);
    final result = await WebCheckout.open(context.read<Dio>(), slug: tier.slug);
    if (!mounted) return;
    setState(() => _opening = null);

    final tr = context.tr;
    final target = result.target;

    // Four outcomes, four different things worth saying. The one that used to
    // be silent — "we couldn't sign you in, so the page will ask you to" — is
    // the one that made this look broken: you tap Subscribe as a signed-in
    // user and land on a login form with no explanation.
    final String? message;
    if (target.blocking) {
      // Never launched: no connection, or the session ended. The failure text
      // is the real reason, so use it rather than a generic line.
      message = ApiErrorMapper.messageForLocale(tr, target.failure);
    } else if (!result.launched) {
      message = tr.pricingOpenFailed;
    } else if (target.failure != null) {
      // Opened, but on the plain page AND something actually went wrong.
      message = '${ApiErrorMapper.messageForLocale(tr, target.failure)} '
          '${tr.pricingWebSignInNote}';
    } else if (!target.signedIn) {
      // Opened on the plain page because the server offers no hand-off. Not
      // an error — just a heads-up so the sign-in form isn't a surprise.
      message = tr.pricingWebSignInNote;
    } else {
      message = null;
    }

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
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
              return _ErrorState(onRetry: _reload);
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  tr.pricingSubtitle,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.saqqar.muted,
                    height: 1.4,
                  ),
                ),
                if (showPaidUpsell) ...[
                  const SizedBox(height: 16),
                  _CycleSwitch(
                    annual: _annual,
                    onChanged: (v) => setState(() => _annual = v),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr.pricingVatNote,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.saqqar.muted),
                  ),
                ],
                const SizedBox(height: 18),
                for (final tier in data.plans) ...[
                  _PlanTierCard(
                    tier: tier,
                    annual: _annual,
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
                    onSubscribe: () => _subscribe(tier),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 4),
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
                    height: 1.45,
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
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: s.cardBorder.withValues(alpha: 0.35),
          borderRadius: AppRadius.pillR,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? s.brandCyan : Colors.transparent,
            borderRadius: AppRadius.pillR,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : s.text,
                ),
              ),
              if (note != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : s.muted,
                    ),
                  ),
                ),
              ],
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
    required this.isCurrent,
    required this.sellable,
    required this.opening,
    required this.onSubscribe,
  });

  final PlanTier tier;
  final bool annual;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.name.isEmpty ? tier.slug : tier.name,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: s.brandCyan.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pillR,
                    border:
                        Border.all(color: s.brandCyan.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    tr.pricingCurrent,
                    style: context.text.labelSmall?.copyWith(
                      color: s.brandCyan,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          // Price line. Gated so the same screen can still be shipped as a
          // pure feature comparison if a store objects to the prices — the
          // caps and features below are what actually differentiate the
          // tiers, and they read fine without a number attached.
          if (showPaidUpsell) ...[
            const SizedBox(height: 4),
            Text(
              // "$0", not the word "Free" — the free tier is *named* Free, so
              // the word under its own title read as a rendering bug. A figure
              // also lines the column up with the paid tiers above and below.
              tier.isFree
                  ? tr.pricingZero
                  : annual
                      ? tr.priceAnnualPerMonth(tier.priceAnnualCents)
                      : tr.pricePerMonth(tier.priceMonthlyCents),
              style: context.text.titleMedium?.copyWith(
                color: s.brandCyan,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
          const SizedBox(height: 6),
          _CapRow(
            label: tr.pricingProjectsLabel,
            value: tier.maxProjects == null
                ? tr.pricingUnlimited
                : '${tier.maxProjects}',
          ),
          const SizedBox(height: 12),
          _FeatureLine(label: tr.featureVoice, on: tier.features.voice),
          _FeatureLine(label: tr.featurePostgres, on: tier.features.postgres),
          _FeatureLine(label: tr.featureGithub, on: tier.features.github),
          _FeatureLine(
            label: tr.featureServerShell,
            on: tier.features.serverShell,
          ),
          // Subscribe → saqqaar.com. Not shown on the tier you already have
          // (nothing to buy) or on Free (nothing to charge). `AppIcons.open`
          // is the external-link glyph: the button leaves the app, and the
          // icon is the only thing that says so before the tap.
          if (showPaidUpsell && sellable && !isCurrent && !tier.isFree) ...[
            const SizedBox(height: 14),
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
            style: context.text.bodyMedium?.copyWith(color: s.muted),
          ),
        ),
        Text(
          value,
          style: context.text.bodyMedium
              ?.copyWith(color: s.text, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.label, required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = on ? s.success : s.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(on ? AppIcons.check : AppIcons.close, size: 16, color: color),
          const SizedBox(width: 8),
          // Expanded + wrap so a long Arabic feature label (at up to 1.4x
          // text scale on a narrow phone) wraps instead of overflowing the
          // row — mirrors the sibling _CapRow which already uses Expanded.
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: on ? s.text : s.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.tr.pricingLoadError, style: context.text.bodyLarge),
          const SizedBox(height: 12),
          GhostButton(
            label: context.tr.retry,
            icon: AppIcons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
