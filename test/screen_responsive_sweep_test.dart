// Whole-screen responsive sweep for the signed-in core surfaces.
//
// `responsive_sweep_test.dart` sweeps *widgets* (bubbles, cards, chips) and
// `new_screens_render_test.dart` pumps a handful of screens once, at the
// default 800×600. Neither covers these nine full screens across the device
// matrix, so a `Row` that only breaks at 320 px — or only in Arabic, or only
// at 1.3× text — had nothing watching it:
//
//   AccountScreen · AuthFlowScreen · PricingScreen · UsageScreen ·
//   ConversationsScreen · LaunchSplashScreen · NotificationsInboxScreen ·
//   DevicesScreen · VaultScreen
//
// The remaining screens are swept by `screen_responsive_sweep_extra_test.dart`
// — same matrix, same harness, split only so neither file grows past the
// point where the fakes crowd out the tests.
//
// Screens are pumped WHOLE (their own Scaffold, AppBar, FAB and bottom
// padding included) rather than as extracted bodies, because the overflows
// that reach users come from the chrome competing with the body for the same
// 320 px — an extracted body would have room the real screen never gets.
//
// The matrix (5 viewports × 2 locales × 2 text scales = 20 layouts per
// screen) and the provider chrome both live in `support/responsive_harness`.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/features/home/home_screen.dart';
import 'package:saqqar_app/features/onboarding/onboarding_screen.dart';
import 'package:saqqar_app/features/setup/setup_screens.dart';
import 'package:saqqar_app/features/tasks/tasks_screen.dart';
import 'package:saqqar_app/core/app_build_info.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/account/view/account_screen.dart';
import 'package:saqqar_app/features/account/widgets/plan_usage_card.dart';
import 'package:saqqar_app/features/auth/view/auth_flow_screen.dart';
import 'package:saqqar_app/features/auth/view_model/auth_flow_cubit.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/plan_tier_models.dart';
import 'package:saqqar_app/features/billing/data/plans_api.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/billing/view/pricing_screen.dart';
import 'package:saqqar_app/features/billing/view/usage_screen.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/saqqar_features_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_cache.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view/conversations_screen.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_state.dart';
import 'package:saqqar_app/features/launch/launch_splash_screen.dart';
import 'package:saqqar_app/features/notifications/data/notifications_store.dart';
import 'package:saqqar_app/features/notifications/view/notifications_inbox_screen.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart';
import 'package:saqqar_app/features/push/view/devices_screen.dart';
import 'package:saqqar_app/features/share/intake/share_destination_sheet.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_persona_service.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view/vault_screen.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/features/vault/widgets/environment_detail_sheet.dart';
import 'package:saqqar_app/features/vault/widgets/project_detail_sheet.dart';
import 'package:saqqar_app/features/vault/widgets/projects_list_sheet.dart';

import 'support/responsive_harness.dart';

// ── Content that stresses the layout ─────────────────────────────────────
//
// Deliberately hostile but *realistic*. The Arabic strings are longer than
// their English equivalents, which is what actually breaks a `Row`.

const _window = UsageWindow(used: 8423, cap: 10000, pct: 84, remaining: 1577);

const _plan = PlanSnapshot(
  slug: 'max-20x',
  name: 'Max 20×',
  exempt: false,
  day: _window,
  week: _window,
  month: _window,
  features: PlanFeatures(
    voice: true,
    postgres: true,
    github: true,
    serverShell: true,
  ),
);

final _projects = <Project>[
  Project(
    id: 'p1',
    name: kLongName,
    slug: 'alzomman-trading-contracting-staging',
    environments: List.generate(
      3,
      (i) => Environment(
        id: 'e$i',
        name: '$kLongName #$i',
        slug: 'env-$i',
        isLive: i.isEven,
        readOnly: i.isOdd,
        autoApprove: i.isEven,
        projectId: 'p1',
      ),
    ),
  ),
];

