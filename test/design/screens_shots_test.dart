import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/account/view/account_screen.dart';
import 'package:saqqar_app/features/apps/data/app_package_models.dart';
import 'package:saqqar_app/features/apps/data/apps_api.dart';
import 'package:saqqar_app/features/apps/view/apps_screen.dart';
import 'package:saqqar_app/features/apps/view_model/apps_cubit.dart';
import 'package:saqqar_app/features/auth/data/auth_models.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/auth/view_model/auth_state.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/saqqar_features_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_state.dart';
import 'package:saqqar_app/features/home/home_screen.dart';
import 'package:saqqar_app/features/notifications/data/notifications_store.dart';
import 'package:saqqar_app/features/notifications/view/notifications_inbox_screen.dart';
import 'package:saqqar_app/features/notifications/view_model/notifications_settings_cubit.dart';
import 'package:saqqar_app/features/onboarding/onboarding_screen.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart';
import 'package:saqqar_app/features/security/view_model/app_lock_cubit.dart';
import 'package:saqqar_app/features/setup/setup_screens.dart';
import 'package:saqqar_app/features/tasks/tasks_screen.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/features/vault/view_model/vault_state.dart';
import 'package:saqqar_app/core/i18n/view_model/locale_cubit.dart';
import 'package:saqqar_app/features/launch/launch_splash_screen.dart';
import 'package:saqqar_app/shared/fig/fig.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot_harness.dart';

