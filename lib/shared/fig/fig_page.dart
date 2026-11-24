import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import 'fig.dart';

/// The page frame of the redesign for screens that were not drawn in the
/// Figma set: gradient backdrop, light status-bar icons, back button and a big
/// white title, with [child] filling the rest.
///
/// [child] keeps using the regular light theme (`context.saqqar`, `AppTextField`
/// and friends), pinned to light so those widgets stay legible on the fixed
/// light page whatever the device theme is.
class FigPage extends StatelessWidget {
  const FigPage({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.action,
    this.dark = false,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget child;

  /// Optional control shown opposite the back button, e.g. an "open in
  /// another app" icon.
  final Widget? action;

  /// Draws the body on the dark Figma panel (like the tools and company
  /// sheets) instead of the light one; popups opened from it follow.
  final bool dark;

  /// Defaults to popping, or to the home tab when there is nothing to pop.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The header takes the room it needs, but never more than
                  // under half the screen: a long title at a large text size or
                  // on a small phone scrolls inside its own band rather than
                  // squeezing the page body out of the layout.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: box.maxHeight.isFinite
                          ? box.maxHeight * AppFractions.pageHeaderMax
                          : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      child: Stack(
                        children: [
                          FigPageHeader(
                            eyebrow: eyebrow,
                            title: title,
                            subtitle: subtitle,
                            onBack:
                                onBack ??
                                () => context.canPop()
                                    ? context.pop()
                                    : context.go(RouteNames.homePath),
                          ),
                          if (action != null)
                            PositionedDirectional(
                              end: AppSpacing.s12,
                              top: AppSpacing.s29,
                              child: action!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  // The body sits on its own light sheet so the regular light-theme
                  // widgets keep their contrast instead of landing on the
                  // gradient, whatever height it is at.
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.sheetTop),
                      ),
                      child: ColoredBox(
                        color: dark ? AppColors.figCFF17181B : Fig.pageGrey,
                        child: Theme(
                          data: dark
                              ? AppTheme.dark(Localizations.localeOf(context))
                              : AppTheme.light(Localizations.localeOf(context)),
                          // Screens pad their own content by 16; this 8 brings
                          // the cards to the header's 24 gutter, the one the
                          // drawn Figma pages (Account, Vault) already use.
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                            ),
                            child: dark ? FigDarkSurface(child: child) : child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
