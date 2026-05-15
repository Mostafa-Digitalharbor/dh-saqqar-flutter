import 'package:flutter/material.dart';

/// Spec §12 — typing cursor that blinks at 0.9 s in steps (no fade).
///
/// Renders as a thin 2 × 16 vertical bar in the supplied [color]. Drop it
/// at the end of a streaming assistant bubble so the user knows the agent
/// is still generating tokens. Respects MediaQuery `disableAnimations`
/// (driven by OS Reduce Motion): when on, it stays fully visible.
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({
    super.key,
    required this.color,
    this.width = 2,
    this.height = 16,
  });

  final Color color;
  final double width;
  final double height;

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return block;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Step opacity (no fade) so the blink reads as a cursor, not a pulse.
        final visible = _ctrl.value < 0.5;
        return Opacity(opacity: visible ? 1 : 0, child: child);
      },
      child: block,
    );
  }
}
