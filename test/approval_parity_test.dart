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
import 'package:saqqar_app/features/chat/data/approval_adapter.dart';
import 'package:saqqar_app/features/chat/widgets/chat_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/email_approval_preview.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart'
    show Approval, ApprovalActionType, ApprovalStatus, kDeleteOperation;
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';

ChatApproval _approval({
  required Map<String, String> payload,
  String actionType = 'odoo_write',
  int? recordCount,
  String? confirmPhrase,
  bool batchScoped = false,
}) =>
    ChatApproval(
      id: 'a1',
      title: 'Delete 6× Sales Order',
      prompt: 'Saqqar wants to delete records.',
      actionType: actionType,
      risk: 'high',
      status: ChatApprovalStatus.pending,
      payload: payload,
      recordCount: recordCount,
      confirmPhrase: confirmPhrase,
      batchScoped: batchScoped,
    );

/// The email-approval variant of [_approval] — `action_type` is what
/// `ChatApprovalCard` now gates the rich preview on (Task 4), so every §9
/// fixture must actually be a `send_email` approval, not an `odoo_write` one
/// that merely happens to carry email-shaped keys.
ChatApproval _emailApproval({required Map<String, String> payload}) =>
    _approval(payload: payload, actionType: 'send_email');

Future<List<String>> _pumpCard(
  WidgetTester tester,
  ChatApproval approval, {
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

    test('a payload with no recipient is left on the ordinary chip rendering',
        () {
      // `title` alone is shared by half the approval types — treating those
      // as emails would hide their real payloads behind an email layout.
      // `to` is now the ONLY thing `of()` itself requires (Task 4 loosened
      // subject/body to optional, since they may legitimately be empty) —
      // `ChatApprovalCard` is what actually decides "is this an email" now,
      // off `action_type == 'send_email'`, so this guard only has to reject
      // a payload with nothing to send to at all.
      expect(EmailApprovalPreview.of({'title': 'Something'}), isNull);
      expect(EmailApprovalPreview.of({'command': 'ls -la'}), isNull);
      expect(EmailApprovalPreview.of(const {}), isNull);
    });

    test('subject and body are optional — `to` alone is still an email', () {
      final preview = EmailApprovalPreview.of({'to': 'x@y.z'})!;
      expect(preview.subject, isEmpty);
      expect(preview.body, isEmpty);
    });

    testWidgets('an empty subject and body show placeholders, not blanks',
        (tester) async {
      await _pumpCard(
        tester,
        _emailApproval(payload: {'to': 'ops@acme.test'}),
      );

      expect(find.text(en.emailPreviewEmptySubject), findsOneWidget);
      expect(find.text(en.emailPreviewEmptyBody), findsOneWidget);
    });

    testWidgets('a list-valued `to`/`cc` renders joined, not as [a, b]',
        (tester) async {
      // The tool schema allows `to`/`cc`/`bcc` as either one comma-separated
      // string or a JSON array — `approval_adapter.dart` joins a list before
      // it ever reaches this widget, so this exercises the whole path from
      // the server's `Approval.payload` rather than just the widget's own
      // parsing.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          theme: AppTheme.light(const Locale('en')),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatApprovalCard(
                approval: adaptApiApproval(
                  const Approval(
                    id: 'a1',
                    actionType: ApprovalActionType.sendEmail,
                    status: ApprovalStatus.pending,
                    prompt: 'Send the statement.',
                    payload: {
                      'to': ['ops@acme.test', 'ap@acme.test'],
                    },
                  ),
                  AppStrings(const Locale('en')),
                ),
                onApprove: () {},
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ops@acme.test, ap@acme.test'), findsOneWidget);
      expect(find.textContaining('['), findsNothing);
    });

    testWidgets('renders inside the approval card, in both locales',
        (tester) async {
      for (final (locale, tr) in [
        (const Locale('en'), en),
        (const Locale('ar'), ar),
      ]) {
        await _pumpCard(
          tester,
          _emailApproval(payload: {
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
        _emailApproval(payload: {
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
}
