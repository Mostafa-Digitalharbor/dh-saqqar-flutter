import 'package:flutter/material.dart';

/// Custom design tokens that don't fit Material's [ColorScheme].
///
/// Access via `Theme.of(context).extension<SaqqarThemeExtension>()!` or the
/// `context.saqqar` extension declared in `shared/extensions/context_extensions.dart`.
@immutable
class SaqqarThemeExtension extends ThemeExtension<SaqqarThemeExtension> {
  const SaqqarThemeExtension({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.muted,
    required this.border,
    required this.cardBg,
    required this.cardBorder,
    required this.hoverBg,
    required this.brandCyan,
    required this.brandCyanStrong,
    required this.brandPurple,
    required this.brandNavy,
    required this.success,
    required this.warning,
    required this.danger,
    required this.brandCyanSoft,
    required this.brandCyanBorder,
    required this.overlay,
    required this.codePlate,
  });

  // Surfaces.
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;

  // Text.
  final Color text;
  final Color muted;

  // Borders / hairlines.
  final Color border;
  final Color cardBg;
  final Color cardBorder;
  final Color hoverBg;

  // Brand.
  final Color brandCyan;
  final Color brandCyanStrong;
  final Color brandPurple;
  final Color brandNavy;

  // Status.
  final Color success;
  final Color warning;
  final Color danger;

  // Soft tints.
  final Color brandCyanSoft;
  final Color brandCyanBorder;

  // Overlays.
  final Color overlay;

  // Code / monospace plate background.
  final Color codePlate;

  @override
  SaqqarThemeExtension copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? text,
    Color? muted,
    Color? border,
    Color? cardBg,
    Color? cardBorder,
    Color? hoverBg,
    Color? brandCyan,
    Color? brandCyanStrong,
    Color? brandPurple,
    Color? brandNavy,
    Color? success,
    Color? warning,
    Color? danger,
    Color? brandCyanSoft,
    Color? brandCyanBorder,
    Color? overlay,
    Color? codePlate,
  }) {
    return SaqqarThemeExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      hoverBg: hoverBg ?? this.hoverBg,
      brandCyan: brandCyan ?? this.brandCyan,
      brandCyanStrong: brandCyanStrong ?? this.brandCyanStrong,
      brandPurple: brandPurple ?? this.brandPurple,
      brandNavy: brandNavy ?? this.brandNavy,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      brandCyanSoft: brandCyanSoft ?? this.brandCyanSoft,
      brandCyanBorder: brandCyanBorder ?? this.brandCyanBorder,
      overlay: overlay ?? this.overlay,
      codePlate: codePlate ?? this.codePlate,
    );
  }

  @override
  SaqqarThemeExtension lerp(
    ThemeExtension<SaqqarThemeExtension>? other,
    double t,
  ) {
    if (other is! SaqqarThemeExtension) return this;
    return SaqqarThemeExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      hoverBg: Color.lerp(hoverBg, other.hoverBg, t)!,
      brandCyan: Color.lerp(brandCyan, other.brandCyan, t)!,
      brandCyanStrong: Color.lerp(brandCyanStrong, other.brandCyanStrong, t)!,
      brandPurple: Color.lerp(brandPurple, other.brandPurple, t)!,
      brandNavy: Color.lerp(brandNavy, other.brandNavy, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      brandCyanSoft: Color.lerp(brandCyanSoft, other.brandCyanSoft, t)!,
      brandCyanBorder: Color.lerp(brandCyanBorder, other.brandCyanBorder, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      codePlate: Color.lerp(codePlate, other.codePlate, t)!,
    );
  }
}
