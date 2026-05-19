import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Globally observe every Cubit lifecycle (create / state change /
  // error / close) so debugging doesn't require manual `print`s inside
  // cubits. No-op in release builds — see [AppBlocObserver].
  Bloc.observer = AppBlocObserver();

  // Replace Flutter's default red ErrorWidget (which is fine in debug
  // but terrifying in production) with a friendly plate that explains
  // what happened in human terms and exposes the raw exception only in
  // debug builds.
  ErrorWidget.builder = (details) => AppErrorScreen(details: details);

  // Route every uncaught Flutter framework error through AppLogger —
  // that way a wired crash reporter (Sentry / Crashlytics) catches them
  // automatically alongside the cubit warnings/errors. Preserve the
  // default presenter so the debug console still prints the full stack.
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.error(
      'FlutterError',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    defaultOnError?.call(details);
  };

  // Same treatment for errors that escape the framework entirely —
  // background isolates, async gaps the framework can't catch.
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'PlatformDispatcher',
      error.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    return true; // signal handled — otherwise the engine logs again
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
