import 'package:flutter/material.dart';

/// Spec §12 — 2.6 s scan-line gradient that sweeps horizontally across the
/// child. Used on typing / working chat bubbles to signal that Saqqar is
/// actively generating a response.
///
/// Renders the [child] inside a [Stack] with a translucent gradient on top.
/// The gradient is a thin (~40 % wide) bright band that travels from one
/// side to the other every 2.6 s. Respects MediaQuery `disableAnimations`:
/// when on, the overlay is omitted entirely (no static gradient is drawn,
/// since that would just be a faint highlight forever).
class ScanlineOverlay extends StatefulWidget {
  const ScanlineOverlay({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 2600),
  });

  final Widget child;
  final Color color;
  final BorderRadius? borderRadius;
  final Duration duration;

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
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

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius ?? BorderRadius.zero,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  // Sweep from -1.0 (off-screen start) to 2.0 (off-screen
                  // end) so the band fully enters and fully exits each cycle.
                  final t = (_ctrl.value * 3) - 1;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(t - 0.4, 0),
                        end: Alignment(t + 0.4, 0),
                        colors: [
                          widget.color.withValues(alpha: 0),
                          widget.color.withValues(alpha: 0.20),
                          widget.color.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
