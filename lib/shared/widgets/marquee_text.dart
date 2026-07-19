import 'package:flutter/material.dart';

/// Horizontally scrolling text — falls back to static [Text] when the
/// string fits inside the parent's width, and turns into a seamless
/// loop when it doesn't.
///
/// The loop is built from two copies of the text separated by [gap]; we
/// translate the pair by `-(textWidth + gap)` every cycle so as the
/// first copy scrolls out the second slides into place with no visible
/// seam. Direction follows [Directionality] so Arabic/Hebrew scroll the
/// other way naturally.
///
/// Use this for any narrow container where a localised label is longer
/// than the slot it's given — tab headers, chip rows, list-tile titles.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.gap = 32,
    this.pixelsPerSecond = 36,
    this.startDelay = const Duration(milliseconds: 800),
    this.alwaysScroll = false,
    this.maxCycles = 3,
  });

  final String text;
  final TextStyle? style;

  /// Used when the text fits — controls the static fallback's alignment.
  final TextAlign textAlign;

  /// When `true`, the marquee animates even if the text already fits the
  /// slot. Useful when a group of labels should all share the same
  /// motion for visual rhythm (e.g. a row of tab headers where you want
  /// all three to scroll together even though one of them is short).
  final bool alwaysScroll;

  /// Empty space between the two repeated copies of the text in marquee
  /// mode. Wider gaps read as "a clear break", narrower as "ticker".
  final double gap;

  /// Scroll speed. ~30–50 pps reads as a calm, readable ticker; higher
  /// gets agitated.
  final double pixelsPerSecond;

  /// Pause at the start of each cycle so the user sees the text from its
  /// natural starting position before motion begins — the eye anchors,
  /// then reads.
  final Duration startDelay;

  /// How many times the text scrolls past before settling back at its start
  /// and stopping for good.
  ///
  /// A marquee is an animation, and an animation that never ends means the
  /// app never stops producing frames: an idle Account screen was measured
  /// rendering ~62 frames per second with nobody touching it, purely because
  /// two labels were scrolling. Three passes is plenty to read a label, and
  /// the screen goes quiet afterwards.
  ///
  /// Set higher for a surface that genuinely needs a continuous ticker, but
  /// know that you are trading battery for it.
  final int maxCycles;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _lastCycleDistance = 0;

  /// Completed passes since the current geometry was configured.
  int _cyclesRun = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_onCycleComplete);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onCycleComplete)
      ..dispose();
    super.dispose();
  }

  Size _measureText(
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 1,
      textDirection: direction,
      // CRITICAL: pass the active text scaler so our measurement
      // matches what's actually rendered on screen. Without this,
      // devices with system text-scaling (1.25×+) render text wider
      // than we measured — we'd think it fits and silently clip,
      // never engaging the marquee.
      textScaler: textScaler,
    )..layout();
    return tp.size;
  }

  /// (Re)configures the controller for the active cycle distance. Guard
  /// with `_lastCycleDistance` so a parent rebuild that doesn't change
  /// the geometry doesn't restart the animation (which would snap the
  /// text back to its start every frame).
  void _ensureRunning(Duration cycleDuration, double cycleDistance) {
    // Same geometry as the run we already configured? Leave it alone —
    // whether it's still mid-scroll OR has finished its cycles and settled.
    //
    // Testing `_controller.isAnimating` alone is NOT enough, and getting this
    // wrong silently restores the very bug this class is trying to avoid:
    // once the marquee settles, `isAnimating` is false, so the next parent
    // rebuild (ProfileHero watches two cubits, so it rebuilds often) would
    // fall through and start the whole thing again — forever, a few cycles at
    // a time. The screen never goes quiet and the fix reads as working while
    // measuring identically to the bug.
    if (_lastCycleDistance == cycleDistance) return;

    _lastCycleDistance = cycleDistance;
    _cyclesRun = 0;
    _controller
      ..stop()
      ..duration = cycleDuration
      ..reset()
      ..forward();
  }

  /// Advances to the next cycle, or settles for good once [maxCycles] have
  /// played.
  ///
  /// This is what keeps a marquee from pinning the whole app at the display
  /// refresh rate forever. `repeat()` used to drive this, and an idle Account
  /// screen measured ~62 rendered frames per second with the user touching
  /// nothing — the UI thread never got to sleep, which costs battery on every
  /// screen a marquee appears on. A few passes is all anyone needs to read a
  /// label; after that the text parks at its start and the screen goes quiet.
  void _onCycleComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _cyclesRun++;
    if (_cyclesRun >= widget.maxCycles) {
      // Park at the natural reading position rather than mid-scroll.
      _controller.reset();
      return;
    }
    _controller
      ..reset()
      ..forward();
  }

  void _ensureStopped() {
    if (_controller.isAnimating) _controller.stop();
    _lastCycleDistance = 0;
    _cyclesRun = 0;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        widget.style ?? DefaultTextStyle.of(context).style;
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final textSize =
            _measureText(effectiveStyle, direction, textScaler);
        final textWidth = textSize.width;
        final textHeight = textSize.height;

        // Fits in the slot — no need to animate (unless `alwaysScroll`
        // was opted into); render plain text and make sure the
        // controller isn't burning frames in the background.
        // 1-pixel slack so a rounding mismatch between TextPainter and
        // the live render doesn't bounce a tight-fitting label between
        // marquee and static on every layout.
        final fits = textWidth <= maxWidth - 1 || !maxWidth.isFinite;
        if (fits && !widget.alwaysScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStopped());
          return Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
            maxLines: 1,
            softWrap: false,
            // Ellipsis (not clip) so any leftover overflow at least
            // shows "…" instead of silently chopping characters.
            overflow: TextOverflow.ellipsis,
          );
        }

        final cycleDistance = textWidth + widget.gap;
        final motionMs =
            (cycleDistance / widget.pixelsPerSecond * 1000).toInt();
        final delayMs = widget.startDelay.inMilliseconds;
        final cycleDuration = Duration(milliseconds: motionMs + delayMs);
        final delayFraction = delayMs / (motionMs + delayMs);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureRunning(cycleDuration, cycleDistance);
        });

        final isRtl = direction == TextDirection.rtl;

        // Constrain the marquee surface to the text's natural single-
        // line height. Without this, OverflowBox inherits the parent's
        // unbounded height (AppBar title slot is 0<=h<=Infinity) and
        // crashes with "given an infinite size during layout".
        return SizedBox(
          height: textHeight,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: textHeight,
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final raw = _controller.value;
                // Hold at 0 during the delay portion of the cycle, then
                // ramp 0→1 over the remaining portion.
                final t = raw < delayFraction
                    ? 0.0
                    : (raw - delayFraction) / (1 - delayFraction);
                final dx = (isRtl ? cycleDistance : -cycleDistance) * t;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: direction,
                children: [
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(width: widget.gap),
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
