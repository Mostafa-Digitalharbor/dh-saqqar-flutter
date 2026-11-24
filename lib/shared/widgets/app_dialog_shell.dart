import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../fig/fig.dart';

/// The app's standard modal dialog chrome, in the Figma look: a white card with
/// the large sheet radius and a soft lift, no hairline border or accent bar.
///
/// The content is pinned to the light theme (as [FigPage] does) so the regular
/// `context.saqqar` widgets inside — text fields, ghost buttons — stay legible
/// on the white card whatever the device theme is.
///
/// Supplies chrome only. Content, buttons and padding stay with the caller.
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.child,
    this.maxWidth = 380,
  });

  /// Dialog body — usually a `Column(mainAxisSize: .min)` or a
  /// `SingleChildScrollView`. Wrapped in a [Flexible] so long content scrolls
  /// instead of overflowing.
  final Widget child;

  /// Cap so the card doesn't stretch edge-to-edge on tablets/foldables.
  final double maxWidth;

  /// Horizontal AND vertical insets, deliberately.
  ///
  /// `vertical: 24` is load-bearing, not cosmetic: passing only
  /// `horizontal` sets the vertical inset to 0, which lets the dialog claim
  /// the FULL viewport height. An unscrollable column then has nothing to
  /// push back against and overflows — in landscape (~320 px tall), or with
  /// a long user-supplied name at 1.4x Arabic. Keep both axes.
  static const insetPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s32,
    vertical: AppSpacing.s24,
  );

  @override
  Widget build(BuildContext context) {
    final dark = FigDarkSurface.of(context);
    final locale = Localizations.localeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? AppColors.figCFF17181B : AppColors.figWhite,
            borderRadius: BorderRadius.circular(AppRadius.sheetTop),
            boxShadow: const [
              BoxShadow(
                color: Fig.drawerShadow,
                blurRadius: AppSpacing.s36,
                offset: Offset(0, AppSpacing.s12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sheetTop),
            child: Theme(
              data: dark ? AppTheme.dark(locale) : AppTheme.light(locale),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: dark ? FigDarkSurface(child: child) : child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
