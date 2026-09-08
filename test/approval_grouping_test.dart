// A burst of same-shape approvals collapses into one card — the web's
// `groupApprovalsByShape` / `renderGroupedApprovalCard` pair, ported.
//
// The app used to render one full card per approval, so the agent writing six
// manufacturing orders cost six scrolls and twelve taps, and rejecting the run
// together was not possible at all even though the API has always accepted
// `scope: "batch"` on a reject.
//
// The thing these tests are really guarding is the *source of the count*. An
// earlier attempt read the group size from a `grouped_count` wire field that
// does not exist and was deleted for it (commit a4a5cdb). "6" here is counted
// from the pending list the client already holds — which is exactly where the
// web counts it — so no server field is involved and none is needed.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/approval_grouping.dart';
import 'package:saqqar_app/features/chat/widgets/chat_grouped_approval_card.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart'
    show Approval, ApprovalActionType, ApprovalStatus, kDeleteOperation;

Approval _a(
  String id, {
  String operation = 'create',
  String model = 'mrp.production',
  ApprovalActionType actionType = ApprovalActionType.odooWrite,
  bool batchScoped = false,
  String prompt = 'Saqqar wants to create a manufacturing order.',
}) =>
    Approval(
      id: id,
      actionType: actionType,
      status: ApprovalStatus.pending,
      prompt: prompt,
      payload: {'operation': operation, 'model': model},
      batchScoped: batchScoped,
    );

