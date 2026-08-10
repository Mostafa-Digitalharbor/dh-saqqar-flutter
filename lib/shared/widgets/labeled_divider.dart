import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// A hairline rule with a centered label — "or continue with", "Already have
/// an account?".
///
/// Extracted because the auth screen had two byte-identical copies of this
/// `Row` (the social-sign-in separator and the sign-in/sign-up footer), and
/// both carried the same latent overflow.
///
/// **Why the label is width-capped.** The obvious spelling gives the label its
/// natural width and lets two `Expanded` dividers split the rest:
///
/// ```dart
/// Row(children: [
///   Expanded(child: Divider()),
///   Padding(padding: ..., child: Text(label)),   // ← unbounded
///   Expanded(child: Divider()),
/// ])
/// ```
///
/// A `Row` hands its non-flex children *unbounded* main-axis constraints, so
/// that `Text` never wraps no matter how narrow the screen — it just keeps
/// growing and pushes the row past its bounds. On a 320 px phone the English
/// "Already have an account?" overflowed the sign-up footer by 16 px.
///
/// Capping the label at [labelWidthFactor] of the row makes it wrap instead,
/// while still leaving the dividers a guaranteed share. A short label ("or")
/// stays well under the cap and renders exactly as before, so the common case
/// is unchanged.
class LabeledDivider extends StatelessWidget {
  const LabeledDivider({
    super.key,
    required this.label,
    this.labelWidthFactor = 0.7,
  });

  final String label;

  /// Fraction of the available width the label may occupy before it wraps.
  /// The remainder is split between the two dividers, so this also sets
  /// their minimum combined length.
  final double labelWidthFactor;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return LayoutBuilder(
      builder: (context, constraints) {
        // `maxWidth` is finite here in every real caller (the auth panes are
        // inside a 440 px-capped scroll view). Guard anyway so dropping this
        // into an unbounded Row degrades to the old behaviour rather than
        // throwing on `infinity * 0.7`.
        final cap = constraints.maxWidth.isFinite
            ? constraints.maxWidth * labelWidthFactor
            : double.infinity;
        return Row(
          children: [
            Expanded(child: Divider(color: s.cardBorder)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(color: s.muted),
                ),
              ),
            ),
            Expanded(child: Divider(color: s.cardBorder)),
          ],
        );
      },
    );
  }
}
