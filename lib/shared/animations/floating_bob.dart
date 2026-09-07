import 'dart:math' show pi;

import 'package:flutter/material.dart';

/// Gentle vertical "bob" — translates a child by ±[amplitude] px on a slow
/// sine curve. Used to make hero avatars on empty/welcome states feel
/// alive without distracting from the rest of the screen.
///
/// Respects MediaQuery `disableAnimations`: when on, the child renders
/// stationary at its rest position.
///
/// Bobs [cycles] times, then parks at rest. An empty list is a RESTING
/// state — a user with no conversations can sit on that screen indefinitely
/// — so an unbounded bob meant the app never stopped rendering, purely for
/// decoration. A few bobs deliver the "alive" feeling; forever just costs
/// battery.
class FloatingBob extends StatefulWidget {
  const FloatingBob({
    super.key,
    required this.child,
    this.amplitude = 4,
    this.duration = const Duration(milliseconds: 3200),
    this.cycles = 3,
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  /// Full sine cycles to run before settling at the rest position.
  final int cycles;

  @override
  State<FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<FloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  int _cyclesDone = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener(_onCycleEnd);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start here, not in initState, because the decision needs MediaQuery.
    //
    // Under Reduce Motion `build` returns the child unchanged — nothing on
    // screen moves — but the controller would still tick every vsync and
    // schedule frames for an animation nobody can see. That's the worst
    // version of this bug: it burns battery precisely for the users who
    // turned motion OFF, often to save battery. Mirrors the guard on the
    // brand-bar pulse in `page_scaffold.dart`.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
      return;
    }
    if (!_ctrl.isAnimating && _cyclesDone < widget.cycles) {
      _ctrl.forward();
    }
  }

  void _onCycleEnd(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _cyclesDone++;
    if (_cyclesDone >= widget.cycles) {
      // value 0 == sin(0) == the rest position, so the child lands exactly
      // where a non-animating build would place it.
      _ctrl.value = 0;
      return;
    }
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _ctrl
      ..removeStatusListener(_onCycleEnd)
      ..dispose();
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
        final radians = _ctrl.value * 2 * pi;
        final offset = (_sin(radians)) * widget.amplitude;
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  // Small inline sine (Taylor approx, normalized to [-π, π]) — good enough
  // for animation work without pulling in the full dart:math sin().
  double _sin(double x) {
    var t = x % (2 * pi);
    if (t > pi) t -= 2 * pi;
    final t2 = t * t;
    return t * (1 - t2 / 6 + t2 * t2 / 120);
  }
}
