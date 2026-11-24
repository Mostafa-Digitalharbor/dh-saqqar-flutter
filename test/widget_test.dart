import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/app.dart';
import 'package:saqqar_app/core/i18n/platform_strings.dart';
import 'package:saqqar_app/core/i18n/remote_i18n_api.dart';
import 'package:saqqar_app/core/i18n/view_model/locale_cubit.dart';
import 'package:saqqar_app/core/network/dio_client.dart';
import 'package:saqqar_app/core/network/view_model/connectivity_cubit.dart';
import 'package:saqqar_app/core/storage/secure_token_store.dart';
import 'package:saqqar_app/core/theme/view_model/theme_cubit.dart';
import 'package:saqqar_app/features/auth/data/auth_api.dart';
import 'package:saqqar_app/features/auth/data/social_auth_service.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/chat/data/live_env_ack_service.dart';
import 'package:saqqar_app/features/chat/view_model/task_prep_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/running_agents_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversations_api.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/inbox/view_model/approvals_cubit.dart';
import 'package:saqqar_app/features/notifications/data/notifications_store.dart';
import 'package:saqqar_app/features/notifications/view_model/notifications_settings_cubit.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart';
import 'package:saqqar_app/features/push/data/push_notifications_service.dart';
import 'package:saqqar_app/features/share/data/shares_api.dart';
import 'package:saqqar_app/features/share/intake/share_intake_service.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/shared/fig/fig.dart';

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

/// In-memory fake for [ApprovalsApi] — never touches the network. `list`
/// returns the seeded approvals (filtered by status), `decide` flips the
/// matching approval's status so a subsequent `list(status: pending)` drops
/// it, mirroring the server resolving an approval.
class _FakeApprovalsApi implements ApprovalsApi {
  _FakeApprovalsApi(this._approvals);

  List<Approval> _approvals;
  final List<String> decided = [];

  @override
  Future<ApprovalsPage> list({
    ApprovalStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    final filtered = status == null
        ? _approvals
        : _approvals.where((a) => a.status == status).toList();
    final pending =
        _approvals.where((a) => a.status == ApprovalStatus.pending).length;
    return ApprovalsPage(
      approvals: filtered,
      total: filtered.length,
      pendingCount: pending,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<ApprovalDecisionResult> decide({
    required String id,
    required bool approved,
    String? note,
    bool batchScope = false,
    String? confirmPhrase,
  }) async {
    decided.add(id);
    _approvals = [
      for (final a in _approvals)
        if (a.id == id)
          Approval(
            id: a.id,
            actionType: a.actionType,
            status:
                approved ? ApprovalStatus.approved : ApprovalStatus.rejected,
            prompt: a.prompt,
            payload: a.payload,
          )
        else
          a,
    ];
    return ApprovalDecisionResult(
      approval: _approvals.firstWhere((a) => a.id == id),
    );
  }
}

Approval _pendingApproval(String id) => Approval(
      id: id,
      actionType: ApprovalActionType.odooWrite,
      status: ApprovalStatus.pending,
      prompt: 'Write to res.partner',
      payload: const {},
    );

/// Mirrors main.dart's repository + cubit tree so widget tests boot a
/// fully-wired SaqqarApp without going through the real `main()` entrypoint
/// (which would touch the secure-storage platform channel).
Future<void> _pumpApp(WidgetTester tester, {bool onboarded = true}) async {
  // `onboarded: false` is a fresh install — the router sends it to /welcome.
  SharedPreferences.setMockInitialValues(
      {if (onboarded) 'saqqar.onboarding.seen': true});
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
  final socialAuthService = SocialAuthService();
  // Push service + notifications store — provided (never started) so the
  // cold-start push-registration path in app.dart's splash `onReady` can
  // resolve them via context.read. start() only fires for an authenticated
  // user, and this harness boots with no token, so no platform channel is
  // touched.
  final notificationsStore = NotificationsStore(prefs);
  final pushService = PushNotificationsService(
    devicesApi,
    notificationsStore,
    PlatformStrings(prefs),
  );
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
        // Mirror main.dart — AuthFlowScreen's `create` resolves this via
        // context.read to build its AuthFlowCubit, so /sign-in throws
        // ProviderNotFoundException without it. Constructing the real
        // service is safe here: it builds its GoogleSignIn lazily, so
        // nothing touches a platform channel until a sign-in is attempted
        // (which this harness never does).
        RepositoryProvider<SocialAuthService>.value(value: socialAuthService),
        RepositoryProvider<ProjectsApi>.value(value: projectsApi),
        RepositoryProvider<CredentialsApi>.value(value: credentialsApi),
        RepositoryProvider<ConversationsApi>.value(value: conversationsApi),
        RepositoryProvider<ApprovalsApi>.value(value: approvalsApi),
        RepositoryProvider<ArtifactsApi>.value(value: artifactsApi),
        RepositoryProvider<SharesApi>.value(value: sharesApi),
        RepositoryProvider<RemoteI18nApi>.value(value: remoteI18nApi),
        RepositoryProvider<DevicesApi>.value(value: devicesApi),
        RepositoryProvider<PushNotificationsService>.value(value: pushService),
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
          BlocProvider<TaskPrepCubit>(create: (_) => TaskPrepCubit(prefs)),
          BlocProvider<NotificationsSettingsCubit>(
            create: (_) => NotificationsSettingsCubit(prefs),
          ),
          BlocProvider<RunningAgentsCubit>(
            create: (_) => RunningAgentsCubit(),
          ),
          BlocProvider<ApprovalsCubit>(
            create: (_) => ApprovalsCubit(approvalsApi),
          ),
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
    // The redesigned sign-in: the "one AI conversation" headline, email +
    // password fields and the Sign In CTA — assert them so we know the
    // flow's first step mounted.
    expect(find.text('Your business, one AI conversation.'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Enter your email'), findsWidgets);
  });

  testWidgets('A fresh install asks for a language, then shows Welcome', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: false);

    // First launch: the "Choose Your Language" card sits over the splash.
    expect(find.text('Choose Your Language'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Get started'), findsWidgets);
    expect(find.text('Your business, one AI conversation.'), findsNothing);
  });

  test('load() populates approvals + pending count from the real API', () async {
    final api = _FakeApprovalsApi([
      _pendingApproval('a1'),
      _pendingApproval('a2'),
    ]);
    final cubit = ApprovalsCubit(api);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.approvals.isSuccess, isTrue);
    expect(cubit.state.pendingCount, 2);
    expect(cubit.state.pendingTotal, 2);
  });

  test('decide() resolves the approval and refreshes the pending count',
      () async {
    final api = _FakeApprovalsApi([
      _pendingApproval('a1'),
      _pendingApproval('a2'),
    ]);
    final cubit = ApprovalsCubit(api);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.decide('a1', approved: true);

    expect(api.decided, contains('a1'));
    // a1 is now approved → the pending-only reload drops it to one.
    expect(cubit.state.pendingCount, 1);
  });

  testWidgets('FigButton survives tight RTL + scaled-text layouts', (
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
                child: FigButton.compact(
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
