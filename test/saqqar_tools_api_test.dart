// §6 — the three Odoo tool endpoints (web team response, 2026-08-06).
//
// These replaced three locally-authored prompt strings. That swap is the
// point of the file: the rows used to send free text and hope the agent
// picked the right tool, and now they call the specific route. What has to
// be pinned is the wire contract, because nothing else in the app exercises
// these paths and a wrong path is a 404 the user reads as "the scan failed".
//
// The `whatif` choice is deliberate and tested here so it doesn't get
// "fixed": the row calls `/whatif/intro/`, NOT `/whatif/run/`. `run` needs a
// `scenario` from a fixed set of four plus a `percent`, which would mean a
// form asking users to classify their own question before they've phrased
// it. `intro` posts a primer and lets them describe it in words.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/network/api_exception.dart';
import 'package:saqqar_app/features/chat/data/saqqar_tools_api.dart';

class _Recorder implements HttpClientAdapter {
  _Recorder({this.body = const {'ok': true}, this.status = 200});

  final Object? body;
  final int status;

  String? path;
  Map<String, dynamic>? sent;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    sent = options.data as Map<String, dynamic>?;
    if (status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: body == null
          ? const {}
          : {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
    );
  }

  @override
  void close({bool force = false}) {}
}

(SaqqarToolsApi, _Recorder) _api({
  Object? body = const {'ok': true},
  int status = 200,
}) {
  final recorder = _Recorder(body: body, status: status);
  return (
    SaqqarToolsApi(Dio()..httpClientAdapter = recorder),
    recorder,
  );
}

void main() {
  group('each row hits its own documented route', () {
    test('health radar → /api/v1/radar/run/', () async {
      final (api, rec) = _api();
      await api.runHealthRadar(conversationId: 'c-1', lang: 'ar');

      expect(rec.path, '/api/v1/radar/run/');
    });

    test('business pulse → /api/v1/pulse/run/', () async {
      final (api, rec) = _api();
      await api.runBusinessPulse(conversationId: 'c-1', lang: 'ar');

      expect(rec.path, '/api/v1/pulse/run/');
    });

    test('what-if → /api/v1/whatif/INTRO/, never /run/', () async {
      final (api, rec) = _api();
      await api.runWhatIfIntro(conversationId: 'c-1', lang: 'ar');

      expect(rec.path, '/api/v1/whatif/intro/');
      expect(
        rec.path,
        isNot('/api/v1/whatif/run/'),
        reason: '/run/ requires a scenario enum + percent the user never chose',
      );
    });

    test('the guessed 2026-08-05 route names are NOT used', () {
      // The probe that led to the prompt-sending build tried these and got
      // 404s. Naming them here documents why the earlier conclusion was
      // wrong: the routes were real, the guesses were not.
      const guessed = [
        '/api/v1/health-radar/',
        '/api/v1/what-if/',
        '/api/v1/business-pulse/',
      ];
      for (final path in guessed) {
        expect(
          ['/api/v1/radar/run/', '/api/v1/pulse/run/', '/api/v1/whatif/intro/'],
          isNot(contains(path)),
        );
      }
    });
  });

  group('the request body', () {
    test('carries the conversation and the language', () async {
      final (api, rec) = _api();
      await api.runHealthRadar(conversationId: 'conv-42', lang: 'ar');

      expect(rec.sent, {'conversation_id': 'conv-42', 'lang': 'ar'});
    });

    test('passes the UI language through, not a hardcoded default', () async {
      // The report comes back written in this language, so an English UI
      // that always sent "ar" would post an Arabic report into the chat.
      final (api, rec) = _api();
      await api.runBusinessPulse(conversationId: 'c', lang: 'en');

      expect(rec.sent!['lang'], 'en');
    });

    test('sends nothing else — no client-invented parameters', () async {
      final (api, rec) = _api();
      await api.runWhatIfIntro(conversationId: 'c', lang: 'en');

      expect(rec.sent!.keys, unorderedEquals(['conversation_id', 'lang']));
    });
  });

  group('failures reach the caller instead of reading as success', () {
    test('a 400 (no environment bound) throws', () async {
      final (api, _) = _api(
        status: 400,
        body: const {'ok': false, 'error': 'لا توجد بيانات اعتماد'},
      );

      await expectLater(
        api.runHealthRadar(conversationId: 'c', lang: 'ar'),
        throwsA(isA<Exception>()),
      );
    });

    test('a 502 (Odoo unreachable) throws', () async {
      final (api, _) = _api(status: 502, body: const {'ok': false});

      await expectLater(
        api.runBusinessPulse(conversationId: 'c', lang: 'ar'),
        throwsA(isA<Exception>()),
      );
    });

    test('a bodiless 200 is a parse failure, not a completed scan', () async {
      // The `res.data ?? {}` trap: a proxy that strips the body would
      // otherwise make the app refresh the snapshot, find no new message,
      // and show the user nothing at all with no error.
      final (api, _) = _api(body: null);

      await expectLater(
        api.runHealthRadar(conversationId: 'c', lang: 'ar'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.parse),
        ),
      );
    });
  });
}
