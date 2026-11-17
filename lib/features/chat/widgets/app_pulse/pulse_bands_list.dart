import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import 'pulse_helpers.dart';

/// Finance's `collection_aging` / `payment_horizon` — a row of day bands
/// with the money sitting in each.
///
/// Rendered as a labelled strip rather than as [pulseStatTile]s: these are a
/// breakdown of one number the card already shows above, so they read as a
/// sequence ("0–30, 31–60, 61–90, 90+") and giving each its own big tile
/// would compete with the headline figures for attention.
///
/// An [PulseBands.available] of false is stated, not hidden — rule 1: a
/// database that cannot answer is a different answer from a database with
/// nothing overdue.
class PulseBandsList extends StatelessWidget {
  const PulseBandsList({super.key, required this.title, required this.bands});

  final String title;
  final PulseBands bands;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    if (bands.available && bands.bands.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          if (!bands.available)
            Text(
              context.tr.pulseUnavailable,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            )
          else
            Wrap(
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s8,
              children: [for (final band in bands.bands) _Band(band: band)],
            ),
        ],
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.band});

  final PulseBand band;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final amount = band.amount;
    final count = band.count;
    // Amount is the headline where there is one; a band that only carries a
    // count still gets its number rather than an em dash.
    final value = amount != null
        ? compactCount(amount.round(), context.tr)
        : count != null
        ? '$count'
        : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.text.bodyMedium?.copyWith(
            color: amount == null && count == null ? s.muted : s.text,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          // A numeric band ("0–30", "90+") reads the same in both locales
          // and stays as it is. The handful of NAMED bands the server also
          // sends — not due, due today, later — are words, and a word in
          // English under an Arabic card is the kind of half-translated
          // screen this app's i18n rules exist to prevent. Anything else
          // falls back to the server's own label rather than to a guess.
          context.tr.lookup(
            'pulse_band_${band.label.replaceAll(' ', '_')}',
            fallback: band.label,
          ),
          style: context.text.labelSmall?.copyWith(color: s.muted),
        ),
        // Both numbers when the server sent both — "84K over 12 invoices"
        // is two facts, and the second is the one that says how bad it is.
        if (amount != null && count != null)
          Text(
            context.tr.pulseBandInvoices(count),
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
      ],
    );
  }
}