Future<Map<String, List<String>>> _pumpGroup(
  WidgetTester tester,
  ApprovalGroup group, {
  Locale locale = const Locale('en'),
}) async {
  final calls = <String, List<String>>{
    'approveAll': [],
    'rejectAll': [],
    'approveOne': [],
    'rejectOne': [],
  };
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
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatGroupedApprovalCard(
            group: group,
            subtitle: group.first.prompt,
            promptOf: (a) => 'row ${a.id}',
            onApproveAll: (a) => calls['approveAll']!.add(a.id),
            onRejectAll: (a) => calls['rejectAll']!.add(a.id),
            onApproveOne: (a) => calls['approveOne']!.add(a.id),
            onRejectOne: (a) => calls['rejectOne']!.add(a.id),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('grouping the pending list', () {
    test('siblings of one shape become a single group', () {
      final groups = groupApprovalsByShape(
        [for (var i = 0; i < 6; i++) _a('a$i')],
      );

      expect(groups, hasLength(1));
      expect(groups.single.isGroup, isTrue);
      expect(groups.single.count, 6);
      expect(groups.single.key, 'odoo_write|create|mrp.production');
    });

    test('a different model is a different card', () {
      final groups = groupApprovalsByShape([
        _a('a1'),
        _a('a2'),
        _a('b1', model: 'sale.order'),
        _a('b2', model: 'sale.order'),
      ]);

      expect(groups, hasLength(2));
      expect(groups.map((g) => g.count), [2, 2]);
    });

    test('a different operation on the same model is a different card', () {
      final groups = groupApprovalsByShape([
        _a('a1'),
        _a('b1', operation: 'write'),
      ]);

      // Two shapes, one member each — so two ordinary single cards.
      expect(groups, hasLength(2));
      expect(groups.every((g) => g.isGroup), isFalse);
    });

    test('a lone approval is not dressed up as a group of one', () {
      // "1 similar request" is a worse card than the request itself.
      final groups = groupApprovalsByShape([_a('a1')]);

      expect(groups.single.isGroup, isFalse);
      expect(groups.single.key, isNull);
    });

    test('order follows first appearance, not group size', () {
      // A card the user is reading must not be reordered under their thumb
      // when a new approval lands on the next poll tick.
      final groups = groupApprovalsByShape([
        _a('solo', model: 'account.move', operation: 'write'),
        _a('big1'),
        _a('big2'),
        _a('big3'),
      ]);

      expect(groups.map((g) => g.first.id), ['solo', 'big1']);
    });

    test('deletes are never grouped', () {
      // The server 400s on a batched delete, and a batch delete is the one
      // mistake with no undo — each keeps its own card, record list and red
      // button.
      final groups = groupApprovalsByShape([
        for (var i = 0; i < 4; i++) _a('d$i', operation: kDeleteOperation),
      ]);

      expect(groups, hasLength(4));
      expect(groups.every((g) => g.isGroup), isFalse);
    });

    test('non-Odoo approvals are never grouped', () {
      // One tap that pre-approves future server commands is an escalation the
      // user did not ask for.
      for (final type in [
        ApprovalActionType.serverCommand,
        ApprovalActionType.credentialStorage,
        ApprovalActionType.credentialUsage,
        ApprovalActionType.sendEmail,
      ]) {
        final groups = groupApprovalsByShape([
          _a('x1', actionType: type),
          _a('x2', actionType: type),
        ]);
        expect(groups, hasLength(2), reason: type.wire);
      }
    });

    test('an already batch-scoped approval stays on its own', () {
      final groups = groupApprovalsByShape([
        _a('s1', batchScoped: true),
        _a('s2', batchScoped: true),
      ]);

      expect(groups.every((g) => g.isGroup), isFalse);
    });

    test('an approval with no model on the payload stays on its own', () {
      // The shape key needs both halves; without a model there is nothing to
      // say two requests are the same.
      const noModel = Approval(
        id: 'n1',
        actionType: ApprovalActionType.odooWrite,
        status: ApprovalStatus.pending,
        prompt: 'p',
        payload: {'operation': 'create'},
      );

      expect(groupApprovalsByShape([noModel, noModel]), hasLength(2));
    });

    test('an empty list groups into nothing', () {
      expect(groupApprovalsByShape(const []), isEmpty);
    });

    test('every approval survives grouping exactly once', () {
      // The collapse is a summary, never a filter: a card that silently
      // dropped an approval would leave a write pending with nothing on
      // screen to decide it.
      final pending = [
        _a('a1'), _a('a2'),
        _a('b1', model: 'sale.order'),
        _a('d1', operation: kDeleteOperation),
        _a('c1', actionType: ApprovalActionType.serverCommand),
      ];

      final flattened = [
        for (final g in groupApprovalsByShape(pending))
          for (final a in g.approvals) a.id,
      ];

      expect(flattened, pending.map((a) => a.id).toList());
    });
  });

  group('the grouped card', () {
    ApprovalGroup sixCreates() =>
        groupApprovalsByShape([for (var i = 0; i < 6; i++) _a('a$i')]).single;

    testWidgets('states the count it is deciding for', (tester) async {
      await _pumpGroup(tester, sixCreates());

      expect(find.text(en.similarRequestsCount(6)), findsOneWidget);
      expect(find.text(en.approveAllN(6)), findsOneWidget);
      expect(find.text(en.rejectAllN(6)), findsOneWidget);
    });

    testWidgets('both headline buttons fire once, on the first sibling',
        (tester) async {
      // One call, not six: the server resolves the run from `scope: "batch"`,
      // so the card must not fan out N requests and hope they all land.
      var calls = await _pumpGroup(tester, sixCreates());
      await tester.tap(find.text(en.approveAllN(6)));
      expect(calls['approveAll'], ['a0']);

      calls = await _pumpGroup(tester, sixCreates());
      await tester.tap(find.text(en.rejectAllN(6)));
      expect(calls['rejectAll'], ['a0']);
    });

    testWidgets('the batch disclosure travels with the buttons',
        (tester) async {
      // Approving a group also pre-approves future writes of this shape —
      // strictly more than the user asked for, so it has to be said.
      await _pumpGroup(tester, sixCreates());

      expect(find.text(en.preApprovalTip), findsOneWidget);
    });

    testWidgets('nothing is hidden — every request is one tap away',
        (tester) async {
      final calls = await _pumpGroup(tester, sixCreates());

      expect(find.text('row a3'), findsNothing);
      await tester.tap(find.text(en.showIndividual));
      await tester.pumpAndSettle();

      for (var i = 0; i < 6; i++) {
        expect(find.text('row a$i'), findsOneWidget);
      }
      expect(find.text(en.hideIndividual), findsOneWidget);

      // A user who wants to let five of six through still can — the rows are
      // in payload order, so the third Approve is a2's.
      expect(find.text(en.approve), findsNWidgets(6));
      await tester.tap(find.text(en.approve).at(2));
      expect(calls['approveOne'], ['a2']);
    });

    testWidgets('collapsing hides the rows again', (tester) async {
      await _pumpGroup(tester, sixCreates());

      await tester.tap(find.text(en.showIndividual));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.hideIndividual));
      await tester.pumpAndSettle();

      expect(find.text('row a0'), findsNothing);
      expect(find.text(en.showIndividual), findsOneWidget);
    });

    testWidgets('the count on the buttons is never ellipsised away',
        (tester) async {
      // Caught on a real device: "وافق على الكل (3)" rendered as "وافق على
      // الكل (…)" — the count clipped off the end of the button, which is the
      // one word on it that says what the tap does. Both labels are checked
      // in both languages at the narrowest supported width, because the
      // Arabic label is the longer of the two and the buttons split the row.
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        final tr = AppStrings(locale);
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pumpGroup(tester, sixCreates(), locale: locale);

        for (final label in [tr.approveAllN(6), tr.rejectAllN(6)]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '"$label" is clipped at 320 px',
          );
        }
      }
    });

    testWidgets('reads as Arabic under an Arabic locale', (tester) async {
      await _pumpGroup(tester, sixCreates(), locale: const Locale('ar'));

      expect(find.text(ar.similarRequestsCount(6)), findsOneWidget);
      expect(find.text(ar.approveAllN(6)), findsOneWidget);
      expect(find.text(ar.rejectAllN(6)), findsOneWidget);
      expect(find.text(ar.showIndividual), findsOneWidget);
      // The English strings must not leak through a missing key.
      expect(find.text(en.approveAllN(6)), findsNothing);
    });

    testWidgets('a long prompt does not overflow the card', (tester) async {
      final long = _a('a1', prompt: 'ينشئ صقار أمر تصنيع ' * 40);
      final group = groupApprovalsByShape([long, _a('a2')]).single;

      await tester.pumpWidget(const SizedBox());
      await _pumpGroup(tester, group);

      expect(tester.takeException(), isNull);
    });
  });
}
