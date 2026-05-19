import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import 'ghost_button.dart';

/// Renders a "Retry in N s…" countdown button, disabled until the timer
/// reaches zero — at which point it auto-fires [onRetry] (if non-null)
/// AND re-enables itself so the user can re-trigger manually.
///
/// Drop in where you've caught a [RateLimitFailure] with a non-null
/// `retryAfterSeconds`. Once the timer expires, the button label flips
/// to the regular [retryLabel] (or the localized "Retry").
///
/// ```dart
/// RateLimitCountdown(
///   seconds: failure.retryAfterSeconds!,
///   onRetry: () => cubit.refresh(),
/// )
/// ```
///
/// Edge cases handled:
///   * Reduce Motion respected — the seconds counter still updates, we
///     just don't animate the label transition.
///   * The widget's [State] cancels its timer on `dispose`, so embedding
///     in a [SnackBar] / dialog that gets dismissed doesn't leak.
///   * If the parent passes a zero-or-negative seconds value, the
///     button renders ready immediately.
class RateLimitCountdown extends StatefulWidget {
  const RateLimitCountdown({
    super.key,
    required this.seconds,
    required this.onRetry,
    this.retryLabel,
    this.autoFireOnZero = false,
  });

  /// Initial countdown in seconds — sourced from
  /// `RateLimitFailure.retryAfterSeconds`.
  final int seconds;

  /// Invoked on tap once the countdown reaches zero (and also auto-fired
  /// at zero when [autoFireOnZero] is true).
  final VoidCallback onRetry;

  /// Override the "Retry" label. Defaults to `context.tr.retry`.
  final String? retryLabel;

  /// When true, calls [onRetry] automatically the moment the countdown
  /// hits zero. Useful for surfaces where waiting was the only blocker;
  /// leave false (default) when you want the user to confirm.
  final bool autoFireOnZero;

  @override
  State<RateLimitCountdown> createState() => _RateLimitCountdownState();
}

class _RateLimitCountdownState extends State<RateLimitCountdown> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds.clamp(0, 3600);
    if (_remaining > 0) _startTimer();
  }

  @override
  void didUpdateWidget(covariant RateLimitCountdown old) {
    super.didUpdateWidget(old);
    // Reset if the parent passed a fresh count (new 429 hit).
    if (old.seconds != widget.seconds) {
      _timer?.cancel();
      setState(() => _remaining = widget.seconds.clamp(0, 3600));
      if (_remaining > 0) _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
      });
      if (_remaining == 0) {
        _timer?.cancel();
        if (widget.autoFireOnZero) widget.onRetry();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _remaining <= 0;
    final label = ready
        ? (widget.retryLabel ?? context.tr.retry)
        : context.tr.errorRateLimitedWithRetry(_remaining);
    return GhostButton(
      label: label,
      onPressed: ready ? widget.onRetry : null,
    );
  }
}
