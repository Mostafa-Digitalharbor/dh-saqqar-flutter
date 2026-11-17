import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_sizes.dart';

/// Lightweight entrance motion for cards and list rows.
///
/// Tuned to feel "professional and attractive": items fade + slide in
/// quickly with a hairline scale ramp so they read as "settling into
/// place" rather than "popping in from offscreen". Stagger between
/// adjacent items is capped at [maxStaggerSteps] so on long lists a
/// row at index 100 doesn't sit for 4 seconds with `opacity = 0`
/// before its turn arrives — every row animates in well under 300 ms
/// of its first build.
///
/// Respects `MediaQuery.disableAnimations` (system reduce-motion).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, AppMotionTravel.rise),
    this.duration = const Duration(milliseconds: 260),
    this.staggerStep = const Duration(milliseconds: 28),
    this.maxStaggerSteps = 5,
    this.scaleFrom = 0.985,
  });

  final Widget child;

  /// Position in the parent's children list — drives the staggered
  /// start so the first item lands fastest and later items follow.
  /// Pass `0` to disable stagger.
  final int index;

  /// Initial offset applied via `Transform.translate`. Defaults to a
  /// gentle 8 dp downward — items rise into place instead of leaping.
  final Offset offset;

  /// Animation length. 260 ms reads as "snappy" — long enough to be
  /// felt, short enough that fast scrolling doesn't reveal half-faded
  /// rows behind the user's thumb.
  final Duration duration;

  /// Per-index stagger delay. Items animate in with this many
  /// milliseconds between their starts, up to [maxStaggerSteps].
  final Duration staggerStep;

  /// Hard cap on how many staggered steps can compound. Past this,
  /// every additional row uses the cap (so a list of 100 rows still
  /// has bounded total animation time).
  final int maxStaggerSteps;

  /// Items rise from this scale toward 1.0. Defaults to 0.985 — barely
  /// perceptible per item, but together gives the list a soft
  /// "settling" texture.
  final double scaleFrom;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: widget.scaleFrom, end: 1).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      return;
    }

    final steps = widget.index < widget.maxStaggerSteps
        ? widget.index
        : widget.maxStaggerSteps;
    _delayTimer = Timer(widget.staggerStep * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
    );
  }
}
