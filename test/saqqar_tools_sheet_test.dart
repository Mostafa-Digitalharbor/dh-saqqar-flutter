// docs/WEB_UI_PARITY_GAPS.md §1 (+ §6 / §7 / §8) — the composer's ＋ menu.
//
// The sheet mirrors the web's `renderShadowMenu`: Upload file at the top,
// then Modes / Odoo tools / Connections. Two rules carry the weight:
//
//   * **Feature-gated rows.** An off/absent flag omits the row. `ChatFeatures`
//     defaults differ per row on purpose (see its doc), and this file pins
//     both directions so a future "just default everything to true" makes a
//     test fail rather than putting a dead row in front of a user.
//   * **Toggles flip in place**, actions pop. Otherwise setting Task prep
//     would close the menu you opened to then pick an action from.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/chat/data/chat_features.dart';
import 'package:saqqar_app/features/chat/widgets/saqqar_tools_sheet.dart';

PlanSnapshot _plan({Map<String, dynamic> features = const {}}) =>
    PlanSnapshot.fromJson({
      'plan': 'pro',
      'plan_name': 'Pro',
      'features': features,
    });

/// Builds the gate from a `saqqar_features` object — the bag the tools rows
/// actually read. Passing `null` models the pre-fetch state.
ChatFeatures _features([Map<String, dynamic>? saqqar]) =>
    ChatFeatures(_plan(), SaqqarFeatures.fromJson(saqqar));

/// Every §6/§8 row switched on, for the tests that care about layout rather
/// than gating.
ChatFeatures get _allOn => _features(const {
      'health_radar': true,
      'what_if': true,
      'business_pulse': true,
      'voice_support': true,
    });

