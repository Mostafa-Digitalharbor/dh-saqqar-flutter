import 'package:flutter/material.dart';

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
      displayLarge: styled(28, FontWeight.w700),
      displayMedium: styled(28, FontWeight.w700),
      displaySmall: styled(24, FontWeight.w700),

      // Title — screen / conversation title.
      headlineLarge: styled(22, FontWeight.w700),
      headlineMedium: styled(20, FontWeight.w700),
      headlineSmall: styled(18, FontWeight.w700),

      // Subtitle — section heading.
      titleLarge: styled(16, FontWeight.w600),
      titleMedium: styled(15, FontWeight.w600),
      titleSmall: styled(14, FontWeight.w600),

      // Body — chat text, lists.
      bodyLarge: styled(16, FontWeight.w400, height: 1.5),
      bodyMedium: styled(14, FontWeight.w400, height: 1.5, color: text),
      bodySmall: styled(13, FontWeight.w400, height: 1.45, color: muted),

      // Label / caption / micro.
      labelLarge: styled(14, FontWeight.w600),
      labelMedium: styled(12, FontWeight.w600, color: muted),
      labelSmall: styled(11, FontWeight.w700, color: muted),
    );
  }

  /// Eyebrow / micro-caps style — used in panel headers ("MESSAGE", "STATUS").
  /// Spec §2.2: 11pt, weight 700, uppercase, +0.10em tracking.
  static TextStyle eyebrow({required Locale locale, required Color color}) {
    return TextStyle(
      fontFamily: fontSans,
      fontFamilyFallback: fontFallback,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: color,
    );
  }

  /// Status pill text — 10pt weight 700 uppercase +0.10em.
  static TextStyle statusPill({required Locale locale, required Color color}) {
    return TextStyle(
      fontFamily: fontSans,
      fontFamilyFallback: fontFallback,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: color,
    );
  }

  /// Monospace plate — code blocks, inline code, command output.
  /// Uses the platform default monospace family so we don't pay a
  /// network round-trip on first render. On Android that's
  /// "RobotoMono" (always installed); on iOS "Menlo". Both are good
  /// enough for `<pre>` code blocks in agent replies.
  static TextStyle mono({required Color color, double size = 12}) {
    return TextStyle(
      fontSize: size,
      color: color,
      height: 1.45,
      fontFamily: fontMono,
    );
  }
}
