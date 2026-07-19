import 'package:flutter/material.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';

/// Subtle pill rendered between message groups when the calendar day rolls.
/// Reads "Today" / "Yesterday" inside one week of now; otherwise a short
/// localised date ("May 9" within this year, "May 9 2025" earlier).
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.date});

  final DateTime date;

  /// Helper that decides whether two messages need a separator drawn
  /// between them. Returns `true` when [previous] is null OR when the two
  /// timestamps fall on different calendar days (local time).
  static bool needs(DateTime? previous, DateTime current) {
    if (previous == null) return true;
    return previous.year != current.year ||
        previous.month != current.month ||
        previous.day != current.day;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: s.surface2.withValues(alpha: context.isDark ? 0.65 : 0.92),
            borderRadius: AppRadius.pillR,
            border: Border.all(color: s.cardBorder),
          ),
          child: Text(
            AppDateFormat.dayLabel(context, date).toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
