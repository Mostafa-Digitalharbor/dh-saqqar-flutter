import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/view_model/locale_cubit.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/view_model/theme_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Two-icon row pinned to the top of the auth scaffolds (sign-in /
/// sign-up). Lets the user flip language (EN ↔ AR) and theme (light ↔
/// dark) before authenticating — important on first-launch, when the
/// account preferences card (which carries the same controls) isn't
/// reachable yet because the user isn't signed in.
///
/// Trailing-aligned (start-side in LTR, end-side in RTL) so it doesn't
/// fight the brand wordmark that owns the top-start corner of the auth
/// surface on wide layouts.
class AuthHeaderActions extends StatelessWidget {
  const AuthHeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final themeMode = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;

    // "Effective" dark — system mode means whatever the OS is set to.
    final isDark = switch (themeMode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final isArabic =
        locale?.languageCode == UiStrings.localeArabicCode ||
            (locale == null &&
                Localizations.localeOf(context).languageCode ==
                    UiStrings.localeArabicCode);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _HeaderIconButton(
            icon: AppIcons.globe,
            tooltip: isArabic
                ? context.tr.switchLanguageToEnglish
                : context.tr.switchLanguageToArabic,
            label: isArabic
                ? UiStrings.localeEnglishLabel
                : UiStrings.localeArabicLabel,
            color: s.brandCyan,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<LocaleCubit>().toggleEnglishArabic();
            },
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: isDark ? AppIcons.sun : AppIcons.moon,
            tooltip: isDark
                ? context.tr.switchThemeToLight
                : context.tr.switchThemeToDark,
            color: s.brandPurple,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<ThemeCubit>().toggle();
            },
          ),
        ],
      ),
    );
  }
}

/// Circular ghost-style icon button used inside the header row. Translucent
/// surface + brand-tinted border so it reads as a "soft" control rather
/// than a primary action — the screen's primary action is still the
/// sign-in / create-account button.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  /// Tiny letter rendered next to the icon (e.g. "EN" / "ع") so the
  /// language toggle reads at-a-glance which language is one tap away.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: s.surface.withValues(alpha: context.isDark ? 0.55 : 0.82),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.32)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 10 : 12,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: context.text.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
