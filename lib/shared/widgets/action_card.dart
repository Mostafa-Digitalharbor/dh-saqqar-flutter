import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.color,
    this.chips = const [],
    this.actions = const [],
    this.warning = false,
  });

  final String title;
  final String body;
  final IconData? icon;
  final Color? color;
  final List<Widget> chips;
  final List<Widget> actions;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = color ?? (warning ? s.warning : s.brandCyan);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.cardBorder),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          // Accent stripe on the start side (4px wide).
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadiusDirectional.horizontal(
                  start: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Icon(icon, color: accent, size: 17),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                          color: s.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.5,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 340;
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final entry in actions.asMap().entries) ...[
                              if (entry.key > 0) const SizedBox(height: 8),
                              entry.value,
                            ],
                          ],
                        );
                      }

                      return Row(
                        children: [
                          for (final entry in actions.asMap().entries) ...[
                            if (entry.key > 0) const SizedBox(width: 10),
                            Expanded(child: entry.value),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
