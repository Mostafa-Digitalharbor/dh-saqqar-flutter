import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

import 'app.dart';
import 'core/i18n/remote_i18n_api.dart';
import 'core/logging/app_bloc_observer.dart';
import 'core/logging/app_logger.dart';
import 'shared/widgets/app_error_screen.dart';
import 'core/i18n/view_model/locale_cubit.dart';
import 'core/network/dio_client.dart';
import 'core/network/view_model/connectivity_cubit.dart';
import 'core/storage/secure_token_store.dart';
import 'core/theme/view_model/theme_cubit.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/view_model/auth_cubit.dart';
import 'features/chat/data/live_env_ack_service.dart';
import 'features/chat/view_model/deep_think_cubit.dart';
import 'features/chat/view_model/running_agents_cubit.dart';
import 'features/conversations/data/conversations_api.dart';
import 'features/conversations/data/conversations_repository.dart';
import 'features/conversations/view_model/conversations_cubit.dart';
import 'features/inbox/data/approvals_api.dart';
import 'features/inbox/data/artifacts_api.dart';
import 'features/inbox/view_model/approvals_cubit.dart';
import 'features/push/data/devices_api.dart';
import 'features/share/data/shares_api.dart';
import 'features/vault/data/credentials_api.dart';
import 'features/vault/data/projects_api.dart';
import 'features/vault/data/vault_cache.dart';
import 'features/vault/data/vault_repository.dart';
import 'features/vault/view_model/vault_cubit.dart';

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
      // can split prod crashes from dev / CI noise. `release` matches
      // the version line in pubspec.yaml — bump both together so the
      // Sentry UI groups crashes per version correctly.
      options.environment = kReleaseMode ? 'production' : 'development';
      options.release = 'saqqar@1.0.0+1';
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
    },
    appRunner: _bootApp,
  );
}

Future<void> _bootApp() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Globally observe every Cubit lifecycle (create / state change /
  // error / close) so debugging doesn't require manual `print`s inside
  // cubits. No-op in release builds — see [AppBlocObserver].
  Bloc.observer = AppBlocObserver();

  // Bridge cubit-level warn/error calls (caught inside try/catch
  // blocks in repositories and cubits) into Sentry. Without this, only
  // uncaught Flutter errors reach the dashboard — caught exceptions
  // like "PATCH failed, optimistic update rolled back" stay invisible.
  AppLogger.setCrashReporter((level, tag, message, {error, stackTrace}) {
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
  final projectsApi = ProjectsApi(dio);
  final credentialsApi = CredentialsApi(dio);
  final conversationsApi = ConversationsApi(dio);
  final approvalsApi = ApprovalsApi(dio);
  final artifactsApi = ArtifactsApi(dio);
  final sharesApi = SharesApi(dio);
  final remoteI18nApi = RemoteI18nApi(dio);
  final devicesApi = DevicesApi(dio);
  final liveEnvAckService = LiveEnvAckService(prefs);

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
  final conversationsRepository = ConversationsRepository(conversationsApi);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>.value(value: prefs),
        RepositoryProvider<SecureTokenStore>.value(value: tokenStore),
        RepositoryProvider<Dio>.value(value: dio),
        RepositoryProvider<AuthApi>.value(value: authApi),
        RepositoryProvider<ProjectsApi>.value(value: projectsApi),
        RepositoryProvider<CredentialsApi>.value(value: credentialsApi),
        RepositoryProvider<ConversationsApi>.value(value: conversationsApi),
        RepositoryProvider<ApprovalsApi>.value(value: approvalsApi),
        RepositoryProvider<ArtifactsApi>.value(value: artifactsApi),
        RepositoryProvider<SharesApi>.value(value: sharesApi),
        RepositoryProvider<RemoteI18nApi>.value(value: remoteI18nApi),
        RepositoryProvider<DevicesApi>.value(value: devicesApi),
        RepositoryProvider<LiveEnvAckService>.value(value: liveEnvAckService),
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
          BlocProvider<DeepThinkCubit>(create: (_) => DeepThinkCubit(prefs)),
          BlocProvider<RunningAgentsCubit>(
            create: (_) => RunningAgentsCubit(),
          ),
          BlocProvider<ApprovalsCubit>(create: (_) => ApprovalsCubit()),
          BlocProvider<ConversationsCubit>(
            create: (_) =>
                ConversationsCubit(repository: conversationsRepository),
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
