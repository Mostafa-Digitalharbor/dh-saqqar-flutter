import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';

/// A tap target that ripples inside its own rounded corners.
///
/// Wraps the three-part incantation Flutter requires for an ink response on a
/// rounded surface, which had been re-typed at 48 call sites across 31 files:
///
/// ```dart
/// Material(
///   color: Colors.transparent,
///   borderRadius: AppRadius.buttonR,   // ← clips the ink
///   child: InkWell(
///     onTap: onTap,
///     borderRadius: AppRadius.buttonR, // ← shapes the splash
///     child: child,
///   ),
/// )
/// ```
///
/// All three parts are load-bearing and none of them is obvious:
///
///   * The `Material` exists only because `InkWell` paints into the nearest
///     one and there is no guarantee of a suitable ancestor. It must be
///     transparent or it paints over whatever gradient or card sits behind.
///   * The radius has to be given **twice**, to two different widgets, and the
///     two must agree. When they disagree the splash paints past the corner it
///     is meant to be clipped to — a defect that only appears mid-press, so it
///     survives every screenshot and every static review.
///
/// An audit on 2026-08-17 found all 48 sites in agreement, which is the good
/// case and exactly why this is worth extracting now: the invariant is
/// currently held by 48 people remembering it, and this makes it structural
/// instead. One radius goes in, both come out.
class TappableSurface extends StatelessWidget {
  const TappableSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = AppRadius.buttonR,
    this.onLongPress,
    this.splashColor,
    this.highlightColor,
  });

  final Widget child;

  /// Nullable so a disabled control can pass `null` and get the standard
  /// "no ripple, no press" behaviour rather than a separate branch.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// Applied to both the clip and the splash. Defaults to the button radius,
  /// which is what most of the migrated call sites used.
  final BorderRadius radius;

  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        splashColor: splashColor,
        highlightColor: highlightColor,
        child: child,
      ),
    );
  }
}
