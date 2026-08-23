import 'package:flutter/material.dart';

import '../constants/ui_strings.dart';
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
/// **Latin + Arabic pairing:** the UI face is picked *per locale*, not per
/// glyph — [familyFor] returns [fontArabic] (Tajawal) under `ar` and
/// [fontSans] (Space Grotesk) everywhere else, so an Arabic screen is set
/// entirely in Tajawal (its Latin glyphs and digits included) while English
/// keeps Space Grotesk. [fallbackFor] puts the other family behind it so a
/// stray glyph — Arabic in the English UI, or the reverse — still resolves.
/// Every text style must carry both, or the fallback chain is lost.
class AppTypography {
  AppTypography._();

  /// Primary Latin/English face — Space Grotesk (variable; Flutter maps
  /// `fontWeight` onto its `wght` axis).
  static const String fontSans = 'SpaceGrotesk';

  /// Primary Arabic face — Tajawal. Bundled weights: 400 / 500 / 700 / 800
  /// (the family has no 600; Flutter resolves w600 to the nearest one).
  static const String fontArabic = 'Tajawal';

  /// Last resort behind both faces — IBM Plex Sans Arabic covers Arabic
  /// glyphs Tajawal lacks. Bundled weights: 400 / 500 / 600 / 700.
  static const String fontArabicFallback = 'IBMPlexSansArabic';

  /// True when [locale] should be typeset in [fontArabic].
  static bool isArabic(Locale locale) =>
      locale.languageCode == UiStrings.localeArabicCode;

  /// The primary family for [locale] — Tajawal under `ar`, Space Grotesk
  /// otherwise.
  static String familyFor(Locale locale) =>
      isArabic(locale) ? fontArabic : fontSans;

  /// The fallback chain for [locale]: the *other* script's face first, then
  /// IBM Plex Sans Arabic as the final Arabic backstop.
  static List<String> fallbackFor(Locale locale) => isArabic(locale)
      ? const [fontArabicFallback, fontSans]
      : const [fontArabic, fontArabicFallback];

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
      fontFamily: familyFor(locale),
      fontFamilyFallback: fallbackFor(locale),
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
      fontFamily: familyFor(locale),
      fontFamilyFallback: fallbackFor(locale),
      fontSize: AppFontSizes.caption,
      fontWeight: FontWeight.w700,
      letterSpacing: AppLetterSpacing.none,
      color: color,
    );
  }

  /// Status pill text — 10pt weight 700 uppercase +0.10em.
  static TextStyle statusPill({required Locale locale, required Color color}) {
    return TextStyle(
      fontFamily: familyFor(locale),
      fontFamilyFallback: fallbackFor(locale),
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
