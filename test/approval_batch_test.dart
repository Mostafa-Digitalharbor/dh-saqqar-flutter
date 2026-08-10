// §10 + §11 — the two approval contracts the web team corrected on
// 2026-08-06.
//
// **§11 was wrong in an interesting way.** The card had an "Approve all N"
// button driven by a `grouped_count` field. That field does not exist and
// never did. Grouping IS real, but it works the other way round: you POST
// `scope: "batch"` and the server tells you in the RESPONSE how many sibling
// approvals that cleared. So the count can only be reported AFTER the tap,
// and any label promising a number beforehand was a client-side invention.
//
// **§10 was right**, and this file keeps it that way while adding the server
// phrase: `delete N` with no model name, both locales accepted, Arabic-Indic
// digits folded.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/delete_confirmation.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';

class _Recorder implements HttpClientAdapter {
  _Recorder(this.body);

  final Object body;
  Map<String, dynamic>? sent;
  String? path;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    sent = (options.data as Map?)?.cast<String, dynamic>();
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _approvalJson = {
  'id': 'ap-1',
  'action_type': 'odoo_write',
  'status': 'pending',
  'prompt': 'Update 3 partners',
  'payload': {'operation': 'write', 'model': 'res.partner'},
};

/// An approval payload with [extra] merged over the base shape. A builder
/// rather than inline literals at each call site: the analyzer wants const
/// maps for @immutable constructors, and `Approval.fromJson` is a factory
/// that can never be const.
Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) =>
    <String, dynamic>{..._approvalJson, ...extra};

(ApprovalsApi, _Recorder) _api({Map<String, dynamic>? batch}) {
  final recorder = _Recorder({
    'approval': _approvalJson,
    if (batch != null) 'batch': batch,
  });
  return (ApprovalsApi(Dio()..httpClientAdapter = recorder), recorder);
}

void main() {
  group('§11 — the decision body', () {
    test('an ordinary approve sends no scope at all', () async {
      final (api, rec) = _api();
      await api.decide(id: 'ap-1', approved: true);

      expect(rec.path, '/api/v1/approvals/ap-1/decision/');
      expect(rec.sent, {'approved': true});
      expect(rec.sent!.containsKey('scope'), isFalse,
          reason: 'a plain Approve must not silently pre-approve a shape');
    });

    test('batch sends scope: "batch"', () async {
      final (api, rec) = _api(batch: const {'resolved_count': 4});
      await api.decide(id: 'ap-1', approved: true, batchScope: true);

      expect(rec.sent!['scope'], 'batch');
    });

    test('the response carries resolved_count — the only place it exists',
        () async {
      final (api, _) = _api(
        batch: const {'resolved_count': 4, 'scope_added': true},
      );
      final result =
          await api.decide(id: 'ap-1', approved: true, batchScope: true);

      expect(result.batch?['resolved_count'], 4);
      expect(result.batch?['scope_added'], true);
    });

    test('a non-batch decision has no batch summary', () async {
      final (api, _) = _api();
      final result = await api.decide(id: 'ap-1', approved: true);

      expect(result.batch, isNull);
    });
  });

  group('§11 — grouped_count does not exist', () {
    test('an approval never parses a group size', () {
      // The server sends no such field. Nothing in the parse path may invent
      // one, because a card labelled "Approve all 6" that clears a different
      // number is worse than a card that just says "Approve".
      final approval = Approval.fromJson(_json());

      expect(approval.recordCount, isNull);
      // …and even if a server ever sent it, the model has no field to land in.
      final withCount = Approval.fromJson(_json({
        'grouped_count': 6,
        }));
      expect(withCount.recordCount, isNull);
    });
  });

  group('§11 — batch_scope suppresses the offer', () {
    test('an auto-approved approval is flagged', () {
      final approval = Approval.fromJson(_json({
        'payload': {'operation': 'write', 'batch_scope': true},
        }));

      expect(approval.batchScoped, isTrue);
    });

    test('an ordinary approval is not', () {
      expect(Approval.fromJson(_json()).batchScoped, isFalse);
    });

    test('a non-true value does not flag it', () {
      final approval = Approval.fromJson(_json({
        'payload': {'batch_scope': 'yes'},
        }));

      expect(approval.batchScoped, isFalse);
    });
  });

  group('§10 — the delete confirm phrase', () {
    test('is read off the approval when the server sends one', () {
      final approval = Approval.fromJson(_json({
        'confirm_phrase': 'delete 3',
        }));

      expect(approval.confirmPhrase, 'delete 3');
    });

    test('is also accepted from the payload', () {
      // Documented as a field on the approval object; every other
      // delete-specific value lives in the payload, so both placements read.
      final approval = Approval.fromJson(_json({
        'payload': {'operation': 'delete', 'confirm_phrase': 'delete 3'},
        }));

      expect(approval.confirmPhrase, 'delete 3');
    });

    test('a blank or wrong-typed phrase reads as absent', () {
      // Not a detail: an empty required phrase would gate the delete forever,
      // because no input can equal "". Absent means the dialog falls back to
      // the locale-built phrases, which always work.
      for (final value in ['', '   ', 42, null, <String>[]]) {
        final approval = Approval.fromJson(_json({
          'confirm_phrase': value,
          }));
        expect(approval.confirmPhrase, isNull, reason: 'for $value');
      }
    });

    test('the server phrase carries NO model name', () {
      // Confirmed by the web team: the Odoo model used to be in the phrase
      // and was removed because it locked out Arabic users. Replay-defence
      // lives in `payload.record_ids`, not in what gets typed.
      final approval = Approval.fromJson(_json({
        'confirm_phrase': 'delete 3',
        }));

      expect(approval.confirmPhrase, isNot(contains('res.partner')));
    });
  });

  group('§10 — what the gate accepts', () {
    // The server takes `delete N`, `حذف N` and `احذف N` interchangeably, and
    // folds Arabic-Indic digits. The client must not be stricter than that.
    const accepted = ['Delete 3', 'حذف 3', 'delete 3'];

    test('either locale confirms, whatever the UI language', () {
      expect(confirmsDelete('delete 3', accepted), isTrue);
      expect(confirmsDelete('حذف 3', accepted), isTrue);
    });

    test('Arabic-Indic digits confirm', () {
      // The failure this exists to prevent: an Arabic keyboard produces ٣,
      // and a gate that only accepts 3 is a delete the user cannot approve.
      expect(confirmsDelete('حذف ٣', accepted), isTrue);
      expect(confirmsDelete('delete ٣', accepted), isTrue);
    });

    test('Persian digits confirm too', () {
      expect(confirmsDelete('حذف ۳', accepted), isTrue);
    });

    test('case and stray whitespace do not matter', () {
      expect(confirmsDelete('  DELETE   3 ', accepted), isTrue);
    });

    test('a server phrase widens the accepted set, never narrows it', () {
      // What the dialog builds: both locale phrases plus whatever the server
      // named. A server that changes its wording must not lock out the
      // phrase the UI is literally telling the user to type.
      const withServer = ['Delete 3', 'حذف 3', 'remove 3 rows'];

      expect(confirmsDelete('remove 3 rows', withServer), isTrue);
      expect(confirmsDelete('Delete 3', withServer), isTrue);
      expect(confirmsDelete('حذف ٣', withServer), isTrue);
    });

    test('the wrong count does NOT confirm', () {
      expect(confirmsDelete('delete 4', accepted), isFalse);
    });

    test('empty input never confirms', () {
      expect(confirmsDelete('', accepted), isFalse);
      expect(confirmsDelete('   ', accepted), isFalse);
    });
  });
}
