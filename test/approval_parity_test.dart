// docs/WEB_UI_PARITY_GAPS.md §9 + §10 — the two approval-card gaps.
//
// §10 is the one that matters most. The web makes you TYPE a phrase before a
// delete approval goes through; mobile approved one on a single tap. The doc
// asked whether an English-only phrase was blocking Arabic users — the real
// finding was that there was no phrase at all, so the gate ships here, and it
// accepts Arabic-Indic digits from the first commit: a confirmation an Arabic
// keyboard cannot type is the same bug wearing a different hat.
//
// §9 lays an email approval out as an email instead of as key-value chips.
// Approving "send this" from a chip row means approving a message you never
// read.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/delete_confirmation.dart';
import 'package:saqqar_app/features/chat/widgets/chat_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/email_approval_preview.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';

DemoApproval _approval({
  required Map<String, String> payload,
  int? recordCount,
  String? confirmPhrase,
  bool batchScoped = false,
}) =>
    DemoApproval(
      id: 'a1',
      title: 'Delete 6× Sales Order',
      prompt: 'Saqqar wants to delete records.',
      actionType: 'odoo_write',
      risk: 'high',
      status: DemoApprovalStatus.pending,
      payload: payload,
      recordCount: recordCount,
      confirmPhrase: confirmPhrase,
      batchScoped: batchScoped,
    );

