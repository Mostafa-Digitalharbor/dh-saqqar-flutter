// Generates the Figma import bundle under `design/export/`.
//
// This is a generator wearing a test's clothes. It lives in `test/` and runs
// under `flutter test` because that is the only harness that can build a real
// screen — with real constraints, real fonts and a real layout pass — outside
// a device. Nothing here asserts a product invariant; the expectations at the
// bottom guard the *export* (a screen that captured nothing is a broken fake,
// not a blank screen), so a silently empty bundle fails loudly instead of
// producing a Figma file full of empty frames.
//
// Run it:
//
//   flutter test test/figma_export_test.dart
//
// Then import `design/export/` with the plugin in `design/figma_plugin/`.
//
// The per-screen fakes below are close cousins of the ones in
// `screen_responsive_sweep_test.dart` — same classes, different content. The
// sweeps' fakes are private and, more to the point, tuned to be *hostile*:
// the longest plausible names, worst-case Arabic, 1.3× text, because their job
// is to break layouts. A design file wants the opposite — content that reads
// the way the product reads on a good day. Sharing one set would force one of
// the two jobs to use the wrong data.

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
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
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

import 'support/figma_exporter.dart';
import 'support/figma_fonts.dart';
import 'support/figma_tokens.dart';
import 'support/responsive_harness.dart';

// ── Content ──────────────────────────────────────────────────────────────
//
// Realistic, not hostile. Names are the length a real Odoo instance uses, and
// the numbers are mid-range rather than at a cap — a design file showing a
// 100 %-full quota bar teaches the wrong thing about the component.

const _window = UsageWindow(used: 3240, cap: 10000, pct: 32, remaining: 6760);

const _plan = PlanSnapshot(
  slug: 'pro',
  name: 'Pro',
  exempt: false,
  day: _window,
  week: UsageWindow(used: 18400, cap: 60000, pct: 31, remaining: 41600),
  month: UsageWindow(used: 41200, cap: 200000, pct: 21, remaining: 158800),
  features: PlanFeatures(
    voice: true,
    postgres: true,
    github: true,
    serverShell: false,
  ),
);

const _projectName = 'ALZOMMAN Trading';

const _projects = <Project>[
  Project(
    id: 'p1',
    name: _projectName,
    slug: 'alzomman-trading',
    environments: [
      Environment(
        id: 'e0',
        name: 'Production',
        slug: 'production',
        isLive: true,
        readOnly: false,
        autoApprove: false,
        projectId: 'p1',
      ),
      Environment(
        id: 'e1',
        name: 'Staging',
        slug: 'staging',
        isLive: false,
        readOnly: true,
        autoApprove: true,
        projectId: 'p1',
      ),
    ],
  ),
];

final _conversations = <ConversationSummary>[
  ConversationSummary(
    id: 'c1',
    title: 'Q3 receivables ageing report',
    createdAt: DateTime.utc(2026, 8, 11, 8, 30),
    updatedAt: DateTime.utc(2026, 8, 11, 9, 12),
    isArchived: false,
    messageCount: 24,
    lastMessagePreview:
        'Pulled 142 open invoices past 60 days. Total exposure is SAR 1.24M, '
        'concentrated in three accounts.',
    projectName: _projectName,
    environmentName: 'Production',
    filesCount: 3,
  ),
  ConversationSummary(
    id: 'c2',
    title: 'Reconcile the Riyadh warehouse stock count',
    createdAt: DateTime.utc(2026, 8, 10, 15, 2),
    updatedAt: DateTime.utc(2026, 8, 10, 17, 40),
    isArchived: false,
    messageCount: 8,
    lastMessagePreview:
        'Found 11 SKUs where the physical count differs from the system.',
    projectName: _projectName,
    environmentName: 'Staging',
    filesCount: 1,
  ),
  ConversationSummary(
    id: 'c3',
    title: 'Draft the renewal quotation',
    createdAt: DateTime.utc(2026, 8, 9, 10, 15),
    updatedAt: DateTime.utc(2026, 8, 9, 11, 3),
    isArchived: false,
    messageCount: 16,
    lastMessagePreview: 'Quotation SO-2291 is ready for your approval.',
    projectName: _projectName,
    environmentName: 'Production',
    filesCount: 0,
  ),
];

// ── Fakes ────────────────────────────────────────────────────────────────

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

