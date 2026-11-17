// Whole-screen responsive sweep, part three: the surfaces neither of the
// other two sweeps could reach.
//
// Parts one and two cover sixteen screens. An audit on 2026-08-09 listed every
// class in `lib` that extends a screen, sheet or dialog and diffed it against
// what the sweeps actually pump. Nine surfaces had **no device-matrix coverage
// at all** — and the list was led by `ChatScreen`, the surface the app exists
// for and the one every user spends their session inside.
//
//   ChatScreen · VoiceSupportScreen · AppLockScreen · AppLaunchDialog ·
//   ArtifactDetailsSheet · EnvironmentMultiSelectSheet
//
// `ChatScreen` was uncovered for a reason rather than by oversight: it reads
// sixteen providers, so pumping it at all means standing up most of the app's
// object graph. That is exactly why it drifted — the screen with the highest
// setup cost is the screen with the least coverage, and it is also the biggest
// file in the repo at ~3,950 lines. The `_chatProviders` wrapper below is the
// one-time cost of fixing that.
//
// `SaqqarScreen` and `ChatSheet` are deliberately absent: they are generic
// containers with no content of their own, and the widget-level
// `responsive_sweep_test.dart` already stresses them with hostile children.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/features/apps/data/app_package_models.dart';
import 'package:saqqar_app/features/apps/widgets/app_launch_dialog.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/saqqar_features_cubit.dart';
import 'package:saqqar_app/features/chat/data/live_env_ack_service.dart';
import 'package:saqqar_app/features/chat/data/saqqar_tools_api.dart';
import 'package:saqqar_app/features/chat/data/transcribe_api.dart';
import 'package:saqqar_app/features/chat/view/chat_screen.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/chat_state.dart';
import 'package:saqqar_app/features/chat/view_model/task_prep_cubit.dart';
import 'package:saqqar_app/features/chat/widgets/environment_multi_select_sheet.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_cache.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/view/artifact_details_sheet.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/security/view/app_lock_screen.dart';
import 'package:saqqar_app/features/share/intake/share_intake_service.dart';
import 'package:saqqar_app/features/support/data/voice_support_api.dart';
import 'package:saqqar_app/features/support/data/voice_support_models.dart';
import 'package:saqqar_app/features/support/view/voice_support_screen.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/shared/widgets/primary_button.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/core/state/data_state.dart';

import 'design/shot_harness.dart' show loadFonts, shotDir;
import 'support/responsive_harness.dart';

// ── Seeded content ───────────────────────────────────────────────────────
//
// Hostile but realistic, following the rule the other two sweeps set: an
// empty transcript is a centred empty state, which is the one layout that
// cannot overflow. Everything that competes for width — the environment
// chips, the long tool names, the code block, the approval card — only exists
// once there are messages.

/// A transcript that exercises every row type the chat can render at once.
///
/// The long unbroken token is deliberate: a URL or an Odoo external id with no
/// space in it is the classic thing that blows a bubble past a 320 px screen,
/// and it is what real Odoo output looks like.
Map<String, dynamic> _snapshotJson() => {
      'conversation': {
        'id': 'c1',
        'title': kLongName,
        'auto_approve': false,
        'is_running': true,
        'stop_requested': false,
        'project': {'id': 'p1', 'name': kLongName},
        'environment': {'id': 'e1', 'name': '$kLongName — Production'},
      },
      'messages': [
        {
          'id': 'm1',
          'role': 'user',
          'content': 'اعمللي تقرير بكل الفواتير المتأخرة عن السداد من فضلك',
          'created_at': '2026-08-09T10:00:00Z',
        },
        {
          'id': 'm2',
          'role': 'assistant',
          'content':
              'Reading account.move where invoice_date_due < today …\n'
                  'https://alzomman-trading-contracting.odoo.com/web#id=4821&model=account.move&view_type=form',
          'created_at': '2026-08-09T10:00:05Z',
        },
        {
          'id': 'm3',
          'role': 'assistant',
          'content': '```python\n'
              'invoices = env["account.move"].search([("state","=","posted")])\n'
              '```',
          'created_at': '2026-08-09T10:00:09Z',
        },
        {
          'id': 'm4',
          'role': 'assistant',
          'content': 'A couple of quick questions before I start 👇',
          'created_at': '2026-08-09T10:00:12Z',
          'tool_payload': {
            'kind': 'prompt_clarify',
            'original': 'overdue invoices',
            'questions': [
              {
                'question': 'Which period should I cover in this report?',
                'options': [
                  'This month',
                  'This quarter to date',
                  'The whole financial year',
                ],
                'default': 1,
              },
            ],
          },
        },
      ],
      'pending_approvals': [
        {
          'id': 'a1',
          'tool': 'odoo_write',
          'status': 'pending',
          'created_at': '2026-08-09T10:00:15Z',
          'payload': {
            'model': 'account.move',
            'method': 'action_post',
            'ids': [4821, 4822, 4823],
          },
        },
      ],
    };

