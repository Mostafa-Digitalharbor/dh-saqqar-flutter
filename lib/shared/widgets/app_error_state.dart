import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';
import 'colored_icon_box.dart';
import '../fig/fig.dart';

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

    // `default_api_error` and `error_unknown` are the same sentence in both
    // locales — deliberately, they answer the same question. So an error we
    // cannot classify (the single most common failure) used to stack the
    // headline on an identical body:
    //
    //     Something went wrong. Please try again.
    //     Something went wrong. Please try again.
    //
    // which reads as a rendering bug and pushes the retry button off small
    // screens for no information. Collapse to one line when they match, and
    // drop an empty message rather than reserving blank space for it.
    final body = message.trim();
    final showBody = body.isNotEmpty && body != headline.trim();

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredIconBox(
            icon: icon ?? AppIcons.warning,
            color: s.danger,
            size: AppIconSizes.errorHero,
            // A square with a half-side radius IS a circle — same pixels
            // as the `BoxShape.circle` this replaced.
            radius: AppRadius.splashPlate,
            iconSize: AppIconSizes.boxGlyphHero,
            backgroundAlpha: 0.12,
            borderAlpha: 0.32,
          ),
          const SizedBox(height: AppSpacing.s14),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: AppLetterSpacing.heading,
            ),
          ),
          if (showBody) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: s.muted,
                height: AppLineHeights.reading,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.s18),
            FigButton.compact(
              secondary: true,
              label: retryLabel ?? context.tr.retry,
              icon: AppIcons.refresh,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );

    // Centred, but scrollable when it can't fit.
    //
    // The icon + headline + body + retry stack is ~200 px tall, and a phone in
    // landscape is 320 px minus the app bar — so at 1.3× text this overflowed
    // the bottom rather than letting the user reach the retry button, which is
    // the one control an error state exists to offer. Found by the pricing
    // screen's cell in `screen_responsive_sweep_test.dart`.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded height means a scrolling parent already owns the axis
        // (the devices screen puts this inside a ListView). Adding our own
        // there would nest two scrollables and break pull-to-refresh.
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          child: ConstrainedBox(
            // Fill the viewport so short content still centres, and grow past
            // it — the scroll only engages once it has to.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
