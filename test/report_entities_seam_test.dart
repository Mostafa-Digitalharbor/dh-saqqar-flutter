// §4b's one live backend call, checked on the wire.
//
// `WEB_UI_PARITY_GAPS.md` §4 makes this an explicit acceptance criterion —
// *"the report card's entity multi-select calls `/api/v1/report-entities/`"* —
// and it was the one part of the card nothing asserted. Every report-builder
// widget test hands the card a **stub loader**, so all of them pass whether or
// not the real one talks to the right endpoint with the right parameters.
//
// That is exactly the shape of the defect this repo has already shipped twice:
// §8 voice-support guessed `problem` where the server wanted `transcript` and
// produced nothing for weeks, with a green suite, because the test and the
// code were wrong in the same way. A stubbed callback is a test agreeing with
// itself.
//
// So this pins the two halves the private `_loadReportEntities` composes —
// the HTTP call and the response parse — against Appendix A.2 verbatim:
//
//   GET /api/v1/report-entities/?conversation_id=<id>&entity=<…>&q=<optional>
//   200 → { ok, items: [{id, name}], truncated }

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/network/api_endpoints.dart';
import 'package:saqqar_app/core/network/error_interceptor.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';

class _Recorder implements HttpClientAdapter {
  _Recorder(this.body, {this.status = 200});

  final Object? body;
  final int status;

  String? path;
  String? method;
  Map<String, dynamic>? query;
  Object? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    method = options.method;
    query = options.queryParameters;
    requestBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A page shaped exactly as Appendix A.2 documents it.
const _page = <String, dynamic>{
  'ok': true,
  'items': [
    {'id': 42, 'name': 'Acme Co'},
    {'id': 43, 'name': 'مؤسسة الزمان للتجارة'},
  ],
  'truncated': false,
};

OdooDataApi _api(_Recorder recorder) => OdooDataApi(
      Dio(BaseOptions(baseUrl: 'http://x/'))
        ..httpClientAdapter = recorder
        ..interceptors.add(ErrorInterceptor()),
    );

void main() {
  group('the call the card makes', () {
    test('is a GET to the documented path', () async {
      final recorder = _Recorder(_page);

      await _api(recorder).reportEntities(const {
        'conversation_id': 'c1',
        'entity': 'customers',
      });

      expect(recorder.path, ApiEndpoints.reportEntities);
      expect(recorder.path, '/api/v1/report-entities/');
      expect(recorder.method, 'GET');
    });

    test('carries its parameters in the QUERY STRING, not a body', () async {
      // Appendix A.2 specifies query parameters. A GET whose parameters went
      // into the body would be answered with "conversation_id missing" — a
      // 400 the card would surface as an empty record list.
      final recorder = _Recorder(_page);

      await _api(recorder).reportEntities(const {
        'conversation_id': 'c1',
        'entity': 'vendors',
        'q': 'acme',
      });

      expect(recorder.query, {
        'conversation_id': 'c1',
        'entity': 'vendors',
        'q': 'acme',
      });
      expect(recorder.requestBody, isNull);
    });

    test('the three documented entity families are all reachable', () async {
      for (final entity in const ['customers', 'vendors', 'employees']) {
        final recorder = _Recorder(_page);
        await _api(recorder)
            .reportEntities({'conversation_id': 'c1', 'entity': entity});
        expect(recorder.query?['entity'], entity);
      }
    });
  });

  group('the page the card reads back', () {
    test('parses items and the truncated flag', () {
      final page = ReportEntityPage.fromJson(
        Map<String, dynamic>.from(_page),
      );

      expect(page.items.length, 2);
      expect(page.items.first.id, '42');
      expect(page.items.first.name, 'Acme Co');
      // Arabic names come straight off a live Odoo and must survive intact —
      // this list is ticked by name, so a mangled one is unpickable.
      expect(page.items.last.name, 'مؤسسة الزمان للتجارة');
      expect(page.truncated, isFalse);
    });

    test('a truncated page is reported as truncated', () {
      // The card shows "narrow it with search" on this. Reading it as `false`
      // would present a capped list as the complete set — the user ticks
      // "all" their customers and silently excludes everyone past 1000.
      final page = ReportEntityPage.fromJson(
        Map<String, dynamic>.from(_page)..['truncated'] = true,
      );

      expect(page.truncated, isTrue);
    });

    test('an empty page is empty, not an error', () {
      final page = ReportEntityPage.fromJson(
        const <String, dynamic>{
          'ok': true,
          'items': <Object>[],
          'truncated': false,
        },
      );

      expect(page.items, isEmpty);
      expect(page.truncated, isFalse);
    });

    test('a malformed row is dropped, not fatal', () {
      // One bad row must not cost the user the other 999. The server caps at
      // 1000 records off a live Odoo; a null name in the middle of that is a
      // data problem, not a reason to fail the picker.
      final page = ReportEntityPage.fromJson(const {
        'ok': true,
        'items': [
          {'id': 1, 'name': 'Good'},
          'not-a-map',
          {'id': 2, 'name': 'Also good'},
        ],
        'truncated': false,
      });

      expect(page.items.map((e) => e.name), ['Good', 'Also good']);
    });
  });

  group('the errors Appendix A.2 documents', () {
    // Each is a real state: no conversation id, an entity the server does not
    // know, no Odoo linked to the chat, or Odoo unreachable. All four must
    // reach the caller as a throw — the card catches it and shows a message.
    // Returning an empty page instead would render "this customer list is
    // empty", which is a statement of fact about the user's database.
    for (final status in const [400, 502]) {
      test('$status is raised, never flattened into an empty page', () async {
        final api = _api(
          _Recorder(
            const {'ok': false, 'error': 'no Odoo env linked'},
            status: status,
          ),
        );

        await expectLater(
          api.reportEntities(const {'conversation_id': 'c1'}),
          throwsA(anything),
        );
      });
    }

    test('a 200 carrying ok:false is raised too', () async {
      final api = _api(
        _Recorder(const {'ok': false, 'error': 'unsupported entity'}),
      );

      await expectLater(
        api.reportEntities(const {'conversation_id': 'c1'}),
        throwsA(anything),
      );
    });
  });
}