/// Opens the sheet and returns everything the caller observed.
Future<
    ({
      SaqqarTool? picked,
      List<bool> taskPrepFlips,
      List<bool> autoApproveFlips,
    })> _open(
  WidgetTester tester, {
  required ChatFeatures features,
  Locale locale = const Locale('en'),
  bool taskPrep = false,
  bool autoApprove = false,
  String? tapLabel,
}) async {
  SaqqarTool? picked;
  final taskPrepFlips = <bool>[];
  final autoApproveFlips = <bool>[];

  await tester.pumpWidget(
    MaterialApp(
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
                picked = await SaqqarToolsSheet.show(
                  context,
                  features: features,
                  taskPrep: taskPrep,
                  autoApprove: autoApprove,
                  onTaskPrepChanged: taskPrepFlips.add,
                  onAutoApproveChanged: autoApproveFlips.add,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  if (tapLabel != null) {
    // The sheet scrolls: on a 600 px-tall test viewport the Connections rows
    // sit below the fold, and a tap there would silently miss.
    await tester.ensureVisible(find.text(tapLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tapLabel));
    await tester.pumpAndSettle();
  }

  return (
    picked: picked,
    taskPrepFlips: taskPrepFlips,
    autoApproveFlips: autoApproveFlips,
  );
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('sections', () {
    testWidgets('lists upload, the modes, and the connection targets',
        (tester) async {
      await _open(tester, features: _features());

      expect(find.text(en.toolsTitle), findsOneWidget);
      expect(find.text(en.toolsUploadFile), findsOneWidget);
      expect(find.text(en.toolsModesSection), findsOneWidget);
      expect(find.text(en.toolsConnectSection), findsOneWidget);
      expect(find.text(en.taskPrep), findsOneWidget);
      expect(find.text(en.autoApprove), findsOneWidget);
      expect(find.text(en.toolsMyDatabase), findsOneWidget);
      expect(find.text(en.appsTitle), findsOneWidget);
      expect(find.text(en.credentialVault), findsOneWidget);
    });

    testWidgets('carries the read-only footer note', (tester) async {
      await _open(tester, features: _features());

      expect(find.text(en.toolsReadonlyNote), findsOneWidget);
      expect(
        en.toolsReadonlyNote,
        'Tools do not change Odoo without your approval.',
        reason: 'exact string handed over by the web team',
      );
    });
  });

  group('§6 — the Odoo tool rows', () {
    testWidgets('all three show when the server switched them on',
        (tester) async {
      await _open(tester, features: _allOn);

      expect(find.text(en.toolsOdooSection), findsOneWidget);
      expect(find.text(en.toolsHealthRadar), findsOneWidget);
      expect(find.text(en.toolsWhatIf), findsOneWidget);
      expect(find.text(en.toolsBusinessPulse), findsOneWidget);
    });

    testWidgets('each pops its own tool', (tester) async {
      for (final (label, expected) in [
        (en.toolsHealthRadar, SaqqarTool.healthRadar),
        (en.toolsWhatIf, SaqqarTool.whatIf),
        (en.toolsBusinessPulse, SaqqarTool.businessPulse),
      ]) {
        final result = await _open(tester, features: _allOn, tapLabel: label);
        expect(result.picked, expected, reason: '"$label" row');
      }
    });

    testWidgets('an explicit false hides just that row', (tester) async {
      await _open(
        tester,
        features: _features(const {
          'health_radar': false,
          'what_if': true,
          'business_pulse': true,
        }),
      );

      expect(find.text(en.toolsHealthRadar), findsNothing);
      expect(find.text(en.toolsWhatIf), findsOneWidget);
      expect(find.text(en.toolsBusinessPulse), findsOneWidget);
    });

    testWidgets('before any /usage/ fetch, none of the three show',
        (tester) async {
      // The cold-start state. These rows are STRICT: they call endpoints the
      // server refuses when the flag is off, and the backend reports all
      // three off for a normal account today.
      await _open(tester, features: _features());

      expect(find.text(en.toolsHealthRadar), findsNothing);
      expect(find.text(en.toolsWhatIf), findsNothing);
      expect(find.text(en.toolsBusinessPulse), findsNothing);
      // The section survives because Commands is ungated (mobile-only row).
      expect(find.text(en.toolsOdooSection), findsOneWidget);
      expect(find.text(en.commands), findsOneWidget);
    });
  });

  group('feature gating', () {
    testWidgets('prompt bank shows by default', (tester) async {
      // Client-side only (the app's own starter prompts), so there is no
      // server call to be refused.
      await _open(tester, features: _features());

      expect(find.text(en.toolsPromptBank), findsOneWidget);
    });

    testWidgets('prompt bank hides on an explicit false', (tester) async {
      await _open(
        tester,
        features: _features(const {'prompt_bank': false}),
      );

      expect(find.text(en.toolsPromptBank), findsNothing);
    });

    testWidgets('voice support is hidden until the server enables it',
        (tester) async {
      await _open(tester, features: _features());

      expect(find.text(en.toolsVoiceSupport), findsNothing);
    });

    testWidgets('voice support shows on an explicit true', (tester) async {
      await _open(tester, features: _features(const {'voice_support': true}));

      expect(find.text(en.toolsVoiceSupport), findsOneWidget);
    });

    testWidgets('the voice support row pops its own tool', (tester) async {
      final result = await _open(
        tester,
        features: _features(const {'voice_support': true}),
        tapLabel: en.toolsVoiceSupport,
      );

      expect(result.picked, SaqqarTool.voiceSupport);
    });

    testWidgets('an explicit task_prep:false drops the mode row',
        (tester) async {
      // The wire key is `task_prep`. Reading `task_prep_available` — the
      // HTML-context name — would leave this row permanently visible.
      await _open(tester, features: _features(const {'task_prep': false}));

      expect(find.text(en.taskPrep), findsNothing);
      // The section survives because auto-approve is still in it.
      expect(find.text(en.toolsModesSection), findsOneWidget);
      expect(find.text(en.autoApprove), findsOneWidget);
    });

    testWidgets('the HTML-context key name does NOT gate the row',
        (tester) async {
      await _open(
        tester,
        features: _features(const {'task_prep_available': false}),
      );

      expect(
        find.text(en.taskPrep),
        findsOneWidget,
        reason: 'task_prep_available is not the wire key; it must be ignored',
      );
    });
  });

  group('interaction', () {
    testWidgets('an action row pops with its tool', (tester) async {
      for (final (label, expected) in [
        (en.toolsUploadFile, SaqqarTool.uploadFile),
        (en.commands, SaqqarTool.commands),
        (en.toolsMyDatabase, SaqqarTool.myDatabase),
        (en.appsTitle, SaqqarTool.apps),
        (en.credentialVault, SaqqarTool.credentialVault),
      ]) {
        final result = await _open(
          tester,
          features: _features(),
          tapLabel: label,
        );
        expect(result.picked, expected, reason: '"$label" row');
      }
    });

    testWidgets('a toggle reports its value WITHOUT closing the sheet',
        (tester) async {
      final result = await _open(
        tester,
        features: _features(),
        tapLabel: en.taskPrep,
      );

      expect(result.taskPrepFlips, [true]);
      expect(result.picked, isNull);
      // Still open — the user can now pick an action in the same visit.
      expect(find.text(en.toolsTitle), findsOneWidget);
    });

    testWidgets('auto-approve flips through the same path', (tester) async {
      final result = await _open(
        tester,
        features: _features(),
        autoApprove: true,
        tapLabel: en.autoApprove,
      );

      expect(result.autoApproveFlips, [false]);
    });
  });

  testWidgets('renders the exact Arabic section titles', (tester) async {
    await _open(
      tester,
      features: _features(),
      locale: const Locale('ar'),
    );

    expect(ar.toolsTitle, 'أدوات صقار');
    expect(ar.toolsModesSection, 'أوضاع التشغيل');
    expect(ar.toolsConnectSection, 'الربط والتكاملات');
    expect(find.text(ar.toolsTitle), findsOneWidget);
    expect(find.text(ar.toolsUploadFile), findsOneWidget);
    expect(
      find.text(ar.toolsReadonlyNote),
      findsOneWidget,
      reason: 'the footer must be translated, not fall back to English',
    );
  });
}
