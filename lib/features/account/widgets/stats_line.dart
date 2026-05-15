import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Single-line workspace stats — replaces the 4-tile [StatsGrid] in the
/// simplified Account screen.
///
/// Format: `6 chats · 7 credentials · 2 approvals · 8 files`
///
/// Numbers are still placeholder until the API ships; once `/api/auth/me/`
/// returns the `stats` block, swap them in.
class StatsLine extends StatelessWidget {
  const StatsLine({
    super.key,
    this.conversations = 6,
    this.credentials = 7,
    this.approvals = 2,
    this.artifacts = 8,
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
