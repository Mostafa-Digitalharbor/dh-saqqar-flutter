import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// App-wide background. By default it's a flat surface (`bg` token) — clean,
/// professional, no decorative blobs. Pass `withBlobs: true` on hero screens
/// (auth, chat welcome state) to add the cyan→purple ambient glow.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.withBlobs = false,
    this.intensity = 1.0,
  });

  final Widget child;
  final bool withBlobs;

  /// Multiplier on every gradient's opacity. `0` disables the ambient layer.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    if (!withBlobs || intensity == 0) {
      return Container(color: s.bg, child: child);
    }

    // Single cyan glow at the top centre — cheaper to paint than the older
    // 3-blob ambient and reads as a deliberate hero light source instead of
    // ornamental haze.
    final cyan = s.brandCyan.withValues(alpha: 0.07 * intensity);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.9),
          radius: 0.7,
          colors: [cyan, s.bg],
        ),
      ),
      child: child,
    );
  }
}
