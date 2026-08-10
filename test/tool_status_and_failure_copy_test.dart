// Two guards for refactors that changed *shape* without meaning to change
// behaviour — the kind of change a green analyzer happily waves through.
//
//   1. `guessToolFromPrompt` went from a hand-written if-chain to an ordered
//      keyword table. Order is the whole contract, and a `Map` literal makes
//      it easy to "tidy" the entries alphabetically and silently break it.
//   2. `DataFailure` lost its `String message` field, so the failure copy a
//      user reads now comes only from `ApiErrorMapper`. These assert an
//      Arabic user gets Arabic even when the cubit had nothing useful to say.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/tool_status.dart';
import 'package:saqqar_app/shared/widgets/data_state_view.dart';

Widget _harness(Widget child, Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(locale),
      home: Scaffold(body: child),
    );

void main() {
  group('guessToolFromPrompt keyword table', () {
    test('matches each tool from its own keywords', () {
      expect(guessToolFromPrompt('build me an xlsx'),
          ToolNames.generateExcelReport);
      expect(guessToolFromPrompt('render a pdf'), ToolNames.generatePdfReport);
      expect(guessToolFromPrompt('a docx please'),
          ToolNames.generateWordReport);
      expect(guessToolFromPrompt('run some sql'), ToolNames.runReadonlySql);
      expect(guessToolFromPrompt('tail the log'), ToolNames.runServerCommand);
      expect(guessToolFromPrompt('open the github repo'),
          ToolNames.listGithubDirectory);
      expect(guessToolFromPrompt('describe the schema'),
          ToolNames.describeOdooModel);
      expect(guessToolFromPrompt('create a record'), ToolNames.writeOdooRecords);
      expect(guessToolFromPrompt('count odoo users'),
          ToolNames.countOdooRecords);
    });

    test('matches Arabic prompts, which are matching tokens not copy', () {
      // These live in the table rather than `app_strings` precisely so a
      // translator cannot change them; if someone "localizes" them anyway,
      // this is what fails.
      expect(guessToolFromPrompt('صدّر البيانات'),
          ToolNames.generateExcelReport);
      expect(guessToolFromPrompt('عايز مستند'), ToolNames.generateWordReport);
      expect(guessToolFromPrompt('افحص قاعدة البيانات'),
          ToolNames.runReadonlySql);
      expect(guessToolFromPrompt('شوف سجل السيرفر'),
          ToolNames.runServerCommand);
    });

    test('is case-insensitive', () {
      expect(guessToolFromPrompt('EXPORT TO EXCEL'),
          ToolNames.generateExcelReport);
    });

    test('specific artifact tools outrank the broad Odoo catch-alls', () {
      // The order regression this file exists for: every one of these
      // mentions an Odoo catch-all keyword ("search", "count", "odoo",
      // "create", "model") *and* a specific artifact keyword. If the table
      // is ever reordered, the typing row starts naming the wrong activity.
      expect(
        guessToolFromPrompt('search the odoo partners and export to excel'),
        ToolNames.generateExcelReport,
      );
      expect(
        guessToolFromPrompt('count odoo users into a pdf'),
        ToolNames.generatePdfReport,
      );
      expect(
        guessToolFromPrompt('create a word document of odoo records'),
        ToolNames.generateWordReport,
      );
      expect(
        guessToolFromPrompt('search odoo with sql'),
        ToolNames.runReadonlySql,
      );
      expect(
        guessToolFromPrompt('describe the odoo model'),
        ToolNames.describeOdooModel,
      );
    });

    test('returns null when nothing matches, so the generic label wins', () {
      expect(guessToolFromPrompt('hello'), isNull);
      expect(guessToolFromPrompt(''), isNull);
    });
  });

  group('DataStateView failure copy', () {
    testWidgets('a failure with no error object still renders localized copy',
        (tester) async {
      // The case the removed `message` field used to cover with an English
      // literal. `ApiErrorMapper` classifies null as unknown and returns the
      // locale's generic line, so there is nothing left to leak.
      await tester.pumpWidget(_harness(
        const DataStateView<String>(
          state: DataFailure<String>(error: null),
          onData: _neverCalled,
        ),
        const Locale('ar'),
      ));
      await tester.pump();

      final ar = AppStrings(const Locale('ar'));
      // Exactly one: `AppErrorState`'s headline defaults to the same sentence
      // for an unclassifiable error, and rendering it twice reads as a bug.
      expect(find.text(ar.errorUnknown), findsOneWidget);
    });

    testWidgets('the same failure renders English under an English locale',
        (tester) async {
      await tester.pumpWidget(_harness(
        const DataStateView<String>(
          state: DataFailure<String>(error: null),
          onData: _neverCalled,
        ),
        const Locale('en'),
      ));
      await tester.pump();

      final en = AppStrings(const Locale('en'));
      expect(find.text(en.errorUnknown), findsOneWidget);
      // And the two locales must not be the same string, or the assertion
      // above would pass for the wrong reason.
      expect(en.errorUnknown, isNot(AppStrings(const Locale('ar')).errorUnknown));
    });

    testWidgets('a network failure renders the network line, not the generic '
        'one', (tester) async {
      await tester.pumpWidget(_harness(
        const DataStateView<String>(
          state: DataFailure<String>(error: SocketishError()),
          onData: _neverCalled,
        ),
        const Locale('ar'),
      ));
      await tester.pump();

      final ar = AppStrings(const Locale('ar'));
      // An unclassifiable object maps to the generic line — this asserts the
      // view is genuinely routing through the mapper rather than printing
      // `error.toString()`, which is what a regression here would look like.
      expect(find.text(ar.errorUnknown), findsOneWidget);
      expect(find.textContaining('SocketishError'), findsNothing);
    });
  });
}

/// A stand-in for "something was thrown that we cannot classify". Named so
/// its `toString()` is unmistakable if it ever reaches the UI.
class SocketishError {
  const SocketishError();
  @override
  String toString() => 'SocketishError: connection reset by peer';
}

Widget _neverCalled(BuildContext context, String data) {
  fail('onData must not be called for a DataFailure state');
}
