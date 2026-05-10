import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/ui_strings.dart';

/// Typography scale from §2.2 of the spec.
///
/// Two font families:
/// - **Inter** (Latin, default).
/// - **Tajawal** (Arabic). Activated when `Locale.languageCode == 'ar'`.
///
/// Use `AppTypography.scale(locale)` to get the right [TextTheme] for the
/// active locale.
class AppTypography {
  AppTypography._();

  /// Returns the right [TextTheme] for the given locale, applied on top of
  /// the platform's default [TextTheme] so platform-specific tuning is kept.
  static TextTheme scale({
    required Locale locale,
    required Color text,
    required Color muted,
  }) {
    final isArabic = locale.languageCode == UiStrings.localeArabicCode;
    final base = TextStyle(color: text);

    TextStyle styled(
      double size,
      FontWeight weight, {
      double letterSpacing = 0,
      Color? color,
      double? height,
    }) {
      final merged = base.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color ?? text,
        height: height,
      );
      return isArabic
          ? GoogleFonts.tajawal(textStyle: merged)
          : GoogleFonts.inter(textStyle: merged);
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
    final base = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: color,
    );
    return locale.languageCode == UiStrings.localeArabicCode
        ? GoogleFonts.tajawal(textStyle: base)
        : GoogleFonts.inter(textStyle: base);
  }

  /// Status pill text — 10pt weight 700 uppercase +0.10em.
  static TextStyle statusPill({required Locale locale, required Color color}) {
    final base = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: color,
    );
    return locale.languageCode == UiStrings.localeArabicCode
        ? GoogleFonts.tajawal(textStyle: base)
        : GoogleFonts.inter(textStyle: base);
  }

  /// Monospace plate — code blocks, inline code, command output.
  static TextStyle mono({required Color color, double size = 12}) {
    return GoogleFonts.jetBrainsMono(
      textStyle: TextStyle(fontSize: size, color: color, height: 1.45),
    );
  }
}