Future<List<String>> _pumpCard(
  WidgetTester tester,
  DemoApproval approval, {
  Locale locale = const Locale('en'),
  bool withBatch = true,
}) async {
  final decisions = <String>[];
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
          child: ChatApprovalCard(
            approval: approval,
            onApprove: () => decisions.add('approve'),
            onReject: () => decisions.add('reject'),
            // Null on surfaces that can't batch (the rail drawer), which is
            // itself worth exercising: the row must vanish, not sit dead.
            onApproveAllSimilar:
                withBatch ? () => decisions.add('batch') : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return decisions;
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('§10 — delete phrase normalisation', () {
    test('folds Arabic-Indic digits to Western ones', () {
      expect(normalizeConfirmation('حذف ٦'), 'حذف 6');
      // Extended / Persian Arabic-Indic digits too.
      expect(normalizeConfirmation('حذف ۱۲'), 'حذف 12');
    });

    test('ignores case and stray whitespace', () {
      expect(normalizeConfirmation('  DELETE   6 '), 'delete 6');
    });

    test('an Arabic keyboard confirms the Arabic phrase', () {
      final accepted = [
        en.deleteConfirmPhrase(6),
        ar.deleteConfirmPhrase(6),
      ];

      expect(ar.deleteConfirmPhrase(6), 'حذف 6');
      expect(confirmsDelete('حذف ٦', accepted), isTrue);
      expect(confirmsDelete('حذف 6', accepted), isTrue);
    });

    test('either locale confirms, whatever the UI language', () {
      final accepted = [
        en.deleteConfirmPhrase(6),
        ar.deleteConfirmPhrase(6),
      ];

      expect(confirmsDelete('Delete 6', accepted), isTrue);
      expect(confirmsDelete('delete 6', accepted), isTrue);
    });

    test('the wrong count or wrong words do NOT confirm', () {
      final accepted = [
        en.deleteConfirmPhrase(6),
        ar.deleteConfirmPhrase(6),
      ];

      expect(confirmsDelete('delete 7', accepted), isFalse);
      expect(confirmsDelete('delete', accepted), isFalse);
      expect(confirmsDelete('', accepted), isFalse);
      expect(confirmsDelete('   ', accepted), isFalse);
      expect(confirmsDelete('yes', accepted), isFalse);
    });
  });

  group('§10 — the gate in front of Approve', () {
    testWidgets('a delete does not approve on the first tap', (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(
          payload: {'operation': kDeleteOperation, 'model': 'sale.order'},
          recordCount: 6,
        ),
      );

      await tester.tap(find.text(en.approve));
      await tester.pumpAndSettle();

      expect(decisions, isEmpty, reason: 'the dialog must intercept it');
      expect(find.text(en.deleteConfirmTitle), findsOneWidget);
    });

    testWidgets('typing the phrase lets it through', (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(
          payload: {'operation': kDeleteOperation},
          recordCount: 6,
        ),
      );

      await tester.tap(find.text(en.approve));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Delete 6');
      await tester.pumpAndSettle();
      // Two "Approve"s on screen now — the card's and the dialog's.
      await tester.tap(find.text(en.approve).last);
      await tester.pumpAndSettle();

      expect(decisions, ['approve']);
    });

    testWidgets('a wrong phrase explains itself rather than silently failing',
        (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(payload: {'operation': kDeleteOperation}, recordCount: 6),
      );

      await tester.tap(find.text(en.approve));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'delete 5');
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.approve).last);
      await tester.pumpAndSettle();

      expect(decisions, isEmpty);
      expect(
        find.text(en.deleteConfirmMismatch(en.deleteConfirmPhrase(6))),
        findsOneWidget,
      );
    });

    testWidgets('cancelling leaves the approval pending', (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(payload: {'operation': kDeleteOperation}, recordCount: 6),
      );

      await tester.tap(find.text(en.approve));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(decisions, isEmpty);
    });

    testWidgets('an Arabic user can complete the flow with ٦', (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(payload: {'operation': kDeleteOperation}, recordCount: 6),
        locale: const Locale('ar'),
      );

      await tester.tap(find.text(ar.approve));
      await tester.pumpAndSettle();
      expect(find.text(ar.deleteConfirmTitle), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'حذف ٦');
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.approve).last);
      await tester.pumpAndSettle();

      expect(
        decisions,
        ['approve'],
        reason: 'the whole point of §10 — an Arabic user must be able to '
            'confirm a delete using the digits their keyboard produces',
      );
    });

    testWidgets('a non-delete write still approves in one tap', (tester) async {
      // The gate is scoped to the irreversible operation. Adding friction to
      // every write would train users to tap through it.
      final decisions = await _pumpCard(
        tester,
        _approval(payload: {'operation': 'write'}, recordCount: 6),
      );

      await tester.tap(find.text(en.approve));
      await tester.pumpAndSettle();

      expect(decisions, ['approve']);
      expect(find.text(en.deleteConfirmTitle), findsNothing);
    });

    testWidgets('rejecting a delete is never gated', (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(payload: {'operation': kDeleteOperation}, recordCount: 6),
      );

      await tester.tap(find.text(en.reject));
      await tester.pumpAndSettle();

      expect(decisions, ['reject']);
    });
  });

  group('§9 — email approval preview', () {
    test('reads an email-shaped payload', () {
      final preview = EmailApprovalPreview.of({
        'to': 'ops@acme.test',
        'subject': 'June statement',
        'body': 'Attached is your statement.',
      })!;

      expect(preview.to, 'ops@acme.test');
      expect(preview.subject, 'June statement');
      expect(preview.body, startsWith('Attached'));
    });

    test('reads all six confirmed keys', () {
      // The exact key set the web team published on 2026-08-06. The guessed
      // aliases this test used to assert (`email_to`, `email_subject`,
      // `body_html`) turned out to be invented, and are gone.
      final preview = EmailApprovalPreview.of({
        'to': 'ops@acme.test, ap@acme.test',
        'cc': 'cfo@acme.test',
        'bcc': 'audit@acme.test',
        'subject': 'June statement',
        'body': 'Attached is your statement.',
        'in_reply_to': '<msg-123@acme.test>',
      })!;

      // Several recipients arrive as ONE comma-separated string and are
      // shown verbatim — splitting them would mean displaying a list the
      // server never sent.
      expect(preview.to, 'ops@acme.test, ap@acme.test');
      expect(preview.cc, 'cfo@acme.test');
      expect(preview.bcc, 'audit@acme.test');
      expect(preview.isReply, isTrue);
    });

    test('the invented aliases no longer resolve', () {
      // Keeping them would be harmless-looking but wrong: `title` in
      // particular is shared by half the approval types, so it made every
      // titled approval a candidate for the email layout.
      expect(
        EmailApprovalPreview.of({
          'email_to': 'ops@acme.test',
          'email_subject': 'June statement',
          'body_html': '<p>Hi</p>',
        }),
        isNull,
      );
    });

    test('in_reply_to is a badge, not a rendered value', () {
      // The value is an opaque Message-ID header. Its PRESENCE changes what
      // the user is approving (a reply into a thread, not a fresh mail), but
      // printing `<msg-123@acme.test>` on the card would be noise.
      final plain = EmailApprovalPreview.of({
        'to': 'a@b.c',
        'subject': 'S',
        'body': 'B',
      })!;
      expect(plain.isReply, isFalse);

      final blank = EmailApprovalPreview.of({
        'to': 'a@b.c',
        'subject': 'S',
        'body': 'B',
        'in_reply_to': '   ',
      })!;
      expect(blank.isReply, isFalse, reason: 'whitespace is not a thread');
    });

    test('bcc survives to the widget — it is the field with no other trace',
        () {
      // BCC is invisible in the sent mail, so the approval card is the only
      // place a user can ever see it. Dropping it would mean approving a
      // send to a recipient they were never shown.
      final preview = EmailApprovalPreview.of({
        'to': 'a@b.c',
        'subject': 'S',
        'body': 'B',
        'bcc': 'silent@third.party',
      })!;

      expect(preview.bcc, 'silent@third.party');
    });

    test('a non-email payload is left on the ordinary chip rendering', () {
      // `title` alone is shared by half the approval types — treating those
      // as emails would hide their real payloads behind an email layout.
      expect(EmailApprovalPreview.of({'title': 'Something'}), isNull);
      expect(EmailApprovalPreview.of({'command': 'ls -la'}), isNull);
      expect(EmailApprovalPreview.of({'to': 'x@y.z'}), isNull);
      expect(EmailApprovalPreview.of(const {}), isNull);
    });

    testWidgets('renders inside the approval card, in both locales',
        (tester) async {
      for (final (locale, tr) in [
        (const Locale('en'), en),
        (const Locale('ar'), ar),
      ]) {
        await _pumpCard(
          tester,
          _approval(payload: {
            'to': 'ops@acme.test',
            'subject': 'June statement',
            'body': 'Attached is your statement.',
          }),
          locale: locale,
        );

        expect(find.text('June statement'), findsOneWidget);
        expect(find.text(tr.emailPreviewTo), findsOneWidget);
        expect(find.text('ops@acme.test'), findsOneWidget);
      }
    });

    testWidgets('bcc and the reply badge render on the card', (tester) async {
      await _pumpCard(
        tester,
        _approval(payload: {
          'to': 'ops@acme.test',
          'bcc': 'silent@third.party',
          'subject': 'June statement',
          'body': 'Attached.',
          'in_reply_to': '<msg-1@acme.test>',
        }),
      );

      expect(find.text(en.emailPreviewBcc), findsOneWidget);
      expect(find.text('silent@third.party'), findsOneWidget);
      expect(find.text(en.emailPreviewReply), findsOneWidget);
      // The Message-ID itself is noise and must not be printed.
      expect(find.text('<msg-1@acme.test>'), findsNothing);
    });
  });

  group('§11 — the card cannot promise a count it does not have', () {
    testWidgets('the primary button is always the singular Approve',
        (tester) async {
      // `grouped_count` does not exist on the wire. "Approve all 6" was a
      // client-invented number, and the real count only comes back in the
      // decision RESPONSE.
      await _pumpCard(tester, _approval(payload: {'operation': 'write'}));

      expect(find.text(en.approve), findsOneWidget);
      expect(find.text(en.approveAllN(6)), findsNothing);
    });

    testWidgets('a writeable approval offers the un-numbered batch action',
        (tester) async {
      final decisions =
          await _pumpCard(tester, _approval(payload: {'operation': 'write'}));

      expect(find.text(en.approveAllSimilar), findsOneWidget);
      // The disclosure has to travel with it: this does strictly more than
      // the user asked, pre-approving future writes of the same shape.
      expect(find.text(en.preApprovalTip), findsOneWidget);

      await tester.tap(find.text(en.approveAllSimilar));
      await tester.pumpAndSettle();
      expect(decisions, ['batch']);
    });

    testWidgets('a DELETE never offers batching', (tester) async {
      // The server 400s on `scope: "batch"` for a destructive delete, so the
      // button could only ever fail — and a batch delete is the one mistake
      // with no undo.
      await _pumpCard(
        tester,
        _approval(payload: {'operation': kDeleteOperation}, recordCount: 6),
      );

      expect(find.text(en.approveAllSimilar), findsNothing);
      expect(find.text(en.preApprovalTip), findsNothing);
    });

    testWidgets('an already batch-scoped approval does not offer it again',
        (tester) async {
      // `payload.batch_scope: true` means a scope the user granted earlier
      // already auto-approved this one. Offering to batch it is offering a
      // no-op.
      await _pumpCard(
        tester,
        _approval(payload: {'operation': 'write'}, batchScoped: true),
      );

      expect(find.text(en.approveAllSimilar), findsNothing);
    });

    testWidgets('a surface without a batch handler hides the row',
        (tester) async {
      await _pumpCard(
        tester,
        _approval(payload: {'operation': 'write'}),
        withBatch: false,
      );

      expect(find.text(en.approveAllSimilar), findsNothing);
      // …but the ordinary decision buttons are untouched.
      expect(find.text(en.approve), findsOneWidget);
      expect(find.text(en.reject), findsOneWidget);
    });
  });

  group('§10 — the server phrase reaches the dialog', () {
    testWidgets('a server phrase is accepted alongside the locale ones',
        (tester) async {
      final decisions = await _pumpCard(
        tester,
        _approval(
          payload: {'operation': kDeleteOperation},
          recordCount: 3,
          confirmPhrase: 'remove 3 rows',
        ),
      );

      await tester.tap(find.text(en.approve));
      await tester.pumpAndSettle();

      // The server's own wording confirms…
      await tester.enterText(find.byType(TextField), 'remove 3 rows');
      await tester.tap(find.text(en.approve).last);
      await tester.pumpAndSettle();

      expect(decisions, ['approve']);
    });

    testWidgets('the locale phrase still works when a server phrase exists',
        (tester) async {
      // Widening, never narrowing: the dialog TELLS the user to type the
      // localized phrase, so that must keep working whatever the server
      // calls it.
      final decisions = await _pumpCard(
        tester,
        _approval(
          payload: {'operation': kDeleteOperation},
          recordCount: 3,
          confirmPhrase: 'remove 3 rows',
        ),
        locale: const Locale('ar'),
      );

      await tester.tap(find.text(ar.approve));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'حذف ٣');
      await tester.tap(find.text(ar.approve).last);
      await tester.pumpAndSettle();

      expect(decisions, ['approve']);
    });
  });
}
