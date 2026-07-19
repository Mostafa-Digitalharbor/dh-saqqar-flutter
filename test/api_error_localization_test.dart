import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/network/api_error_mapper.dart';
import 'package:saqqar_app/core/network/api_exception.dart';
import 'package:saqqar_app/core/network/error_interceptor.dart';

/// Guards the seam where a server error stops being English transport text
/// and becomes localized copy: [ErrorInterceptor] → [ApiErrorMapper] → UI.
///
/// The contract in one line: `ApiException.message` carries ONLY text the
/// backend actually sent. Empty means "nothing usable", and that emptiness is
/// the signal that makes the mapper reach for `tr.errorServer` /
/// `tr.errorUnknown` instead of echoing transport text at the user.
///
/// This regressed once and nothing caught it. The interceptor seeded `message`
/// with English `defaultApiError` — never empty — so the mapper's `isNotEmpty`
/// guards always took the serverMessage branch and the entire Arabic `error_*`
/// table became unreachable for any response without a JSON `error`/`detail`
/// (nginx 502, gateway timeout, bodiless 5xx). `flutter analyze` sees nothing
/// wrong with that, and an English-locale reviewer sees correct output. Only
/// an Arabic assertion catches it — so that is what these are.
void main() {
  final ar = AppStrings(const Locale('ar'));
  final en = AppStrings(const Locale('en'));

  /// Drives a response through a real Dio + the real [ErrorInterceptor].
  ///
  /// Deliberately end-to-end rather than hand-constructing an [ApiException]:
  /// the bug lived in the interceptor's own default, so a test that built the
  /// exception itself would have passed the whole time it was broken.
  Future<ApiException> intercept({
    required int status,
    required String body,
    String contentType = Headers.jsonContentType,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StubAdapter(status, body, contentType)
      ..interceptors.add(ErrorInterceptor());
    try {
      await dio.get<dynamic>('/api/v1/anything');
      fail('Expected a DioException for HTTP $status');
    } on DioException catch (e) {
      final inner = e.error;
      expect(
        inner,
        isA<ApiException>(),
        reason: 'ErrorInterceptor must wrap every DioException.',
      );
      return inner! as ApiException;
    }
  }

  group('the interceptor invents nothing', () {
    test('a bodiless 5xx yields an empty message', () async {
      final e = await intercept(status: 502, body: '');
      expect(
        e.message,
        isEmpty,
        reason: 'Empty is what routes the mapper to localized fallback. '
            'Seeding copy here re-breaks every non-English locale.',
      );
    });

    test('an nginx HTML 502 (non-JSON body) yields an empty message', () async {
      final e = await intercept(
        status: 502,
        body: '<html><body><h1>502 Bad Gateway</h1></body></html>',
        contentType: Headers.textPlainContentType,
      );
      expect(e.message, isEmpty);
      expect(e.statusCode, 502);
    });

    test('the backend\'s own `error` text IS kept', () async {
      final e = await intercept(
        status: 409,
        body: '{"ok":false,"error":"Conversation already running"}',
      );
      expect(e.message, 'Conversation already running');
    });

    test('the DRF `detail` fallback is kept', () async {
      final e = await intercept(
        status: 400,
        body: '{"detail":"Malformed request"}',
      );
      expect(e.message, 'Malformed request');
    });
  });

  group('status codes that used to fall through to "something went wrong"',
      () {
    // 402 and 415 were unmapped, so both landed in UnknownFailure. For a
    // spent quota that is actively misleading — "try again" is the one
    // thing that cannot work — and for a rejected upload it withholds the
    // only fact the user needs (which formats ARE accepted).
    test('402 classifies as a quota failure, not unknown', () async {
      final e = await intercept(status: 402, body: '{"ok":false}');
      expect(ApiErrorMapper.toFailure(e), isA<QuotaExceededFailure>());
    });

    test('402 renders the quota copy in both locales', () async {
      final e = await intercept(status: 402, body: '{"ok":false}');
      expect(ApiErrorMapper.messageForLocale(ar, e), ar.errorQuotaExceeded);
      expect(ApiErrorMapper.messageForLocale(en, e), en.errorQuotaExceeded);
      expect(ar.errorQuotaExceeded, isNot(en.errorQuotaExceeded));
    });

    test('402 still prefers the server\'s own wording when it sent one',
        () async {
      // Only the server can name the actual cap or reset time.
      final e = await intercept(
        status: 402,
        body: '{"ok":false,"error":"Daily limit reached. Resets at 00:00 UTC."}',
      );
      expect(
        ApiErrorMapper.messageForLocale(en, e),
        'Daily limit reached. Resets at 00:00 UTC.',
      );
    });

    test('415 classifies as an unsupported-media failure', () async {
      final e = await intercept(status: 415, body: '{"ok":false}');
      expect(ApiErrorMapper.toFailure(e), isA<UnsupportedMediaFailure>());
      expect(
        ApiErrorMapper.messageForLocale(ar, e),
        ar.errorUnsupportedMedia,
      );
    });

    test('neither leaks a technical server artifact', () async {
      // `presentableServerMessage` must still screen these — a 402 whose
      // body carries a traceback should fall back to clean copy.
      final e = await intercept(
        status: 402,
        body: '{"ok":false,"error":"Traceback (most recent call last): '
            'psycopg2.errors.CheckViolation"}',
      );
      expect(ApiErrorMapper.messageForLocale(ar, e), ar.errorQuotaExceeded);
    });
  });

  group('a 200 that carries ok:false is still a failure', () {
    // Full coverage of the envelope path lives in error_envelope_test.dart;
    // this pins the LOCALIZED end of it, which is what the user reads.
    test('renders localized copy rather than passing as success', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _StubAdapter(
            200, '{"ok":false}', Headers.jsonContentType)
        ..interceptors.add(ErrorInterceptor());

      try {
        await dio.get<dynamic>('/api/v1/projects');
        fail('A 200 with ok:false must not resolve successfully');
      } on DioException catch (e) {
        final msg = ApiErrorMapper.messageForLocale(ar, e.error);
        expect(msg, isNotEmpty);
        expect(msg, ar.errorUnknown);
      }
    });
  });

  group('an Arabic user gets Arabic', () {
    test('bodiless 5xx renders error_server, not the English default',
        () async {
      final e = await intercept(status: 502, body: '');
      final msg = ApiErrorMapper.messageForLocale(ar, e);
      expect(msg, ar.errorServer);
      expect(
        msg,
        isNot(en.errorServer),
        reason: 'Arabic and English copy must actually differ — if they are '
            'equal the assertion above proves nothing.',
      );
    });

    test('nginx HTML 502 renders Arabic error_server', () async {
      final e = await intercept(
        status: 502,
        body: '<html><h1>502 Bad Gateway</h1></html>',
        contentType: Headers.textPlainContentType,
      );
      expect(ApiErrorMapper.messageForLocale(ar, e), ar.errorServer);
    });

    test('a 409 with no server text renders error_conflict, never blank',
        () async {
      // `_fromApiException` hands `e.message` to ConflictFailure unguarded,
      // so an empty message has to be caught by `_baseMessage`'s own check
      // rather than rendering an empty line to the user.
      final e = await intercept(status: 409, body: '');
      final msg = ApiErrorMapper.messageForLocale(ar, e);
      expect(msg, ar.errorConflict);
      expect(msg, isNotEmpty);
    });

    test('401 tells the user to sign in again, in Arabic', () async {
      final e = await intercept(
        status: 401,
        body: '{"ok":false,"auth":false,"error":"Invalid token"}',
      );
      // Status wins over server text — the user gets actionable copy rather
      // than the backend's "Invalid token".
      expect(ApiErrorMapper.messageForLocale(ar, e), ar.errorUnauthorized);
    });
  });

  group('developer artifacts never reach the user', () {
    // The backend's `error` field is developer-facing by design, so it
    // carries whatever Django/psycopg raised. Before this guard, that text
    // rendered verbatim into AppErrorState — the widget whose own doc says
    // "Don't put raw exception text here". Screened in BOTH locales: an
    // English user has no more use for a traceback than an Arabic one.
    const artifacts = <String, String>{
      'django IntegrityError':
          'IntegrityError: duplicate key value violates unique constraint '
              '"auth_user_email_key"',
      'python traceback':
          'Traceback (most recent call last):\n  File "views.py", line 42, '
              'in post\n    raise ValueError(x)',
      'driver exception': 'psycopg2.OperationalError: FATAL: role "x" does '
          'not exist',
      'ORM internals': 'django.db.utils.DataError: value too long',
      'object repr': '<class \'builtins.TypeError\'> at 0x7f3a9c2b1e40',
      'method call dump': 'odoo.service.model.retrying(func, dbname)',
    };

    artifacts.forEach((label, raw) {
      for (final tr in [en, ar]) {
        final code = tr.locale.languageCode;
        test('$label is suppressed ($code)', () {
          final msg = ApiErrorMapper.messageForLocale(
            tr,
            ApiException(
              kind: ApiExceptionKind.badResponse,
              message: raw,
              statusCode: 500,
            ),
          );
          expect(
            msg,
            tr.errorServer,
            reason: 'A 5xx carrying "$label" must fall back to error_server, '
                'not render the artifact.',
          );
          expect(msg, isNot(contains(raw)));
        });
      }
    });

    test('a 409 artifact falls back to error_conflict, not error_server', () {
      // Each arm keeps its OWN fallback — telling a user with a duplicate
      // record "the server hit a problem" would be wrong.
      final msg = ApiErrorMapper.messageForLocale(
        ar,
        ApiException(
          kind: ApiExceptionKind.badResponse,
          message: 'IntegrityError: duplicate key value violates unique '
              'constraint "projects_name_key"',
          statusCode: 409,
        ),
      );
      expect(msg, ar.errorConflict);
    });
  });

  group('genuine prose still reaches the user', () {
    test('a short human sentence is not suppressed', () {
      final msg = ApiErrorMapper.messageForLocale(
        en,
        ApiException(
          kind: ApiExceptionKind.badResponse,
          message: 'Conversation already running',
          statusCode: 409,
        ),
      );
      expect(
        msg,
        'Conversation already running',
        reason: 'The guard must screen artifacts, not real copy — over-'
            'filtering would hide messages the backend wrote FOR the user.',
      );
    });

    test('a known phrase still localizes to Arabic', () {
      final msg = ApiErrorMapper.messageForLocale(
        ar,
        ApiException(
          kind: ApiExceptionKind.badResponse,
          message: 'Authentication failed',
          statusCode: 500,
        ),
      );
      expect(msg, ar.lookup('testErrAuthFailed'));
      expect(msg, isNot('Authentication failed'));
    });
  });

  group('an unexpected response shape is its own failure', () {
    // The "unexpected reply" case: transport is fine, the server answered,
    // and the body simply isn't what our models expect (a field changed
    // type, a required key vanished, `attachments: []` became `{}`). These
    // all used to land in UnknownFailure → "Something went wrong" — the
    // vaguest copy we have, for the one failure whose cause is specific.
    test('a cast failure classifies as ParseFailure, not Unknown', () {
      late Object thrown;
      try {
        // Exactly what a `fromJson` does when the backend flips a type.
        // ignore: unnecessary_cast
        (<String, dynamic>{'items': <String, dynamic>{}}['items'] as List);
      } catch (e) {
        thrown = e;
      }
      expect(ApiErrorMapper.toFailure(thrown), isA<ParseFailure>());
    });

    test('a FormatException classifies as ParseFailure', () {
      expect(
        ApiErrorMapper.toFailure(const FormatException('bad json')),
        isA<ParseFailure>(),
      );
    });

    test('it does NOT say "try again later" — retry replays the mismatch',
        () {
      for (final tr in [en, ar]) {
        final msg = ApiErrorMapper.messageForLocale(tr, const ParseFailure());
        expect(msg, tr.errorUnexpectedResponse);
        expect(
          msg,
          isNot(tr.errorServer),
          reason: 'The server is healthy and answering — telling the user to '
              'wait and retry sends them into an infinite loop.',
        );
        expect(msg, isNotEmpty);
      }
    });

    test('the Dart type error never reaches the user', () {
      final msg = ApiErrorMapper.messageForLocale(
        ar,
        const ParseFailure(detail: "type 'int' is not a subtype of 'String'"),
      );
      expect(msg, isNot(contains('subtype')));
      expect(msg, ar.errorUnexpectedResponse);
    });

    test('a genuine network error is still a network error', () {
      // Guard against over-classifying: ParseFailure must not swallow the
      // transport failures that have their own (better) advice.
      expect(
        ApiErrorMapper.toFailure(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<NetworkFailure>(),
      );
    });
  });

  group('every locale resolves real copy', () {
    test('no error_* key echoes its own identifier', () {
      for (final tr in [en, ar]) {
        expect(tr.errorServer, isNot('error_server'));
        expect(tr.errorUnknown, isNot('error_unknown'));
        expect(tr.errorConflict, isNot('error_conflict'));
        expect(tr.errorServer, isNotEmpty);
      }
    });
  });
}

/// Returns a canned HTTP response without touching the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body, this.contentType);

  final int status;
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [contentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
