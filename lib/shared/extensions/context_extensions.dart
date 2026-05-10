import 'package:flutter/material.dart';

import '../../core/theme/saqqar_theme_extension.dart';

/// Convenience accessors so widgets can read the design tokens with
/// `context.saqqar.brandCyan` instead of pulling the extension manually.
extension SaqqarContextX on BuildContext {
  SaqqarThemeExtension get saqqar =>
      Theme.of(this).extension<SaqqarThemeExtension>()!;

  TextTheme get text => Theme.of(this).textTheme;

  ColorScheme get colors => Theme.of(this).colorScheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  Locale get locale => Localizations.localeOf(this);
}
