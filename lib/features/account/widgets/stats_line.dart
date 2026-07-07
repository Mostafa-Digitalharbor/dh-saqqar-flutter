import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Single-line workspace stats — replaces the 4-tile [StatsGrid] in the
/// simplified Account screen.
///
/// Format: `6 chats · 7 credentials · 2 approvals · 8 files`
///
/// Counts come from `/api/auth/me/` via [AuthCounts] (0 when the user has
/// none). The values are REQUIRED — there are deliberately no default
/// numbers so a caller can never render fabricated stats, which the
/// product explicitly prohibits.
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
    final s = context.saqqar;
    final parts = [
      '$conversations ${context.tr.conversations}',
      '$credentials ${context.tr.credentials}',
      '$approvals ${context.tr.approvals.toLowerCase()}',
      '$artifacts ${context.tr.artifactsLower}',
    ];

    return Text(
      parts.join(' · '),
      style: context.text.labelSmall?.copyWith(
        color: s.muted,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }
}
