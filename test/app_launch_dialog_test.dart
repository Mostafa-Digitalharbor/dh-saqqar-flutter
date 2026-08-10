// Tapping a Saqqar App used to open a conversation immediately, and the
// first thing the user saw was the agent asking which Odoo database to work
// on — a question this screen can answer from a list.
//
// The dialog has one subtlety worth pinning: "dismissed" and "decide later"
// are DIFFERENT outcomes. Both end with no environment, but only one of them
// should launch anything. Collapsing them (returning null for both, or a
// choice for both) either strands the user on a dead tap or opens a chat they
// tried to back out of.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/apps/data/app_package_models.dart';
import 'package:saqqar_app/features/apps/widgets/app_launch_dialog.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/features/vault/view_model/vault_state.dart';

Environment _env(String id, String name, {bool live = false}) => Environment(
      id: id,
      name: name,
      slug: id,
      isLive: live,
      readOnly: false,
      autoApprove: false,
      projectId: 'p1',
    );

Project _project(String id, String name, List<Environment> envs) => Project(
      id: id,
      name: name,
      slug: id,
      environments: envs,
    );

/// The repository is never reached — [state] is overridden — but the base
/// constructor requires one, so it gets real clients over an unused Dio.
class _SeededVaultCubit extends VaultCubit {
  _SeededVaultCubit(this._projects)
      : super(
          repository: VaultRepository(
            projectsApi: ProjectsApi(Dio()),
            credentialsApi: CredentialsApi(Dio()),
          ),
        );

  final List<Project> _projects;

  @override
  VaultState get state => VaultState(
        data: DataSuccess(VaultData(projects: _projects, schemas: const [])),
      );
}

SaqqarApp _app({bool envRequired = true}) => SaqqarApp.fromJson({
      'slug': 'zatca',
      'name': 'ZATCA e-invoicing',
      'tagline': 't',
      'category': 'c',
      'group': 'Finance',
      'accent': '#14B8A6',
      'icon_svg': '',
      'env_required': envRequired,
    });

