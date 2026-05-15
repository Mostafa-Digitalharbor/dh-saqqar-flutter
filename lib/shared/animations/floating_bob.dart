import 'package:flutter/material.dart';

/// Gentle vertical "bob" — translates a child by ±[amplitude] px on a slow
/// sine curve. Used to make hero avatars on empty/welcome states feel
/// alive without distracting from the rest of the screen.
///
/// Respects MediaQuery `disableAnimations`: when on, the child renders
/// stationary at its rest position.
class FloatingBob extends StatefulWidget {
  const FloatingBob({
    super.key,
    required this.child,
    this.amplitude = 4,
    this.duration = const Duration(milliseconds: 3200),
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<FloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
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
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Map _ctrl.value [0,1] onto sin(2πt) ∈ [-1, 1], then scale by
        // amplitude. Smooth, never reaches a sharp peak.
        final radians = _ctrl.value * 2 * 3.141592653589793;
        final offset = (_sin(radians)) * widget.amplitude;
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  // Small inline sine to avoid pulling in dart:math just for one call.
  double _sin(double x) {
    // Taylor approx good enough for animation work, normalized to [-π, π].
    var t = x % (2 * 3.141592653589793);
    if (t > 3.141592653589793) t -= 2 * 3.141592653589793;
    final t2 = t * t;
    return t * (1 - t2 / 6 + t2 * t2 / 120);
  }
}
