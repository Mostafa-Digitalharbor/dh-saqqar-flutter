import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

/// Brand wordmark image — replaces every spot that used to render the
/// text "Saqqar" or a ShaderMask wordmark. The asset is the SAQQÂR logo
/// with the cyan accents on the Q-tails and the Â circumflex.
///
/// **Asset path:** `assets/img/saqqar-logo.png` — drop the file there
/// (already declared in pubspec via `assets/img/`).
///
/// Renders at a given [height]; aspect ratio preserved automatically.
/// On dark theme the navy letters can read faint — pass [tintForDark]:
/// true (default) to ColorFilter the logo to white so it stays
/// legible on the dark navy surfaces. On light theme the original
/// colours pass through.
///
/// Falls back to a gradient-text "SAQQAR" via [ShaderMask] when the
/// asset isn't on disk yet — keeps the build green during the
/// handover window before the user drops the image file.
class SaqqarLogo extends StatelessWidget {
  const SaqqarLogo({
    super.key,
    this.height = 22,
    this.tintForDark = true,
  });

  final double height;

  /// When true and the active theme is dark, the logo is rendered via
  /// a `ColorFilter.mode(white, srcATop)` so the navy strokes don't
  /// disappear into the dark navy surface. Cyan accents stay visible
  /// because srcATop only replaces opaque pixels' colour, not alpha.
  /// Set to false when the parent already provides a light backdrop.
  final bool tintForDark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      'assets/img/saqqar-logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _FallbackWordmark(height: height),
    );

    if (isDark && tintForDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcATop,
        ),
        child: image,
      );
    }
    return image;
  }
}

/// Gradient-text fallback shown while the user hasn't dropped the logo
/// file into `assets/img/saqqar-logo.png` yet — keeps the layout from
/// throwing during the handover and tracks the brand colour.
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
