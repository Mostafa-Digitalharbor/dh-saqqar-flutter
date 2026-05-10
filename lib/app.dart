import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/ui_strings.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/app_strings.dart';
import 'core/i18n/locale_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class SaqqarApp extends ConsumerWidget {
  const SaqqarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(routerProvider);

    // The theme rebuilds when locale changes so the font family swaps too.
    final effectiveLocale =
        locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final supportedLocale = AppStrings.supported.firstWhere(
      (l) => l.languageCode == effectiveLocale.languageCode,
      orElse: () => const Locale(UiStrings.localeEnglishCode),
    );

    return MaterialApp.router(
      title: AppStrings(supportedLocale).appName,
      debugShowCheckedModeBanner: false,
      themeMode: mode.materialMode,
      theme: AppTheme.light(supportedLocale),
      darkTheme: AppTheme.dark(supportedLocale),
      locale: locale,
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