class _FakeAuth extends Cubit<AuthState> implements AuthCubit {
  _FakeAuth()
      : super(const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(
            id: 1,
            email: 'Moazahmed@gmail.com',
            username: 'moaz',
            isStaff: false,
            isSuperuser: false,
            firstName: 'Moaz',
            lastName: 'Ahmed',
            fullName: 'Moaz Ahmed',
          ),
          counts: AuthCounts(
              conversations: 123, credentials: 0, approvals: 90, artifacts: 0),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConvs extends Cubit<ConversationsState> implements ConversationsCubit {
  @override
  Future<void> load({bool includeArchived = true, bool prefetch = true}) async {}

  @override
  Future<void> refresh() async {}

  _FakeConvs()
      : super(ConversationsState(
          data: DataSuccess(ConversationsData(conversations: [
            for (final t in [
              'Check this month’s revenue',
              'Find low-stock products',
              'Generate a sales report'
            ])
              ConversationSummary(
                id: t,
                title: t,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                isArchived: false,
                messageCount: 2,
              ),
          ])),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVault extends Cubit<VaultState> implements VaultCubit {
  _FakeVault() : super(const VaultState());

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApps extends Cubit<DataState<List<SaqqarApp>>> implements AppsCubit {
  _FakeApps()
      : super(const DataSuccess([
          SaqqarApp(
              slug: 'zatca',
              name: 'ZATCA e-invoicing',
              tagline: 'Validate and submit compliant invoices',
              category: '',
              group: 'Accounting',
              accent: '',
              iconSvg: '',
              envRequired: false),
          SaqqarApp(
              slug: 'whatsapp',
              name: 'WhatsApp integration',
              tagline: 'Manage customer conversations in Odoo',
              category: '',
              group: 'Operations',
              accent: '',
              iconSvg: '',
              envRequired: false),
          SaqqarApp(
              slug: 'chart',
              name: 'Chart of Accounts builder',
              tagline: 'Create a tailored accounting structure',
              category: '',
              group: 'Finance',
              accent: '',
              iconSvg: '',
              envRequired: false),
        ]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> load() async {}
}

class _FakeLock extends Cubit<AppLockState> implements AppLockCubit {
  _FakeLock() : super(const AppLockState(enabled: true, available: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotifSettings extends Cubit<bool> implements NotificationsSettingsCubit {
  _FakeNotifSettings() : super(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocale extends Cubit<Locale?> implements LocaleCubit {
  _FakeLocale() : super(const Locale('en'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _providers(Widget child, {NotificationsStore? store}) {
  return MultiProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: _FakeAuth()),
      BlocProvider<ConversationsCubit>.value(value: _FakeConvs()),
      BlocProvider<VaultCubit>.value(value: _FakeVault()),
      BlocProvider<AppsCubit>.value(value: _FakeApps()),
      BlocProvider<AppLockCubit>.value(value: _FakeLock()),
      BlocProvider<NotificationsSettingsCubit>.value(value: _FakeNotifSettings()),
      BlocProvider<LocaleCubit>.value(value: _FakeLocale()),
      BlocProvider<PlanCubit>.value(value: PlanCubit()),
      BlocProvider<SaqqarFeaturesCubit>.value(value: SaqqarFeaturesCubit(UsageApi(Dio()))),
      Provider<UsageApi>.value(value: UsageApi(Dio())),
      Provider<AppsApi>.value(value: AppsApi(Dio())),
      Provider<DevicesApi>.value(value: DevicesApi(Dio())),
      ChangeNotifierProvider<NotificationsStore>.value(
          value: store ?? NotificationsStore(_prefs)),
    ],
    child: child,
  );
}

late SharedPreferences _prefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('onboarding', (t) async {
    await shot(t, 'onboarding', const OnboardingScreen(onStart: _noop));
  });

  testWidgets('splash', (t) async {
    await shot(t, 'splash', LaunchSplashScreen(onComplete: () {}),
        after: (t) async => t.pump(const Duration(seconds: 2)));
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('home', (t) async {
    await shot(
      t,
      'home',
      _providers(const _HomeWithNav()),
    );
  });

  testWidgets('apps', (t) async {
    await shot(t, 'apps', _providers(const _TabHost(index: 2, child: AppsScreen())));
  });

  testWidgets('tasks', (t) async {
    await shot(
      t,
      'tasks',
      _providers(_TabHost(index: 3, child: TasksScreen(initial: _seedTasks))),
    );
  });

  testWidgets('task_sheet', (t) async {
    await shot(
      t,
      'task_sheet',
      _providers(Builder(
          builder: (c) => Scaffold(
              backgroundColor: Colors.grey,
              body: Center(
                  child: TextButton(
                      onPressed: () => showFigSheetForTest(c),
                      child: const Text('open'))))),),
      after: (t) async {
        await t.tap(find.text('open'));
        await t.pump(const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('notifications', (t) async {
    final store = NotificationsStore(_prefs);
    final now = DateTime.now();
    store.add(AppNotification(
        id: '4',
        type: 'run_complete',
        title: 'Scheduled Action Completed',
        body: 'The customer records synchronization finished successfully.',
        receivedAt: DateTime(2026, 10, 26, 9)));
    store.add(AppNotification(
        id: '3',
        type: 'artifact_ready',
        title: 'Sales Report Generated',
        body: 'Your monthly sales report is ready to review.',
        receivedAt: now.subtract(const Duration(minutes: 35))));
    store.add(AppNotification(
        id: '2',
        type: 'x',
        title: 'Low Stock Alert',
        body: 'Product “Office Chair” is below its minimum stock level.',
        receivedAt: now.subtract(const Duration(minutes: 18))));
    store.add(AppNotification(
        id: '1',
        type: 'approval_required',
        title: 'Purchase Order Requires Approval',
        body: 'Purchase Order #PO-1048 is waiting for your approval.',
        receivedAt: now.subtract(const Duration(minutes: 5))));
    await shot(t, 'notifications',
        _providers(const NotificationsInboxScreen(), store: store));
  });

  testWidgets('notifications_empty', (t) async {
    await shot(t, 'notifications_empty',
        _providers(const NotificationsInboxScreen()));
  });

  for (final e in {'personal': 0, 'prefs': 2, 'workspace': 4, 'closed': -1}.entries) {
    testWidgets('profile_${e.key}', (t) async {
      await shot(
        t,
        'profile_${e.key}',
        _providers(const AccountScreen()),
        size: const Size(375, 1158),
        after: (t) async {
          if (e.value >= 0) {
            final titles = [
              'Personal information',
              'Change password',
              'Preferences',
              'Manage devices',
              'Workspace',
              'Billing'
            ];
            await t.tap(find.text(titles[e.value]));
            await t.pump(const Duration(milliseconds: 500));
          }
        },
      );
    });
  }

  testWidgets('setup_company', (t) async {
    await shot(t, 'setup_company', _providers(const CompanyNameScreen()));
  });

  testWidgets('setup_env', (t) async {
    await shot(t, 'setup_env',
        _providers(const ConnectEnvironmentScreen(companyName: 'assf')),
        size: const Size(375, 1107));
  });
}

void _noop() {}

void showFigSheetForTest(BuildContext c) {
  showModalBottomSheet<void>(
    context: c,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ScheduleTaskSheet(),
  );
}

final _seedTasks = [
  const ScheduledTask(
      id: '1', title: 'Daily stock radar', time: '8:00 AM', timezone: '', module: 'Inventory', frequency: 'Daily', prompt: ''),
  const ScheduledTask(
      id: '2', title: 'Collections summary', time: '9:00 AM', timezone: '', module: 'Accounting', frequency: 'Weekly', prompt: ''),
  const ScheduledTask(
      id: '3', title: 'Low-stock replenishment', time: 'When stock falls below minimum', timezone: '', module: 'Inventory', frequency: 'Low', prompt: ''),
];

class _TabHost extends StatelessWidget {
  const _TabHost({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      body: Stack(children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: FigNavBar(index: index, onSelect: (_) {}),
          ),
        ),
      ]),
    );
  }
}

class _HomeWithNav extends StatelessWidget {
  const _HomeWithNav();

  @override
  Widget build(BuildContext context) {
    return const _TabHostHome();
  }
}

class _TabHostHome extends StatelessWidget {
  const _TabHostHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      body: Stack(children: [
        const Positioned.fill(child: HomeScreen()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(child: FigNavBar(index: 0, showMore: false, onSelect: (_) {})),
        ),
      ]),
    );
  }
}
