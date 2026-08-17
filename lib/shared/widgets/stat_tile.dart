import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../../core/theme/app_sizes.dart';

/// One "big number over a small label" column — the account stats line and the
/// billing balance header.
///
/// Both screens had their own private `_Stat`, and only one of them had
/// survived contact with real data: the account version grew a [FittedBox],
/// tabular figures and a two-line ellipsised label after four-digit counts and
/// longer Arabic labels broke a 320 px row. The billing copy had none of that
/// while rendering token balances and the same Arabic labels in half the
/// width, so it was one long translation away from the bug that was already
/// fixed next door.
///
/// Deliberately does **not** wrap itself in [Expanded]. The account version
/// did, which meant it silently required a [Row] parent and could not be
/// reused anywhere else; sizing belongs to whoever is doing the laying out.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  /// Pre-formatted — callers pass `'$count'` or a compacted `'1.25B'`. Taking
  /// a string keeps number formatting (and its locale) out of a layout widget.
  final String value;

  final String label;

  /// Defaults to the body text colour; billing tints its totals cyan.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      children: [
        // Real accounts reach four digits (2,368 approvals on the account this
        // was designed against), and four of those have to share a 320 px row.
        // FittedBox shrinks only when it must, so typical 1–3 digit counts
        // keep their full size.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: valueColor,
              // Tabular figures so the columns stay optically aligned
              // regardless of which digits land in them.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          label,
          textAlign: TextAlign.center,
          // Two lines, because the Arabic labels are longer than the English
          // ones and a 4-column split on a 320 px phone leaves roughly 70 px
          // per column. Ellipsis rather than overflow.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(
            color: s.muted,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
