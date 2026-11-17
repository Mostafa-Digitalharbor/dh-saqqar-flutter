import 'package:flutter/material.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../shared/fig/fig.dart';
import '../../../core/theme/app_sizes.dart';

/// Small caps day caption ("TODAY") rendered between message groups when the
/// calendar day rolls.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.date});

  final DateTime date;

  /// Whether two messages need a separator drawn between them. True when
  /// [previous] is null OR the timestamps fall on different local days.
  static bool needs(DateTime? previous, DateTime current) {
    if (previous == null) return true;
    return previous.year != current.year ||
        previous.month != current.month ||
        previous.day != current.day;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Center(
        child: Text(
          AppDateFormat.dayLabel(context, date).toUpperCase(),
          style: Fig.t(
            context,
            size: 9,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}
