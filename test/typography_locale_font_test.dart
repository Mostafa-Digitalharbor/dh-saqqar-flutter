import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/core/theme/app_typography.dart';

/// Pins the face each locale is typeset in.
///
/// The pairing is per *locale*, not per glyph: Arabic screens are set in
/// Tajawal, everything else stays on Space Grotesk. A style that drops
/// `fontFamilyFallback` renders tofu the moment the other script appears in
/// the copy — an API error in Arabic on the English UI, a product name in
/// Latin on the Arabic one — so both halves are asserted together.
void main() {
  const ar = Locale('ar');
  const en = Locale('en');

  test('Arabic is set in Tajawal, English in Space Grotesk', () {
    expect(AppTypography.familyFor(ar), AppTypography.fontArabic);
    expect(AppTypography.familyFor(en), AppTypography.fontSans);
    expect(AppTypography.fontArabic, 'Tajawal');
  });

  test('each locale keeps the other script in its fallback chain', () {
    expect(AppTypography.fallbackFor(ar), contains(AppTypography.fontSans));
    expect(AppTypography.fallbackFor(en), contains(AppTypography.fontArabic));
    // IBM Plex Sans Arabic backstops Arabic glyphs Tajawal lacks.
    expect(
      AppTypography.fallbackFor(en),
      contains(AppTypography.fontArabicFallback),
    );
  });

  test('the theme carries the locale face into every text style', () {
    for (final theme in [AppTheme.light(ar), AppTheme.dark(ar)]) {
      final styles = [
        theme.textTheme.displayLarge,
        theme.textTheme.titleLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelSmall,
      ];
      for (final style in styles) {
        expect(style?.fontFamily, AppTypography.fontArabic);
        expect(style?.fontFamilyFallback, contains(AppTypography.fontSans));
      }
    }

    expect(
      AppTheme.light(en).textTheme.bodyMedium?.fontFamily,
      AppTypography.fontSans,
    );
  });

  test('eyebrow and status pill follow the locale too', () {
    const color = Color(0xFF000000);
    expect(
      AppTypography.eyebrow(locale: ar, color: color).fontFamily,
      AppTypography.fontArabic,
    );
    expect(
      AppTypography.statusPill(locale: ar, color: color).fontFamily,
      AppTypography.fontArabic,
    );
    expect(
      AppTypography.eyebrow(locale: en, color: color).fontFamily,
      AppTypography.fontSans,
    );
  });

  test('code stays monospace in both locales', () {
    expect(
      AppTypography.mono(color: const Color(0xFF000000)).fontFamily,
      AppTypography.fontMono,
    );
  });
}
