import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_sizes.dart';
import '../../shared/widgets/saqqar_logo.dart';
import '../../core/theme/app_radius.dart';

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
      duration: AppDurations.splashEntrance,
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
    // Pull brightness from the active MaterialApp theme so the splash
    // tracks the user's saved preference (Theme cubit hydrates from
    // SharedPreferences synchronously in `main.dart`, so first paint
    // already has the correct brightness). Hot restart preserves the
    // preference, which was the bug the user hit: the splash was
    // hardcoded to dark and ignored the active theme.
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? AppColors.lightBg : AppColors.darkBg;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Plain splash backdrop (the animated cyan/purple radial glow was
          // retired on user request 2026-07-06 for a cleaner look) — the
          // Scaffold's solid [bg] shows through, and the logo zoom-in below
          // carries the motion on its own.
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
                // The framing card settles in a touch more gently than the
                // logo's dramatic zoom: a small 0.94 → 1.0 scale so the card
                // never "pops", while the logo keeps its full 0.25 → 1.0
                // expand-into-focus inside it.
                final cardT = reduceMotion
                    ? 1.0
                    : Curves.easeOut.transform(_entrance.value);
                final cardScale = 0.94 + 0.06 * cardT;
                return Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: cardScale,
                    child: _SplashLogoCard(
                      isLight: isLight,
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          scale: scale,
                          child: _Wordmark(isLight: isLight),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: AppSpacing.s64,
            child: _ProgressBar(animation: _progress),
          ),
        ],
      ),
    );
  }
}

/// Thin, elegant frame behind the zooming logo. Deliberately understated so
/// it reads as a refined mount for the mark, not a competing surface: a
/// faint surface fill, a hairline border, generously rounded corners, and a
/// soft drop shadow for a little depth. Theme-aware via [isLight].
class _SplashLogoCard extends StatelessWidget {
  const _SplashLogoCard({required this.isLight, required this.child});

  final bool isLight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fill = isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final border = isLight ? AppColors.lightBorder : AppColors.darkBorder;
    final maxW = MediaQuery.sizeOf(context).width * AppFractions.splashWordmark;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW.clamp(0, 420)),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s34,
          vertical: AppSpacing.s30,
        ),
        decoration: BoxDecoration(
          // Barely-there fill so the card lifts off the plain backdrop
          // without looking like a solid panel.
          color: fill.withValues(alpha: AppAlphaPairs.splashFill.resolve(isDark: !isLight)),
          borderRadius: AppRadius.splashPlateR,
          border: Border.all(
            color: border.withValues(alpha: AppAlphaPairs.splashBorder.resolve(isDark: !isLight)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.scrimBase.withValues(alpha: AppAlphaPairs.splashShadow.resolve(isDark: !isLight)),
              blurRadius: AppShadowSizes.blurModal,
              offset: const Offset(0, AppShadowSizes.dropHalo),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    // The brand lockup is a wide (~3.9:1) hexagon-mark + wordmark, so size
    // it by available width — cap the height at 96 dp but shrink it so the
    // lockup never runs past ~78 % of the screen on narrow phones.
    // Sized against a slightly tighter fraction than before (was 0.78) so
    // the lockup sits comfortably inside the framing card's padding without
    // crowding its rounded edges on narrow phones.
    final maxW = MediaQuery.sizeOf(context).width * AppFractions.splashTagline;
    final logoHeight = (maxW / 3.9).clamp(44.0, 88.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand lockup — force the variant that contrasts with the splash
        // backdrop: navy + cyan strokes on the light/white backdrop, white
        // strokes on the dark navy one.
        SaqqarLogo(
          height: logoHeight,
          forceVariant: isLight ? Brightness.light : Brightness.dark,
        ),
        const SizedBox(height: AppSpacing.s10),
        Text(
          context.tr.appTagline,
          style: TextStyle(
            color: isLight ? AppColors.lightMuted : AppColors.darkMuted,
            fontSize: AppFontSizes.dense,
            fontWeight: FontWeight.w500,
            letterSpacing: AppLetterSpacing.label,
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
        width: AppControlSizes.splashProgressWidth,
        height: AppControlSizes.splashProgressHeight,
        child: ClipRRect(
          borderRadius: AppRadius.pillR,
          child: ColoredBox(
            color: AppColors.brandCyan.withValues(alpha: AppAlphas.a18),
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

