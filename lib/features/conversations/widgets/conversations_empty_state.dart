import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/animations/floating_bob.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/theme/app_radius.dart';

/// Friendly empty state for the Conversations list — vivid Saqqar mark,
/// inviting headline, supporting copy, and a primary "Start a conversation"
/// CTA that opens a fresh chat.
///
/// More welcoming than the generic [EmptyState] shell because this is the
/// first thing a brand-new user sees if no demo data is preloaded.
class ConversationsEmptyState extends StatelessWidget {
  const ConversationsEmptyState({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s28),
      child: Column(
        children: [
          FloatingBob(
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.vivid,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(AppIcons.chats, color: Colors.white, size: AppIconSizes.emptyState),
            ),
          ),
          const SizedBox(height: AppSpacing.s22),
          Text(
            context.tr.askSaqqarAnything,
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
            child: Text(
              context.tr.workspaceSummaryBody,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: s.muted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s22),
          SizedBox(
            width: 220,
            // Breathing cyan glow under the CTA — pulls the user's eye
            // to the "start a conversation" affordance on the first
            // launch when the screen is otherwise empty. Slow tempo so
            // it reads as "available", not "urgent / error".
            child: _BreathingGlow(
              color: s.brandCyan,
              child: PrimaryButton(
                label: context.tr.newConversation,
                icon: AppIcons.plus,
                expand: true,
                onPressed: onStart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps [child] with a slow, soft outer glow that breathes between
/// minimum and maximum opacity. Picks up `MediaQuery.disableAnimations`
/// (reduce-motion) and freezes at the midpoint — the user still gets
/// the visual hint of "this is the primary action" without the motion.
class _BreathingGlow extends StatefulWidget {
  const _BreathingGlow({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<_BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<_BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.breathingGlow,
  );

  /// Breathes this many full in-out cycles, then parks at rest. A `repeat()`
  /// glow never stopped, so the empty Conversations screen — a RESTING state a
  /// user with no chats can sit on indefinitely — rendered ~60 fps forever,
  /// re-rasterizing an animated `BoxShadow` blur every frame purely for
  /// decoration. Mirrors the bounded [FloatingBob] / marquee lesson: a few
  /// pulses draw the eye to the CTA, then the screen goes quiet.
  static const _maxCycles = 4;
  int _cyclesDone = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Reached full glow — breathe back down.
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      // Back at rest = one full cycle. Park once we've pulsed enough.
      _cyclesDone++;
      if (_cyclesDone < _maxCycles) {
        _controller.forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under Reduce Motion the glow holds at a constant `t = 0.5`, so any
    // controller motion would rebuild identical frames. Stop it; otherwise
    // breathe for a bounded number of cycles.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating && _cyclesDone < _maxCycles) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Isolate the animated glow's repaint so its per-frame shadow doesn't
    // invalidate the empty-state content it wraps.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = reduceMotion
              ? 0.5
              : Curves.easeInOut.transform(_controller.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.inputR,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.18 + 0.22 * t),
                  blurRadius: 18 + 10 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: child,
          );
        },
      ),
    );
  }
}
