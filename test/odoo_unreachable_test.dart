// A dead Odoo instance says so, instead of blaming Saqqar.
//
// Found on the emulator, against the live server, on 2026-09-08: running the
// data explorer's default `count` against one environment returned a gateway
// 502 whose body was an HTML maintenance page — no JSON, no `error` string.
// The generic mapper had nothing to work with and rendered "something went
// wrong on the server, try again later".
//
// That is wrong in both halves. Saqqar was up: the same endpoint returned
// `{"ok": true, "count": 18}` for a healthy environment seconds later. And
// waiting does not fix it — the Odoo database bound to that environment is
// the thing that is down, which the user owns and can check.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/network/api_error_mapper.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';

/// A Dio that answers every request with [status] and [body].
Dio _dioAnswering(int status, {Object body = const <String, dynamic>{}}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  dio.httpClientAdapter = _FakeAdapter(status, body);
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isJson = body is Map;
    return ResponseBody.fromString(
      isJson ? '{"ok": true, "count": 18}' : body.toString(),
      status,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? Headers.jsonContentType : 'text/html',
        ],
      },
    );
  }
}

/// The real thing the gateway sent, trimmed.
const _maintenanceHtml = '<!doctype html><html lang="en"><head>'
    '<title>Saqqar — We\'ll be right back</title></head><body></body></html>';

void main() {
  final api502 = OdooDataApi(_dioAnswering(502, body: _maintenanceHtml));
  final api504 = OdooDataApi(_dioAnswering(504, body: _maintenanceHtml));

  group('what a gateway 5xx on an Odoo route means', () {
    test('502 with an HTML body, on every read', () async {
      // All six go through the same wrapper; a new one added without it
      // would quietly fall back to the generic message.
      final calls = <String, Future<Object?> Function()>{
        'search': () => api502.search('e1', const {'model': 'res.partner'}),
        'count': () => api502.count('e1', const {'model': 'res.partner'}),
        'readGroup': () => api502.readGroup('e1', const {}),
        'read': () => api502.read('e1', const {}),
        'fields': () => api502.fields('e1', const {}),
        'sql': () => api502.sql('e1', const {'query': 'select 1'}),
      };

      for (final entry in calls.entries) {
        await expectLater(
          entry.value(),
          throwsA(isA<OdooUnreachableFailure>()),
          reason: entry.key,
        );
      }
    });

    test('504 too — a gateway that gave up waiting on Odoo', () async {
      await expectLater(
        api504.count('e1', const {'model': 'res.partner'}),
        throwsA(isA<OdooUnreachableFailure>()),
      );
    });

    test('but a bad query is still a bad query', () async {
      // Relabelling a 400 as "Odoo is down" trades one wrong explanation for
      // another, and sends the user to check a database that is fine.
      final api400 = OdooDataApi(_dioAnswering(400, body: '{"error":"bad"}'));

      await expectLater(
        api400.count('e1', const {'model': 'nope'}),
        throwsA(isNot(isA<OdooUnreachableFailure>())),
      );
    });

    test('and a healthy environment still returns its rows', () async {
      final ok = OdooDataApi(_dioAnswering(200));

      final result = await ok.count('e1', const {'model': 'res.partner'});

      expect(result['count'], 18);
    });

    test('report-entities is not wrapped — it is not an Odoo route', () async {
      // It is conversation-scoped and served by Saqqar itself, so a 502 there
      // really is our problem.
      await expectLater(
        api502.reportEntities(const {'conversation_id': 'c1'}),
        throwsA(isNot(isA<OdooUnreachableFailure>())),
      );
    });
  });

  group('what the user reads', () {
    test('the cause and the two things they can do about it', () {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        final tr = AppStrings(locale);
        final message = ApiErrorMapper.messageForLocale(
          tr,
          const OdooUnreachableFailure(statusCode: 502),
        );

        expect(message, isNotEmpty);
        // Not the generic server line — that is the whole point.
        expect(message, isNot(tr.errorServer));
        expect(message, tr.errorOdooUnreachable);
      }
    });

    test('the Arabic is Arabic and says something different', () {
      final en = AppStrings(const Locale('en'));
      final ar = AppStrings(const Locale('ar'));

      expect(ar.errorOdooUnreachable, isNot(en.errorOdooUnreachable));
      expect(ar.errorOdooUnreachable, matches(RegExp(r'[؀-ۿ]')));
      // Both name Odoo, which is what makes the message actionable.
      expect(en.errorOdooUnreachable.toLowerCase(), contains('odoo'));
      expect(ar.errorOdooUnreachable, contains('أودو'));
    });
  });
}
