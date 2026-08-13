import 'package:flutter/material.dart';

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
  static final Color brandCyanSoftDark = brandCyan.withValues(alpha: 0.18);
  static final Color brandCyanSoftLight = brandCyan.withValues(alpha: 0.14);
  static final Color brandCyanBorder = brandCyan.withValues(alpha: 0.30);

  // Overlay (modal/sheet backdrop) — saqqaar.com app.css uses rgba(2,6,23,0.72).
  static const overlayDark = Color(0xB8020617);
  static const overlayLight = Color(0x66020617);

  // Cyan pop shadow (CTA + active rows) — 0 10px 30px rgba(6,182,212,0.18).
  static final Color popShadowCyan = brandCyan.withValues(alpha: 0.18);

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
  static const List<List<Color>> avatarGradients = [
    [brandNavy, brandCyan],
    [Color(0xFF0E7490), brandCyanStrong],
    [Color(0xFF5B21B6), brandPurple],
    [Color(0xFF155E63), success],
    [Color(0xFF1E3A8A), Color(0xFF6366F1)],
    [Color(0xFF0F766E), Color(0xFF2DD4BF)],
  ];
}
