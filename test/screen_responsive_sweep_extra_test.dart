// Whole-screen responsive sweep, part two: the screens the original sweep
// never reached.
//
// `screen_responsive_sweep_test.dart` covers the nine signed-in core
// surfaces. These seven were outside every device-matrix test in the repo —
// each had a unit test for its models or its cubit, but nothing that pumped
// the screen at 320 px, in Arabic, at 1.3× text:
//
//   AppsScreen · BillingHistoryScreen · DataExplorerScreen · MeetingsScreen ·
//   TrialScreen · SharedTranscriptScreen · AppErrorScreen
//
// Same matrix and same provider chrome as part one, both imported from
// `support/responsive_harness` so a viewport added there applies to all
// sixteen screens at once.
//
// Every fake seeds *populated* content, not an empty list: an empty state is
// a column of two centred labels, which is the one layout that cannot
// overflow. The rows, chips and metric tiles that compete for width only
// exist once there is data, so a fake that returns `[]` produces a sweep that
// passes without testing anything.

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/features/apps/data/app_package_models.dart';
import 'package:saqqar_app/features/apps/data/apps_api.dart';
import 'package:saqqar_app/features/apps/view/apps_screen.dart';
import 'package:saqqar_app/features/apps/view_model/apps_cubit.dart';
import 'package:saqqar_app/features/billing/data/billing_history_api.dart';
import 'package:saqqar_app/features/billing/data/billing_history_models.dart';
import 'package:saqqar_app/features/billing/view/billing_history_screen.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';
import 'package:saqqar_app/features/data_api/view/data_explorer_screen.dart';
import 'package:saqqar_app/features/data_api/view_model/data_explorer_cubit.dart';
import 'package:saqqar_app/features/meetings/data/meetings_api.dart';
import 'package:saqqar_app/features/meetings/view/meetings_screen.dart';
import 'package:saqqar_app/features/meetings/view_model/meetings_cubit.dart';
import 'package:saqqar_app/features/share/data/shared_transcript_models.dart';
import 'package:saqqar_app/features/share/data/shares_api.dart';
import 'package:saqqar_app/features/share/view/shared_transcript_screen.dart';
import 'package:saqqar_app/features/share/view_model/shared_transcript_cubit.dart';
import 'package:saqqar_app/features/trial/data/trial_api.dart';
import 'package:saqqar_app/features/trial/data/trial_models.dart';
import 'package:saqqar_app/features/trial/view/trial_screen.dart';
import 'package:saqqar_app/features/trial/view_model/trial_cubit.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';

import 'support/responsive_harness.dart';

// ── Seeded content ───────────────────────────────────────────────────────

/// A long Arabic tagline next to a long English name is the pairing that
/// breaks app tiles: the card sizes itself off one and wraps the other.
final _apps = <SaqqarApp>[
  SaqqarApp.fromJson(const {
    'slug': 'zatca',
    'name': 'ZATCA e-invoicing (Fatoora Phase-2)',
    'tagline': 'ربط فواتيرك بمنصة فاتورة وتفعيل المرحلة الثانية من الفوترة',
    'category': 'Compliance · KSA',
    'group': 'Finance',
    'accent': '#14B8A6',
    'icon_svg': '<svg/>',
    'env_required': true,
  }),
  SaqqarApp.fromJson(const {
    'slug': 'payroll',
    'name': 'Payroll & GOSI reconciliation',
    'tagline': 'تسوية الرواتب مع التأمينات الاجتماعية شهريًا',
    'category': 'HR',
    'group': 'People',
    'accent': '#F59E0B',
    'icon_svg': '<svg/>',
    'env_required': false,
  }),
];

final _history = BillingHistory.fromJson(const {
  'rows': [
    {
      'what': 'Max 20× — annual subscription',
      'is_paid': true,
      'receipt_ref': '7EA02D5F',
      'amount': 1999,
      'currency': 'SAR',
    },
    {
      'what': 'Token recharge — 5,000,000 tokens',
      'is_paid': false,
      'receipt_ref': 'B31C9A44',
      'amount': 499,
      'currency': 'SAR',
    },
  ],
  'token_balance': 4200000,
  'total_purchased': 5000000,
  'has_any': true,
});

final _trialReady = TrialInfo.fromJson(const {
  'status': 'ready',
  'ready': true,
  'url': 'https://alzomman-trading-contracting.odoo.com',
  'db': 'alzomman-trading-contracting-staging',
  'login': 'ai-tools@digital-harbor.net',
  'password': 'c0rrect-horse-battery-staple',
});

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

