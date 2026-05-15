import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/glass_card.dart';

/// Theme + language preferences card. Reads/writes the two top-level
/// Riverpod controllers (`themeControllerProvider`, `localeControllerProvider`).
class PreferencesCard extends StatelessWidget {
  const PreferencesCard({
    super.key,
    required this.mode,
    required this.locale,
    required this.ref,
  });

  final AppThemeMode mode;
  final Locale? locale;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr.preferences, style: context.text.titleMedium),
          const SizedBox(height: 14),
          Text(
            context.tr.theme,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text(context.tr.themeLight),
                icon: const Icon(AppIcons.sun),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text(context.tr.themeDark),
                icon: const Icon(AppIcons.moon),
              ),
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text(context.tr.themeSystem),
                icon: const Icon(AppIcons.settings),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => ref
                .read(themeControllerProvider.notifier)
                .setMode(selection.first),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr.language,
            style: context.text.labelLarge?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: UiStrings.localeEnglishCode,
                label: Text(context.tr.english),
              ),
              ButtonSegment(
                value: UiStrings.localeArabicCode,
                label: Text(context.tr.arabic),
              ),
              ButtonSegment(
                value: UiStrings.localeSystemCode,
                label: Text(context.tr.system),
              ),
            ],
            selected: {locale?.languageCode ?? UiStrings.localeSystemCode},
            onSelectionChanged: (selection) {
              final value = selection.first;
              ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(
                    value == UiStrings.localeSystemCode ? null : Locale(value),
                  );
            },
          ),
        ],
      ),
    );
  }
}
