import 'package:flutter/material.dart';

/// Animates a child away when [dismissing] flips to `true`. Slides the
/// content out to the end side, fades it to 0, and collapses its vertical
/// space — so removing an item from a list feels like a swipe rather than
/// a pop.
///
/// After the outgoing animation completes, [onDismissed] is called once.
/// Typical usage: keep the data in place, set `dismissing: true`, and let
/// [onDismissed] remove the row from the underlying list. The widget
/// disposes itself once the parent stops rendering it.
///
/// Respects MediaQuery `disableAnimations` — when on, [onDismissed] fires
/// synchronously on the next microtask and no animation runs.
class AnimatedDismiss extends StatefulWidget {
  const AnimatedDismiss({
    super.key,
    required this.child,
    required this.dismissing,
    required this.onDismissed,
    this.duration = const Duration(milliseconds: 240),
  });

  final Widget child;
  final bool dismissing;
  final VoidCallback onDismissed;
  final Duration duration;

  @override
  State<AnimatedDismiss> createState() => _AnimatedDismissState();
}

class _AnimatedDismissState extends State<AnimatedDismiss>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    if (widget.dismissing) _startDismiss();
  }

  @override
  void didUpdateWidget(AnimatedDismiss old) {
    super.didUpdateWidget(old);
    if (widget.dismissing && !old.dismissing) _startDismiss();
  }

  void _startDismiss() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _fire();
      return;
    }
    _ctrl.forward().whenCompleteOrCancel(_fire);
  }

  void _fire() {
    if (_fired || !mounted) return;
    _fired = true;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = _ctrl.value;
        // Opacity goes 1→0 across the full duration. Slide pushes the card
        // out to the end side (RTL-aware via SlideTransition). Size factor
        // collapses to 0 at the very end so the gap closes only once the
        // card is invisible.
        return ClipRect(
          child: Align(
            heightFactor: 1 - Curves.easeIn.transform(v).clamp(0.0, 1.0),
            child: Opacity(
              opacity: 1 - v,
              child: Transform.translate(
                offset: Offset(24 * v * _endSign(context), 0),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }

  // Slide outward: rightwards in LTR, leftwards in RTL.
  double _endSign(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl ? -1 : 1;
  }
}
