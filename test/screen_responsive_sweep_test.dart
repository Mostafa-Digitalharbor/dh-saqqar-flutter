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

import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/account/view/account_screen.dart';
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
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
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
        );
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

WrapBuilder get _withVault => (child) => BlocProvider<VaultCubit>(
      create: (_) => _SeededVaultCubit(),
      child: child,
    );

WrapBuilder get _withDevices => (child) => RepositoryProvider<DevicesApi>(
      create: (_) => _FakeDevicesApi(),
      child: child,
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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
      expect(find.text('Digital Harbor'), findsWidgets);
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
  });
}
