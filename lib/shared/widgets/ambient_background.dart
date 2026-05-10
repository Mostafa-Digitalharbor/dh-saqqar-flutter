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

    final cyan = s.brandCyan.withValues(alpha: 0.06 * intensity);
    final purple = s.brandPurple.withValues(alpha: 0.04 * intensity);

    return Container(
      decoration: BoxDecoration(color: s.bg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _RadialBlob(color: cyan, alignment: const Alignment(-0.7, -0.85)),
          _RadialBlob(color: purple, alignment: const Alignment(0.7, -0.85)),
          child,
        ],
      ),
    );
  }
}

class _RadialBlob extends StatelessWidget {
  const _RadialBlob({required this.color, required this.alignment});

  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: 0.45,
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}
