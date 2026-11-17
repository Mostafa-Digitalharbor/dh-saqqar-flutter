import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_sizes.dart';
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

  /// The chevron meaning "onward" — into a detail, to the next page.
  ///
  /// Points right in English and **left in Arabic**, because "forward" is a
  /// direction on the screen, not a fixed glyph. Seven widgets drew one of
  /// these and only three flipped it: on a device running in Arabic, the
  /// account rows, the chat sidebar's footer and the share sheet's rows all
  /// pointed their chevron *back the way the user came*, while the vault
  /// three rows away pointed the other way. Reading it off the context means
  /// a call site cannot get it wrong by not knowing to ask.
  IconData get chevronForward =>
      isRtl ? AppIcons.chevronLeft : AppIcons.chevronRight;

  /// The chevron meaning "back" — out of a detail, to the previous page.
  /// The mirror of [chevronForward].
  IconData get chevronBack =>
      isRtl ? AppIcons.chevronRight : AppIcons.chevronLeft;

  /// The double chevron meaning "all the way back" — to the first page.
  IconData get chevronsBack =>
      isRtl ? AppIcons.chevronsRight : AppIcons.chevronsLeft;

  /// The arrow meaning "continue" — on a primary button that advances a flow.
  ///
  /// Seven of the auth flow's nine steps put this on their Continue button,
  /// so on an Arabic device the arrow pointed backwards on the first screen
  /// the user ever sees.
  IconData get arrowForward => isRtl ? AppIcons.arrowLeft : AppIcons.arrowRight;

  // No `signOutGlyph` / `signInGlyph` here any more. They used to swap
  // Lucide's `logOut` for `logIn` in RTL on the belief that the two are
  // mirrors — they are not, and the swap put an ENTER arrow on the Arabic
  // Sign out button. Those two glyphs now carry `matchTextDirection`, so a
  // bare `AppIcons.signOut` reflects itself and needs no accessor. See
  // [AppIcons.signOut].

  /// Resolves an [AlphaPair] against the active brightness.
  ///
  /// ```dart
  /// color: s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.panel)),
  /// ```
  ///
  /// Exists so the brightness check lives in one place. Every glass surface
  /// in the app used to inline its own `isDark ? 0.55 : 0.9`, and 54 of
  /// those ternaries spelled 29 different pairs for what were mostly the
  /// same few roles — see [AppAlphaPairs] for the full census.
  double alpha(AlphaPair pair) => pair.resolve(isDark: isDark);

  /// The 1 x 1 rect used as a degenerate fallback below. Not a design
  /// token: it is the smallest legal source rect, deliberately not a
  /// visible size.
  static const double _fallbackOriginExtent = 1;

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
      width: _fallbackOriginExtent,
      height: _fallbackOriginExtent,
    );
  }
}
