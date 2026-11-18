import 'package:flutter/material.dart';

import 'app_sizes.dart';

class AppColors {
  AppColors._();

  // Dark theme
  static const darkBg = Color(0xFF030712);
  static const darkSurface = Color(0xFF111827);
  static const darkSurface2 = Color(0xFF1E293B);
  static const darkSurface3 = Color(0xFF0F172A);
  static const darkText = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF1E293B);
  static const darkCardBg = Color(0xB3111827);
  static const darkCardBorder = Color(0xCC1E293B);
  static const darkHoverBg = Color(0x141E293B);

  // Light theme
  static const lightBg = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);

  /// Bottom-sheet fill in light mode: the cool grey the redesign's notch sheets
  /// use, so every sheet in the app reads as one family.
  static const sheetSurface = Color(0xFFEFF1F6);
  static const lightSurface2 = Color(0xFFF1F5F9);
  static const lightSurface3 = Color(0xFFE2E8F0);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightCardBg = Color(0xD9FFFFFF);
  static const lightCardBorder = Color(0xF2E2E8F0);
  static const lightHoverBg = Color(0x14E2E8F0);

  // Brand (theme-agnostic)
  static const brandCyan = Color(0xFF06B6D4);
  static const brandCyanStrong = Color(0xFF22D3EE); // saqqaar.com app.css
  static const brandPurple = Color(0xFF8B5CF6);
  static const brandNavy = Color(0xFF1F3C88);

  // Status (theme-agnostic)
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Soft tints used by mini-chip, cyan plates, etc.
  static final Color brandCyanSoftDark = brandCyan.withValues(
    alpha: AppAlphas.a18,
  );
  static final Color brandCyanSoftLight = brandCyan.withValues(
    alpha: AppAlphas.a14,
  );
  static final Color brandCyanBorder = brandCyan.withValues(
    alpha: AppAlphas.a30,
  );

  // Overlay (modal/sheet backdrop) — saqqaar.com app.css uses rgba(2,6,23,0.72).
  static const overlayDark = Color(0xB8020617);
  static const overlayLight = Color(0x66020617);

  // Cyan pop shadow (CTA + active rows) — 0 10px 30px rgba(6,182,212,0.18).
  static final Color popShadowCyan = brandCyan.withValues(alpha: AppAlphas.a18);

  /// Base hues every drop shadow is tinted from — the near-black the design
  /// system casts shadows in, per theme.
  ///
  /// Shadows are the one place raw hex kept reappearing: four shared widgets
  /// each wrote their own `Color(0xFF020617)` / `Color(0xFF0F172A)` because a
  /// shadow needs a colour *plus* a blur and an offset, and only the colour had
  /// a home. Elevations that are genuinely shared live as
  /// `SaqqarThemeExtension.glassShadow` / `.modalShadow`; anything with its own
  /// shape tints from here rather than inventing the hue again.
  static const shadowDark = Color(0xFF020617);
  static const shadowLight = Color(0xFF0F172A);

  /// The two shared elevations, pre-tinted.
  ///
  /// These are the alpha variants of [shadowDark] / [shadowLight] that
  /// `SaqqarThemeExtension.glassShadow` and `.modalShadow` cast. They are
  /// spelled as literals rather than `shadowDark.withValues(alpha: …)` because
  /// the `BoxShadow` lists that consume them are `const`, and `withValues` is
  /// not a const expression — so the choice was a literal here or a literal
  /// there. Here, where the rest of the palette lives.
  static const glassShadowDark = Color(0x66020617); // shadowDark @ 40%
  static const glassShadowLight = Color(0x170F172A); // shadowLight @ 9%
  static const modalShadowDark = Color(0x8C020617); // shadowDark @ 55%
  static const modalShadowLight = Color(0x1F0F172A); // shadowLight @ 12%

  /// Inline-code / pre-block plate. Dark tints from pure black rather than
  /// [shadowDark] so the plate reads as a recess on an already-navy surface.
  static const codePlateDark = Color(0x40000000);
  static const codePlateLight = Color(0x0F0F172A); // shadowLight @ 6%

  /// Per-conversation avatar gradient palette (ports the design system's
  /// `AVATAR_GRADS`). Lives here — the one home for brand hex — instead of
  /// being hand-duplicated inside the conversation card. Reuses the brand /
  /// status tokens above where the stops match; the remaining stops are the
  /// palette's own accent blends.

  // ── Absolutes ──────────────────────────────────────────────────────────
  //
  // Pure white and pure black are not part of the light/dark palettes above
  // — they do not flip with the theme. They are named here because "white"
  // at a call site says nothing about *why* it is white, and the four
  // reasons this app has for reaching for it are genuinely different
  // decisions that happen to resolve to the same value today.

  /// Foreground on a brand fill — the label and glyph on a cyan button, a
  /// gradient FAB, a selected chip, an avatar's initial.
  ///
  /// White regardless of theme, because the fill underneath is the brand
  /// cyan in both. If the brand ever gains a light variant this is the one
  /// constant that has to change, and the twenty-odd call sites do not.
  static const onBrand = Color(0xFFFFFFFF);

  /// The barrier behind a modal. Always black, tinted down by an
  /// `AppAlphas` scrim level at the call site.
  static const scrimBase = Color(0xFF000000);

  /// The attachment viewer's backdrop when it is showing an image.
  ///
  /// Deliberately not `bg`: a photo is displayed against black in every
  /// gallery on both platforms, and matching the app's surface instead
  /// would tint the user's own image.
  static const imageBackdrop = Color(0xFF000000);

  /// Foreground on [imageBackdrop] — the viewer's app-bar title and
  /// actions.
  static const onImageBackdrop = Color(0xFFFFFFFF);

  static const List<List<Color>> avatarGradients = [
    [brandNavy, brandCyan],
    [Color(0xFF0E7490), brandCyanStrong],
    [Color(0xFF5B21B6), brandPurple],
    [Color(0xFF155E63), success],
    [Color(0xFF1E3A8A), Color(0xFF6366F1)],
    [Color(0xFF0F766E), Color(0xFF2DD4BF)],
  ];

  // ── Figma redesign palette ───────────────────────────────────────────
  //
  // The redesign screens are fixed-colour surfaces (a dark gradient, a white
  // page): they do not follow the light/dark theme. `Fig` names these by role;
  // the hex values live here so this stays the one home for colour literals.

  /// Fixed white of the redesign (does not follow the theme).
  static const figWhite = Color(0xFFFFFFFF);

  /// Fixed black of the redesign (does not follow the theme).
  static const figBlack = Color(0xFF000000);

  static const figPageGrey = Color(0xFFEEEEEF);
  static const figInk = Color(0xFF111827);
  static const figNavy = Color(0xFF1B2140);
  static const figMuted = Color(0xFF4A5274);
  static const figMutedSoft = Color(0xFF5F6888);
  static const figPlaceholder = Color(0xFF656E8E);
  static const figBlue = Color(0xFF235FE7);
  static const figBlueTop = Color(0xFF1D50D9);
  static const figBlueBottom = Color(0xFF357AF3);
  static const figFieldBorder = Color(0xFFB3C3F4);
  static const figCardFill = Color(0xFFF8F9FA);
  static const figDanger = Color(0xFFE5604A);
  static const figDangerText = Color(0xFFD9503C);
  static const figSuccess = Color(0xFF22C58B);
  static const figNearBlack = Color(0xFF08090B);
  static const figChipBlue = Color(0xFF3A6FF0);
  static const figIconTile = Color(0xFFDDE3F3);
  static const figTileText = Color(0xFF3B4268);
  static const figInkDeep = Color(0xFF0B0B0C);
  static const figAccentBlue = Color(0xFF4C8DFF);
  static const figHairline = Color(0xFFD7DBE8);
  static const figBlueSoft = Color(0xFF3B6FF0);
  static const figMutedGrey = Color(0xFF666B80);
  static const figBlueStrong = Color(0xFF2F63F0);
  static const figTintBlue = Color(0xFFE7EDFC);
  static const figMutedCool = Color(0xFF636A80);
  static const figBorderBlue = Color(0xFFDCE3F6);
  static const figSlate = Color(0xFF6E7BB0);
  static const figMutedLight = Color(0xFF7D8190);
  static const figBlueBright = Color(0xFF3B6FF5);
  static const figDarkPanel = Color(0xFF16181C);
  static const figNavyDeep = Color(0xFF0E1830);
  static const figNavyText = Color(0xFF2F3760);
  static const figPanelTint = Color(0xFFF4F5FA);
  static const figPanelBorder = Color(0xFFE1E5F1);
  static const figMutedBlue = Color(0xFF5E678A);
  static const figSwitchOn = Color(0xFF2F7BF5);
  static const figShadowInk = Color(0x990B1230);
  static const figMutedDim = Color(0xFF6A7088);
  static const figBlueAction = Color(0xFF2F6BF0);
  static const figFileRed = Color(0xFFFF6B7A);
  static const figFileBlue = Color(0xFF3B8BFF);
  static const figFileGreen = Color(0xFF4CD28F);
  static const figFileAmber = Color(0xFFF3B93C);
  static const figDrawerShadow = Color(0x33101840);
  static const figDividerCool = Color(0xFFE3E6EF);
  static const figDividerSoft = Color(0xFFE7E8EE);
  static const figInkBlack = Color(0xFF0D0D10);
  static const figMutedIndigo = Color(0xFF4F5C8A);
  static const figInkPlain = Color(0xFF111111);
  static const figBlueFocus = Color(0xFF3B7BF5);
  static const figSurfaceCool = Color(0xFFEFF1F6);

  // One-offs that appear once or twice in the redesign, named by value.
  static const figC00FFFFFF = Color(0x00FFFFFF);
  static const figCFF03050A = Color(0xFF03050A);
  static const figCFF05070C = Color(0xFF05070C);
  static const figCFF07080C = Color(0xFF07080C);
  static const figCFF080909 = Color(0xFF080909);
  static const figCFF08090E = Color(0xFF08090E);
  static const figCFF090A0D = Color(0xFF090A0D);
  static const figCFF090A0E = Color(0xFF090A0E);
  static const figCFF090A10 = Color(0xFF090A10);
  static const figCFF0A0D14 = Color(0xFF0A0D14);
  static const figCFF0A0E14 = Color(0xFF0A0E14);
  static const figCFF0B0B1A = Color(0xFF0B0B1A);
  static const figCFF0B101A = Color(0xFF0B101A);
  static const figCFF0E1529 = Color(0xFF0E1529);
  static const figCFF101936 = Color(0xFF101936);
  static const figCFF101A2E = Color(0xFF101A2E);
  static const figCFF12296A = Color(0xFF12296A);
  static const figCFF123B2E = Color(0xFF123B2E);
  static const figCFF132142 = Color(0xFF132142);
  static const figCFF142547 = Color(0xFF142547);
  static const figCFF152658 = Color(0xFF152658);
  static const figCFF152750 = Color(0xFF152750);
  static const figCFF17181B = Color(0xFF17181B);
  static const figCFF182D5A = Color(0xFF182D5A);
  static const figCFF193161 = Color(0xFF193161);
  static const figCFF1A1C22 = Color(0xFF1A1C22);
  static const figCFF1A3E96 = Color(0xFF1A3E96);
  static const figCFF1B337A = Color(0xFF1B337A);
  static const figCFF1B4FD0 = Color(0xFF1B4FD0);
  static const figCFF1D3972 = Color(0xFF1D3972);
  static const figCFF1E397F = Color(0xFF1E397F);
  static const figCFF1E3D7A = Color(0xFF1E3D7A);
  static const figCFF1F6B6B = Color(0xFF1F6B6B);
  static const figCFF1F9D63 = Color(0xFF1F9D63);
  static const figCFF1FA37A = Color(0xFF1FA37A);
  static const figCFF21438B = Color(0xFF21438B);
  static const figCFF2245A6 = Color(0xFF2245A6);
  static const figCFF232529 = Color(0xFF232529);
  static const figCFF2350B8 = Color(0xFF2350B8);
  static const figCFF2373E9 = Color(0xFF2373E9);
  static const figCFF244994 = Color(0xFF244994);
  static const figCFF2449A7 = Color(0xFF2449A7);
  static const figCFF2953CA = Color(0xFF2953CA);
  static const figCFF2A5598 = Color(0xFF2A5598);
  static const figCFF2B3A8F = Color(0xFF2B3A8F);
  static const figCFF2B56C8 = Color(0xFF2B56C8);
  static const figCFF2B5BD2 = Color(0xFF2B5BD2);
  static const figCFF2E5EE1 = Color(0xFF2E5EE1);
  static const figCFF2E5FE8 = Color(0xFF2E5FE8);
  static const figCFF2F5FEA = Color(0xFF2F5FEA);
  static const figCFF3062EF = Color(0xFF3062EF);
  static const figCFF3166FD = Color(0xFF3166FD);
  static const figCFF3A3C42 = Color(0xFF3A3C42);
  static const figCFF3A3C48 = Color(0xFF3A3C48);
  static const figCFF3B4A9E = Color(0xFF3B4A9E);
  static const figCFF3D4054 = Color(0xFF3D4054);
  static const figCFF414A9E = Color(0xFF414A9E);
  static const figCFF4A4F63 = Color(0xFF4A4F63);
  static const figCFF4E6AEA = Color(0xFF4E6AEA);
  static const figCFF555B70 = Color(0xFF555B70);
  static const figCFF5878E8 = Color(0xFF5878E8);
  static const figCFF5A6590 = Color(0xFF5A6590);
  static const figCFF5A66A8 = Color(0xFF5A66A8);
  static const figCFF5B3E8B = Color(0xFF5B3E8B);
  static const figCFF5B6075 = Color(0xFF5B6075);
  static const figCFF5B6585 = Color(0xFF5B6585);
  static const figCFF5E6478 = Color(0xFF5E6478);
  static const figCFF656B80 = Color(0xFF656B80);
  static const figCFF6A7BC8 = Color(0xFF6A7BC8);
  static const figCFF6C8CFF = Color(0xFF6C8CFF);
  static const figCFF6F7FB0 = Color(0xFF6F7FB0);
  static const figCFF7A5230 = Color(0xFF7A5230);
  static const figCFF8BE8C0 = Color(0xFF8BE8C0);
  static const figCFF8D93A5 = Color(0xFF8D93A5);
  static const figCFF8E97B8 = Color(0xFF8E97B8);
  static const figCFFA9B6E6 = Color(0xFFA9B6E6);
  static const figCFFB0B4C2 = Color(0xFFB0B4C2);
  static const figCFFB8741A = Color(0xFFB8741A);
  static const figCFFB9BCC4 = Color(0xFFB9BCC4);
  static const figCFFD4DBF4 = Color(0xFFD4DBF4);
  static const figCFFD5DAEA = Color(0xFFD5DAEA);
  static const figCFFD6DCF3 = Color(0xFFD6DCF3);
  static const figCFFD9962B = Color(0xFFD9962B);
  static const figCFFD9DEEE = Color(0xFFD9DEEE);
  static const figCFFD9DFEF = Color(0xFFD9DFEF);
  static const figCFFD9E0F5 = Color(0xFFD9E0F5);
  static const figCFFDCE1EB = Color(0xFFDCE1EB);
  static const figCFFDCE1F1 = Color(0xFFDCE1F1);
  static const figCFFDFE2EE = Color(0xFFDFE2EE);
  static const figCFFE2EAFB = Color(0xFFE2EAFB);
  static const figCFFE2F5EF = Color(0xFFE2F5EF);
  static const figCFFE3E7F4 = Color(0xFFE3E7F4);
  static const figCFFE3E8F5 = Color(0xFFE3E8F5);
  static const figCFFE3EBFB = Color(0xFFE3EBFB);
  static const figCFFE4E6EE = Color(0xFFE4E6EE);
  static const figCFFE5E8F2 = Color(0xFFE5E8F2);
  static const figCFFE6E7EC = Color(0xFFE6E7EC);
  static const figCFFE7E8ED = Color(0xFFE7E8ED);
  static const figCFFE7ECFB = Color(0xFFE7ECFB);
  static const figCFFE7EEFF = Color(0xFFE7EEFF);
  static const figCFFE9EBF3 = Color(0xFFE9EBF3);
  static const figCFFEAEDFB = Color(0xFFEAEDFB);
  static const figCFFEDEEF3 = Color(0xFFEDEEF3);
  static const figCFFEEEEF1 = Color(0xFFEEEEF1);
  static const figCFFEFF2FC = Color(0xFFEFF2FC);
  static const figCFFEFF2FD = Color(0xFFEFF2FD);
  static const figCFFF1F2F6 = Color(0xFFF1F2F6);
  static const figCFFF3F3F5 = Color(0xFFF3F3F5);
  static const figCFFF7F8FC = Color(0xFFF7F8FC);
  static const figCFFFBEFE0 = Color(0xFFFBEFE0);
  static const figCFFFF5A4D = Color(0xFFFF5A4D);
  static const figCFFFF6B6B = Color(0xFFFF6B6B);
  static const figCFFFF8A78 = Color(0xFFFF8A78);
  static const figCFFFFFFFF = Color(0xFFFFFFFF);
}
