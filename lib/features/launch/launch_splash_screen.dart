import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

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
  late final Animation<double> _wordmarkFade;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = AnimationController(
      vsync: this,
      duration: widget.minDuration,
    );

    _scale = Tween<double>(begin: 0.62, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _wordmarkSlide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _wordmarkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutQuad),
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
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, child) {
                    final scale = reduceMotion ? 1.0 : _scale.value;
                    final fade = reduceMotion ? 1.0 : _fade.value;
                    final glow = reduceMotion ? 1.0 : _glowPulse.value;
                    return Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: scale,
                        child: _LogoMark(glow: glow),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, child) {
                    final dy = reduceMotion ? 0.0 : _wordmarkSlide.value;
                    final fade = reduceMotion ? 1.0 : _wordmarkFade.value;
                    return Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: child,
                      ),
                    );
                  },
                  child: const _Wordmark(),
                ),
              ],
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

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.glow});
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.vivid,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandCyan.withValues(alpha: 0.55 * glow),
            blurRadius: 60 * glow,
            spreadRadius: 8 * glow,
          ),
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.35 * glow),
            blurRadius: 40 * glow,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Image.asset(
        'assets/img/saqqar-icon-foreground.png',
        width: 96,
        height: 96,
        fit: BoxFit.contain,
        // Asset is generated by tool/generate_app_icon.dart; if it's somehow
        // missing on a fresh checkout, fall back to a sparkle glyph so the
        // splash never renders empty.
        errorBuilder: (_, __, ___) => const Icon(
          Icons.auto_awesome,
          size: 64,
          color: Colors.white,
        ),
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
        ShaderMask(
          shaderCallback: (rect) =>
              AppGradients.vivid.createShader(Offset.zero & rect.size),
          child: const Text(
            'Saqqar',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
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
