import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';

/// Spec §12 — 6×6 round dot, 2s opacity pulse.
///
/// Respects MediaQuery's `disableAnimations` (driven by OS Reduce Motion).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppDurations.pulseDot,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.repeat(reverse: true);
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
      return _staticDot();
    }

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: _staticDot(),
    );
  }

  Widget _staticDot() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
  }
}
