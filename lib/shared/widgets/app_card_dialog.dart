import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// A floating card dialog sized against the viewport rather than its content.
///
/// The vault's project list and project detail had this identical shell —
/// same `insetPadding`, same transparent surface tint, same corner, same
/// 520 px width cap — differing only in how tall they were allowed to grow.
/// Both had also typed the corner as a literal `20`, which is how the pair
/// drifted away from `AppTheme.dialogTheme` (18) without anyone deciding to.
///
/// **Why the height is a fraction with a clamp.** A dialog holding a list
/// needs to grow on a tall phone and shrink on a short one, but neither
/// extreme is usable: unclamped, it becomes a full-screen sheet on a tablet
/// and a two-row window in landscape. The fraction handles the middle, the
/// clamp handles the ends.
///
/// **Why `maxWidth` is capped.** Past ~520 px a project name and its
/// environment list stop being scannable — the eye travels too far between the
/// label and its value. On phones the cap never binds; on foldables and
/// tablets it is the difference between a dialog and a stretched banner.
///
/// The keyboard is deliberately not handled here: Flutter's [Dialog] already
/// adds `MediaQuery.viewInsets` to its own padding, so floating the card above
/// the keyboard is automatic. An inner `AnimatedPadding` on top of that
/// doubles the offset — which is exactly what both call sites used to do, and
/// what overflowed their columns by a few pixels.
class AppCardDialog extends StatelessWidget {
  const AppCardDialog({
    super.key,
    required this.heightFactor,
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  /// Fraction of the viewport height the card may occupy before clamping.
  final double heightFactor;

  /// Floor for the clamp — below this the content stops being usable.
  final double minHeight;

  /// Ceiling for the clamp — above this the card reads as a full-screen sheet
  /// rather than something layered over the page.
  final double maxHeight;

  final Widget child;

  /// Width past which the card's content stops being scannable.
  static const double maxContentWidth = 520;

  static const EdgeInsets _inset =
      EdgeInsets.symmetric(horizontal: 20, vertical: 24);

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final resolvedHeight = (MediaQuery.sizeOf(context).height * heightFactor)
        .clamp(minHeight, maxHeight);

    return Dialog(
      insetPadding: _inset,
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardDialogR),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: resolvedHeight,
          maxWidth: maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
