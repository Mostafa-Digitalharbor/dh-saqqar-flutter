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

  /// Anchor rect for `share_plus`'s `sharePositionOrigin`.
  ///
  /// Required on iPad, ignored everywhere else. `UIActivityViewController`
  /// is presented as a **popover** on iPad, and a popover with no source
  /// rect is a hard error — `share_plus` returns
  /// "sharePositionOrigin: argument must be set …" instead of showing the
  /// sheet, so Share just does nothing there. iPhone and Android never hit
  /// it, which is exactly why it survives testing on those.
  ///
  /// Falls back to a small rect at the centre of the screen when this
  /// context has no box (or a zero-sized one), because passing null would
  /// reintroduce the failure.
  Rect get sharePositionOrigin {
    final box = findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(this);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }
}
