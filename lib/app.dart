import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/constants/ui_strings.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/app_strings.dart';
import 'core/i18n/view_model/locale_cubit.dart';
import 'core/routing/app_router.dart';
import 'core/routing/deep_link_service.dart';
import 'features/notifications/view_model/notifications_settings_cubit.dart';
import 'features/push/data/push_notifications_service.dart';
import 'features/security/view/app_lock_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/view_model/theme_cubit.dart';
import 'features/app_update/view/app_update_gate.dart';
import 'features/auth/view_model/auth_cubit.dart';
import 'features/auth/view_model/auth_state.dart';
import 'features/billing/view_model/plan_cubit.dart';
import 'features/billing/view_model/saqqar_features_cubit.dart';
import 'features/conversations/view_model/conversations_cubit.dart';
import 'features/launch/launch_splash_screen.dart';
import 'features/share/intake/share_intent_bootstrap.dart';
import 'features/vault/view_model/vault_cubit.dart';

class SaqqarApp extends StatefulWidget {
  const SaqqarApp({super.key});

  @override
  State<SaqqarApp> createState() => _SaqqarAppState();
}

class _SaqqarAppState extends State<SaqqarApp> {
  bool _splashDone = false;
  bool _nativeRemoved = false;
  bool _deepLinksStarted = false;

  /// The router is built once, lazily, the moment the splash finishes —
  /// kept in `late final` so theme/locale rebuilds don't tear it down.
  late final _router = buildAppRouter(context.read<AuthCubit>());

  /// Universal / App Links + `saqqar://` handler. Started after the router
  /// mounts (see the post-splash `onComplete` below) so a cold-start link has
  /// a live [appRouter] to navigate through.
  final DeepLinkService _deepLinks = DeepLinkService();

  @override
  void dispose() {
    _deepLinks.dispose();
    super.dispose();
  }

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
            // Capture the boot-scoped services BEFORE the async gap so we
            // never touch `context` after the await.
            final authCubit = context.read<AuthCubit>();
            final push = context.read<PushNotificationsService>();
            final notificationsEnabled =
                context.read<NotificationsSettingsCubit>().state;
            // Block the splash → router handoff until AuthCubit's
            // cold-start bootstrap (read stored token + validate via
            // /auth/me/) resolves. Otherwise the router's redirect
            // callback sees `auth.isResolved == false` and lets the user
            // through to /chats for one frame before bouncing them out —
            // visible as a flicker.
            await authCubit.bootstrap();
            // Cold-start push registration for a RETURNING signed-in user.
            // bootstrap() flips auth → authenticated HERE, before the
            // post-splash `BlocListener<AuthCubit>` (which owns the runtime
            // push.start/stop) has mounted — and BlocListener never fires
            // for the state present at mount. Without this, a returning user
            // never re-registers their FCM token (stale token → missed
            // pushes) until they re-auth or toggle the setting. start() is
            // idempotent (guards on `_started`), so if a later real
            // sign-in transition also fires the listener, this is a no-op.
            if (authCubit.state.status == AuthStatus.authenticated &&
                notificationsEnabled) {
              unawaited(push.start(localeCode: supportedLocale.languageCode));
            }
          },
          onComplete: () {
            if (!mounted) return;
            setState(() => _splashDone = true);
            // Start deep-link handling once, AFTER this rebuild mounts the
            // router (the `_router` getter — and therefore the global
            // `appRouter` — is evaluated during the rebuild that `setState`
            // triggers, before this post-frame callback runs). Doing it here
            // rather than at boot guarantees a cold-start link has a live
            // router to navigate through.
            if (!_deepLinksStarted) {
              _deepLinksStarted = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _deepLinks.start(),
              );
            }
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
        final push = context.read<PushNotificationsService>();
        if (authState.status == AuthStatus.authenticated) {
          // Register the FCM token + start listening once we know who's
          // signed in (idempotent — safe on every authenticated emit) — but
          // only if the user hasn't turned notifications off. The locale
          // rides along so the backend localizes the text (API_MOBILE_PUSH §9).
          if (context.read<NotificationsSettingsCubit>().state) {
            push.start(localeCode: supportedLocale.languageCode);
          }
          context.read<ConversationsCubit>().reset();
          context.read<VaultCubit>().reset();
          // The plan cubit is app-scoped and never closed, so without this
          // the previous account's feature gates stay live for the next user.
          context.read<PlanCubit>().clear();
          // Same reasoning: staff-only tool rows must not survive into the
          // next account's tools sheet.
          context.read<SaqqarFeaturesCubit>().clear();
          // Unregister this device so a signed-out phone gets no pushes.
          push.stop();
        }
      },
      child: BlocListener<LocaleCubit, Locale?>(
        // Re-register the push token when the UI language changes so the
        // backend localizes future notifications to the new language.
        listenWhen: (prev, curr) => prev?.languageCode != curr?.languageCode,
        listener: (context, loc) {
          final code = (loc?.languageCode ??
                      WidgetsBinding
                          .instance.platformDispatcher.locale.languageCode) ==
                  UiStrings.localeArabicCode
              ? UiStrings.localeArabicCode
              : UiStrings.localeEnglishCode;
          context.read<PushNotificationsService>().updateLocale(code);
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
          // [ShareIntentBootstrap] lives INSIDE the MaterialApp.router
          // builder so it sits BELOW the Navigator — that's the level at
          // which `showModalBottomSheet` finds an Overlay to draw on.
          // Wrapping above the router would yield "No MaterialLocalizations
          // found" the moment the share sheet tries to render.
          return MediaQuery(
            data: media.copyWith(textScaler: clamped),
            // AppUpdateGate sits OUTSIDE AppLockGate: when a build is below
            // the backend's supported floor there is nothing behind the lock
            // worth authenticating into, so making the user pass Face ID
            // first only to meet a wall would be pure friction. The wall
            // shows no user data, so it is also safe as the app-switcher
            // snapshot that the lock normally exists to hide.
            child: AppUpdateGate(
              // AppLockGate overlays the biometric lock above EVERYTHING
              // (including the share sheet + any open dialog) and re-locks on
              // background. Sits inside the builder so it's below the root
              // Navigator — the lock screen's sign-out dialog still resolves.
              child: AppLockGate(
                child: ShareIntentBootstrap(
                  // Global "tap a blank area to dismiss the keyboard". iOS has
                  // no system button to hide the soft keyboard (Android's back
                  // gesture does), so without this a user can get stuck with
                  // the keyboard covering the UI on any screen that lacks an
                  // obvious "done" affordance.
                  child: _DismissKeyboardOnTap(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

/// Root wrapper that unfocuses the active text field when the user taps a
/// blank area, dismissing the soft keyboard.
///
/// Primarily an iOS fix: unlike Android (whose system back gesture hides
/// the keyboard), iOS offers no built-in way to dismiss it, so a field on a
/// screen without an explicit "done" affordance can trap the user with the
/// keyboard covering the UI. A translucent tap recognizer at the app root
/// catches taps that aren't consumed by a button, field, or scroll/drag
/// gesture and clears the focus. Tap-only, so it never competes with the
/// swipe-to-archive Dismissible, drawers, or list scrolling.
class _DismissKeyboardOnTap extends StatelessWidget {
  const _DismissKeyboardOnTap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      // Translucent so taps landing on non-interactive blank space still
      // reach this recognizer; interactive children (buttons/fields) win
      // the gesture arena and keep working normally.
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      child: child,
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
