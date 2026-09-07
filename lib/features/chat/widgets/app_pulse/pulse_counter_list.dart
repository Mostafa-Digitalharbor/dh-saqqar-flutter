import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import '../../data/app_pulse_payloads.dart';
import 'pulse_helpers.dart';

/// The accountant's and HR's shared `counters` list — each row's label and
/// suggested next step already written in the screen's working language by
/// the server (rule 4), so every line renders verbatim via
/// [AutoDirectionText] rather than through `context.tr`. The value badge is
/// the one thing this widget adds: a tri-state cell (real number vs. `null`)
/// exactly like [pulseScalarCell], so a counter the server didn't send a
/// value for reads as "—", never as a manufactured zero.
class PulseCounterList extends StatelessWidget {
  const PulseCounterList({super.key, required this.counters});

  final List<PulseCounter> counters;

  @override
  Widget build(BuildContext context) {
    if (counters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final counter in counters) _CounterRow(counter: counter),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({required this.counter});

  final PulseCounter counter;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final cell = pulseScalarCell(context, counter.value);
    final flagged = counter.value != null && counter.value! > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoDirectionText(
                  counter.label,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (flagged && counter.action.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s2),
                    child: AutoDirectionText(
                      counter.action,
                      style: context.text.labelSmall?.copyWith(color: s.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s10,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: (flagged ? s.warning : s.muted)
                  .withValues(alpha: AppAlphas.a12),
              borderRadius: AppRadius.pillR,
            ),
            child: Text(
              cell.value,
              style: context.text.labelMedium?.copyWith(
                color: flagged ? s.warning : s.muted,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