final _projects = <Project>[
  Project(
    id: 'p1',
    name: kLongName,
    slug: 'alzomman-staging',
    environments: List.generate(
      4,
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

/// A paid plan with a window at 92 % — the state that renders the amber
/// near-limit banner *above* the composer, i.e. the tallest chat layout.
final _plan = PlanSnapshot.fromJson(const {
  'plan': 'pro',
  'plan_name': 'Professional',
  'exempt': false,
  'features': {
    'voice': true,
    'postgres': true,
    'github': true,
    'server_shell': true,
  },
  'day': {'used': 32200000, 'cap': 35000000, 'pct': 92, 'remaining': 2800000},
  'week': {'used': 32200000, 'cap': 35000000, 'pct': 92, 'remaining': 2800000},
  'month': {'used': 32200000, 'cap': 35000000, 'pct': 92, 'remaining': 2800000},
});

// ── Fakes ────────────────────────────────────────────────────────────────

class _FakeRepo implements ConversationsRepository {
  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;
  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;
  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}
  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async =>
      ConversationSnapshot.fromJson(_snapshotJson());
  @override
  Future<ConversationSnapshot> getSnapshotOffIsolate(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async =>
      ConversationSnapshot.fromJson(_snapshotJson());
  @override
  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    int offset = 0,
    bool includeArchived = false,
  }) async =>
      (conversations: const <ConversationSummary>[], total: 0);
  @override
  Future<({List<ConversationSummary> conversations, int? total})> listAll({
    int pageSize = 200,
    int maxPages = 12,
    bool includeArchived = false,
  }) async =>
      (conversations: const <ConversationSummary>[], total: 0);
  @override
  Future<({Map<String, int> pendingByConv, Map<String, int> filesByConv})>
      conversationMeta() async =>
          (pendingByConv: const <String, int>{}, filesByConv: const <String, int>{});
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

/// Seeds the transcript directly instead of letting `load()` race the pump.
///
/// The sweep pumps a fixed number of frames; a cubit that only reaches
/// `DataSuccess` after an async round-trip would render its skeleton in some
/// cells and its content in others, which makes an overflow look flaky rather
/// than real.
class _SeededChatCubit extends ChatCubit {
  _SeededChatCubit()
      : super(conversationId: 'c1', repository: _FakeRepo()) {
    emit(ChatState(
      data: DataSuccess(ConversationSnapshot.fromJson(_snapshotJson())),
    ));
  }

  // The screen starts a 1.5 s poll on a running conversation. Left alone it
  // keeps the tester's clock dirty across cells; there is nothing to poll for
  // here because the snapshot is already seeded.
  @override
  Future<void> load({bool force = false}) async {}
}

class _FakeProjectsApi implements ProjectsApi {
  @override
  Future<List<Project>> list() async => _projects;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeVaultRepo implements VaultRepository {
  @override
  Future<List<Project>> listProjects() async => _projects;

  /// `VaultCubit.load()` calls this too, and letting `noSuchMethod` take it
  /// returns `null` where a `Future` is expected — the cubit catches the
  /// resulting error and emits a failure, so every sheet reading out of it
  /// resolves to nothing. Both calls `load()` makes are answered here; if it
  /// ever makes a third, the fix is another override rather than a
  /// `noSuchMethod` that quietly hollows the fixture out again.
  @override
  Future<List<CredentialSchema>> getCredentialSchemas({
    bool forceRefresh = false,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeUsageApi implements UsageApi {
  @override
  Future<UsageSnapshot> fetch() async => UsageSnapshot(
        plan: _plan,
        saqqarFeatures: SaqqarFeatures.fromJson(const {
          'task_prep': true,
          'prompt_bank': true,
          'health_radar': true,
          'what_if': true,
          'business_pulse': true,
          'voice_support': true,
        }),
      );
}

/// Every §6/§8 feature on, so the tools sheet and the voice-support entry both
/// render. The *fuller* layout is the one that can overflow.
class _SeededFeaturesCubit extends SaqqarFeaturesCubit {
  _SeededFeaturesCubit() : super(_FakeUsageApi()) {
    emit(SaqqarFeatures.fromJson(const {
      'task_prep': true,
      'prompt_bank': true,
      'health_radar': true,
      'what_if': true,
      'business_pulse': true,
      'voice_support': true,
    }));
  }
  @override
  Future<void> ensureLoaded({bool force = false}) async {}
}

class _SeededPlanCubit extends PlanCubit {
  _SeededPlanCubit() {
    emit(_plan);
  }
}

class _FakeApprovalsApi implements ApprovalsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeArtifactsApi implements ArtifactsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeOdooDataApi implements OdooDataApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTranscribeApi implements TranscribeApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeVoiceSupportApi implements VoiceSupportApi {
  /// A full draft, so the sweep can measure the CARD and not just the empty
  /// form. Deliberately hostile-but-real: Arabic prose, a long Odoo module
  /// name, and every optional section populated — the widest the card gets.
  @override
  Future<VoiceSupportDraft> draft({
    required String problem,
    required String lang,
  }) async =>
      VoiceSupportDraft.fromJson(const {
        'ok': true,
        'draft': {
          'title': 'الفواتير لا تُرحَّل في يومية المبيعات',
          'module': 'account_accountant',
          'category': 'bug',
          'priority': 'High',
          'summary':
              'العميل ما يقدر يرحّل الفواتير، وتبقى بحالة مسودة رغم اكتمال '
                  'كل الحقول المطلوبة.',
          'diagnosis':
              'الأرجح أن تسلسل اليومية وصل إلى نهايته أو أن الفترة المحاسبية '
                  'مقفلة لهذا الشهر.',
          'questions': [
            'ما إصدار أودو المستخدم لدى العميل؟',
            'هل تظهر المشكلة في كل اليوميات أم في يومية المبيعات فقط؟',
          ],
          'reproduction_steps': [
            'افتح الإعدادات ثم تسلسل اليومية وتأكد من المدى المتاح.',
            'أعد محاولة الترحيل من فاتورة واحدة للتأكد.',
          ],
          'customer_reply':
              'شكلها مشكلة في تسلسل اليومية. جرّب تتأكد من الإعداد وبعدها '
                  'أعد الترحيل، وإذا استمرت المشكلة ابعتلنا رقم الفاتورة.',
        },
      });

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSaqqarToolsApi implements SaqqarToolsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Types a problem into §8 and asks for a draft, so the sweep measures the
/// result card rather than the empty form.
///
/// The scroll loop is not defensive padding: `PageScaffold` lays its children
/// out in a lazy list, and the 568×320 landscape cell is barely taller than
/// the five-line text box — so the submit button is genuinely not built yet
/// and `find.byType` reports nothing at all. Dragging brings it into the
/// build window. Bounded, so a screen that never renders the button fails
/// loudly on the tap instead of spinning.
Future<void> _requestVoiceSupportDraft(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).first,
    'الفواتير مش بتترحّل في يومية المبيعات',
  );
  await tester.pump();

  final submit = find.byType(PrimaryButton);
  for (var i = 0; i < 4 && submit.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pump();
  }
  await tester.ensureVisible(submit.first);
  await tester.pump();
  // `warnIfMissed: false` — the button can sit partly under the viewport edge
  // in the landscape cell, which is a hit-test miss but not a layout problem,
  // and the tap still dispatches.
  await tester.tap(submit.first, warnIfMissed: false);
  await tester.pump();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// The sixteen providers `ChatScreen` reads, in the shape `app.dart` and the
  /// route builder install them.
  WrapBuilder chatProviders() => (child) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ConversationsRepository>(
              create: (_) => _FakeRepo()),
          RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjectsApi()),
          RepositoryProvider<VaultRepository>(create: (_) => _FakeVaultRepo()),
          RepositoryProvider<ApprovalsApi>(create: (_) => _FakeApprovalsApi()),
          RepositoryProvider<ArtifactsApi>(create: (_) => _FakeArtifactsApi()),
          RepositoryProvider<OdooDataApi>(create: (_) => _FakeOdooDataApi()),
          RepositoryProvider<TranscribeApi>(create: (_) => _FakeTranscribeApi()),
          RepositoryProvider<SaqqarToolsApi>(
              create: (_) => _FakeSaqqarToolsApi()),
          RepositoryProvider<VoiceSupportApi>(
              create: (_) => _FakeVoiceSupportApi()),
          RepositoryProvider<UsageApi>(create: (_) => _FakeUsageApi()),
          RepositoryProvider<LiveEnvAckService>(
              create: (_) => LiveEnvAckService(prefs)),
          RepositoryProvider<Dio>(create: (_) => Dio()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ChatCubit>(create: (_) => _SeededChatCubit()),
            BlocProvider<PlanCubit>(create: (_) => _SeededPlanCubit()),
            BlocProvider<SaqqarFeaturesCubit>(
                create: (_) => _SeededFeaturesCubit()),
            BlocProvider<TaskPrepCubit>(create: (_) => TaskPrepCubit(prefs)),
            BlocProvider<ConversationsCubit>(
                create: (_) => ConversationsCubit(repository: _FakeRepo())),
            BlocProvider<VaultCubit>(
                create: (_) => VaultCubit(repository: _FakeVaultRepo())),
          ],
          child: ChangeNotifierProvider<ShareIntakeService>(
            create: (_) => ShareIntakeService(),
            child: child,
          ),
        ),
      );

  // Design screenshots (only when SHOT_DIR is set) — see test/design/.
  group('design shots', () {
    Future<void> snap(WidgetTester tester, String name, String id,
        {Future<void> Function(WidgetTester)? act}) async {
      await loadFonts();
      await tester.binding.setSurfaceSize(const Size(375, 812));
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(750, 1624);
      tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
      tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.view.reset();
      });
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: buildHarness(
          ChatScreen(conversationId: id),
          locale: const Locale('en'),
          scale: 1.0,
          wrap: (app) => appChrome(chatProviders()(app), prefs),
        ),
      ));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold).first);
        for (final a in const [
          'assets/design/orb.png',
          'assets/design/avatar.png',
        ]) {
          await precacheImage(AssetImage(a), ctx);
        }
      });
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      if (act != null) {
        await act(tester);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        final f = File('${shotDir}/$name.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    testWidgets('chat populated', (tester) async {
      await snap(tester, 'chat_populated', 'c1');
    });
    testWidgets('chat new', (tester) async {
      await snap(tester, 'chat_new', 'new');
    });
    testWidgets('chats drawer', (tester) async {
      await snap(tester, 'drawer_chats', 'c1', act: (t) async {
        await t.tap(find.byIcon(LucideIcons.menu));
      });
    });
    testWidgets('workspace drawer', (tester) async {
      await snap(tester, 'drawer_workspace', 'c1', act: (t) async {
        await t.tap(find.byIcon(LucideIcons.info));
      });
    });
  }, skip: Platform.environment['SHOT_DIR'] == null);

  group('ChatScreen — the surface the app exists for', () {
    testWidgets('survives the matrix with a populated transcript',
        (tester) async {
      await sweepMatrix(
        tester,
        () => const ChatScreen(conversationId: 'c1'),
        prefs: prefs,
        wrap: chatProviders(),
      );
    });

    testWidgets('the fake actually feeds it — not an error state',
        (tester) async {
      // Without this the sweep above would pass on whatever `ChatScreen`
      // renders when its providers throw, which is a centred error column:
      // the one layout that cannot overflow. Same trap that let the pricing
      // sweep run green against a fixture that threw for months.
      await pumpOnce(
        tester,
        const ChatScreen(conversationId: 'c1'),
        prefs: prefs,
        wrap: chatProviders(),
      );

      // `findRichText: true` is load-bearing. Message bodies render through
      // `ChatMarkdown` → `MarkdownBody`, which emits `RichText` spans, not
      // `Text` widgets — so the default finder reports zero matches on a chat
      // that is rendering perfectly. Getting this wrong is how a sweep ends up
      // "passing" against an empty state.
      //
      // The assertion targets the agent's body rather than the user's opening
      // line: the list opens scrolled to the newest message, so the oldest row
      // is legitimately above the viewport and culled.
      expect(
        find.textContaining('Reading account.move', findRichText: true),
        findsWidgets,
        reason: 'the seeded transcript never reached the screen — the sweep '
            'was stressing an empty state, not the chat',
      );
    });
  });

  group('the five other uncovered surfaces', () {
    testWidgets('VoiceSupportScreen survives the matrix', (tester) async {
      // Driven past its first paint on purpose. An untouched §8 screen is an
      // intro line, a text box and a button — a layout that essentially
      // cannot overflow, so sweeping only that measured nothing. Everything
      // that competes for width (the chip row, the four prose sections, the
      // bulleted lists) exists only once a draft has come back, which is what
      // `afterPump` produces here.
      await sweepMatrix(
        tester,
        // A fresh key per cell, deliberately. `pumpWidget` with the same
        // widget type at the same position UPDATES the existing element, so
        // the `State` — and with it the scroll offset and the draft already
        // fetched — survives into the next cell. The first cell would then
        // leave the list scrolled past the text box, and the second cell's
        // `enterText` would fail on a field the lazy list had culled. Keying
        // each cell makes every one start from the pristine screen.
        () => VoiceSupportScreen(key: UniqueKey()),
        prefs: prefs,
        wrap: (child) => RepositoryProvider<VoiceSupportApi>(
          create: (_) => _FakeVoiceSupportApi(),
          child: child,
        ),
        afterPump: _requestVoiceSupportDraft,
      );
    });

    testWidgets('the voice-support fake actually fills the card',
        (tester) async {
      // The sweep above is only meaningful if the draft really rendered. A
      // fake whose `draft()` threw would leave the screen in its empty state
      // and every cell would pass — the exact way this repo has been fooled
      // before.
      await pumpOnce(
        tester,
        const VoiceSupportScreen(),
        prefs: prefs,
        locale: const Locale('ar'),
        wrap: (child) => RepositoryProvider<VoiceSupportApi>(
          create: (_) => _FakeVoiceSupportApi(),
          child: child,
        ),
      );
      await _requestVoiceSupportDraft(tester);
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.textContaining('تسلسل اليومية'),
        findsWidgets,
        reason: 'the seeded draft never reached the card — the sweep was '
            'stressing the empty form',
      );
      // The field the model used to drop on the floor. It has a section now,
      // so it has to survive the round trip too.
      expect(find.textContaining('الفترة المحاسبية'), findsWidgets);
    });

    testWidgets('AppLockScreen survives the matrix', (tester) async {
      // `AppLockCubit` is already in `appChrome`, backed by the fake that
      // reports biometric hardware present — the branch that renders the
      // unlock button rather than the bare fallback.
      await sweepMatrix(
        tester,
        () => const AppLockScreen(),
        prefs: prefs,
      );
    });

    testWidgets('AppLaunchDialog survives the matrix', (tester) async {
      final app = SaqqarApp.fromJson(const {
        'slug': 'zatca',
        'name': 'ZATCA e-invoicing (Fatoora Phase-2 onboarding)',
        'tagline':
            'ربط فواتيرك بمنصة فاتورة وتفعيل المرحلة الثانية من الفوترة الإلكترونية',
        'category': 'Compliance · KSA',
        'group': 'Finance',
        'accent': '#14B8A6',
        'icon_svg': '<svg/>',
        'env_required': true,
      });

      await sweepMatrix(
        tester,
        () => Scaffold(body: AppLaunchDialog(app: app)),
        prefs: prefs,
        wrap: (child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjectsApi()),
            RepositoryProvider<VaultRepository>(
                create: (_) => _FakeVaultRepo()),
          ],
          child: BlocProvider<VaultCubit>(
            // `..load()`, because nothing else calls it. In the app a sheet is
            // only reachable through a screen that has already loaded this;
            // pumped standalone the cubit is idle and the sheet renders an
            // empty picker, which is a layout that cannot overflow.
            create: (_) => VaultCubit(repository: _FakeVaultRepo())..load(),
            child: child,
          ),
        ),
      );
    });

    testWidgets('EnvironmentMultiSelectSheet survives the matrix',
        (tester) async {
      await sweepMatrix(
        tester,
        () => const Scaffold(
          body: EnvironmentMultiSelectSheet(
            projectId: 'p1',
            selectedEnvironmentIds: ['e0', 'e2'],
          ),
        ),
        prefs: prefs,
        wrap: (child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjectsApi()),
            RepositoryProvider<VaultRepository>(create: (_) => _FakeVaultRepo()),
          ],
          child: BlocProvider<VaultCubit>(
            // `..load()`, because nothing else calls it. In the app a sheet is
            // only reachable through a screen that has already loaded this;
            // pumped standalone the cubit is idle and the sheet renders an
            // empty picker, which is a layout that cannot overflow.
            create: (_) => VaultCubit(repository: _FakeVaultRepo())..load(),
            child: child,
          ),
        ),
      );
    });

    testWidgets('ArtifactDetailsSheet survives the matrix', (tester) async {
      await sweepMatrix(
        tester,
        () => Scaffold(
          body: ArtifactDetailsSheet(
            api: _FakeArtifactsApi(),
            id: 'art-1',
            name: '$kLongName — overdue-invoices-2026-08.xlsx',
          ),
        ),
        prefs: prefs,
        wrap: (child) => RepositoryProvider<ArtifactsApi>(
          create: (_) => _FakeArtifactsApi(),
          child: child,
        ),
      );
    });
  });

  // ── Anti-false-green guard ───────────────────────────────────────────────
  //
  // Same rule as the other two sweep files: a sweep that renders an empty
  // shell cannot overflow, so it passes while measuring nothing. Both sheets
  // below read their subject out of `VaultCubit`, and `load()` is called in
  // exactly one place in the app — `VaultScreen.initState` — which a sheet
  // pumped on its own never goes through.
  group('the sheets actually resolve their subject', () {
    testWidgets('EnvironmentMultiSelectSheet lists the project\'s envs',
        (tester) async {
      await pumpOnce(
        tester,
        const Scaffold(
          body: EnvironmentMultiSelectSheet(
            projectId: 'p1',
            selectedEnvironmentIds: ['e0', 'e2'],
          ),
        ),
        prefs: prefs,
        wrap: (child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjectsApi()),
            RepositoryProvider<VaultRepository>(create: (_) => _FakeVaultRepo()),
          ],
          child: BlocProvider<VaultCubit>(
            create: (_) => VaultCubit(repository: _FakeVaultRepo())..load(),
            child: child,
          ),
        ),
      );
      expect(find.textContaining('ALZOMMAN'), findsWidgets);
    });

    testWidgets('AppLaunchDialog offers an environment to launch into',
        (tester) async {
      final app = SaqqarApp.fromJson(const {
        'slug': 'zatca',
        'name': 'ZATCA e-invoicing (Fatoora Phase-2 onboarding)',
        'tagline': 'ربط فواتيرك بمنصة فاتورة',
        'category': 'Compliance · KSA',
        'group': 'Finance',
        'accent': '#14B8A6',
        'icon_svg': '<svg/>',
        'env_required': true,
      });

      await pumpOnce(
        tester,
        Scaffold(body: AppLaunchDialog(app: app)),
        prefs: prefs,
        wrap: (child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjectsApi()),
            RepositoryProvider<VaultRepository>(create: (_) => _FakeVaultRepo()),
          ],
          child: BlocProvider<VaultCubit>(
            create: (_) => VaultCubit(repository: _FakeVaultRepo())..load(),
            child: child,
          ),
        ),
      );
      // `env_required: true`, so the picker is the whole point of this dialog
      // — an empty one means the sweep measured a title and a disabled button.
      expect(find.textContaining('ALZOMMAN'), findsWidgets);
    });
  });

  tearDown(() {
    // `AttachmentViewerScreen` takes a real `File`; anything the tests above
    // wrote is cleaned up here so a temp file never leaks between runs.
    final tmp = Directory.systemTemp.listSync().whereType<File>().where(
        (f) => f.path.contains('saqqar_sweep_'));
    for (final f in tmp) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  });
}
