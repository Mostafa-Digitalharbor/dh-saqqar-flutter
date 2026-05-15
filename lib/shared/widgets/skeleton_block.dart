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

    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (reduceMotion) return block;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Sweep a soft highlight from -1 to 2 (slightly past both edges) so
        // the shimmer enters from one side and leaves on the other.
        final t = (_ctrl.value * 3) - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 0.6, 0),
              end: Alignment(t + 0.6, 0),
              colors: [s.surface2, s.surface3, s.surface2],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
