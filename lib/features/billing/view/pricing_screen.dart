import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/plan_tier_models.dart';
import '../data/plans_api.dart';
import '../view_model/plan_cubit.dart';

/// Pricing screen (Gap L) — renders the live tiers from `GET /api/v1/plans/`
/// and marks the caller's current tier. Self-serve payments aren't built yet
/// (deferred until a payment provider is signed), so the upgrade CTA on each
/// paid tier is "Contact us" for now.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late Future<PlansResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PlansApi>().list();
  }

  void _reload() {
    setState(() => _future = context.read<PlansApi>().list());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.pricingTitle)),
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final tier in data.plans) ...[
                  _PlanTierCard(
                    tier: tier,
                    isCurrent: tier.slug == current,
                    onContact: () => _showContactSheet(context),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetCtx.tr.upgradeSheetTitle,
                style: sheetCtx.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                sheetCtx.tr.upgradeSheetBody,
                style: sheetCtx.text.bodyMedium
                    ?.copyWith(color: sheetCtx.saqqar.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: sheetCtx.tr.close,
                expand: true,
                onPressed: () => Navigator.of(sheetCtx).pop(),
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
    required this.isCurrent,
    required this.onContact,
  });

  final PlanTier tier;
  final bool isCurrent;
  final VoidCallback onContact;

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
                    borderRadius: BorderRadius.circular(999),
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
          const SizedBox(height: 4),
          Text(
            tr.pricePerMonth(tier.priceMonthlyCents),
            style: context.text.titleMedium?.copyWith(
              color: s.brandCyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _CapRow(
            label: tr.pricingDailyCap,
            value: '${compactCount(tier.dailyBurstTokens)} ${tr.pricingStUnit}',
          ),
          const SizedBox(height: 6),
          _CapRow(
            label: tr.pricingMonthlyCap,
            value: '${compactCount(tier.monthlyTokens)} ${tr.pricingStUnit}',
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
          if (!isCurrent && !tier.isFree) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: tr.pricingContactCta,
              icon: AppIcons.sparkles,
              expand: true,
              onPressed: onContact,
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