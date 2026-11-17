import 'package:flutter/material.dart';

import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

/// Branded loading indicator with an optional label.
///
/// Used by [DataStateView] and any screen-level "fetching data…" surface.
/// The spinner uses [SaqqarThemeExtension.brandCyan] so it ties back to
/// the brand without needing every caller to thread theme colors.
///
/// Variants:
///   * `AppLoadingState()` — centered spinner, no text.
///   * `AppLoadingState(label: 'Loading projects…')` — spinner + label,
///     vertically stacked. Use when the wait is meaningful enough that
///     the user benefits from knowing what's happening.
///   * `AppLoadingState.inline()` — tiny 16 dp spinner sized for use
///     inside a row (e.g. next to a button label while a save is in
///     flight).
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label,
    this.size = AppControlSizes.spinner,
  }) : _inline = false;

  /// Compact in-line spinner — same color, scaled for use inside buttons
  /// or list rows.
  const AppLoadingState.inline({
    super.key,
    this.size = AppControlSizes.spinnerInline,
  }) : label = null,
       _inline = true;

  final String? label;
  final double size;
  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: _inline ? 2 : 2.6,
        valueColor: AlwaysStoppedAnimation(s.brandCyan),
      ),
    );

    if (_inline) return spinner;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          if (label != null) ...[
            const SizedBox(height: AppSpacing.s14),
            Text(
              label!,
              style: context.text.bodySmall?.copyWith(color: s.muted),
            ),
          ],
        ],
      ),
    );
  }
}
