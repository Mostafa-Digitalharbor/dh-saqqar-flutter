// Reads the app's design tokens back out of `AppTheme` and writes them in the
// shape the Figma plugin turns into Variables, Text Styles and Effect Styles.
//
// Built from `AppTheme.light()` / `AppTheme.dark()` rather than from
// `AppColors` directly, on purpose. `AppColors` is a bag of constants; the
// *theme* is what decides that `bg` means `lightBg` on one side and `darkBg`
// on the other. Reading the pair out of the two built themes is what lets a
// single Figma variable carry both modes and be correct in both — and it means
// a token that gets re-pointed in `AppTheme` moves in Figma too, instead of
// this file quietly describing last month's palette.
//
// The Light/Dark split maps exactly onto Figma's variable *modes*: one
// collection, two modes, and every consumer of `color/bg` flips with the page.
// That correspondence is the whole reason this export is worth generating
// rather than hand-building the palette once.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:saqqar_app/core/theme/app_colors.dart';
import 'package:saqqar_app/core/theme/app_gradients.dart';
import 'package:saqqar_app/core/theme/app_radius.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/core/theme/app_typography.dart';
import 'package:saqqar_app/core/theme/saqqar_theme_extension.dart';

import 'figma_exporter.dart' show kExportDir;

/// Builds the token document. Pure — the caller writes it.
Map<String, Object?> buildTokens() {
  const locale = Locale('en');
  final light = AppTheme.light(locale).extension<SaqqarThemeExtension>()!;
  final dark = AppTheme.dark(locale).extension<SaqqarThemeExtension>()!;

  return {
    'colors': _colors(light, dark),
    'radius': _radius(),
    'spacing': _spacing(),
    'text': _textStyles(locale),
    'effects': _effects(light, dark),
    'gradients': _gradients(),
  };
}

