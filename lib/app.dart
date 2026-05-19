import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/constants/ui_strings.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/app_strings.dart';
import 'core/i18n/view_model/locale_cubit.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/view_model/theme_cubit.dart';
import 'features/auth/view_model/auth_cubit.dart';
import 'features/auth/view_model/auth_state.dart';
import 'features/conversations/view_model/conversations_cubit.dart';
import 'features/launch/launch_splash_screen.dart';
import 'features/vault/view_model/vault_cubit.dart';

class SaqqarApp extends StatefulWidget {
  const SaqqarApp({super.key});

  @override
  State<SaqqarApp> createState() => _SaqqarAppState();
}

class _SaqqarAppState extends State<SaqqarApp> {
  bool _splashDone = false;
  bool _nativeRemoved = false;

  /// The router is built once, lazily, the moment the splash finishes —
  /// kept in `late final` so theme/locale rebuilds don't tear it down.
  late final _router = buildAppRouter(context.read<AuthCubit>());

  @override
  Widget build(BuildContext context) {
    // Rebuild the MaterialApp on every theme/locale change so the font
    // family (Inter / Tajawal) and surface palette swap correctly.
    final mode = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;

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
            // Block the splash → router handoff until AuthCubit's
            // cold-start bootstrap (read stored token + validate via
            // /auth/me/) resolves. Otherwise the router's redirect
            // callback sees `auth.isResolved == false` and lets the user
            // through to /chats for one frame before bouncing them out —
            // visible as a flicker.
            await context.read<AuthCubit>().bootstrap();
          },
          onComplete: () {
            if (!mounted) return;
            setState(() => _splashDone = true);
          },
        ),
      );
    }

    return BlocListener<AuthCubit, AuthState>(
      // Wipe per-account caches whenever the signed-in identity changes:
      // sign-out, 401-driven session drop, OR a new account signing in
      // on the same device. Without this, ConversationsCubit / VaultCubit
      // keep their last user's data in memory and the new session sees
      // a flash of the previous account's chats / projects before the
      // first refresh lands.
      listenWhen: (prev, curr) {
        if (prev.status != curr.status) return true;
        return prev.user?.id != curr.user?.id;
      },
      listener: (context, authState) {
        if (authState.status == AuthStatus.unauthenticated) {
          context.read<ConversationsCubit>().reset();
          context.read<VaultCubit>().reset();
        }
      },
      child: MaterialApp.router(
        title: AppStrings(supportedLocale).appName,
        debugShowCheckedModeBanner: false,
        themeMode: mode.materialMode,
        theme: lightTheme,
        darkTheme: darkTheme,
        locale: locale,
        supportedLocales: AppStrings.supported,
        // Smooth iOS-style scroll on every platform. Android's default
        // ClampingScrollPhysics felt "heavy / panicky" on touch — the
        // bouncing physics + AlwaysScrollable parent gives momentum
        // and gentle deceleration everywhere consistently.
        scrollBehavior: const _SmoothScrollBehavior(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
        builder: (context, child) {
          // Honour the OS Dynamic Type setting but clamp to a safe range so
          // very large user scaling (e.g. accessibility 3x) doesn't break
          // the chat bubble + tab bar layouts. 0.85–1.4 keeps the spec
          // §2.2 type hierarchy legible without overflowing fixed-height
          // surfaces.
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
      ),
    );
  }
}

/// App-wide [ScrollBehavior] that swaps Android's default clamping
/// physics for the iOS-style bouncing variant on every platform.
///
/// IMPORTANT: plain [BouncingScrollPhysics] without an
/// `AlwaysScrollable` parent. An earlier revision wrapped it with
/// `AlwaysScrollableScrollPhysics` and that turned every nested
/// scrollable in the app — markdown bodies, code blocks, dropdowns —
/// into a scroll surface, which made long messages inside a chat
/// bubble scroll internally instead of expanding the bubble. Surfaces
/// that genuinely need "always scrollable" (e.g. the chat list itself,
/// which has to support pull-to-refresh) opt in locally on their own
/// `physics` parameter.
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
