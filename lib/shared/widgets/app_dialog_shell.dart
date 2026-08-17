import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';
import '../../core/theme/app_sizes.dart';

/// The app's standard modal dialog chrome: surface card, hairline border,
/// rounded clip, and a 3 px accent bar along the top edge.
///
/// [ConfirmDialog] and the live-environment warning were byte-identical
/// down to the comment explaining the inset — including the part that is
/// easy to get wrong (see [insetPadding] below). Any dialog that wants the
/// house style should build on this rather than a fourth copy.
///
/// Supplies chrome only. Content, buttons and padding stay with the caller,
/// because that is where the two existing dialogs genuinely differ.
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.child,
    this.accent,
    this.elevated = false,
    this.maxWidth = 380,
  });

  /// Dialog body — usually a `Column(mainAxisSize: .min)` or a
  /// `SingleChildScrollView`. Wrapped in a [Flexible] so the accent bar
  /// stays pinned while long content scrolls instead of overflowing.
  final Widget child;

  /// Gradient for the 3 px top bar. Defaults to the brand CTA gradient;
  /// pass a danger gradient for destructive prompts. A gradient rather
  /// than a flat colour because both existing dialogs use one.
  final Gradient? accent;

  /// Danger-tinted bar for destructive prompts — the shape both callers
  /// were hand-rolling identically.
  static Gradient dangerAccent(BuildContext context) {
    final danger = context.saqqar.danger;
    return LinearGradient(
      colors: [danger, danger.withValues(alpha: 0.7)],
    );
  }

  /// Adds the heavy drop shadow [ConfirmDialog] uses. Off by default —
  /// dialogs stacked over an already-dim barrier don't need it.
  final bool elevated;

  /// Cap so the card doesn't stretch edge-to-edge on tablets/foldables.
  final double maxWidth;

  /// Horizontal AND vertical insets, deliberately.
  ///
  /// `vertical: 24` is load-bearing, not cosmetic: passing only
  /// `horizontal` sets the vertical inset to 0, which lets the dialog claim
  /// the FULL viewport height. An unscrollable column then has nothing to
  /// push back against and overflows — in landscape (~320 px tall), or with
  /// a long user-supplied name at 1.4× Arabic. Keep both axes.
  static const insetPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.s32, vertical: AppSpacing.s24);

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: AppRadius.cardR,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: AppRadius.cardR,
              border: Border.all(color: s.cardBorder),
              // `modalShadow` carries the same 36/16 lift this had, and adds
              // the light-theme half it was missing: the hardcoded colour was
              // 55%-opaque near-black in *both* themes, so a dialog on a white
              // page cast a shadow darker than any other surface in the app.
              boxShadow: elevated ? s.modalShadow : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 3 px gradient hairline along the top — same accent used
                // on the chat bottom sheets so the visual family stays
                // tight.
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: accent ?? AppGradients.primaryCta,
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
