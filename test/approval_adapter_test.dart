// One approval must read the same wherever it is rendered.
//
// The chat screen and the rail drawer each carried a private
// `_adaptApiApproval` over the same `Approval` type, feeding the same
// `ChatApprovalCard`. They had drifted on the field that matters most:
//
//   inline card:  "Create 6 × Manufacturing Order"
//   rail drawer:  "Odoo write"
//
// Same approval, same data, two different sentences — on the screen whose
// entire job is telling the user what they are about to let the agent do to
// their Odoo. The risk table was duplicated verbatim too, so a new action
// type added to one copy would have been rated differently on each surface.
//
// `approval_adapter.dart` is now the single implementation. These tests pin
// the behaviour the merged version has to keep — and, first, that the merge
// resolved in favour of the informative title rather than the generic one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/chat/data/approval_adapter.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';

final _en = AppStrings(const Locale('en'));
final _ar = AppStrings(const Locale('ar'));

Approval _approval({
  ApprovalActionType type = ApprovalActionType.odooWrite,
  ApprovalStatus status = ApprovalStatus.pending,
  Map<String, dynamic> payload = const {},
  String? modelEn,
  String? modelAr,
  int? recordCount,
  String? confirmPhrase,
  bool batchScoped = false,
}) =>
    Approval(
      id: 'a1',
      actionType: type,
      status: status,
      prompt: 'The agent wants to do a thing.',
      payload: payload,
      modelLabelEn: modelEn,
      modelLabelAr: modelAr,
      recordCount: recordCount,
      confirmPhrase: confirmPhrase,
      batchScoped: batchScoped,
    );

void main() {
  group('the title says what will actually happen', () {
    test('a model-labelled approval names the model and the count', () {
      final a = _approval(
        modelEn: 'Manufacturing Order',
        recordCount: 6,
        payload: const {'operation': 'create'},
      );

      final title = adaptApiApproval(a, _en).title;

      expect(title, contains('Manufacturing Order'));
      expect(title, contains('6'));
      expect(
        title,
        isNot(_en.approvalActionTitle(a.actionType.wire)),
        reason: 'this is the generic title the drawer used to show — the '
            'merge had to resolve the other way',
      );
    });

    test('and does so in Arabic on an Arabic phone', () {
      final a = _approval(
        modelEn: 'Manufacturing Order',
        modelAr: 'أمر التصنيع',
        recordCount: 6,
        payload: const {'operation': 'create'},
      );

      expect(adaptApiApproval(a, _ar).title, contains('أمر التصنيع'));
    });

    test('an approval with no model label still gets a name', () {
      // Never blank: an unnamed approval is one the user cannot judge.
      final a = _approval();

      expect(adaptApiApproval(a, _en).title, isNotEmpty);
      expect(
        adaptApiApproval(a, _en).title,
        _en.approvalActionTitle(a.actionType.wire),
      );
    });

    test('an empty model label counts as no label, not as a blank name', () {
      final a = _approval(modelEn: '', modelAr: '');

      expect(adaptApiApproval(a, _en).title, isNotEmpty);
    });
  });

  group('the risk table', () {
    test('reads are low, credentials are medium', () {
      expect(approvalRisk(ApprovalActionType.reportExport), 'low');
      expect(approvalRisk(ApprovalActionType.credentialStorage), 'medium');
      expect(approvalRisk(ApprovalActionType.credentialUsage), 'medium');
    });

    test('everything else is high — the safe direction to be wrong in', () {
      // Over-warning about a harmless action costs a glance; under-warning
      // about a write costs data. A new action type inherits `high`.
      for (final t in ApprovalActionType.values) {
        if (t == ApprovalActionType.reportExport ||
            t == ApprovalActionType.credentialStorage ||
            t == ApprovalActionType.credentialUsage) {
          continue;
        }
        expect(approvalRisk(t), 'high', reason: t.name);
      }
    });

    test('the adapter carries the same band onto the card', () {
      expect(
        adaptApiApproval(
          _approval(type: ApprovalActionType.reportExport),
          _en,
        ).risk,
        'low',
      );
    });
  });

  group('payload rendering', () {
    test('null fields are dropped, never stringified', () {
      // `value.toString()` on a null yields the literal "null", which is a
      // non-empty string — so every optional field the server left empty
      // rendered as a real value ("Cc: null", "Bcc: null", a Reply badge on
      // every mail).
      final a = _approval(payload: const {
        'to': 'ops@acme.com',
        'cc': null,
        'bcc': null,
      });

      final payload = adaptApiApproval(a, _en).payload;

      expect(payload.keys, ['to']);
      expect(payload.values, isNot(contains('null')));
    });

    test('non-string values are stringified rather than dropped', () {
      final a = _approval(payload: const {'limit': 50, 'dry_run': false});

      final payload = adaptApiApproval(a, _en).payload;

      expect(payload['limit'], '50');
      expect(payload['dry_run'], 'false');
    });
  });

  group('the destructive-delete gate survives the mapping', () {
    test("the server's confirm phrase reaches the card", () {
      // The type-to-confirm gate lives on the card. Dropping the phrase here
      // would leave a surface accepting only client-built strings.
      final a = _approval(confirmPhrase: 'DELETE 12 ORDERS');

      expect(adaptApiApproval(a, _en).confirmPhrase, 'DELETE 12 ORDERS');
    });

    test('the record list and batch flag come across', () {
      final a = _approval(
        payload: const {
          'records': [
            {'id': 1, 'name': 'MO/0001'},
            {'id': 2, 'name': ''},
          ],
        },
        batchScoped: true,
        recordCount: 2,
      );

      final card = adaptApiApproval(a, _en);

      expect(card.deleteRecords, ['MO/0001', '#2']);
      expect(card.batchScoped, isTrue);
      expect(card.recordCount, 2);
    });
  });

  group('status mapping', () {
    test('every server status has a card status', () {
      const expected = {
        ApprovalStatus.pending: ChatApprovalStatus.pending,
        ApprovalStatus.approved: ChatApprovalStatus.approved,
        ApprovalStatus.rejected: ChatApprovalStatus.rejected,
      };

      for (final entry in expected.entries) {
        expect(
          adaptApiApproval(_approval(status: entry.key), _en).status,
          entry.value,
          reason: entry.key.name,
        );
      }
      expect(expected.keys, hasLength(ApprovalStatus.values.length));
    });
  });

  group('both surfaces get the identical object', () {
    test('one approval maps to one result, whoever asks', () {
      // The regression itself: the drawer and the inline card now call the
      // same function with the same arguments, so there is no second
      // implementation left to drift.
      final a = _approval(
        modelEn: 'Sales Order',
        recordCount: 3,
        payload: const {'operation': 'write'},
        confirmPhrase: 'YES',
      );

      final fromChat = adaptApiApproval(a, _en);
      final fromDrawer = adaptApiApproval(a, _en);

      expect(fromChat.title, fromDrawer.title);
      expect(fromChat.risk, fromDrawer.risk);
      expect(fromChat.confirmPhrase, fromDrawer.confirmPhrase);
      expect(fromChat.payload, fromDrawer.payload);
    });
  });
}
