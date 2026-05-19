import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

/// Brand wordmark image — the SAQQÂR logo with the cyan accents on the
/// Q-tails and the Â circumflex. Two assets ship side-by-side so the
/// logo is always legible against whichever surface it lands on:
///
///   * **Light mode** → `assets/img/saqqar-logo-light.png` (navy strokes
///     readable on light backgrounds).
///   * **Dark mode** → `assets/img/saqqar-logo-dark.png` (white strokes
///     readable on dark navy backgrounds).
///
/// Picking the right asset directly beats the old ColorFilter hack
/// (`ColorFilter.mode(white, srcATop)` blanched the cyan accents on
/// some Android renderers).
///
/// Renders at a given [height]; aspect ratio preserved automatically.
///
/// Falls back to a gradient-text "SAQQAR" via [ShaderMask] when the
/// asset isn't on disk yet — keeps the build green during the handover
/// window before the user drops the image files in.
class SaqqarLogo extends StatelessWidget {
  const SaqqarLogo({
    super.key,
    this.height = 22,
    this.forceVariant,
  });

  final double height;

  /// Optional override — pin the variant regardless of the active
  /// theme. Useful when the wordmark sits on a surface that doesn't
  /// follow the app theme (e.g. a permanently-dark splash screen
  /// shown over a light system theme).
  final Brightness? forceVariant;

  @override
  Widget build(BuildContext context) {
    final brightness =
        forceVariant ?? Theme.of(context).brightness;
    final asset = brightness == Brightness.dark
        ? 'assets/img/saqqar-logo-dark.png'
        : 'assets/img/saqqar-logo-light.png';

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _FallbackWordmark(height: height),
    );
  }
}

/// Gradient-text fallback shown while the user hasn't dropped the logo
/// files into `assets/img/` yet — keeps the layout from throwing during
/// the handover and tracks the brand colour.
class _FallbackWordmark extends StatelessWidget {
  const _FallbackWordmark({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    // Font size is roughly the height; the wordmark is a single line
    // of bold text so glyph height ≈ font size.
    final fontSize = height;
    return ShaderMask(
      shaderCallback: (rect) =>
          AppGradients.vivid.createShader(Offset.zero & rect.size),
      blendMode: BlendMode.srcIn,
      child: Text(
        'SAQQAR',
        style: TextStyle(
          color: AppColors.brandNavy, // overridden by ShaderMask
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          height: 1.0,
        ),
      ),
    );
  }
}
