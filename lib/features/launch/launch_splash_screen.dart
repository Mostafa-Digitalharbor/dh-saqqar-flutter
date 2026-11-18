import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../shared/widgets/saqqar_logo.dart';
import '../../core/theme/app_colors.dart';

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
    this.minDuration = AppDurations.agentPulse,
    this.maxDuration = AppDurations.splashMax,
    this.beforeComplete,
  });

  /// Runs after boot work, before [onComplete] — used for the first-launch
  /// language prompt shown over the splash.
  final Future<void> Function(BuildContext context)? beforeComplete;

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

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: AppDurations.splashEntrance,
    );
    _progress = AnimationController(vsync: this, duration: widget.minDuration);

    // Big zoom-in: tiny → full size with a smooth ease so the wordmark
    // appears to "expand into focus" instead of popping in.
    _scale = Tween<double>(
      begin: AppSplashMotion.logoScaleStart,
      end: AppScaleFractions.settled,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(
          0.0,
          AppSplashMotion.fadeIntervalEnd,
          curve: Curves.easeOut,
        ),
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
    if (widget.beforeComplete != null) {
      await widget.beforeComplete!(context);
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
      backgroundColor: AppColors.figCFF05070C,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SplashBackdrop(),
          Center(
            child: FadeTransition(
              opacity: reduceMotion ? const AlwaysStoppedAnimation(1) : _fade,
              child: ScaleTransition(
                scale: reduceMotion ? const AlwaysStoppedAnimation(1) : _scale,
                child: const SaqqarLogo(
                  height: 59,
                  forceVariant: Brightness.dark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Black canvas with the electric-blue corner glows from the launch frame.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key, this.blur = false});

  final bool blur;

  @override
  Widget build(BuildContext context) {
    Widget glow(Alignment c, double r, Color color) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: c,
            radius: r,
            colors: [color, color.withValues(alpha: AppAlphas.a0)],
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.figCFF03050A),
        glow(const Alignment(0.9, -1.1), 1.15, AppColors.figCFF2B5BD2),
        glow(const Alignment(-0.6, 1.1), 1.25, AppColors.figCFF2350B8),
        glow(const Alignment(-1.3, -0.2), 0.9, AppColors.figCFF12296A),
      ],
    );
  }
}
