import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider, Provider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/foundation.dart';

import 'app.dart';
import 'core/i18n/platform_strings.dart';
import 'core/i18n/remote_i18n_api.dart';
import 'core/logging/app_bloc_observer.dart';
import 'core/logging/app_logger.dart';
import 'shared/widgets/app_error_screen.dart';
import 'core/i18n/view_model/locale_cubit.dart';
import 'core/network/api_exception.dart';
import 'core/network/dio_client.dart';
import 'core/network/view_model/connectivity_cubit.dart';
import 'core/storage/secure_token_store.dart';
import 'core/theme/view_model/theme_cubit.dart';
import 'features/apps/data/apps_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/social_auth_service.dart';
import 'features/auth/view_model/auth_cubit.dart';
import 'features/billing/data/billing_history_api.dart';
import 'features/billing/data/plans_api.dart';
import 'features/billing/data/usage_api.dart';
import 'features/data_api/data/odoo_data_api.dart';
import 'features/meetings/data/meetings_api.dart';
import 'features/trial/data/trial_api.dart';
import 'features/billing/view_model/plan_cubit.dart';
import 'features/billing/view_model/saqqar_features_cubit.dart';
import 'features/chat/data/live_env_ack_service.dart';
import 'features/chat/data/saqqar_tools_api.dart';
import 'features/support/data/voice_support_api.dart';
import 'features/chat/data/transcribe_api.dart';
import 'features/chat/view_model/task_prep_cubit.dart';
import 'features/chat/view_model/running_agents_cubit.dart';
import 'features/conversations/data/conversations_api.dart';
import 'features/chat/data/chat_snapshot_disk_cache.dart';
import 'features/notifications/data/notifications_store.dart';
import 'features/notifications/view_model/notifications_settings_cubit.dart';
import 'features/push/data/push_notifications_service.dart';
import 'features/security/data/biometric_auth.dart';
import 'features/security/view_model/app_lock_cubit.dart';
import 'features/conversations/data/conversations_cache.dart';
import 'features/conversations/data/conversations_repository.dart';
import 'features/conversations/view_model/conversations_cubit.dart';
import 'features/inbox/data/approvals_api.dart';
import 'features/inbox/data/artifacts_api.dart';
import 'features/inbox/view_model/approvals_cubit.dart';
import 'features/push/data/devices_api.dart';
import 'features/share/data/shares_api.dart';
import 'features/share/intake/share_intake_service.dart';
import 'features/vault/data/credentials_api.dart';
import 'features/vault/data/projects_api.dart';
import 'features/vault/data/vault_cache.dart';
import 'features/vault/data/vault_repository.dart';
import 'features/vault/view_model/vault_cubit.dart';
import 'features/watch/data/watch_bridge.dart';