final _conversations = <ConversationSummary>[
  ConversationSummary(
    id: 'c1',
    title: 'محتاجه منك في فقرات كل مستخدم ايه الصلاحيات اللي عنده في الجروبات',
    createdAt: DateTime.utc(2026, 8, 4, 6, 40),
    updatedAt: DateTime.utc(2026, 8, 4, 6, 41),
    isArchived: false,
    messageCount: 1349,
    lastMessagePreview:
        'تم. اتضاف 30 مستخدم في اللايف بنجاح (المعرّفات من 5 لـ 34)، وكلهم بالاسم',
    projectName: kLongName,
    environmentName: '$kLongName Live',
    filesCount: 77,
  ),
];

// ── Per-screen fakes ─────────────────────────────────────────────────────

class _SeededPlanCubit extends PlanCubit {
  _SeededPlanCubit() {
    emit(_plan);
  }
}

class _FakeUsageApi extends UsageApi {
  _FakeUsageApi() : super(Dio());
  @override
  Future<UsageSnapshot> fetch() async => const UsageSnapshot(
        plan: _plan,
        saqqarFeatures: SaqqarFeatures.unknown,
      );
}

/// The full live catalogue, in the wire shape `/api/v1/plans/` really
/// returns (verified against saqqaar.com, 2026-08-06).
///
/// It used to be a single tier carrying `price`, `currency` and a
/// `features` **list** — three fields `PlanTier.fromJson` does not read, and
/// no `price_monthly_cents` / `price_annual_cents` at all. So the sweep drew
/// one card with a $0 price and swept a screen the user never sees. The tier
/// that actually stresses this layout is the longest one (Business: five
/// bullets, an "Everything in Professional, plus:" header and a two-cycle
/// price line), and it was the one absent.
const _kPlansWire = {
  'plans': [
    {
      'slug': 'free',
      'name': 'Free',
      'sort': 0,
      'price_monthly_cents': 0,
      'price_annual_cents': 0,
      'monthly_tokens': 15000000,
      'max_projects': 1,
    },
    {
      'slug': 'starter',
      'name': 'Starter',
      'sort': 1,
      'price_monthly_cents': 200,
      'price_annual_cents': 100,
      'monthly_tokens': 15000000,
      'max_projects': 1,
    },
    {
      'slug': 'max-5x',
      'name': 'Solo',
      'sort': 2,
      'price_monthly_cents': 1000,
      'price_annual_cents': 500,
      'monthly_tokens': 18000000,
    },
    {
      'slug': 'pro',
      'name': 'Professional',
      'sort': 3,
      'price_monthly_cents': 2000,
      'price_annual_cents': 1000,
      'monthly_tokens': 35000000,
      'max_projects': 5,
    },
    {
      'slug': 'max-20x',
      'name': 'Business',
      'sort': 4,
      'price_monthly_cents': 9800,
      'price_annual_cents': 4900,
      'monthly_tokens': 170000000,
    },
  ],
};

class _FakePlansApi extends PlansApi {
  _FakePlansApi() : super(Dio());
  @override
  Future<PlansResponse> list() async => PlansResponse.fromJson(_kPlansWire);
}

class _FakeDevicesApi extends DevicesApi {
  _FakeDevicesApi() : super(Dio());
  @override
  Future<List<DeviceRow>> list() async => [
        DeviceRow(
          id: 'd1',
          platform: DevicePlatform.android,
          tokenPreview: 'fcm-token-abcdef0123456789',
          appVersion: '1.0.22+23 (production, arm64-v8a)',
          lastSeenAt: DateTime.utc(2026, 8, 3, 17, 19),
          createdAt: DateTime.utc(2026, 5, 8),
        ),
      ];
}