final _transcript = SharedTranscript.fromJson({
  'conversation': {
    'title': 'محتاجه منك في فقرات كل مستخدم ايه الصلاحيات اللي عنده في الجروبات',
    'updated_at': DateTime.utc(2026, 8, 4, 6, 41).toIso8601String(),
  },
  'messages': [
    {
      'id': 'm1',
      'role': 'user',
      'content':
          'اعملي مراجعة لصلاحيات المستخدمين في اللايف وقولي مين عنده صلاحية حذف',
      'created_at': DateTime.utc(2026, 8, 4, 6, 40).toIso8601String(),
    },
    {
      'id': 'm2',
      'role': 'assistant',
      'content':
          'تم. اتضاف 30 مستخدم في اللايف بنجاح (المعرّفات من 5 لـ 34)، وكلهم '
              'بالاسم والإيميل الصح، ومربوطين بمجموعة المبيعات.',
      'created_at': DateTime.utc(2026, 8, 4, 6, 41).toIso8601String(),
    },
  ],
});

// ── Fakes ────────────────────────────────────────────────────────────────

class _FakeAppsApi implements AppsApi {
  @override
  Future<List<SaqqarApp>> list() async => _apps;
  @override
  Future<String> launch(String slug, {String? environmentId}) async => 'c1';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeBillingHistoryApi implements BillingHistoryApi {
  @override
  Future<BillingHistory> fetch() async => _history;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeProjectsApi implements ProjectsApi {
  @override
  Future<List<Project>> list() async => _projects;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Returns a wide result set — the data explorer renders raw JSON, and a
/// single long unbreakable value is exactly what overflows its result pane.
class _FakeOdooDataApi implements OdooDataApi {
  Future<Map<String, dynamic>> _result(String op) async => {
        'op': op,
        'count': 3,
        'records': [
          {
            'id': 5,
            'display_name': kLongName,
            'email': 'ai-tools@digital-harbor.net',
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> count(String e, Map<String, dynamic> q) =>
      _result('count');
  @override
  Future<Map<String, dynamic>> search(String e, Map<String, dynamic> q) =>
      _result('search');
  @override
  Future<Map<String, dynamic>> readGroup(String e, Map<String, dynamic> q) =>
      _result('read-group');
  @override
  Future<Map<String, dynamic>> read(String e, Map<String, dynamic> q) =>
      _result('read');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMeetingsApi implements MeetingsApi {
  @override
  Future<Map<String, dynamic>> start(Map<String, dynamic> body) async =>
      {'id': 'm1', 'status': 'recording'};
  @override
  Future<Map<String, dynamic>> transcript(String id) async => {
        'status': 'ended',
        'transcript': [
          {'speaker': 'Sara', 'text': 'نبدأ بمراجعة أرقام المبيعات للربع الحالي'},
          {'speaker': 'Omar', 'text': 'تمام، عندي التقرير جاهز من أودو'},
        ],
      };
  @override
  Future<Map<String, dynamic>> stop(String id) async => {'status': 'ended'};
  @override
  Future<Map<String, dynamic>> summarize(String id) async =>
      {'summary': 'ملخص الاجتماع: مراجعة أرقام المبيعات وإقرار خطة الربع القادم.'};
  @override
  Future<Map<String, dynamic>> chat(String id, Map<String, dynamic> b) async =>
      {'reply': 'الرد على السؤال'};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTrialApi implements TrialApi {
  @override
  Future<TrialInfo> request(TrialRequest req) async => _trialReady;
  @override
  Future<TrialInfo> status() async => _trialReady;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSharesApi implements SharesApi {
  @override
  Future<SharedTranscript> get(String token) async => _transcript;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Provider wrappers ────────────────────────────────────────────────────

WrapBuilder get _withApps => (child) => BlocProvider<AppsCubit>(
      create: (_) => AppsCubit(_FakeAppsApi()),
      child: RepositoryProvider<AppsApi>(
        create: (_) => _FakeAppsApi(),
        child: child,
      ),
    );

WrapBuilder get _withBillingHistory =>
    (child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<BillingHistoryApi>(
              create: (_) => _FakeBillingHistoryApi(),
            ),
            // The receipt-open path builds an `ArtifactDownloader` from Dio.
            RepositoryProvider<Dio>(create: (_) => Dio()),
          ],
          child: child,
        );

WrapBuilder get _withDataExplorer => (child) => BlocProvider<DataExplorerCubit>(
      create: (_) => DataExplorerCubit(
        projects: _FakeProjectsApi(),
        data: _FakeOdooDataApi(),
      ),
      child: child,
    );

WrapBuilder get _withMeetings => (child) => BlocProvider<MeetingsCubit>(
      create: (_) => MeetingsCubit(_FakeMeetingsApi()),
      child: child,
    );

WrapBuilder get _withTrial => (child) => BlocProvider<TrialCubit>(
      create: (_) => TrialCubit(_FakeTrialApi()),
      child: child,
    );

WrapBuilder get _withSharedTranscript =>
    (child) => BlocProvider<SharedTranscriptCubit>(
          create: (_) => SharedTranscriptCubit(_FakeSharesApi())..load('tok-1'),
          child: child,
        );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('AppsScreen survives the matrix', (tester) async {
    await sweepMatrix(tester, prefs: prefs, () => const AppsScreen(),
        wrap: _withApps);
  });

  testWidgets('BillingHistoryScreen survives the matrix', (tester) async {
    await sweepMatrix(tester, prefs: prefs, () => const BillingHistoryScreen(),
        wrap: _withBillingHistory);
  });

  // Both of these screens open on a *form*, and everything worth measuring —
  // the result card, the live status panel, the transcript, the summary —
  // exists only after the user acts. Swept on first paint alone they were two
  // text fields and a button, which is not what they overflow at.
  //
  // Driven through the cubit rather than by tapping a labelled button: the
  // matrix runs each screen in English and Arabic, so a finder keyed on button
  // copy passes in one locale and silently does nothing in the other.

  testWidgets('DataExplorerScreen survives the matrix, with a result',
      (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const DataExplorerScreen(),
      wrap: _withDataExplorer,
      afterPump: (tester) async {
        final cubit = BlocProvider.of<DataExplorerCubit>(
          tester.element(find.byType(DataExplorerScreen)),
        );
        // `run` needs a selected environment or it refuses; the picker is
        // populated by the `loadEnvironments()` that `initState` fires.
        final env = cubit.state.environments.first;
        cubit.selectEnv(env.id);
        await cubit.run('{"domain": []}');
      },
    );
  });

  testWidgets('MeetingsScreen survives the matrix, mid-meeting',
      (tester) async {
    await sweepMatrix(
      tester,
      prefs: prefs,
      () => const MeetingsScreen(),
      wrap: _withMeetings,
      afterPump: (tester) async {
        final cubit = BlocProvider.of<MeetingsCubit>(
          tester.element(find.byType(MeetingsScreen)),
        );
        await cubit.start(UiStrings.meetingUrlExample);
        // `start` only arms a 5-second poll; it never fetches the transcript
        // itself. Without this the panel renders with an empty transcript
        // placeholder, which is shorter than every real state.
        await cubit.refreshTranscript();
        // The tallest state this screen reaches: status panel + two-speaker
        // transcript + summary + the ask field, all at once.
        await cubit.summarize();
      },
    );
  });

  testWidgets('TrialScreen survives the matrix', (tester) async {
    await sweepMatrix(tester, prefs: prefs, () => const TrialScreen(),
        wrap: _withTrial);
  });

  testWidgets('SharedTranscriptScreen survives the matrix', (tester) async {
    await sweepMatrix(
        tester, prefs: prefs, () => const SharedTranscriptScreen(token: 'tok-1'),
        wrap: _withSharedTranscript);
  });

  // ── Anti-false-green guard ─────────────────────────────────────────────
  //
  // Mirrors part one: a fake that quietly stops answering would leave each
  // screen rendering its error state, which cannot overflow and would keep
  // the sweep green while testing nothing.
  group('the fakes actually feed the screens', () {
    testWidgets('AppsScreen shows a seeded app', (tester) async {
      await pumpOnce(tester, const AppsScreen(), prefs: prefs, wrap: _withApps);
      expect(find.textContaining('ZATCA'), findsWidgets);
    });

    testWidgets('BillingHistoryScreen shows a seeded row', (tester) async {
      await pumpOnce(tester, const BillingHistoryScreen(),
          prefs: prefs, wrap: _withBillingHistory);
      expect(find.textContaining('Max 20×'), findsWidgets);
    });

    testWidgets('TrialScreen shows the ready instance', (tester) async {
      await pumpOnce(tester, const TrialScreen(),
          prefs: prefs, wrap: _withTrial);
      expect(find.textContaining('alzomman'), findsWidgets);
    });

    testWidgets('SharedTranscriptScreen shows the transcript', (tester) async {
      await pumpOnce(tester, const SharedTranscriptScreen(token: 'tok-1'),
          prefs: prefs, wrap: _withSharedTranscript);
      expect(find.textContaining('اتضاف 30 مستخدم'), findsWidgets);
    });

    testWidgets('DataExplorerScreen lists the seeded environments',
        (tester) async {
      await pumpOnce(tester, const DataExplorerScreen(),
          prefs: prefs, wrap: _withDataExplorer);
      // `loadEnvironments()` is fired from `initState`; if it fails the screen
      // renders "no environments" and the whole query form is never built.
      expect(find.textContaining('ALZOMMAN'), findsWidgets);
    });

    testWidgets('MeetingsScreen reaches the live panel', (tester) async {
      await pumpOnce(tester, const MeetingsScreen(),
          prefs: prefs, wrap: _withMeetings);
      final cubit = BlocProvider.of<MeetingsCubit>(
        tester.element(find.byType(MeetingsScreen)),
      );
      await cubit.start(UiStrings.meetingUrlExample);
      await cubit.refreshTranscript();
      await tester.pump(const Duration(milliseconds: 350));
      // The two-speaker transcript is the payload the fake returns. Seeing it
      // proves the sweep's `afterPump` above lands on the populated screen
      // rather than leaving the intro form up.
      expect(find.textContaining('أرقام المبيعات'), findsWidgets);
    });
  });
}
