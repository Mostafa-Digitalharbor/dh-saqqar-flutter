import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// A warning-tinted, screen-top caveat banner: a small leading icon + a single
/// line of text. Used to flag surfaces built against an unconfirmed backend
/// contract or a store-policy caveat (Meetings / Data explorer / Checkout).
///
/// One home for the recipe so the three screens share the exact tint, radius,
/// and spacing instead of each carrying a byte-identical private copy.
class PreviewBanner extends StatelessWidget {
  const PreviewBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.warning.withValues(alpha: 0.10),
        borderRadius: AppRadius.rowR,
        border: Border.all(color: s.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: s.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.labelSmall
                  ?.copyWith(color: s.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