class _FakeProjectsApi implements ProjectsApi {
  @override
  Future<List<Project>> list() async => _projects;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeCredentialsApi implements CredentialsApi {
  @override
  Future<List<CredentialSchema>> getSchemas() async => const [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Answers the calls `ConversationsCubit.load()` makes.
///
/// Letting `noSuchMethod` swallow the list call looked like it worked — the
/// sweep went green — but the cubit caught the `NoSuchMethodError` and emitted
/// a failure, so the screen under test was the *error* state and the card
/// layout this file exists to stress was never built.
///
/// It regressed exactly once, the day `load()` moved from `list()` to
/// `listAll()`: this class still answered `list()`, `noSuchMethod` took the
/// new call, and the sweep went green again on the error state. Both are
/// overridden now — and if `load()` ever calls a third thing, the fix is
/// another override here, not a `noSuchMethod` that returns null.
class _FakeConversationsRepo implements ConversationsRepository {
  @override
  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    int offset = 0,
    bool includeArchived = false,
  }) async =>
      (conversations: _conversations, total: _conversations.length);

  @override
  Future<({List<ConversationSummary> conversations, int? total})> listAll({
    int pageSize = 200,
    int maxPages = 12,
    bool includeArchived = false,
  }) async =>
      (conversations: _conversations, total: _conversations.length);

  @override
  Future<({Map<String, int> pendingByConv, Map<String, int> filesByConv})>
      conversationMeta() async => (
            pendingByConv: {_conversations.first.id: 12},
            filesByConv: {_conversations.first.id: 77},
          );

  @override
  ConversationsCacheEntry? readCachedList() => null;

  @override
  Future<void> writeCachedList({
    required List<ConversationSummary> conversations,
    required Map<String, int> pendingByConv,
    required Map<String, int> filesByConv,
  }) async {}

  @override
  Future<void> prefetchSnapshots(List<String> ids) async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Seeds the list with a genuinely hostile row rather than letting the cubit
/// sit idle: an empty list exercises none of the card layout, which is where
/// the long project / environment tags actually compete for width.
class _SeededConversationsCubit extends ConversationsCubit {
  _SeededConversationsCubit() : super(repository: _FakeConversationsRepo()) {
    emit(state.copyWith(
      data: DataSuccess(ConversationsData(conversations: _conversations)),
    ));
  }
}

class _SeededVaultCubit extends VaultCubit {
  _SeededVaultCubit()
      : super(
          repository: VaultRepository(
            projectsApi: _FakeProjectsApi(),
            credentialsApi: _FakeCredentialsApi(),
          ),
        ) {
    // Loads itself, because nothing else will.
    //
    // `load()` is called in exactly one place in the app — `VaultScreen`'s
    // `initState` — so a cubit handed straight to one of the three sheets is
    // idle, and every sheet resolves its subject to `null` and draws an empty
    // shell. That is what the sheets were being swept as: twenty layouts each
    // of a form with a `—` where the 55-character Odoo instance name should
    // be, passing green while measuring nothing. In production a sheet cannot
    // be reached without going through the screen that loads this first, so
    // loading here is what makes the fixture match the app rather than a
    // convenience.
    load();
  }
}

// ── Provider wrappers, named once ────────────────────────────────────────
//
// The billing screens all need the same PlanCubit + UsageApi pair; writing it
// inline three times is how one of them ends up seeded differently from the
// other two after a refactor.

WrapBuilder get _withPlan => (child) => BlocProvider<PlanCubit>(
      create: (_) => _SeededPlanCubit(),
      child: RepositoryProvider<UsageApi>(
        create: (_) => _FakeUsageApi(),
        // Both screens that fetch `/usage/` now hand the response's
        // `saqqar_features` half to this cubit, so it has to be in scope
        // wherever UsageApi is.
        child: BlocProvider<SaqqarFeaturesCubit>(
          create: (context) => SaqqarFeaturesCubit(_FakeUsageApi()),
          child: child,
        ),
      ),
    );

WrapBuilder get _withConversations => (child) => BlocProvider<ConversationsCubit>(
      create: (_) => _SeededConversationsCubit(),
      child: child,
    );

/// Set in `setUp` so `_withVault` can hand the environment sheet the same
/// prefs instance the sweep is already using. The sheet reads its audience
/// (user / developer) synchronously in `initState`, so the service has to be
/// above it in the tree, not created inside it.
late SharedPreferences _sweepPrefs;

WrapBuilder get _withVault => (child) => BlocProvider<VaultCubit>(
      create: (_) => _SeededVaultCubit(),
      child: RepositoryProvider<VaultPersonaService>(
        create: (_) => VaultPersonaService(_sweepPrefs),
        child: child,
      ),
    );

WrapBuilder get _withDevices => (child) => RepositoryProvider<DevicesApi>(
      create: (_) => _FakeDevicesApi(),
      child: child,
    );

void _noopStart() {}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    _sweepPrefs = prefs;
  });

  // ── Redesign screens (2026-11) ───────────────────────────────────────────
  testWidgets('HomeScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const HomeScreen(),
      wrap: (child) => _withConversations(_withVault(child)),
    );
  });

  testWidgets('TasksScreen survives the matrix, with hostile titles',
      (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const TasksScreen(initial: [
        ScheduledTask(
          id: '1',
          title: kLongName,
          time: '8:00',
          timezone: 'Riyadh (GMT+3)',
          module: 'Sales',
          frequency: 'Daily',
          prompt: kLongName,
        ),
        ScheduledTask(
          id: '2',
          title: 'Collections summary',
          time: 'When stock falls below the configured minimum level',
          timezone: 'Riyadh (GMT+3)',
          module: 'Inventory',
          frequency: 'Weekly',
          prompt: '',
        ),
      ]),
    );
  });

  testWidgets('OnboardingScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const OnboardingScreen(onStart: _noopStart),
    );
  });

  testWidgets('CompanyNameScreen survives the matrix', (tester) async {
    await sweepMatrix(tester, prefs: prefs, () => const CompanyNameScreen());
  });

  testWidgets('ConnectEnvironmentScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const ConnectEnvironmentScreen(companyName: kLongName),
    );
  });

  testWidgets('AccountScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const AccountScreen(),
      wrap: _withPlan,
    );
  });

  testWidgets('AuthFlowScreen survives the matrix, on every step',
      (tester) async {
    // Every step is swept: the sign-in, register and OTP panes have
    // different field counts, and the OTP pane is the tallest — it is the
    // one that runs out of room first in landscape at 1.3× text.
    for (final step in AuthFlowStep.values) {
      // No `AuthFlowCubit` provider here on purpose — the screen builds its
      // own from `AuthApi` + `AuthCubit` + `SocialAuthService`, all of which
      // the shared chrome supplies. Providing one above it would test a
      // wiring the app never uses.
      await sweepMatrix(
        tester,
        prefs: prefs,
        () => AuthFlowScreen(initial: step),
      );
    }
  });

  testWidgets('a sign-up error goes away as soon as the field is edited',
      (tester) async {
    await pumpOnce(
      tester,
      const AuthFlowScreen(initial: AuthFlowStep.signUpEmail),
      prefs: prefs,
    );

    await tester.tap(find.text('Sign Up').last);
    await tester.pump();
    expect(find.text('Enter your first name.'), findsOneWidget);

    // The first field is the name; typing there fixes that message only.
    await tester.enterText(find.byType(EditableText).first, 'Mostafa');
    await tester.pump();
    expect(find.text('Enter your first name.'), findsNothing);
    expect(find.text('Email is required.'), findsOneWidget);
  });

  testWidgets('AuthFlowScreen shows no build/version string', (tester) async {
    // The version badge that used to sit above the header was removed by
    // request. `AppBuildInfo` still carries the label — push registration
    // reports it as `app_version` — so "the value is empty" is NOT what keeps
    // it off this screen, and a test that left it empty would pass even if
    // the badge came back. Seed it, then assert nothing renders it.
    AppBuildInfo.version = '1.2.6';
    AppBuildInfo.buildNumber = '203';
    addTearDown(() {
      AppBuildInfo.version = '';
      AppBuildInfo.buildNumber = '';
    });

    await pumpOnce(
      tester,
      const AuthFlowScreen(initial: AuthFlowStep.signInEmail),
      prefs: prefs,
    );

    expect(find.text('1.2.6 (203)'), findsNothing);
    expect(find.textContaining('1.2.6'), findsNothing);
    expect(find.textContaining('(203)'), findsNothing);
  });

  testWidgets('PricingScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const PricingScreen(),
      wrap: (child) => BlocProvider<PlanCubit>(
        create: (_) => _SeededPlanCubit(),
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PlansApi>(create: (_) => _FakePlansApi()),
            RepositoryProvider<Dio>(create: (_) => Dio()),
          ],
          child: child,
        ),
      ),
    );
  });

  testWidgets('UsageScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const UsageScreen(),
      wrap: _withPlan,
    );
  });

  testWidgets('ConversationsScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const ConversationsScreen(),
      wrap: _withConversations,
    );
  });

  testWidgets('ShareDestinationOverlayContent survives the matrix',
      (tester) async {
    // The share-intake picker: the full-screen surface that comes up when the
    // user shares files into Saqqar from another app. It is a routed-looking
    // screen that no route builds — `ShareIntentBootstrap` renders it into a
    // `Stack` — so the router-derived screen list never named it, and no test
    // in the suite rendered it even once.
    //
    // That is the whole reason it is swept here rather than trusted: it
    // reprints a conversation title and its last-message preview in list rows
    // whose widths nobody had ever measured, and the copy that lands in them
    // comes from a live Odoo instance, not from the fixture someone imagined.
    //
    // A file count of 3 on purpose — the subtitle is pluralised, and the
    // plural branch is the longer string in both locales.
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => ShareDestinationOverlayContent(
        fileCount: 3,
        onCancel: () {},
        onPick: (_) {},
      ),
      wrap: _withConversations,
    );
  });

  testWidgets('LaunchSplashScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => LaunchSplashScreen(onComplete: () {}),
    );
  });

  testWidgets('NotificationsInboxScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const NotificationsInboxScreen(),
      wrap: (child) => ChangeNotifierProvider<NotificationsStore>(
        create: (_) => NotificationsStore(prefs),
        child: child,
      ),
    );
  });

  testWidgets('DevicesScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const DevicesScreen(),
      wrap: _withDevices,
    );
  });

  testWidgets('VaultScreen survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const VaultScreen(),
      wrap: _withVault,
    );
  });

  // ── Vault's sheets ─────────────────────────────────────────────────────
  //
  // Sweeping `VaultScreen` proves nothing about these: a sheet only exists
  // after a tap, so the screen sweep measures the tree with all three of
  // them closed. They are also the worst-case surface in the app for an
  // overflow — a *form* inside a *height-capped* container, which is the one
  // combination where a field, its label and its trailing control compete
  // for width against a viewport that the sheet has already given away 15 %
  // of. `EnvironmentDetailSheet` takes 92 % and puts a segmented control in
  // it, so at 320 px in Arabic at 1.3× it has the least room of anything
  // rendered anywhere.
  //
  // Pumped inside `_withVault` so the seeded project (long Odoo name, three
  // environments) is really in scope — each of these reads its subject out
  // of `VaultCubit` in `initState` and renders an empty shell if it isn't
  // there, which would sweep green while measuring nothing.

  testWidgets('ProjectsListSheet survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const Scaffold(body: ProjectsListSheet()),
      wrap: _withVault,
    );
  });

  testWidgets('ProjectDetailSheet survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const Scaffold(
        body: ProjectDetailSheet(existingProjectId: 'p1'),
      ),
      wrap: _withVault,
    );
  });

  testWidgets('EnvironmentDetailSheet survives the matrix', (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const Scaffold(
        body: EnvironmentDetailSheet(environmentId: 'e0'),
      ),
      wrap: _withVault,
    );
  });

  // ── Anti-false-green guard ─────────────────────────────────────────────
  //
  // A sweep only proves something if the screen actually rendered its
  // content. `_FakeConversationsRepo` originally let `noSuchMethod` swallow
  // `list()`; the cubit caught the resulting `NoSuchMethodError`, emitted a
  // failure, and the "passing" sweep was pumping an error state with none of
  // the card layout in it. These assert the data reached the screen, so a
  // fake that silently stops answering turns the sweep red instead of
  // quietly hollowing it out.
  group('the fakes actually feed the screens', () {
    testWidgets('AccountScreen shows the signed-in identity', (tester) async {
      await pumpOnce(tester, const AccountScreen(),
          prefs: prefs, wrap: _withPlan);
      expect(find.text(kUser.displayName), findsWidgets);
    });

    testWidgets('ConversationsScreen shows the seeded row', (tester) async {
      await pumpOnce(tester, const ConversationsScreen(),
          prefs: prefs, wrap: _withConversations);
      expect(find.textContaining('محتاجه منك'), findsWidgets);
    });

    testWidgets('VaultScreen shows the seeded project', (tester) async {
      await pumpOnce(tester, const VaultScreen(),
          prefs: prefs, wrap: _withVault);
      expect(find.textContaining('ALZOMMAN'), findsWidgets);
    });

    testWidgets('DevicesScreen shows the seeded device', (tester) async {
      await pumpOnce(tester, const DevicesScreen(),
          prefs: prefs, wrap: _withDevices);
      expect(find.textContaining('Android'), findsWidgets);
    });

    // The four below were swept for twenty layouts each with nothing checking
    // they had drawn anything. `PricingScreen` is the cautionary one: it spent
    // months sweeping green while rendering only its error state, because its
    // fixture was in a wire shape `PlanTier.fromJson` could not read. The
    // sweep cannot tell a laid-out screen from an empty one — that is what
    // these assertions are for, and every surface that reads a fixture needs
    // one.

    testWidgets('PricingScreen shows the real tier catalogue', (tester) async {
      await pumpOnce(
        tester,
        const PricingScreen(),
        prefs: prefs,
        wrap: (child) => BlocProvider<PlanCubit>(
          create: (_) => _SeededPlanCubit(),
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<PlansApi>(create: (_) => _FakePlansApi()),
              RepositoryProvider<Dio>(create: (_) => Dio()),
            ],
            child: child,
          ),
        ),
      );
      // Business is the tier that stresses this layout hardest — five
      // bullets, a "everything in Professional" header and a two-cycle price
      // line. If the parse silently dropped the catalogue, it is the first
      // thing to go missing.
      // The redesign's cards are taller, so Business sits below the first
      // viewport — scroll it into the lazy list's build window.
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await tester.pump();
      expect(find.textContaining('Business'), findsWidgets);
    });

    testWidgets('UsageScreen shows the usage card, not a spinner or an error',
        (tester) async {
      await pumpOnce(tester, const UsageScreen(), prefs: prefs, wrap: _withPlan);
      // `PlanUsageCard` is built on exactly one branch — `plan != null`. The
      // other three branches of that `BlocBuilder` (error, loading, public
      // catalogue fallback) are all short, and all of them sweep green.
      expect(find.byType(PlanUsageCard), findsOneWidget);
    });

    testWidgets('ShareDestinationOverlayContent lists real conversations',
        (tester) async {
      await pumpOnce(
        tester,
        ShareDestinationOverlayContent(
          fileCount: 3,
          onCancel: () {},
          onPick: (_) {},
        ),
        prefs: prefs,
        wrap: _withConversations,
      );
      // The picker has three states that all render without throwing —
      // spinner, empty hint, and the error state — and the sweep above is
      // happy with any of them. Only one of those is the screen this test
      // exists for, and it is the one whose rows carry the long titles.
      //
      // Asserting on the seeded row is what tells the difference: if the
      // cubit ever stops reaching this widget, the sweep keeps passing on an
      // empty column and this goes red instead.
      //
      // The assertion is on the TITLE, not on the project name every other
      // fixture check in this file uses. `_ConversationRow` here renders only
      // the title and the preview — unlike the Chats list's card, it prints no
      // project or environment tag — so `ALZOMMAN` is genuinely absent from
      // this screen and asserting on it would have failed against a perfectly
      // correct render.
      expect(find.textContaining('الصلاحيات'), findsWidgets);
    });

    testWidgets('ProjectDetailSheet resolves its project', (tester) async {
      await pumpOnce(
        tester,
        const Scaffold(body: ProjectDetailSheet(existingProjectId: 'p1')),
        prefs: prefs,
        wrap: _withVault,
      );
      expect(find.textContaining('ALZOMMAN'), findsWidgets);
    });

    testWidgets('EnvironmentDetailSheet resolves its environment',
        (tester) async {
      await pumpOnce(
        tester,
        const Scaffold(body: EnvironmentDetailSheet(environmentId: 'e0')),
        prefs: prefs,
        wrap: _withVault,
      );
      expect(find.textContaining('ALZOMMAN'), findsWidgets);
      // Both sheets fall back to a literal em dash when the lookup misses.
      // That fallback is a legitimate runtime state, but inside the sweep it
      // means the widest string in the app was never laid out — so the sweep
      // measured a dash where it thought it was measuring a 55-character
      // Odoo instance name.
      expect(find.text('—'), findsNothing);
    });
  });
}