/// Boot order:
///   1. Bind Flutter immediately and PRESERVE the native splash so the
///      OS-rendered logo stays visible while we hydrate SharedPreferences.
///   2. Build the eager dependencies (SharedPreferences + SecureTokenStore
///      + Dio + repositories) — they're cheap and let the
///      RepositoryProvider tree resolve synchronously.
///   3. Hand off to [SaqqarApp]. Its first child is the in-app
///      [LaunchSplashScreen] which animates the same logo (zoom-in) on
///      top of the OS splash before removing it. The transition feels
///      seamless because both surfaces center the same artwork.
///   4. The in-app splash awaits `AuthCubit.bootstrap()` (cold-start
///      `/auth/me/` validation) before handing off to the router, so the
///      router's auth gate sees a resolved status and doesn't flash the
///      /chats surface before redirecting.
Future<void> main() async {
  // Disable Provider's debug check that flags any Listenable / Stream
  // value as "you probably want ChangeNotifierProvider instead". We
  // already use `ChangeNotifierProvider.value` for [ShareIntakeService]
  // — but flutter_bloc's `MultiRepositoryProvider` re-wraps every
  // child in an `InheritedProvider` whose value-type check still trips
  // on Listenable subtypes in some configurations. Silencing the
  // debug-only check here keeps the share-from-WhatsApp flow working
  // without making the architecture less explicit.
  Provider.debugCheckInvalidValueType = null;

  // Read the app version/build ONCE up front so Sentry's `release` tag
  // tracks pubspec automatically. `PackageInfo.fromPlatform()` needs the
  // binding, so ensure it here — the call is idempotent, so `_bootApp`
  // re-ensuring it below is harmless. Guarded so a platform channel
  // failure degrades to an empty release instead of blocking boot.
  //
  // **`SentryWidgetsFlutterBinding`, not `WidgetsFlutterBinding`.** A Flutter
  // binding is a singleton: whichever type is instantiated first wins for the
  // life of the process. Ensuring the plain one here — before
  // `SentryFlutter.init` runs below — left Sentry's `FramesTrackingIntegration`
  // with a binding it cannot hook, so it disabled itself at boot with
  //   "incompatible binding, SentryWidgetsFlutterBinding has not been
  //    instantiated"
  // and every slow-frame / frozen-frame metric was silently never collected.
  // Observed on a real device 2026-08-09. It is a subclass of
  // `WidgetsFlutterBinding`, so nothing else changes.
  SentryWidgetsFlutterBinding.ensureInitialized();
  String release = '';
  try {
    final info = await PackageInfo.fromPlatform();
    release = 'saqqar@${info.version}+${info.buildNumber}';
  } catch (e, st) {
    AppLogger.warn('main', 'PackageInfo read failed', error: e, stackTrace: st);
  }

  // Sentry wraps the boot via `appRunner` so any synchronous OR async
  // crash during startup is captured (including the first frame paint).
  // The DSN comes from `--dart-define=SAQQAR_SENTRY_DSN=https://…@…/…`
  // so it never lands in source control. When the define is empty
  // (local dev), Sentry effectively disables itself — no network calls,
  // no overhead.
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment(
        'SAQQAR_SENTRY_DSN',
        defaultValue: '',
      );
      // Tag every event with the build environment so the dashboard
      // can split prod crashes from dev / CI noise. `release` is read
      // from PackageInfo above so it tracks pubspec automatically — no
      // hand-edited version string to drift on each bump. Falls back to
      // Sentry's own auto-detection when the PackageInfo read failed.
      options.environment = kReleaseMode ? 'production' : 'development';
      if (release.isNotEmpty) options.release = release;
      // Drop sample rate for transactions to 10% — chat polling fires
      // every 1.5 s; tracing every call would burn the free quota in
      // hours. Errors are always sent (sample rate ignored on those).
      options.tracesSampleRate = 0.1;
      // Never ship PII: no email, no IP, no screenshots, no widget
      // tree dumps. The app touches credentials and Odoo data, so the
      // payload to Sentry stays strictly to stack traces + breadcrumbs.
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
      options.attachViewHierarchy = false;
      // Final filter before any event leaves the device. Catches the
      // small percentage of errors that bypass our AppLogger crash
      // reporter — e.g. uncaught DioException from a future Flutter
      // engine path, or anything the Sentry integration auto-captures.
      // `_shouldSkipSentry` is the single source of truth for "is this
      // a real bug or environmental noise" — see its doc for the rules.
      options.beforeSend = (event, hint) {
        if (_shouldSkipSentry(event.throwable)) return null;
        return event;
      };
    },
    appRunner: _bootApp,
  );
}

