import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../shared/widgets/saqqar_logo.dart';

/// Custom in-app launch screen.
///
/// Native splash (managed by `flutter_native_splash`) shows the bare logo
/// instantly while Flutter boots. The moment Flutter is ready, we hand off
/// to this widget which:
///
/// 1. Renders the same logo position (so the transition is seamless — the
///    user can't tell where native splash ends and this begins).
/// 2. Plays a 900 ms zoom-in (0.6 → 1.0) + soft fade.
/// 3. Slides in the "Saqqar" wordmark + tagline.
/// 4. Shows a thin cyan loading bar for ~1.4 s while [onReady] does any
///    boot work (warm caches, restore session, etc.).
/// 5. Calls [onReady] then transitions out via [onComplete].
///
/// The total on-screen time is bounded — even if `onReady` resolves early,
/// the splash stays for at least [minDuration] so the animation has time
/// to land. Conversely if `onReady` takes longer the splash extends to
/// match (capped at [maxDuration]).
class LaunchSplashScreen extends StatefulWidget {
  const LaunchSplashScreen({
    super.key,
    required this.onComplete,
    this.onReady,
    this.minDuration = const Duration(milliseconds: 1400),
    this.maxDuration = const Duration(seconds: 4),
  });

  final VoidCallback onComplete;
  final Future<void> Function()? onReady;
  final Duration minDuration;
  final Duration maxDuration;

  @override
  State<LaunchSplashScreen> createState() => _LaunchSplashScreenState();
}

class _LaunchSplashScreenState extends State<LaunchSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _progress;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _wordmarkSlide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      // Longer than the old 900 ms so the dramatic zoom has room to
      // breathe — the wordmark starts at ~25 % of its final size and
      // grows smoothly, which would feel rushed at the old duration.
      duration: const Duration(milliseconds: 1600),
    );
    _progress = AnimationController(
      vsync: this,
      duration: widget.minDuration,
    );

    // Big zoom-in: tiny → full size with a smooth ease so the wordmark
    // appears to "expand into focus" instead of popping in.
    _scale = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _wordmarkSlide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entrance.forward();
    _progress.forward();
    _bootSequence();
  }

  Timer? _timeoutTimer;
  Timer? _holdTimer;

  Future<void> _bootSequence() async {
    final stopwatch = Stopwatch()..start();
    final readyFuture = widget.onReady?.call() ?? Future<void>.value();

    // Race the ready future against a hard deadline so a hung onReady never
    // traps the user on the splash. Use a cancellable Timer (not
    // Future.delayed) so the pending callback is dropped the moment ready
    // wins — otherwise the timer keeps a strong reference until maxDuration
    // elapses, which trips the test framework's "pending timer" check and
    // delays GC in prod.
    final completer = Completer<void>();
    _timeoutTimer = Timer(widget.maxDuration, () {
      if (!completer.isCompleted) completer.complete();
    });
    unawaited(
      readyFuture.whenComplete(() {
        if (!completer.isCompleted) completer.complete();
      }),
    );
    await completer.future;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    final remaining = widget.minDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      final holdCompleter = Completer<void>();
      _holdTimer = Timer(remaining, () {
        if (!holdCompleter.isCompleted) holdCompleter.complete();
      });
      await holdCompleter.future;
      _holdTimer = null;
    }

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    _entrance.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AmbientBackdrop(animation: _entrance),
          // Wordmark only — the circular "S" icon was retired on user
          // request. The entrance scale/fade animation that used to land
          // on the icon now lands on the wordmark itself so the splash
          // still feels alive instead of popping flat.
          Center(
            child: AnimatedBuilder(
              animation: _entrance,
              builder: (context, _) {
                final scale = reduceMotion ? 1.0 : _scale.value;
                final fade = reduceMotion ? 1.0 : _fade.value;
                final dy = reduceMotion ? 0.0 : _wordmarkSlide.value;
                return Opacity(
                  opacity: fade,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: const _Wordmark(),
                    ),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 64,
            child: _ProgressBar(animation: _progress),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SAQQÂR wordmark — bumped to 96 dp so the zoom-in lands on a
        // genuinely large hero. Force the dark variant (white strokes)
        // because the splash always sits on a dark navy backdrop
        // regardless of the system theme.
        const SaqqarLogo(height: 96, forceVariant: Brightness.dark),
        const SizedBox(height: 10),
        Text(
          context.tr.appTagline,
          style: const TextStyle(
            color: AppColors.darkMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ColoredBox(
            color: AppColors.brandCyan.withValues(alpha: 0.18),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: animation.value.clamp(0.0, 1.0),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.vivid,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft cyan→purple gradient that breathes behind the logo. Driven by the
/// same entrance controller so it lands in sync with the wordmark.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOut.transform(animation.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 0.95 + 0.15 * t,
              colors: [
                AppColors.brandCyan.withValues(alpha: 0.18 * t),
                AppColors.brandPurple.withValues(alpha: 0.10 * t),
                AppColors.darkBg,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        );
      },
    );
  }
}
