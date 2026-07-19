// Guards the `200 + {"ok": false}` path.
//
// The backend's envelope lets a *successful* HTTP status carry a failure.
// Dio only raises on non-2xx, so before `ErrorInterceptor.onResponse`
// existed those bodies reached the repositories as successes — and the
// list endpoints turned them into an EMPTY LIST, which the UI renders as
// "you have no projects / devices / credentials yet". A false success is
// worse than an error: it is confidently wrong and it hides the retry.
//
// These run the real interceptor against a stubbed adapter so the
// assertion covers the actual wiring, not a reimplementation of it.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/network/api_exception.dart';
import 'package:saqqar_app/core/network/error_interceptor.dart';

/// Serves one canned response for any request.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        body,
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int statusCode, String body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _StubAdapter(statusCode, body);
  dio.interceptors.add(ErrorInterceptor());
  return dio;
}

/// Drives a request and returns the [ApiException] it failed with, or null
/// when the call succeeded.
Future<ApiException?> _failureFrom(Dio dio) async {
  try {
    await dio.get<dynamic>('/anything');
    return null;
  } on DioException catch (e) {
    final err = e.error;
    return err is ApiException ? err : null;
  }
}

void main() {
  group('2xx carrying ok:false', () {
    test('is rejected instead of flowing through as a success', () async {
      final dio = _dioReturning(200, '{"ok": false, "error": "Odoo is down"}');
      final failure = await _failureFrom(dio);

      expect(failure, isNotNull,
          reason: 'a 200 with ok:false must not reach the repository as a '
              'successful response');
      expect(failure!.kind, ApiExceptionKind.badResponse);
    });

    test("preserves the server's own reason so the UI can show it", () async {
      // Losing this is what made the old `TypeError` path so poor: the
      // server said exactly what was wrong and the user got "unexpected
      // response".
      final dio = _dioReturning(
        200,
        '{"ok": false, "error": "Odoo connection failed: invalid credentials"}',
      );
      final failure = await _failureFrom(dio);

      expect(failure?.message, 'Odoo connection failed: invalid credentials');
    });

    test('reports the real transport status rather than inventing a 4xx',
        () async {
      final dio = _dioReturning(200, '{"ok": false, "error": "nope"}');
      expect((await _failureFrom(dio))?.statusCode, 200);
    });

    test('carries code, field errors and retry_after across', () async {
      final dio = _dioReturning(
        200,
        '{"ok": false, "error": "Invalid", "code": "bad_input", '
        '"retry_after": 30, "name": ["This field is required."]}',
      );
      final failure = await _failureFrom(dio);

      expect(failure?.code, 'bad_input');
      expect(failure?.retryAfterSeconds, 30);
      expect(failure?.fieldErrors?['name'], ['This field is required.']);
    });
  });

  group('successful responses still flow through', () {
    test('ok:true is not treated as a failure', () async {
      final dio = _dioReturning(200, '{"ok": true, "projects": []}');
      expect(await _failureFrom(dio), isNull);
    });

    test('a body that omits `ok` entirely is not treated as a failure',
        () async {
      // Most endpoints never send `ok` on success. Rejecting those would
      // break the whole app — the check must be for an EXPLICIT false.
      final dio = _dioReturning(200, '{"projects": []}');
      expect(await _failureFrom(dio), isNull);
    });

    test('a bare JSON list body is not treated as a failure', () async {
      final dio = _dioReturning(200, '[{"id": "1"}]');
      expect(await _failureFrom(dio), isNull);
    });

    test('201 with ok:true is not treated as a failure', () async {
      final dio = _dioReturning(201, '{"ok": true, "id": "abc"}');
      expect(await _failureFrom(dio), isNull);
    });
  });

  group('non-2xx keeps its existing behaviour', () {
    test('a 500 still maps to badResponse with the server text', () async {
      final dio = _dioReturning(500, '{"ok": false, "error": "boom"}');
      final failure = await _failureFrom(dio);

      expect(failure?.kind, ApiExceptionKind.badResponse);
      expect(failure?.statusCode, 500);
      expect(failure?.message, 'boom');
    });

    test('a bodiless 5xx leaves the message EMPTY for the localizer',
        () async {
      // Empty is meaningful: `ApiErrorMapper` substitutes localized copy.
      // Seeding English here would pin an Arabic user's error to English.
      final dio = _dioReturning(502, '<html>nginx</html>');
      expect((await _failureFrom(dio))?.message, isEmpty);
    });

    test('a 429 reads retry_after from the body', () async {
      final dio = _dioReturning(429, '{"ok": false, "retry_after": 12}');
      expect((await _failureFrom(dio))?.retryAfterSeconds, 12);
    });
  });
}
