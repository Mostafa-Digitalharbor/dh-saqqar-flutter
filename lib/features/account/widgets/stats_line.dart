import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Workspace stats for the Account identity card — four counts rendered as a
/// row of tiles rather than a sentence.
///
/// This used to be one line of muted text
/// (`6 chats · 7 credentials · 2 approvals · 8 files`). It sat directly under
/// another muted line (joined / last-login), which put the only four real
/// numbers on the screen in the same weight and colour as the timestamps
/// beside them — so nothing read as data. Giving each count its own column,
/// with the figure in the primary text colour and the label small underneath,
/// makes the card scannable without adding a single pixel of chrome.
///
/// Counts come from `/api/auth/me/` via `AuthCounts` (0 when the user has
/// none). The values are REQUIRED — there are deliberately no default numbers
/// so a caller can never render fabricated stats, which the product
/// explicitly prohibits.
class StatsLine extends StatelessWidget {
  const StatsLine({
    super.key,
    required this.conversations,
    required this.credentials,
    required this.approvals,
    required this.artifacts,
  });

  final int conversations;
  final int credentials;
  final int approvals;
  final int artifacts;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // Lower-cased at the call site, all four, rather than trusting the i18n
    // strings to agree: `approvals` ships capitalised (it doubles as a screen
    // title) while the rest don't, so a straight render produced
    // "conversations · credentials · Approvals · artifacts". A no-op in
    // Arabic, which has no letter case.
    final stats = <({int value, String label})>[
      (value: conversations, label: tr.conversations.toLowerCase()),
      (value: credentials, label: tr.credentials.toLowerCase()),
      (value: approvals, label: tr.approvals.toLowerCase()),
      (value: artifacts, label: tr.artifactsLower.toLowerCase()),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across needs roughly 76 px a column before the longest label
        // ("conversations", and its longer Arabic counterpart) stops fitting
        // on one line. Below that Flutter breaks mid-word — the card rendered
        // "conversati / ons" and "credential / s" on a 320 px phone, which
        // reads as a layout bug. Two rows of two gives each label ~150 px,
        // so the words stay whole instead.
        final fourAcross = constraints.maxWidth >= 304;
        if (fourAcross) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) _Divider(),
                _Stat(value: stats[i].value, label: stats[i].label),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat(
                    value: stats[row * 2].value,
                    label: stats[row * 2].label,
                  ),
                  _Divider(),
                  _Stat(
                    value: stats[row * 2 + 1].value,
                    label: stats[row * 2 + 1].label,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Expanded(
      child: Column(
        children: [
          // Real accounts reach four digits (2,368 approvals on the account
          // this was designed against), and four of those have to share a
          // 320 px row. FittedBox shrinks only when it must, so typical
          // 1–3 digit counts keep their full size.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              maxLines: 1,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
                // Tabular figures so the four columns stay optically aligned
                // regardless of which digits land in them.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            // Two lines, because the Arabic labels are longer than the
            // English ones and a 4-column split on a 320 px phone leaves
            // roughly 70 px per column. Ellipsis rather than overflow.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hairline between columns. Fixed height rather than `stretch` so a label
/// that wraps to two lines doesn't drag the rule down with it.
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: context.saqqar.cardBorder,
    );
  }
}
