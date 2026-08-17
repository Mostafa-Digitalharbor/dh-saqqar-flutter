// Deep regression pass over the 2026-08-06 parity work.
//
// Every group here exists because a defect was FOUND, not because a defect
// was imagined. The existing suites all passed while these were live — which
// is the point: each one lives at a seam BETWEEN two units that were
// individually well tested.
//
//   1. The approval adapter stringified nulls, so `cc: null` became the
//      literal string "null". Every email approval rendered "Cc: null",
//      "Bcc: null", and a Reply badge — on the shape the backend says is
//      normal. `EmailApprovalPreview` was correct; `Approval` was correct;
//      the adapter between them was not.
//   2. "Approve all similar" was offered on `server_command` and
//      `credential_storage` approvals, silently pre-approving future shell
//      commands from one tap.
//   3. A §6 scan showed a Stop button that could not stop it.
//
// Nothing below asserts on the fix's implementation — each one asserts on
// what a user would see.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/widgets/email_approval_preview.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';

/// The payload adapter both approval surfaces use, extracted verbatim so this
/// file tests the real transformation rather than a paraphrase of it.
///
/// If the two copies in `chat_screen.dart` / `chat_rail_drawer.dart` ever
/// diverge from this, the `both surfaces agree` group below fails.
Map<String, String> adaptPayload(Map<String, dynamic> payload) => {
      for (final entry in payload.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };

Approval _approval(Map<String, dynamic> extra) => Approval.fromJson({
      'id': 'ap-1',
      'action_type': 'odoo_write',
      'status': 'pending',
      'prompt': 'p',
      'payload': const <String, dynamic>{},
      ...extra,
    });

DemoApproval _demo({
  required String actionType,
  Map<String, String> payload = const {},
  bool batchScoped = false,
}) =>
    DemoApproval(
      id: 'a1',
      title: 't',
      prompt: 'p',
      actionType: actionType,
      risk: 'high',
      status: DemoApprovalStatus.pending,
      payload: payload,
      batchScoped: batchScoped,
    );

void main() {
  group('a null payload field must read as ABSENT, never as "null"', () {
    // `null.toString()` is "null", a perfectly non-empty String. The backend
    // documents `cc`, `bcc` and `in_reply_to` as nullable, so this was the
    // COMMON path, not an edge case.
    test('the adapter drops nulls instead of stringifying them', () {
      final adapted = adaptPayload({
        'to': 'ops@acme.test',
        'cc': null,
        'bcc': null,
        'subject': 'June statement',
        'body': 'Attached.',
        'in_reply_to': null,
      });

      expect(adapted.containsKey('cc'), isFalse);
      expect(adapted.containsKey('bcc'), isFalse);
      expect(adapted.containsKey('in_reply_to'), isFalse);
      expect(adapted['to'], 'ops@acme.test');
    });

    test('the ordinary email renders no blank Cc/Bcc and no Reply badge', () {
      final preview = EmailApprovalPreview.of(adaptPayload({
        'to': 'ops@acme.test',
        'cc': null,
        'bcc': null,
        'subject': 'June statement',
        'body': 'Attached.',
        'in_reply_to': null,
      }))!;

      expect(preview.cc, isEmpty, reason: 'rendered "Cc: null" before the fix');
      expect(preview.bcc, isEmpty);
      expect(
        preview.isReply,
        isFalse,
        reason: 'every email carried a Reply badge before the fix',
      );
    });

    test('real values still come through', () {
      final preview = EmailApprovalPreview.of(adaptPayload({
        'to': 'ops@acme.test',
        'cc': 'cfo@acme.test',
        'bcc': 'audit@acme.test',
        'subject': 'S',
        'body': 'B',
        'in_reply_to': '<m-1@acme.test>',
      }))!;

      expect(preview.cc, 'cfo@acme.test');
      expect(preview.bcc, 'audit@acme.test');
      expect(preview.isReply, isTrue);
    });

    test('a null never reaches the chip fallback either', () {
      // The non-email path renders the payload as `key: value` chips, where a
      // stringified null reads as a field the agent set to the word "null".
      final adapted = adaptPayload({
        'command': 'ls -la',
        'cwd': null,
        'timeout': 30,
      });

      expect(adapted, {'command': 'ls -la', 'timeout': '30'});
    });

    test('false and 0 are NOT dropped — only null is', () {
      // The tempting over-fix is `if (entry.value != null && ...isNotEmpty)`,
      // which would silently swallow a meaningful `false`.
      final adapted = adaptPayload({
        'dry_run': false,
        'limit': 0,
        'note': '',
      });

      expect(adapted['dry_run'], 'false');
      expect(adapted['limit'], '0');
      expect(adapted['note'], '');
    });
  });

  group('batching is offered only where the backend describes it', () {
    // The doc says the scope registers a shape so future same-shape WRITES
    // auto-approve silently. One tap that pre-approves future shell commands
    // or credential storage is a privilege escalation nobody asked for, and
    // those are the two approvals most worth reading one at a time.
    test('an Odoo write may be batched', () {
      expect(
        _demo(actionType: 'odoo_write', payload: {'operation': 'write'})
            .canBatchApprove,
        isTrue,
      );
    });

    test('a server command may NOT', () {
      expect(
        _demo(actionType: 'server_command', payload: {'command': 'rm -rf /'})
            .canBatchApprove,
        isFalse,
      );
    });

    test('credential storage and usage may NOT', () {
      for (final type in ['credential_storage', 'credential_usage']) {
        expect(
          _demo(actionType: type).canBatchApprove,
          isFalse,
          reason: type,
        );
      }
    });

    test('a report export may NOT', () {
      expect(_demo(actionType: 'report_export').canBatchApprove, isFalse);
    });

    test('an unknown action type may NOT', () {
      // Fail closed: a type the client has never heard of is the last thing
      // that should get a silent pre-approval.
      expect(_demo(actionType: '').canBatchApprove, isFalse);
      expect(_demo(actionType: 'something_new').canBatchApprove, isFalse);
    });

    test('an Odoo DELETE may not, even though it is a write', () {
      expect(
        _demo(
          actionType: 'odoo_write',
          payload: {'operation': kDeleteOperation},
        ).canBatchApprove,
        isFalse,
      );
    });

    test('an already-scoped write may not', () {
      expect(
        _demo(
          actionType: 'odoo_write',
          payload: {'operation': 'write'},
          batchScoped: true,
        ).canBatchApprove,
        isFalse,
      );
    });
  });

  group('destructive-delete detection survives a hostile payload', () {
    test('a missing operation is not a delete', () {
      expect(_demo(actionType: 'odoo_write').canBatchApprove, isTrue);
    });

    test('the delete check reads the SERVER operation, not the title', () {
      // The card's title is agent prose ("Delete 6× Sales Order"). Gating on
      // it would let a rename of the prompt disable the type-to-confirm gate.
      final notADelete = _demo(
        actionType: 'odoo_write',
        payload: {'operation': 'create'},
      );

      expect(notADelete.canBatchApprove, isTrue);
    });
  });

  group('confirm_phrase cannot lock a user out', () {
    test('an empty server phrase falls back rather than gating forever', () {
      // A blank phrase must read as ABSENT so `decide` omits the key. Were
      // it kept as "", the POST would carry an empty confirmation the server
      // rejects — the delete would be permanently un-approvable.
      expect(_approval({'confirm_phrase': ''}).confirmPhrase, isNull);
      expect(_approval({'confirm_phrase': '   '}).confirmPhrase, isNull);
    });

    test('a phrase is trimmed, so trailing whitespace still matches', () {
      expect(_approval({'confirm_phrase': ' delete 3 '}).confirmPhrase,
          'delete 3');
    });
  });

  group('both approval surfaces adapt the payload the same way', () {
    // The adapter is duplicated in `chat_screen.dart` and
    // `chat_rail_drawer.dart` — one-way translation at each widget boundary.
    // Two copies is two places to regress, and the drawer copy is the one
    // nobody looks at. A source assertion is crude but it is the only thing
    // that catches "fixed in one, missed in the other", which is exactly how
    // the null bug would come back.
    const sources = [
      'lib/features/chat/view/chat_screen.dart',
      'lib/features/chat/widgets/chat_rail_drawer.dart',
    ];

    test('neither stringifies a null payload value', () {
      for (final path in sources) {
        // Comment lines are stripped first. The note explaining this very
        // bug quotes the offending expression, and counting it as code makes
        // the guard fail on its own documentation — which is how a test
        // starts getting weakened instead of believed.
        final code = File(path)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');

        final stringifications =
            'entry.value.toString()'.allMatches(code).length;
        final guards = 'if (entry.value != null)'.allMatches(code).length;

        expect(
          stringifications,
          greaterThan(0),
          reason: '$path no longer adapts a payload — retarget this guard',
        );
        expect(
          guards,
          greaterThanOrEqualTo(stringifications),
          reason: '$path stringifies a payload value without a null guard — '
              'that renders the literal "null" to the user',
        );
      }
    });
  });

  group('batch_scope parsing is strict about truthiness', () {
    test('only a real boolean true flags it', () {
      expect(
        _approval({
          'payload': const {'batch_scope': true},
        }).batchScoped,
        isTrue,
      );
      for (final v in ['true', 1, 'yes', null]) {
        expect(
          _approval({
            'payload': {'batch_scope': v},
          }).batchScoped,
          isFalse,
          reason: 'for $v',
        );
      }
    });
  });
}
