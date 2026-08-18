import 'package:flutter/material.dart';

import 'app_sizes.dart';

/// Typography scale from §2.2 of the spec.
///
/// **Fonts are bundled** (not fetched via `google_fonts` CDN) so they render
/// offline / on geo-blocked devices. The .ttf files live under
/// `assets/fonts/` and are declared in pubspec.yaml's `fonts:` section. To
/// change a face, bundle its weights there and point the family constant at
/// it — do NOT re-enable the `google_fonts` runtime fetch (it crashed on
/// offline / geo-blocked devices).
///
/// **Latin + Arabic pairing:** [fontSans] (Space Grotesk) is the primary
/// family, with [fontFallback] (IBM Plex Sans Arabic) behind it. Latin/English
/// glyphs render in Space Grotesk; Arabic — which Space Grotesk doesn't
/// contain — falls through to IBM Plex Sans Arabic per-glyph. Every text
/// style must carry `fontFamilyFallback: fontFallback` for Arabic to resolve.
class AppTypography {
  AppTypography._();

  /// Primary Latin/English face — Space Grotesk (variable; Flutter maps
  /// `fontWeight` onto its `wght` axis).
  static const String fontSans = 'SpaceGrotesk';

  /// Arabic face + the Latin fallback. Any glyph missing from [fontSans]
  /// (i.e. all Arabic) resolves here. Bundled weights: 400 / 500 / 600 / 700.
  static const String fontArabic = 'IBMPlexSansArabic';

  /// Fallback chain applied to every UI text style so Arabic resolves to
  /// [fontArabic] while Latin stays on [fontSans].
  static const List<String> fontFallback = [fontArabic];

  /// Bundled monospace face for code blocks / inline code / hosts —
  /// mirrors the design system's `--font-mono: JetBrains Mono`.
  static const String fontMono = 'JetBrainsMono';

  static TextTheme scale({
    required Locale locale,
    required Color text,
    required Color muted,
  }) {
    final base = TextStyle(
      color: text,
      fontFamily: fontSans,
      fontFamilyFallback: fontFallback,
    );

    TextStyle styled(
      double size,
      FontWeight weight, {
      double letterSpacing = 0,
      Color? color,
      double? height,
    }) {
      return base.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color ?? text,
        height: height,
      );
    }

    return TextTheme(
      // Display — auth hero, profile name.
      displayLarge: styled(AppFontSizes.displayLarge, FontWeight.w700),
      displayMedium: styled(AppFontSizes.displayMedium, FontWeight.w700),
      displaySmall: styled(AppFontSizes.displaySmall, FontWeight.w700),

      // Title — screen / conversation title.
      headlineLarge: styled(AppFontSizes.headlineLarge, FontWeight.w700),
      headlineMedium: styled(AppFontSizes.headlineMedium, FontWeight.w700),
      headlineSmall: styled(AppFontSizes.headlineSmall, FontWeight.w700),

      // Subtitle — section heading.
      titleLarge: styled(AppFontSizes.titleLarge, FontWeight.w600),
      titleMedium: styled(AppFontSizes.titleMedium, FontWeight.w600),
      titleSmall: styled(AppFontSizes.titleSmall, FontWeight.w600),

      // Body — chat text, lists.
      bodyLarge: styled(AppFontSizes.bodyLarge, FontWeight.w400, height: AppLineHeights.body),
      bodyMedium: styled(
        AppFontSizes.bodyMedium,
        FontWeight.w400,
        height: AppLineHeights.body,
        color: text,
      ),
      bodySmall: styled(
        AppFontSizes.bodySmall,
        FontWeight.w400,
        height: AppLineHeights.reading,
        color: muted,
      ),

      // Label / caption / micro.
      labelLarge: styled(AppFontSizes.labelLarge, FontWeight.w600),
      labelMedium: styled(AppFontSizes.labelMedium, FontWeight.w600, color: muted),
      labelSmall: styled(AppFontSizes.labelSmall, FontWeight.w700, color: muted),
    );
  }

  /// Eyebrow / micro-caps style — used in panel headers ("MESSAGE", "STATUS").
  /// Spec §2.2: 11pt, weight 700, uppercase, +0.10em tracking.
  static TextStyle eyebrow({required Locale locale, required Color color}) {
    return TextStyle(
      fontFamily: fontSans,
      fontFamilyFallback: fontFallback,
      fontSize: AppFontSizes.caption,
      fontWeight: FontWeight.w700,
      letterSpacing: AppLetterSpacing.none,
      color: color,
    );
  }

  /// Status pill text — 10pt weight 700 uppercase +0.10em.
  static TextStyle statusPill({required Locale locale, required Color color}) {
    return TextStyle(
      fontFamily: fontSans,
      fontFamilyFallback: fontFallback,
      fontSize: AppFontSizes.chipLabel,
      fontWeight: FontWeight.w700,
      letterSpacing: AppLetterSpacing.none,
      color: color,
    );
  }

  /// Monospace plate — code blocks, inline code, command output.
  /// Uses the platform default monospace family so we don't pay a
  /// network round-trip on first render. On Android that's
  /// "RobotoMono" (always installed); on iOS "Menlo". Both are good
  /// enough for `<pre>` code blocks in agent replies.
  static TextStyle mono({
    required Color color,
    double size = AppFontSizes.mono,
  }) {
    return TextStyle(
      fontSize: size,
      color: color,
      height: AppLineHeights.reading,
      fontFamily: fontMono,
    );
  }
}