Future<void> _bootApp() async {
  // Same binding as `main` ensured above — idempotent, and named the same way
  // so nobody "tidies" this back to the plain type and re-breaks frame
  // tracking from a call site that looks unrelated to Sentry.
  final binding = SentryWidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Firebase (push notifications). `firebase_options.dart` + the Android
  // google-services plugin were generated by `flutterfire configure`.
  // Wrapped in try/catch so a misconfigured platform (e.g. iOS before its
  // GoogleService-Info.plist lands) degrades to "no push" instead of a boot
  // crash. The background message handler MUST be registered here, top-level.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    AppLogger.warn('main', 'Firebase init skipped', error: e, stackTrace: st);
  }

  // (google_fonts removed in 1.0.17+18 — `AppTypography` now uses
  // platform default fonts directly. Keeping the comment so future
  // refactors don't reintroduce the CDN dependency without a deliberate
  // discussion about bundling the .ttf files.)

  // Globally observe every Cubit lifecycle (create / state change /
  // error / close) so debugging doesn't require manual `print`s inside
  // cubits. No-op in release builds — see [AppBlocObserver].
  Bloc.observer = AppBlocObserver();

  // Bridge cubit-level warn/error calls (caught inside try/catch
  // blocks in repositories and cubits) into Sentry. Without this, only
  // uncaught Flutter errors reach the dashboard — caught exceptions
  // like "PATCH failed, optimistic update rolled back" stay invisible.
  AppLogger.setCrashReporter((level, tag, message, {error, stackTrace}) {
    if (_shouldSkipSentry(error)) return;
    Sentry.captureException(
      error ?? message,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('source', tag);
        scope.level = level == LogLevel.error
            ? SentryLevel.error
            : SentryLevel.warning;
      },
    );
  });

  // Replace Flutter's default red ErrorWidget (which is fine in debug
  // but terrifying in production) with a friendly plate that explains
  // what happened in human terms and exposes the raw exception only in
  // debug builds.
  ErrorWidget.builder = (details) => AppErrorScreen(details: details);

  // Chain AppLogger on top of whatever handler Sentry already
  // installed inside `SentryFlutter.init`. Forwarding to the previous
  // handler (instead of overwriting it) keeps both surfaces wired:
  // AppLogger prints to the dev console + bloc observer log, Sentry
  // captures the error to the dashboard. Same pattern for the
  // platform dispatcher so async errors outside the framework hit
  // both pipelines.
  final sentryFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.error(
      'FlutterError',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    sentryFlutterError?.call(details);
  };

  final sentryPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'PlatformDispatcher',
      error.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    return sentryPlatformError?.call(error, stackTrace) ?? true;
  };

  final prefs = await SharedPreferences.getInstance();
  final tokenStore = SecureTokenStore();

  // Chicken-and-egg: Dio's auth interceptor needs to notify AuthCubit
  // on 401, but the cubit can't exist until Dio is built (it depends on
  // AuthApi which depends on Dio). The forward holder is a one-element
  // box we populate after AuthCubit is constructed below, so the
  // interceptor's `onUnauthorized` callback resolves correctly at call
  // time even though we wired it before the cubit existed.
  AuthCubit? authCubitRef;
  final Dio dio = buildDio(
    tokenStore,
    onUnauthorized: () => authCubitRef?.handleUnauthorized(),
  );

  // Repositories are constructed once at boot and shared across every
  // cubit via `RepositoryProvider`. Cheap to build (no I/O), so doing it
  // here keeps `main` predictable and lets tests override individually.
  final authApi = AuthApi(dio);
  // Native Google / Apple sign-in wrapper (docs/MOBILE_AUTH_GUIDE.md). No I/O
  // at construction — the underlying SDKs init lazily on first use.
  final socialAuthService = SocialAuthService();
  final projectsApi = ProjectsApi(dio);
  final plansApi = PlansApi(dio);
  final usageApi = UsageApi(dio);
  // New endpoints (API_MOBILE_NEW_ENDPOINTS.md). Cheap to build (no I/O);
  // the §4 clients (meetings / direct-data) are data-layer-only seams with
  // no UI yet, provided so a future feature can `context.read` them.
  final appsApi = AppsApi(dio);
  final trialApi = TrialApi(dio);
  final billingHistoryApi = BillingHistoryApi(dio);
  final meetingsApi = MeetingsApi(dio);
  final odooDataApi = OdooDataApi(dio);
  final credentialsApi = CredentialsApi(dio);
  final conversationsApi = ConversationsApi(dio);
  final approvalsApi = ApprovalsApi(dio);
  final artifactsApi = ArtifactsApi(dio);
  final sharesApi = SharesApi(dio);
  final remoteI18nApi = RemoteI18nApi(dio);
  final devicesApi = DevicesApi(dio);
  final transcribeApi = TranscribeApi(dio);
  final saqqarToolsApi = SaqqarToolsApi(dio);
  final voiceSupportApi = VoiceSupportApi(dio);
  // Resolves localized copy for the surfaces that render OUTSIDE the widget
  // tree — Android's notification channels (shown in system Settings) and
  // the Apple Watch face. Neither has a BuildContext, so neither can reach
  // `context.tr`; without this they'd be hardcoded English.
  final platformStrings = PlatformStrings(prefs);
  // Companion Apple Watch bridge — pushes the pending-approvals feed to a
  // paired watch, relays approve/deny taps back to this same
  // ApprovalsApi, and turns a watch-recorded voice note into a normal
  // chat turn via transcribeApi + conversationsApi. No-op on Android /
  // when no watch is paired.
  final watchBridge = WatchBridge(
    approvalsApi,
    transcribeApi: transcribeApi,
    conversationsApi: conversationsApi,
    projectsApi: projectsApi,
    platformStrings: platformStrings,
  );
  // In-app inbox of received notifications (persisted); the header bell reads
  // it, the push service + background isolate write to it.
  final notificationsStore = NotificationsStore(prefs);
  // FCM push: registers the device token, displays foreground messages,
  // records them to the inbox, and routes notification taps. Started/stopped
  // by the auth listener in app.dart.
  final pushService =
      PushNotificationsService(devicesApi, notificationsStore, platformStrings);
  final liveEnvAckService = LiveEnvAckService(prefs);
  // In-memory hand-off between Android's ACTION_SEND intent-filter and
  // the chat screen. Lives at boot scope so files survive the
  // BlocProvider rebuild that fires when the user picks a destination.
  final shareIntakeService = ShareIntakeService();

  // Feature-level repositories aggregate one-or-more low-level APIs into
  // a single surface the cubit reads against. Add new ones here as you
  // wire each feature in Phase 3 of the API migration.
  final vaultRepository = VaultRepository(
    projectsApi: projectsApi,
    credentialsApi: credentialsApi,
    // Offline cache: persists projects + schemas (NEVER credential
    // payloads) to SharedPreferences so the Vault renders instantly on
    // cold start while a fresh fetch runs in the background.
    cache: VaultCache(prefs),
  );
  final conversationsRepository = ConversationsRepository(
    conversationsApi,
    approvalsApi: approvalsApi,
    watchBridge: watchBridge,
    // Offline cache: persists the Chats list + counts so the tab paints
    // instantly on cold start while a fresh fetch runs in the background.
    listCache: ConversationsCache(prefs),
    // On-disk transcript cache (+ background prefetch) so opening any chat
    // is instant even after an app restart. Dir resolves lazily, so this
    // costs nothing at startup.
    snapshotDiskCache: ChatSnapshotDiskCache(),
  );


  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>.value(value: prefs),
        RepositoryProvider<SecureTokenStore>.value(value: tokenStore),
        RepositoryProvider<Dio>.value(value: dio),
        RepositoryProvider<AuthApi>.value(value: authApi),
        RepositoryProvider<SocialAuthService>.value(value: socialAuthService),
        RepositoryProvider<ProjectsApi>.value(value: projectsApi),
        RepositoryProvider<PlansApi>.value(value: plansApi),
        RepositoryProvider<UsageApi>.value(value: usageApi),
        // New endpoints (API_MOBILE_NEW_ENDPOINTS.md).
        RepositoryProvider<AppsApi>.value(value: appsApi),
        RepositoryProvider<TrialApi>.value(value: trialApi),
        RepositoryProvider<BillingHistoryApi>.value(value: billingHistoryApi),
        RepositoryProvider<MeetingsApi>.value(value: meetingsApi),
        RepositoryProvider<OdooDataApi>.value(value: odooDataApi),
        RepositoryProvider<CredentialsApi>.value(value: credentialsApi),
        RepositoryProvider<ConversationsApi>.value(value: conversationsApi),
        RepositoryProvider<ApprovalsApi>.value(value: approvalsApi),
        RepositoryProvider<ArtifactsApi>.value(value: artifactsApi),
        RepositoryProvider<SharesApi>.value(value: sharesApi),
        RepositoryProvider<RemoteI18nApi>.value(value: remoteI18nApi),
        RepositoryProvider<DevicesApi>.value(value: devicesApi),
        RepositoryProvider<PushNotificationsService>.value(value: pushService),
        RepositoryProvider<TranscribeApi>.value(value: transcribeApi),
        RepositoryProvider<SaqqarToolsApi>.value(value: saqqarToolsApi),
        RepositoryProvider<VoiceSupportApi>.value(value: voiceSupportApi),
        RepositoryProvider<LiveEnvAckService>.value(value: liveEnvAckService),
        // `ShareIntakeService` extends `ChangeNotifier`, so a plain
        // `RepositoryProvider`/`Provider` throws — Provider auto-detects
        // Listenable subtypes and refuses to wrap them (it can't drive
        // rebuilds on notify). `ChangeNotifierProvider.value` is the
        // right shape, and consumers that just want `context.read<>()`
        // still work because it exposes the same Provider API.
        ChangeNotifierProvider<ShareIntakeService>.value(
          value: shareIntakeService,
        ),
        ChangeNotifierProvider<NotificationsStore>.value(
          value: notificationsStore,
        ),
        RepositoryProvider<VaultRepository>.value(value: vaultRepository),
        RepositoryProvider<ConversationsRepository>.value(
          value: conversationsRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>(create: (_) => ThemeCubit(prefs)),
          BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(prefs)),
          BlocProvider<ConnectivityCubit>(create: (_) => ConnectivityCubit()),
          BlocProvider<AuthCubit>(
            // `lazy: false` so the cubit instantiates immediately and the
            // splash can await its bootstrap() future before the router
            // mounts (see app.dart).
            lazy: false,
            create: (_) {
              final cubit = AuthCubit(api: authApi, tokenStore: tokenStore);
              // Populate the forward holder so the Dio AuthInterceptor's
              // `onUnauthorized` callback can reach the cubit on 401s
              // that originate AFTER boot (the cubit didn't exist when
              // Dio was built).
              authCubitRef = cubit;
              return cubit;
            },
          ),
          BlocProvider<TaskPrepCubit>(create: (_) => TaskPrepCubit(prefs)),
          // Biometric / device-credential app lock. `lazy: false` so it
          // probes device availability and engages the cold-start lock
          // before the first frame, not on first read.
          BlocProvider<AppLockCubit>(
            lazy: false,
            create: (_) =>
                AppLockCubit(prefs: prefs, auth: BiometricAuth()),
          ),
          // User's push on/off preference (defaults on). Gates the push
          // service in app.dart and drives device (un)registration.
          BlocProvider<NotificationsSettingsCubit>(
            create: (_) => NotificationsSettingsCubit(prefs),
          ),
          BlocProvider<PlanCubit>(create: (_) => PlanCubit()),
          // Separate from PlanCubit on purpose: `saqqar_features` rides on
          // `/api/v1/usage/` only, while PlanCubit is replaced by every chat
          // poll from a snapshot that never carries it.
          BlocProvider<SaqqarFeaturesCubit>(
            create: (_) => SaqqarFeaturesCubit(usageApi),
          ),
          BlocProvider<RunningAgentsCubit>(
            create: (_) => RunningAgentsCubit(),
          ),
          BlocProvider<ApprovalsCubit>(
            create: (_) => ApprovalsCubit(approvalsApi),
          ),
          BlocProvider<ConversationsCubit>(
            // `..hydrateFromCache()` paints the persisted Chats list on the
            // first frame so the tab never opens to a bare skeleton when we
            // have a cached list; the screen's load() then revalidates.
            create: (_) =>
                ConversationsCubit(repository: conversationsRepository)
                  ..hydrateFromCache(),
          ),
          BlocProvider<VaultCubit>(
            // Warm-start from the offline cache (if any) the instant the
            // cubit constructs so the Vault tab paints projects on the
            // first frame even before the live fetch returns.
            create: (_) =>
                VaultCubit(repository: vaultRepository)..hydrateFromCache(),
          ),
        ],
        child: const SaqqarApp(),
      ),
    ),
  );
}

