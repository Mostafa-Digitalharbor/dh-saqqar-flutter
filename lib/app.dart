import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/ui_strings.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/app_strings.dart';
import 'core/i18n/locale_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/launch/launch_splash_screen.dart';

class SaqqarApp extends ConsumerStatefulWidget {
  const SaqqarApp({super.key});

  @override
  ConsumerState<SaqqarApp> createState() => _SaqqarAppState();
}

class _SaqqarAppState extends ConsumerState<SaqqarApp> {
  bool _splashDone = false;
  bool _nativeRemoved = false;

  @override
  Widget build(BuildContext context) {
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

    final lightTheme = AppTheme.light(supportedLocale);
    final darkTheme = AppTheme.dark(supportedLocale);

    // Until the in-app splash finishes its zoom-in + loading sequence, we
    // render a bare-bones MaterialApp whose only child is
    // [LaunchSplashScreen]. The router (and therefore the rest of the
    // shell, conversations, etc.) doesn't mount until `_splashDone` flips,
    // which prevents a flash of the chat surface behind the splash.
    if (!_splashDone) {
      return MaterialApp(
        title: AppStrings(supportedLocale).appName,
        debugShowCheckedModeBanner: false,
        themeMode: mode.materialMode,
        theme: lightTheme,
        darkTheme: darkTheme,
        locale: locale,
        supportedLocales: AppStrings.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LaunchSplashScreen(
          onReady: () async {
            // Remove the native OS splash the moment the in-app one is up.
            // Once-only — calling .remove() twice is a no-op but noisy.
            if (!_nativeRemoved) {
              FlutterNativeSplash.remove();
              _nativeRemoved = true;
            }
          },
          onComplete: () {
            if (!mounted) return;
            setState(() => _splashDone = true);
          },
        ),
      );
    }

    return MaterialApp.router(
      title: AppStrings(supportedLocale).appName,
      debugShowCheckedModeBanner: false,
      themeMode: mode.materialMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      locale: locale,
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        // Honour the OS Dynamic Type setting but clamp to a safe range so
        // very large user scaling (e.g. accessibility 3x) doesn't break the
        // chat bubble + tab bar layouts. 0.85–1.4 keeps the spec §2.2 type
        // hierarchy legible without overflowing fixed-height surfaces.
        final media = MediaQuery.of(context);
        final clamped = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.4,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