class _FakeDevicesApi extends DevicesApi {
  _FakeDevicesApi() : super(Dio());
  @override
  Future<List<DeviceRow>> list() async => [
        DeviceRow(
          id: 'd1',
          platform: DevicePlatform.android,
          tokenPreview: 'fcm-token-abcdef0123456789',
          appVersion: '1.0.22+23',
          lastSeenAt: DateTime.utc(2026, 8, 11, 9, 20),
          createdAt: DateTime.utc(2026, 5, 8),
        ),
        DeviceRow(
          id: 'd2',
          platform: DevicePlatform.ios,
          tokenPreview: 'apns-token-9f8e7d6c5b4a3210',
          appVersion: '1.0.22+23',
          lastSeenAt: DateTime.utc(2026, 8, 10, 21, 5),
          createdAt: DateTime.utc(2026, 6, 2),
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

/// Both list calls are overridden for the same reason the sweep's copy
/// overrides both: `noSuchMethod` returning null makes the cubit emit a
/// failure, and the export would then capture the *error* state — a handful
/// of layers that still looks like a successful capture.
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
            pendingByConv: {'c1': 2},
            filesByConv: {'c1': 3, 'c2': 1},
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

// ── Provider wrappers ────────────────────────────────────────────────────

WrapBuilder get _withPlan => (child) => BlocProvider<PlanCubit>(
      create: (_) => _SeededPlanCubit(),
      child: RepositoryProvider<UsageApi>(
        create: (_) => _FakeUsageApi(),
        child: BlocProvider<SaqqarFeaturesCubit>(
          create: (_) => SaqqarFeaturesCubit(_FakeUsageApi()),
          child: child,
        ),
      ),
    );

WrapBuilder get _withConversations =>
    (child) => BlocProvider<ConversationsCubit>(
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

// ── The export ───────────────────────────────────────────────────────────

void main() {
  late SharedPreferences prefs;

  // Before anything is pumped. `flutter test` registers no fonts at all, so
  // every family falls back to Ahem — the test face whose glyphs are solid
  // black boxes. Without this the screenshots come out as a wall of black
  // rectangles, which looks like a broken renderer and is really just the
  // documented default.
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('tokens export carries every collection', () {
    final tokens = buildTokens();
    writeTokens(tokens);

    // Guards the generator, not the palette: a refactor that renames a getter
    // on `SaqqarThemeExtension` would otherwise write an empty list and the
    // plugin would build a variable collection with nothing in it.
    expect(tokens['colors']! as List, isNotEmpty);
    expect(tokens['radius']! as List, isNotEmpty);
    expect(tokens['text']! as List, isNotEmpty);
    expect(tokens['effects']! as List, isNotEmpty);
    expect(tokens['gradients']! as List, isNotEmpty);
  });

  testWidgets('screens export', (tester) async {
    final captures = <ScreenCapture>[];

    // Per-screen floor, not one number for all nine.
    //
    // The check exists to catch a fake that threw — the screen then renders an
    // error state, which still exports as a handful of perfectly valid layers
    // and looks like a successful capture. But screens legitimately differ by
    // an order of magnitude: the splash is a logo on a background, Account is
    // a dozen rows of settings. A single threshold either passes the error
    // states or fails the simple screens, so each names its own.
    Future<void> grab(
      String name,
      Widget screen, {
      required int minLayers,
      WrapBuilder? wrap,
      Locale locale = const Locale('en'),
    }) async {
      // A `RepaintBoundary` directly above `MaterialApp` — the only render
      // object a widget test can read real pixels out of. It goes *inside*
      // whatever providers the screen needs so it wraps the app and nothing
      // else, and it is keyed fresh per screen because the previous tree is
      // torn down by the time this one pumps.
      final boundaryKey = GlobalKey();

      // Overflows are worth catching *here specifically*, and not because
      // this file is a layout test — it isn't.
      //
      // Every other sweep in the repo runs without `loadAppFonts`, so every
      // string it measures is set in Ahem, whose glyphs are all one square em.
      // Real Space Grotesk is wider than Ahem at some sizes and narrower at
      // others, so a Row that fits the test font can overflow the shipping
      // one — and this is the only harness in the project that measures with
      // the fonts the user actually sees. An overflow found here is a real
      // one that the device shows and CI cannot.
      final overflows = <String>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.toString();
        if (text.contains('overflowed by')) {
          overflows.add(
            text.split('\n').where((line) {
              final t = line.trim();
              return t.contains('overflowed by') ||
                  t.startsWith('The relevant error-causing widget');
            }).take(2).join(' · '),
          );
        }
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await pumpOnce(
        tester,
        screen,
        prefs: prefs,
        wrap: (app) {
          final bounded = RepaintBoundary(key: boundaryKey, child: app);
          return wrap == null ? bounded : wrap(bounded);
        },
        locale: locale,
      );

      // Let the entrance animations finish before reading the tree.
      //
      // `pumpOnce` stops at 350 ms, which is mid-flight for `listFadeIn`
      // (400 ms) and well short of a staggered list. Capturing there gave a
      // Conversations frame with its section headers ("Today", "Yesterday")
      // and a card-shaped hole between them: the rows existed, at opacity
      // 0.04, and the exporter correctly drops anything that faint as
      // invisible. A full second puts every entrance at rest.
      //
      // `pumpAndSettle` is not an option — the agent pulse, the typing dots
      // and the ambient glow never settle, so it would time out.
      //
      // Two seconds rather than one because the splash's own entrance runs
      // 1600 ms and its minimum on-screen time is 1400 ms; at one second it
      // exported mid-zoom, with the logo plate still at part size.
      await tester.pump(const Duration(seconds: 2));

      // Asset images decode on a real callback the fake clock never fires, so
      // without this every `Image.asset` in the tree paints its placeholder
      // forever — and the raster records the placeholder.
      await precacheImages(tester);
      await tester.pump(const Duration(milliseconds: 100));

      const scale = 2.0;
      final png = await capturePng(tester, boundaryKey, pixelRatio: scale);

      final capture = await captureScreen(
        tester,
        name: name,
        locale: locale.languageCode,
        // `pumpOnce` builds `MaterialApp` with both themes and no explicit
        // `themeMode`, so the platform brightness decides — and under
        // `flutter test` that is always light.
        brightness: Brightness.light,
        screenshot: png,
        screenshotScale: scale,
      );
      captures.add(capture);

      expect(
        capture.layers.length,
        greaterThanOrEqualTo(minLayers),
        reason: '$name captured only ${capture.layers.length} layers — its '
            'fake probably threw and the screen rendered an error state',
      );
      // A PNG this small is a blank or near-blank frame. The raster is the
      // one artefact nothing else can substitute for — it carries the
      // `CustomPainter` work and the blurs the layer walk cannot see — so a
      // silently empty one would leave a hole nobody notices until Figma.
      expect(
        png?.length ?? 0,
        greaterThan(8 * 1024),
        reason: '$name rendered a ${png?.length ?? 0}-byte PNG — the raster '
            'is blank',
      );

      FlutterError.onError = previousOnError;

      // Printed, not just counted: this generator pumps nine screens in one
      // test, and when one of them hangs the run dies on a bare timeout that
      // names the test rather than the screen. The trail says which.
      // ignore: avoid_print
      print('  ✓ $name — ${capture.layers.length} layers, '
          '${((png?.length ?? 0) / 1024).round()} KB raster');
      for (final overflow in overflows.toSet()) {
        // ignore: avoid_print
        print('    ⚠ $overflow');
      }
    }

    // A logo on a gradient, and that is the whole screen.
    await grab(
      'Launch Splash',
      LaunchSplashScreen(onComplete: () {}),
      minLayers: 4,
    );
    // Two panes, not one: the email step and the OTP step are the two auth
    // layouts a designer actually has to lay out, and they differ by more
    // than a field — the OTP pane carries the code boxes and a resend timer.
    await grab(
      'Auth Email',
      const AuthFlowScreen(initial: AuthFlowStep.signInEmail),
      minLayers: 25,
    );
    await grab(
      'Auth OTP',
      const AuthFlowScreen(initial: AuthFlowStep.signInOtp),
      minLayers: 25,
    );
    await grab(
      'Account',
      const AccountScreen(),
      wrap: _withPlan,
      minLayers: 60,
    );
    await grab(
      'Usage',
      const UsageScreen(),
      wrap: _withPlan,
      minLayers: 18,
    );
    await grab(
      'Conversations',
      const ConversationsScreen(),
      wrap: _withConversations,
      minLayers: 60,
    );
    await grab(
      'Vault',
      const VaultScreen(),
      wrap: _withVault,
      minLayers: 35,
    );
    await grab(
      'Devices',
      const DevicesScreen(),
      wrap: _withDevices,
      minLayers: 18,
    );
    await grab(
      'Notifications',
      const NotificationsInboxScreen(),
      wrap: (child) => ChangeNotifierProvider<NotificationsStore>(
        create: (_) => _seededNotifications(prefs),
        child: child,
      ),
      minLayers: 30,
    );

    writeCaptures(captures);
  });
}

/// The inbox with three rows in it.
///
/// The empty state is a real screen and worth having eventually, but it is not
/// the one to build a design file from — an empty inbox teaches nothing about
/// the row, which is the only component on the screen.
NotificationsStore _seededNotifications(SharedPreferences prefs) {
  final store = NotificationsStore(prefs);
  // Added oldest-first: `add` prepends, so this leaves the newest on top.
  store.add(AppNotification(
    id: 'n3',
    type: 'quota_warning',
    title: 'Daily quota at 80%',
    body: 'You have used 8,000 of 10,000 requests today.',
    receivedAt: DateTime.utc(2026, 8, 10, 14, 2),
    read: true,
  ));
  store.add(AppNotification(
    id: 'n2',
    type: 'run_complete',
    title: 'Stock reconciliation finished',
    body: '11 SKUs need review before the count can be posted.',
    receivedAt: DateTime.utc(2026, 8, 11, 8, 45),
    conversationId: 'c2',
  ));
  store.add(AppNotification(
    id: 'n1',
    type: 'approval_required',
    title: 'Approval needed',
    body: 'Saqqar wants to post quotation SO-2291 to Production.',
    receivedAt: DateTime.utc(2026, 8, 11, 9, 12),
    conversationId: 'c1',
  ));
  return store;
}
