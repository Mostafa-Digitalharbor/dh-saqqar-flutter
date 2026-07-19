import 'package:flutter/material.dart';

/// A horizontally-scrolling row of chips that sizes itself to its content —
/// including when the user scales text up.
///
/// ## Why this exists
///
/// A horizontal `ListView` needs a bounded cross-axis extent, so every chip
/// strip reached for `SizedBox(height: 52)` and hardcoded a guess. That
/// silently CLIPS at large text scales: a horizontal list hands children a
/// *tight* cross-axis constraint, and `RenderParagraph` sizes to
/// `constraints.constrain(text)` — it reports the clamped height but paints
/// the full one. The symptom is cut-off Arabic descenders with **no overflow
/// banner**, which is exactly why it went unnoticed.
///
/// A `Row` inside a horizontal `SingleChildScrollView` has no such
/// constraint: it takes the height its chips actually need, at whatever
/// scale they're rendered. No magic number to keep in sync with the padding
/// and font metrics — the layout derives it.
///
/// The tradeoff is that a `Row` builds every child eagerly where a
/// `ListView` builds lazily. That's the right trade here: these strips hold
/// a handful of filter chips, and laziness across ~4 items buys nothing
/// while the fixed height costs correctness. Reach for a `ListView` again if
/// a strip ever grows to dozens of items.
///
/// ## Why not `TextScaleLock`
///
/// [TextScaleLock] is the other fix, and it's right for `MiniChip` — whose
/// doc scopes it to "supplementary status (LIVE, READ-ONLY, AUTO)", i.e.
/// decorative badges nobody needs to read closely. These strips hold real,
/// tappable filter labels. Freezing them at 1.0 would deny the accessibility
/// setting the one job it has, for the users who most need it.
class ChipStrip extends StatelessWidget {
  const ChipStrip({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.spacing = 8,
    this.physics,
  });

  final List<Widget> children;

  /// Padding inside the scroll view, so leading/trailing chips clear the
  /// edge while still scrolling under it.
  final EdgeInsetsGeometry padding;

  /// Gap between adjacent chips.
  final double spacing;

  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: physics,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}
