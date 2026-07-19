import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../core/theme/app_radius.dart';

/// Compact card used inside the chat Action Center sheet. Distinct from the
/// shared [ActionCard] used on the Inbox screen — this one is denser, single
/// trailing slot, no chips.
class ChatActionCard extends StatelessWidget {
  const ChatActionCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.trailing,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.inputR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Row(
        children: [
          ColoredIconBox(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