/// Synchronous for the same reason `writeCaptures` is — see the note there.
void writeTokens(Map<String, Object?> tokens) {
  Directory(kExportDir).createSync(recursive: true);
  File('$kExportDir/tokens.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(tokens));
}

// ── Colours ──────────────────────────────────────────────────────────────

/// Every colour token, as `name → {light, dark}`.
///
/// Brand and status colours are theme-agnostic in the app — the same cyan in
/// both themes — and they are still written with both modes filled in rather
/// than as single values. A Figma variable with one mode empty resolves to
/// transparent, which turns "this token doesn't change with the theme" into
/// "this button vanishes in dark mode".
List<Map<String, Object?>> _colors(
  SaqqarThemeExtension light,
  SaqqarThemeExtension dark,
) {
  Map<String, Object?> pair(String name, Color l, Color d) => {
        'name': name,
        'light': _hex(l),
        'dark': _hex(d),
      };

  return [
    // Surfaces.
    pair('surface/bg', light.bg, dark.bg),
    pair('surface/surface', light.surface, dark.surface),
    pair('surface/surface-2', light.surface2, dark.surface2),
    pair('surface/surface-3', light.surface3, dark.surface3),
    pair('surface/card-bg', light.cardBg, dark.cardBg),
    pair('surface/hover', light.hoverBg, dark.hoverBg),
    pair('surface/code-plate', light.codePlate, dark.codePlate),
    pair('surface/overlay', light.overlay, dark.overlay),

    // Text.
    pair('text/primary', light.text, dark.text),
    pair('text/muted', light.muted, dark.muted),

    // Lines.
    pair('border/default', light.border, dark.border),
    pair('border/card', light.cardBorder, dark.cardBorder),

    // Brand — same in both modes, written twice deliberately (see above).
    pair('brand/cyan', light.brandCyan, dark.brandCyan),
    pair('brand/cyan-strong', light.brandCyanStrong, dark.brandCyanStrong),
    pair('brand/purple', light.brandPurple, dark.brandPurple),
    pair('brand/navy', light.brandNavy, dark.brandNavy),
    pair('brand/cyan-soft', light.brandCyanSoft, dark.brandCyanSoft),
    pair('brand/cyan-border', light.brandCyanBorder, dark.brandCyanBorder),

    // Status.
    pair('status/success', light.success, dark.success),
    pair('status/warning', light.warning, dark.warning),
    pair('status/danger', light.danger, dark.danger),

    // Shadow base.
    pair('shadow/base', light.shadowBase, dark.shadowBase),

    // Avatar gradient stops, flattened. These are picked per conversation by
    // index, so they are indexed here too rather than named — a name would
    // imply a meaning the palette does not have.
    for (var i = 0; i < AppColors.avatarGradients.length; i++) ...[
      pair(
        'avatar/$i-from',
        AppColors.avatarGradients[i][0],
        AppColors.avatarGradients[i][0],
      ),
      pair(
        'avatar/$i-to',
        AppColors.avatarGradients[i][1],
        AppColors.avatarGradients[i][1],
      ),
    ],
  ];
}

// ── Numbers ──────────────────────────────────────────────────────────────

/// Corner radii. `pill` is 999 in the app — a sentinel meaning "fully round",
/// not a measurement — so it is passed through as-is and the plugin clamps it
/// per shape, the same way Flutter does.
List<Map<String, Object?>> _radius() => [
      {'name': 'radius/card', 'value': AppRadius.card},
      {'name': 'radius/button', 'value': AppRadius.button},
      {'name': 'radius/pill', 'value': AppRadius.pill},
      {'name': 'radius/input', 'value': AppRadius.input},
      {'name': 'radius/toast', 'value': AppRadius.toast},
      {'name': 'radius/modal', 'value': AppRadius.modal},
      {'name': 'radius/sheet-top', 'value': AppRadius.sheetTop},
      {'name': 'radius/bubble', 'value': AppRadius.bubble},
      {'name': 'radius/row', 'value': AppRadius.row},
      {'name': 'radius/small', 'value': AppRadius.small},
      {'name': 'radius/tight', 'value': AppRadius.tight},
      {'name': 'radius/micro', 'value': AppRadius.micro},
      {'name': 'radius/badge', 'value': AppRadius.badge},
      {'name': 'radius/checkbox', 'value': AppRadius.checkbox},
      {'name': 'radius/icon-box', 'value': AppRadius.iconBox},
      {'name': 'radius/waveform-bar', 'value': AppRadius.waveformBar},
      {'name': 'radius/nav-bar', 'value': AppRadius.navBar},
      {'name': 'radius/hero-plate', 'value': AppRadius.heroPlate},
      {'name': 'radius/splash-plate', 'value': AppRadius.splashPlate},
    ];

List<Map<String, Object?>> _spacing() => [
      {'name': 'space/xs', 'value': AppSpacing.xs},
      {'name': 'space/sm', 'value': AppSpacing.sm},
      {'name': 'space/md', 'value': AppSpacing.md},
      {'name': 'space/lg', 'value': AppSpacing.lg},
      {'name': 'space/xl', 'value': AppSpacing.xl},
      {'name': 'space/xxl', 'value': AppSpacing.xxl},
      {'name': 'space/xxxl', 'value': AppSpacing.xxxl},
    ];

// ── Type ─────────────────────────────────────────────────────────────────

/// The Material `TextTheme` slots, renamed to what the design calls them.
///
/// Colour is deliberately NOT part of a Figma text style here: Figma applies
/// fills separately, and baking `text/primary` into the style would make a
/// muted caption need its own duplicate of every size. The scale's own
/// muted-by-default slots (`bodySmall`, `labelMedium`, `labelSmall`) still
/// record which fill they expect, as a hint for the plugin.
List<Map<String, Object?>> _textStyles(Locale locale) {
  final theme = AppTheme.dark(locale).textTheme;

  Map<String, Object?> style(String name, TextStyle? s, {String? fill}) => {
        'name': name,
        'family': s?.fontFamily ?? AppTypography.fontSans,
        'size': s?.fontSize ?? 14,
        'weight': _weight(s?.fontWeight),
        'letterSpacing': s?.letterSpacing ?? 0,
        'lineHeight':
            s?.height == null ? null : s!.height! * (s.fontSize ?? 14),
        if (fill != null) 'fill': fill,
      };

  return [
    style('Display/Large', theme.displayLarge),
    style('Display/Medium', theme.displayMedium),
    style('Display/Small', theme.displaySmall),
    style('Title/Large', theme.headlineLarge),
    style('Title/Medium', theme.headlineMedium),
    style('Title/Small', theme.headlineSmall),
    style('Subtitle/Large', theme.titleLarge),
    style('Subtitle/Medium', theme.titleMedium),
    style('Subtitle/Small', theme.titleSmall),
    style('Body/Large', theme.bodyLarge),
    style('Body/Medium', theme.bodyMedium),
    style('Body/Small', theme.bodySmall, fill: 'text/muted'),
    style('Label/Large', theme.labelLarge),
    style('Label/Medium', theme.labelMedium, fill: 'text/muted'),
    style('Label/Small', theme.labelSmall, fill: 'text/muted'),
    style(
      'Eyebrow',
      AppTypography.eyebrow(locale: locale, color: const Color(0xFFFFFFFF)),
      fill: 'text/muted',
    ),
    style(
      'Status Pill',
      AppTypography.statusPill(locale: locale, color: const Color(0xFFFFFFFF)),
    ),
    style('Mono', AppTypography.mono(color: const Color(0xFFFFFFFF))),
  ];
}

int _weight(FontWeight? weight) =>
    weight == null ? 400 : (FontWeight.values.indexOf(weight) + 1) * 100;

// ── Effects ──────────────────────────────────────────────────────────────

/// The three named elevations, per mode.
///
/// `cyanPopShadow` reads the same in both themes (it is tinted from the brand
/// cyan, not from the background), so it is emitted once.
List<Map<String, Object?>> _effects(
  SaqqarThemeExtension light,
  SaqqarThemeExtension dark,
) {
  List<Map<String, Object?>> shadows(List<BoxShadow> list) => [
        for (final s in list)
          {
            'color': _hex(s.color),
            'dx': s.offset.dx,
            'dy': s.offset.dy,
            'blur': s.blurRadius,
            'spread': s.spreadRadius,
          },
      ];

  return [
    {'name': 'Shadow/Glass (Light)', 'shadows': shadows(light.glassShadow)},
    {'name': 'Shadow/Glass (Dark)', 'shadows': shadows(dark.glassShadow)},
    {'name': 'Shadow/Modal (Light)', 'shadows': shadows(light.modalShadow)},
    {'name': 'Shadow/Modal (Dark)', 'shadows': shadows(dark.modalShadow)},
    {'name': 'Shadow/Cyan Pop', 'shadows': shadows(dark.cyanPopShadow)},
  ];
}

// ── Gradients ────────────────────────────────────────────────────────────

List<Map<String, Object?>> _gradients() {
  Map<String, Object?> grad(String name, LinearGradient g) {
    final begin = g.begin.resolve(TextDirection.ltr);
    final end = g.end.resolve(TextDirection.ltr);
    double u(double v) => (v + 1) / 2;
    return {
      'name': name,
      'from': [u(begin.x), u(begin.y)],
      'to': [u(end.x), u(end.y)],
      'colors': [for (final c in g.colors) _hex(c)],
      'stops': g.stops ??
          List.generate(g.colors.length, (i) => i / (g.colors.length - 1)),
    };
  }

  return [
    grad('Gradient/Primary CTA', AppGradients.primaryCta),
    grad('Gradient/Vivid', AppGradients.vivid),
    grad('Gradient/User Bubble', AppGradients.userBubble),
    grad('Gradient/Server Activity', AppGradients.serverActivity),
    grad('Gradient/Active Row', AppGradients.activeRow),
  ];
}

// ── Primitives ───────────────────────────────────────────────────────────

String _hex(Color c) {
  final argb = c.toARGB32();
  final rgb = (argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
  final a = ((argb >> 24) & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#$rgb$a'.toUpperCase();
}
