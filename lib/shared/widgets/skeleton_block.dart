import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// Base shimmer block used by list-row skeletons.
///
/// A rounded rectangle filled with a subtly animated horizontal gradient
/// (from `surface2` → `surface3` → `surface2`). Respects MediaQuery
/// `disableAnimations` (driven by OS Reduce Motion) and falls back to a
/// static plate.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  /// Convenience constructor for a circular avatar-shaped block.
  factory SkeletonBlock.circle({Key? key, required double size}) {
    return SkeletonBlock(
      key: key,
      width: size,
      height: size,
      radius: size / 2,
    );
  }

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Edge tone — a fraction darker than `surface2` so the gradient
    // bookends with the appearance of recessed corners. Keeps the
    // block reading as "a slot waiting to be filled" instead of "a
    // flat rectangle". Computed once outside the animator so the
    // shimmer frame doesn't pay for the color math each tick.
    final edgeTone = Color.lerp(s.surface2, s.cardBorder, 0.35) ?? s.surface2;
    final border = Border.all(
      color: s.cardBorder.withValues(alpha: 0.45),
      width: 0.6,
    );

    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(widget.radius),
        border: border,
      ),
    );

    if (reduceMotion) return block;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Sweep a soft highlight from -1 to 2 (slightly past both edges)
        // so the shimmer enters from one side and leaves on the other.
        // 5-stop gradient (edge → mid → highlight → mid → edge) gives
        // the sweep a faux-curvature: the block looks like it's
        // catching light on a soft cylinder instead of being a flat
        // plate. Edge tone is just dim enough to imply depth without
        // making the skeleton look bruised.
        final t = (_ctrl.value * 3) - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: border,
            gradient: LinearGradient(
              begin: Alignment(t - 0.7, 0),
              end: Alignment(t + 0.7, 0),
              colors: [
                edgeTone,
                s.surface2,
                s.surface3,
                s.surface2,
                edgeTone,
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}
