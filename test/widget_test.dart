import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/app.dart';
import 'package:saqqar_app/core/i18n/remote_i18n_api.dart';
import 'package:saqqar_app/core/i18n/view_model/locale_cubit.dart';
import 'package:saqqar_app/core/network/dio_client.dart';
import 'package:saqqar_app/core/network/view_model/connectivity_cubit.dart';
import 'package:saqqar_app/core/storage/secure_token_store.dart';
import 'package:saqqar_app/core/theme/view_model/theme_cubit.dart';
import 'package:saqqar_app/features/auth/data/auth_api.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/chat/data/live_env_ack_service.dart';
import 'package:saqqar_app/features/chat/view_model/deep_think_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/running_agents_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversations_api.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/inbox/view_model/approvals_cubit.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart';
import 'package:saqqar_app/features/share/data/shares_api.dart';
import 'package:saqqar_app/features/share/intake/share_intake_service.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/shared/widgets/primary_button.dart';

/// In-memory fake for tests — the real FlutterSecureStorage backs onto a
/// platform channel that doesn't exist in the test harness, which would
/// otherwise hang the auth cubit's bootstrap forever.
class _FakeSecureTokenStore implements SecureTokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<void> writeAccessToken(String token) async => _access = token;

  @override
  Future<void> writeRefreshToken(String token) async => _refresh = token;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// Mirrors main.dart's repository + cubit tree so widget tests boot a
/// fully-wired SaqqarApp without going through the real `main()` entrypoint
/// (which would touch the secure-storage platform channel).
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final tokenStore = _FakeSecureTokenStore();
  final dio = buildDio(tokenStore);

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
  final shareIntakeService = ShareIntakeService();
  final vaultRepository = VaultRepository(
    projectsApi: projectsApi,
    credentialsApi: credentialsApi,
  );
  final conversationsRepository = ConversationsRepository(conversationsApi);

  await tester.pumpWidget(
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
        // Mirror main.dart — ShareIntentBootstrap (mounted inside
        // MaterialApp.router's builder) reads this via context.watch, so
        // the widget tree throws ProviderNotFoundException without it.
        ChangeNotifierProvider<ShareIntakeService>.value(
          value: shareIntakeService,
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
            lazy: false,
            create: (_) => AuthCubit(api: authApi, tokenStore: tokenStore),
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
            create: (_) => VaultCubit(repository: vaultRepository),
          ),
        ],
        child: const SaqqarApp(),
      ),
    ),
  );
  // The in-app launch splash holds for ~1.4 s (its minDuration) before
  // handing off to MaterialApp.router. Pump past that so the rest of the
  // shell mounts. Avoid pumpAndSettle — the home shell contains looping
  // animations (connectivity strip, shimmer placeholders) that never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('App boots into Sign-in when no token is stored', (
    tester,
  ) async {
    await _pumpApp(tester);

    // Auth gate redirects unauthenticated users to /sign-in on cold start.
    // The sign-in screen renders the "Welcome back" headline + "Sign in"
    // primary button — assert both so we know the form mounted (not just
    // the brand panel).
    expect(find.text('Welcome back'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
  });

  test('Approval decision updates pending count', () {
    final cubit = ApprovalsCubit();
    addTearDown(cubit.close);

    final initialPending = cubit.state.pendingCount;
    expect(initialPending, greaterThan(0));

    final firstPending = demoApprovals.firstWhere(
      (a) => a.status == DemoApprovalStatus.pending,
    );
    cubit.decide(firstPending.id, DemoApprovalStatus.approved);

    expect(cubit.state.pendingCount, initialPending - 1);
  });

  test('Dismissing an action shrinks the open list', () {
    final cubit = ApprovalsCubit();
    addTearDown(cubit.close);

    final before = cubit.state.openActionsCount;
    expect(before, greaterThan(0));

    cubit.dismissAction(demoPendingActions.first.id);

    expect(cubit.state.openActionsCount, before - 1);
  });

  testWidgets('PrimaryButton survives tight RTL + scaled-text layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 159,
                child: PrimaryButton(
                  label: 'Save credential',
                  icon: Icons.save_outlined,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
