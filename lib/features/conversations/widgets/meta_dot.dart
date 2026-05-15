import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';

/// Tiny icon-plus-label pair used in the conversation row footer.
/// Replaces noisy mini chips with a denser, single-row glyph + text combo.
class MetaDot extends StatelessWidget {
  const MetaDot({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}
