import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import 'glass_card.dart';

class CredentialCard extends StatelessWidget {
  const CredentialCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.chips = const [],
    this.trailing,
    this.disabled = false,
    this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> chips;
  final Widget? trailing;
  final bool disabled;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = accent ?? s.brandCyan;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GlassCard(
        blur: false,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withValues(alpha: 0.30)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: s.muted,
                      height: 1.3,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: chips),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
