import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
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
import 'package:saqqar_app/features/inbox/data/artifact_models.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/inbox/view/artifact_details_sheet.dart';
import 'package:saqqar_app/features/meetings/data/meetings_api.dart';
import 'package:saqqar_app/features/meetings/view/meetings_screen.dart';
import 'package:saqqar_app/features/meetings/view_model/meetings_cubit.dart';
import 'package:saqqar_app/features/trial/data/trial_api.dart';
import 'package:saqqar_app/features/trial/data/trial_models.dart';
import 'package:saqqar_app/features/trial/view/trial_screen.dart';
import 'package:saqqar_app/features/trial/view_model/trial_cubit.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';

// ── Fakes ────────────────────────────────────────────────────────────────
class _FakeAppsApi implements AppsApi {
  @override
  Future<List<SaqqarApp>> list() async => const [
        SaqqarApp(
          slug: 'zatca',
          name: 'ZATCA e-invoicing',
          tagline: 'Onboard Fatoora Phase-2',
          category: 'Compliance · KSA',
          group: 'Finance',
          accent: '#14B8A6',
          iconSvg: '',
          envRequired: true,
        ),
      ];
  @override
  Future<String> launch(String slug, {String? environmentId}) async => 'c1';
}

class _FakeTrialApi implements TrialApi {
  @override
  Future<TrialInfo> request(TrialRequest req) async => TrialInfo.none;
  @override
  Future<TrialInfo> status() async => TrialInfo.none;
}

class _FakeMeetingsApi implements MeetingsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<Map<String, dynamic>> start(Map<String, dynamic> b) async => const {};
}

class _FakeProjectsApi implements ProjectsApi {
  @override
  Future<List<Project>> list() async => [
        const Project(id: 'p1', name: 'Acme', slug: 'acme', environments: [
          Environment(
            id: 'e1',
            name: 'prod',
            slug: 'prod',
            isLive: false,
            readOnly: true,
            autoApprove: false,
            projectId: 'p1',
          ),
        ]),
      ];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeOdooDataApi implements OdooDataApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeBillingHistoryApi implements BillingHistoryApi {
  @override
  Future<BillingHistory> fetch() async => BillingHistory.fromJson(const {
        'rows': [
          {
            'what': 'Pro — monthly',
            'amount': 99.0,
            'currency': 'SAR',
            'is_paid': true,
            'receipt_ref': 'R1',
            'when': '2026-07-20T10:15:00+00:00',
            'tokens_m': 5.0,
          },
        ],
        'token_balance': 4200000,
        'total_purchased': 5000000,
        'has_any': true,
      });
}

class _FakeArtifactsApi implements ArtifactsApi {
  @override
  Future<Artifact> detail(String id) async => const Artifact(
        id: 'a1',
        name: 'report.pdf',
        kind: 'pdf',
        mimeType: 'application/pdf',
        url: '/media/report.pdf',
      );
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _harness(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ar')],
    theme: AppTheme.light(const Locale('en')),
    darkTheme: AppTheme.dark(const Locale('en')),
    home: child,
  );
}

void main() {
  testWidgets('AppsScreen renders the catalogue tiles', (tester) async {
    await tester.pumpWidget(_harness(
      BlocProvider(
        create: (_) => AppsCubit(_FakeAppsApi()),
        child: const AppsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ZATCA e-invoicing'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget); // header title
  });

  testWidgets('TrialScreen renders the request form for a fresh user',
      (tester) async {
    await tester.pumpWidget(_harness(
      BlocProvider(
        create: (_) => TrialCubit(_FakeTrialApi()),
        child: const TrialScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Request trial'), findsOneWidget);
    // AppTextField labels render through EyebrowLabel (uppercased).
    expect(find.text('COMPANY NAME'), findsOneWidget);
  });

  testWidgets('MeetingsScreen renders the start form', (tester) async {
    await tester.pumpWidget(_harness(
      BlocProvider(
        create: (_) => MeetingsCubit(_FakeMeetingsApi()),
        child: const MeetingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Start transcription'), findsOneWidget);
  });

  testWidgets('DataExplorerScreen renders the env picker + Run', (tester) async {
    await tester.pumpWidget(_harness(
      BlocProvider(
        create: (_) => DataExplorerCubit(
          projects: _FakeProjectsApi(),
          data: _FakeOdooDataApi(),
        ),
        child: const DataExplorerScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Operation'), findsOneWidget);
  });

  testWidgets('BillingHistoryScreen renders balances + a row', (tester) async {
    await tester.pumpWidget(_harness(
      RepositoryProvider<BillingHistoryApi>(
        create: (_) => _FakeBillingHistoryApi(),
        child: const BillingHistoryScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Token balance'), findsOneWidget);
    expect(find.text('Pro — monthly'), findsOneWidget);
  });

  // The CheckoutScreen test that lived here is gone with the screen: the app
  // no longer has a purchase surface to render. Its replacement is
  // `no_in_app_purchase_test.dart`, which asserts the absence.

  testWidgets('ArtifactDetailsSheet renders the fetched metadata',
      (tester) async {
    await tester.pumpWidget(_harness(
      Scaffold(
        body: ArtifactDetailsSheet(
          api: _FakeArtifactsApi(),
          id: 'a1',
          name: 'report.pdf',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Artifact details'), findsOneWidget);
    // The pretty-printed JSON includes the real mime type from detail().
    expect(find.textContaining('application/pdf'), findsOneWidget);
  });
}
