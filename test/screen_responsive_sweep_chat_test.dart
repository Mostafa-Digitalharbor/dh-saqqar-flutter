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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
import 'package:saqqar_app/features/support/view/voice_support_screen.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/core/state/data_state.dart';

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
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSaqqarToolsApi implements SaqqarToolsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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
      await sweepMatrix(
        tester,
        () => const VoiceSupportScreen(),
        prefs: prefs,
        wrap: (child) => RepositoryProvider<VoiceSupportApi>(
          create: (_) => _FakeVoiceSupportApi(),
          child: child,
        ),
      );
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
            create: (_) => VaultCubit(repository: _FakeVaultRepo()),
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
            create: (_) => VaultCubit(repository: _FakeVaultRepo()),
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
