import 'package:flutter/material.dart';

/// Typography scale from §2.2 of the spec.
///
/// **2026-05-24 — `google_fonts` removed.** The runtime CDN fetch
/// crashed on offline / geo-blocked devices; the `allowRuntimeFetching
/// = false` fallback then crashed because we don't bundle the .ttf
/// files. Switching to platform defaults eliminates both failure
/// modes: Android uses **Roboto** (Latin) + **Noto Sans Arabic**
/// (Arabic) — both ship with the OS — and iOS uses **San Francisco**
/// + **SF Arabic**. Both stacks handle our content natively and the
/// visual difference vs. Inter / Tajawal is minor enough that
/// production launch wasn't worth blocking on bundling.
///
/// If we ever want to bring Inter / Tajawal back, the right path is
/// to bundle the .ttf files under `assets/fonts/` and declare them in
/// pubspec.yaml's `fonts:` section — NOT to re-enable the
/// `google_fonts` CDN fetch.
class AppTypography {
  AppTypography._();

  /// Returns the right [TextTheme] for the given locale, applied on top of
  /// the platform's default [TextTheme] so platform-specific tuning is kept.
  static TextTheme scale({
    required Locale locale,
    required Color text,
    required Color muted,
  }) {
    final base = TextStyle(color: text);

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
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: color,
    );
  }

  /// Status pill text — 10pt weight 700 uppercase +0.10em.
  static TextStyle statusPill({required Locale locale, required Color color}) {
    return TextStyle(
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
      fontFamily: 'monospace',
    );
  }
}
