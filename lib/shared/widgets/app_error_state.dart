import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../extensions/context_extensions.dart';
import 'colored_icon_box.dart';
import 'ghost_button.dart';

/// Standard "something went wrong" surface with an optional retry button.
///
/// Used by [DataStateView] when a fetch fails, but also handy as a
/// stand-alone fallback (e.g. the chat screen's 404 plate). Sits inside
/// a soft danger-tinted card to read as "warning" without being alarming.
///
/// The message is whatever [ApiErrorMapper] returned — already localized
/// and user-friendly. Don't put raw exception text here.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onRetry,
    this.retryLabel,
  });

  /// The localized, user-facing error message. Required because every
  /// error state needs SOMETHING to read — a bare icon teaches the user
  /// nothing.
  final String message;

  /// Headline above the message. Defaults to "Something went wrong" via
  /// `tr.defaultApiError` if omitted.
  final String? title;

  /// Glyph rendered in the tinted circle at the top. Defaults to the
  /// generic warning icon.
  final IconData? icon;

  /// When non-null, renders a retry button at the bottom that invokes
  /// [onRetry] when tapped. Omit for terminal errors (e.g. 404 deep link)
  /// where retry won't help.
  final VoidCallback? onRetry;

  /// Override the retry button label. Defaults to a generic "Try again"
  /// from i18n.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final headline = title ?? context.tr.defaultApiError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredIconBox(
              icon: icon ?? AppIcons.warning,
              color: s.danger,
              size: 56,
              // A square with a half-side radius IS a circle — same pixels
              // as the `BoxShape.circle` this replaced.
              radius: 28,
              iconSize: 26,
              backgroundAlpha: 0.12,
              borderAlpha: 0.32,
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: s.muted,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              GhostButton(
                label: retryLabel ?? context.tr.retry,
                icon: AppIcons.refresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
