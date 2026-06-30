import 'package:flutter/material.dart';

/// A small square chip with a tinted background, optional hairline border,
/// and a centered icon — the recurring "icon tile" leading the action /
/// artifact / attachment cards.
///
/// Every call site used to hand-roll the same `Container` + `BoxDecoration`
/// (background at ~14% of an accent [color], border at ~30%, centered
/// [Icon]). This collapses that boilerplate to one widget while preserving
/// each site's exact look via the size/radius/alpha knobs.
///
/// Pass [borderAlpha] `null` to omit the border entirely (e.g. the compact
/// attachment chip).
class ColoredIconBox extends StatelessWidget {
  const ColoredIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.radius = 11,
    this.iconSize = 18,
    this.backgroundAlpha = 0.14,
    this.borderAlpha = 0.30,
  });

  final IconData icon;

  /// Accent the box is tinted with — applied to the background, border, and
  /// the icon itself.
  final Color color;

  final double size;
  final double radius;
  final double iconSize;
  final double backgroundAlpha;

  /// Border opacity, or `null` for no border.
  final double? borderAlpha;

  @override
  Widget build(BuildContext context) {
    final border = borderAlpha;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: border == null
            ? null
            : Border.all(color: color.withValues(alpha: border)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
