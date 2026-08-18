import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.12 — dashed-bordered empty plate.
///
/// Flutter has no first-class dashed border, so we paint one with a
/// [CustomPainter]. Cheap enough since empty states are rare.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon,
    this.action,
  });

  final String title;
  final String? body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return CustomPaint(
      painter: _DashedBorderPainter(color: s.border),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s18,
          vertical: AppSpacing.s24,
        ),
        decoration: BoxDecoration(
          color: s.surface2,
          borderRadius: AppRadius.rowR,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppIconSizes.emptyState, color: s.muted),
              const SizedBox(height: AppSpacing.s12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: (context.text.titleMedium ?? const TextStyle()).copyWith(
                color: s.text,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.s6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: (context.text.bodySmall ?? const TextStyle()).copyWith(
                  color: s.muted,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.s16), action!],
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dash = 6.0;
    const gap = AppSpacing.s4;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.row),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final m in metrics) {
      double distance = 0;
      while (distance < m.length) {
        final next = (distance + dash).clamp(0, m.length).toDouble();
        canvas.drawPath(m.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}
