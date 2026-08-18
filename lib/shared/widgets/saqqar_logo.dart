import 'package:flutter/material.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/constants/ui_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_sizes.dart';

/// The single Saqqar brand logo — the hexagonal mark + "SAQQAR" lockup
/// shipped at `assets/img/logo-light.png`. This is the canonical app logo;
/// every in-app logo surface (header, splash, auth, drawer) renders it via
/// this widget so there is exactly one source of truth.
///
/// The asset itself is the navy/cyan lockup tuned for **light** backgrounds.
/// On **dark** surfaces it's tinted solid white (`BlendMode.srcIn`) so the
/// lockup stays legible — the same monochrome-white treatment the Saqqar
/// Design System's header uses (`brightness(0) invert(1)`).
///
/// Renders at a given [height]; aspect ratio preserved automatically.
///
/// Falls back to a gradient-text "SAQQAR" via [ShaderMask] when the
/// asset isn't on disk yet — keeps the build green during the handover
/// window before the user drops the image file in.
class SaqqarLogo extends StatelessWidget {
  const SaqqarLogo({
    super.key,
    this.height = AppLogoSizes.navBar,
    this.forceVariant,
  });

  final double height;

  /// Optional override — pin the variant regardless of the active
  /// theme. Useful when the logo sits on a surface that doesn't follow
  /// the app theme (e.g. a permanently-dark splash screen shown over a
  /// light system theme).
  final Brightness? forceVariant;

  static const String asset = AssetPaths.logo;

  @override
  Widget build(BuildContext context) {
    final brightness = forceVariant ?? Theme.of(context).brightness;
    final onDark = brightness == Brightness.dark;

    Widget image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _FallbackWordmark(height: height),
    );

    // On dark surfaces the navy lockup would vanish — tint it solid white.
    if (onDark) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.mode(AppColors.onBrand, BlendMode.srcIn),
        child: image,
      );
    }
    return image;
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
        UiStrings.brandWordmark,
        style: TextStyle(
          color: AppColors.brandNavy, // overridden by ShaderMask
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: AppLetterSpacing.wide,
          height: AppLineHeights.flush,
        ),
      ),
    );
  }
}
