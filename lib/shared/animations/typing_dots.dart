import 'package:flutter/material.dart';

/// Spec §12 — three-dot indicator with a 1 s staggered pulse.
///
/// Two motion styles: opacity pulse (default) or a vertical [bounce] where
/// each dot hops up and down. Respects MediaQuery's `disableAnimations`
/// (driven by OS Reduce Motion): when on, the dots render statically at full
/// opacity with no motion.
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    required this.color,
    this.dotSize = 6,
    this.bounce = false,
  });

  final Color color;
  final double dotSize;

  /// When true the dots hop up/down instead of fading in/out. Used by the
  /// conversation-list "Saqqar is working" preview.
  final bool bounce;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(),
          SizedBox(width: widget.dotSize * 0.7),
          _dot(),
          SizedBox(width: widget.dotSize * 0.7),
          _dot(),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _animatedDot(0),
            SizedBox(width: widget.dotSize * 0.7),
            _animatedDot(0.18),
            SizedBox(width: widget.dotSize * 0.7),
            _animatedDot(0.36),
          ],
        );
      },
    );
  }

  Widget _animatedDot(double delay) {
    // Shift the unit interval by `delay`, wrapping around so each dot leads
    // the next by the configured stagger.
    final t = (_ctrl.value - delay) % 1.0;
    // Map the wrapped interval onto a soft 0 → 1 → 0 curve.
    final eased = Curves.easeInOut.transform(
      t < 0.5 ? t * 2 : (1 - t) * 2,
    );
    if (widget.bounce) {
      // Hop up (negative dy) at the peak, back to baseline at the troughs.
      return Transform.translate(
        offset: Offset(0, -eased * widget.dotSize * 0.8),
        child: _dot(),
      );
    }
    final opacity = 0.35 + (1 - 0.35) * eased;
    return Opacity(opacity: opacity, child: _dot());
  }

  Widget _dot() {
    return Container(
      width: widget.dotSize,
      height: widget.dotSize,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
  }
}
