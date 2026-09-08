import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
import '../../data/app_pulse_payloads.dart';
import 'pulse_helpers.dart';
import 'pulse_raw_items.dart';

/// The accountant's and HR's shared `counters` list — each row's label and
/// suggested next step already written in the screen's working language by
/// the server (rule 4), so every line renders verbatim via
/// [AutoDirectionText] rather than through `context.tr`. The value badge is
/// the one thing this widget adds: a tri-state cell (real number vs. `null`)
/// exactly like [pulseScalarCell], so a counter the server didn't send a
/// value for reads as "—", never as a manufactured zero.
class PulseCounterList extends StatelessWidget {
  const PulseCounterList({super.key, required this.counters, this.detailsFor});

  final List<PulseCounter> counters;

  /// The audit rows behind a counter, looked up by its wire key — the
  /// accountant's `blocks`. Null (or an empty result) leaves the row as a
  /// plain number, which is what HR sends.
  final List<Object?> Function(String key)? detailsFor;

  @override
  Widget build(BuildContext context) {
    if (counters.isEmpty) return const SizedBox.shrink();
    final lookup = detailsFor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final counter in counters)
          _CounterRow(
            counter: counter,
            details: lookup == null ? const [] : lookup(counter.key),
          ),
      ],
    );
  }
}

/// One counter, with its trail collapsed underneath.
///
/// Stateful only for the disclosure: the trail is opened per row rather
/// than for the whole card, because a user checking "which five invoices
/// have no reference" does not want the other four checks' rows unfolding
/// under it at the same time.
class _CounterRow extends StatefulWidget {
  const _CounterRow({required this.counter, this.details = const []});

  final PulseCounter counter;
  final List<Object?> details;

  @override
  State<_CounterRow> createState() => _CounterRowState();
}

class _CounterRowState extends State<_CounterRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final counter = widget.counter;
    final cell = pulseScalarCell(context, counter.value);
    final flagged = counter.value != null && counter.value! > 0;
    final details = widget.details;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          style:
                              context.text.labelSmall?.copyWith(color: s.muted),
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
          // The rows behind the number, collapsed. Same disclosure the
          // approval card uses for a raw payload, and for the same reason:
          // the headline is enough for most readings, and the trail is only
          // interesting once the number surprises you.
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _open ? AppIcons.chevronUp : AppIcons.chevronDown,
                    size: AppIconSizes.inline,
                    color: s.muted,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    _open ? context.tr.hideDetails : context.tr.showDetails,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_open)
              PulseRawItemsList(title: counter.label, items: details),
          ],
        ],
      ),
    );
  }
}