/// Returns `true` for errors we deliberately don't ship to Sentry.
///
/// The bar is "would a senior engineer file this as a bug?":
///
///   * **Network errors** (Dio timeout / connection / cancel,
///     `ApiException.network|timeout|cancelled`) — environmental: slow
///     cellular, captive portal, airplane mode, app backgrounded mid-
///     request. Already surfaced to the user as a friendly toast via
///     `ApiErrorMapper`. Forwarding to Sentry just drowns real bugs
///     in noise and burns the free quota (SAQQAR-1 was the wake-up
///     call — a single Cairo user on 3G triggered a "production
///     error" alert for an expected timeout).
///   * **4xx responses** — expected business-logic failures (401 =
///     stale token, 403 = no permission, 404 = deleted, 409 = race,
///     422 = validation). Repositories handle them inline; they're
///     not crashes.
///
/// We DO report:
///   * 5xx server errors — those are backend bugs worth knowing about.
///   * `ApiExceptionKind.unknown` — we don't know what it is, so we
///     want a trace.
///   * Everything else (StateError, TypeError, parse failures, etc.).
bool _shouldSkipSentry(Object? error) {
  if (error is ApiException) {
    switch (error.kind) {
      case ApiExceptionKind.network:
      case ApiExceptionKind.timeout:
      case ApiExceptionKind.cancelled:
        return true;
      case ApiExceptionKind.badResponse:
        // 4xx = client/business expected; 5xx = backend bug worth shipping.
        final status = error.statusCode;
        return status != null && status >= 400 && status < 500;
      // A body that failed to decode is a backend or proxy bug — the one
      // party who can fix it is us, and the user's report ("it just says
      // something went wrong") carries none of the detail a trace does.
      // These used to be classified `network` and silently dropped here.
      case ApiExceptionKind.parse:
        return false;
      case ApiExceptionKind.unknown:
        return false;
    }
  }
  // Belt-and-braces: if a raw DioException leaks past the
  // ErrorInterceptor (unlikely but cheap to guard), apply the same
  // network-noise filter.
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return status != null && status >= 400 && status < 500;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }
  // google_fonts throws when it tries to fetch a font over the network
  // and the device is offline. With `GoogleFonts.config.allowRuntimeFetching
  // = false` (set below) the SDK now falls back to system fonts silently,
  // but the older builds and any leftover in-flight requests still throw.
  // Filter those — they're environmental noise, never a real bug we need
  // to chase in the dashboard.
  final message = error?.toString() ?? '';
  if (message.contains('fonts.gstatic.com') ||
      message.contains('Failed to load font')) {
    return true;
  }
  return false;
}