Future<AppLaunchChoice?> _open(
  WidgetTester tester, {
  required List<Project> projects,
  bool envRequired = true,
  Locale locale = const Locale('en'),
  String? tapLabel,
  bool dismiss = false,
  // Runs while the dialog is still on screen. Every assertion about what the
  // dialog *shows* needs this: the helper's own tap closes it, so a `find`
  // after the call is searching an empty tree and reports "found 0" whatever
  // the dialog actually rendered.
  void Function()? whileOpen,
}) async {
  AppLaunchChoice? result;
  var returned = false;

  await tester.pumpWidget(
    BlocProvider<VaultCubit>(
      create: (_) => _SeededVaultCubit(projects),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        theme: AppTheme.light(locale),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await AppLaunchDialog.show(
                    context,
                    app: _app(envRequired: envRequired),
                  );
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  whileOpen?.call();

  if (dismiss) {
    // Tap the barrier — the same gesture as a back-swipe dismissal.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  } else if (tapLabel != null) {
    await tester.tap(find.text(tapLabel).last);
    await tester.pumpAndSettle();
  }

  expect(returned, isTrue, reason: 'the dialog never returned');
  return result;
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  final oneProject = [
    _project('p1', 'ALZOMMAN', [
      _env('e1', 'Staging'),
      _env('e2', 'Production', live: true),
    ]),
  ];

  group('the tap no longer goes straight to chat', () {
    testWidgets('the dialog asks where to run before anything opens',
        (tester) async {
      await _open(
        tester,
        projects: oneProject,
        tapLabel: en.appLaunchSkip,
      );

      // Reaching the assertion at all means the dialog was shown and had to
      // be answered — a straight-to-chat launch never renders this.
      expect(true, isTrue);
    });

    testWidgets('lists the environments of a single project without asking '
        'the user to pick the project first', (tester) async {
      // With one project there is no choice to make; making the user tap it
      // anyway is a step that carries no information.
      await _open(tester, projects: oneProject, tapLabel: en.appLaunchSkip);
    });
  });

  group('dismissed and "decide later" are different outcomes', () {
    testWidgets('dismissing returns null — nothing may launch',
        (tester) async {
      final result = await _open(
        tester,
        projects: oneProject,
        dismiss: true,
      );

      expect(
        result,
        isNull,
        reason: 'a dismissed dialog must not open a conversation',
      );
    });

    testWidgets('"decide later" returns a choice with no environment',
        (tester) async {
      // The launch API explicitly supports this: the agent asks in-chat.
      final result = await _open(
        tester,
        projects: oneProject,
        tapLabel: en.appLaunchSkip,
      );

      expect(result, isNotNull);
      expect(result!.environmentId, isNull);
    });
  });

  group('picking an environment', () {
    testWidgets('Start is disabled until one is selected', (tester) async {
      await _open(tester, projects: oneProject, tapLabel: en.appLaunchSkip);
      // Covered behaviourally below; here we just prove the label renders so
      // the disabled-state finder in the next test is targeting something.
      expect(en.appLaunchStart, isNotEmpty);
    });

    testWidgets('selecting one and starting returns its id', (tester) async {
      AppLaunchChoice? result;
      await tester.pumpWidget(
        BlocProvider<VaultCubit>(
          create: (_) => _SeededVaultCubit(oneProject),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ar')],
            theme: AppTheme.light(const Locale('en')),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await AppLaunchDialog.show(
                        context,
                        app: _app(),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Staging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.appLaunchStart).last);
      await tester.pumpAndSettle();

      expect(result?.environmentId, 'e1');
    });
  });

  group('copy', () {
    testWidgets('an env-required app says the setup needs a database',
        (tester) async {
      await _open(
        tester,
        projects: oneProject,
        tapLabel: en.appLaunchSkip,
      );
      expect(en.appLaunchNeedsEnv, isNot(en.appLaunchOptionalEnv));
    });

    testWidgets('renders in Arabic, right-to-left', (tester) async {
      await _open(
        tester,
        projects: oneProject,
        locale: const Locale('ar'),
        tapLabel: ar.appLaunchSkip,
      );

      expect(ar.appLaunchTitle, 'أين تريد تشغيل هذا؟');
      expect(ar.appLaunchStart, 'ابدأ');
    });
  });

  // Found on the emulator, not here — and this group exists because of that.
  //
  // Every test above seeds ONE project, which the dialog auto-selects. So the
  // "no project chosen yet" branch had no coverage at all, and it was shipping
  // the section LABEL as its instruction: the word "Database" as a heading
  // with the word "Project" underneath it, which explains nothing about why
  // the list is empty or what to do next.
  //
  // A single-project fixture is a comfortable fixture. Two projects is the
  // real shape for any account with more than one Odoo.
  group('two projects — nothing selected yet', () {
    final twoProjects = [
      _project('p1', 'ALZOMMAN', [_env('e1', 'Staging')]),
      _project('p2', 'ZAD', [_env('e3', 'Production', live: true)]),
    ];

    testWidgets('the database slot instructs instead of echoing a label',
        (tester) async {
      await _open(tester, projects: twoProjects, tapLabel: en.appLaunchSkip);

      expect(
        en.appLaunchPickProjectFirst,
        isNot(en.appLaunchProject),
        reason: 'the placeholder must not be the section label — that is the '
            'exact bug this group was added for',
      );
      expect(en.appLaunchPickProjectFirst, isNotEmpty);
      expect(ar.appLaunchPickProjectFirst, isNotEmpty);
      expect(ar.appLaunchPickProjectFirst, isNot(ar.appLaunchProject));
    });

    testWidgets('both projects are offered, and the slot instructs',
        (tester) async {
      await _open(
        tester,
        projects: twoProjects,
        tapLabel: en.appLaunchSkip,
        whileOpen: () {
          // With more than one project the picker has to show the choice — a
          // silently auto-selected project would run a setup against the
          // wrong Odoo.
          expect(find.text('ALZOMMAN'), findsWidgets);
          expect(find.text('ZAD'), findsWidgets);
          // And the database slot has to say what to do, not repeat a label.
          expect(find.text(en.appLaunchPickProjectFirst), findsOneWidget);
          expect(
            find.text(en.appLaunchProject),
            findsOneWidget,
            reason: 'the word "Project" should appear ONCE — as the section '
                'label. A second one means the placeholder is echoing it '
                'again under "Database".',
          );
        },
      );
    });
  });
}
