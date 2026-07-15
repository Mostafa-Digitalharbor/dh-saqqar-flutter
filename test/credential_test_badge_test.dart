import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';

/// Guards the Test-Connection badge against a generic English marker coming
/// back as a "reason".
///
/// The badge renders `"<testConnectionFailed>: <testConnectionError(reason)>"`
/// when a reason is present, and the bare localized `testConnectionFailed`
/// when it isn't. `CredentialsApi` used to substitute the literal
/// `'Connection failed'` whenever it had no real reason. That matches no
/// branch in `localizeServerMessage`, so it passed through raw and the badge
/// read:
///
///   * English → "Connection failed: Connection failed"  (stutter)
///   * Arabic  → "فشل الاتصال: Connection failed"        (leaked English)
///
/// The contract these tests pin: a reason is either the SERVER's own words,
/// or null. Never a generic string we invented.
void main() {
  group('CredentialTestResult', () {
    test('a failure with no known reason carries a null error', () {
      // Null is what routes the badge to its single localized line.
      expect(const CredentialTestResult.failure().error, isNull);
      expect(const CredentialTestResult.failure().success, isFalse);
    });

    test('a failure with a server reason keeps it verbatim', () {
      const result = CredentialTestResult.failure('AccessDenied: bad password');
      expect(result.error, 'AccessDenied: bad password');
    });
  });

  group('CredentialsApi.testConnection', () {
    Future<CredentialTestResult> run(_FakeAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      return CredentialsApi(dio).testConnection(
        kind: CredentialKind.xmlrpc,
        payload: const {},
      );
    }

    test('surfaces the server\'s own reason when it sends one', () async {
      final result = await run(
        _FakeAdapter.json(200, {'ok': false, 'error': 'AccessDenied: nope'}),
      );
      expect(result.success, isFalse);
      expect(result.error, 'AccessDenied: nope');
    });

    test('reports null — not a generic marker — when ok:false has no error',
        () async {
      final result = await run(_FakeAdapter.json(200, {'ok': false}));
      expect(result.success, isFalse);
      expect(
        result.error,
        isNull,
        reason: 'A generic reason here renders as "Connection failed: '
            'Connection failed" in EN and leaks English into an AR badge.',
      );
    });

    test('reports null when the body is unparseable', () async {
      final result = await run(_FakeAdapter.raw(200, 'not json at all'));
      expect(result.success, isFalse);
      expect(result.error, isNull);
    });

    test('reports null on a transport failure rather than Dio\'s English',
        () async {
      // `e.message` here is raw Dio text no locale table can translate.
      final result = await run(_FakeAdapter.boom());
      expect(result.success, isFalse);
      expect(result.error, isNull);
    });

    test('still surfaces a server reason carried on an error response',
        () async {
      final result = await run(
        _FakeAdapter.json(400, {'error': 'GitHub token is required.'}),
      );
      expect(result.error, 'GitHub token is required.');
    });

    test('a success carries no error', () async {
      final result = await run(_FakeAdapter.json(200, {'ok': true}));
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });
  });

  test('the Arabic badge prefix does not contain the English marker', () {
    // Belt-and-braces: if `testConnectionFailed` ever regressed to English,
    // an Arabic badge would read as English even with a null reason.
    final tr = AppStrings(const Locale('ar'));
    expect(tr.testConnectionFailed, isNot(contains('Connection failed')));
  });
}

/// Minimal `HttpClientAdapter` that replays a canned response, so the tests
/// exercise the real `testConnection` parsing without a network or a
/// mocking package.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter._(this._body, this._status, {this.throws = false});

  factory _FakeAdapter.json(int status, Map<String, dynamic> body) =>
      _FakeAdapter._(jsonEncode(body), status);

  factory _FakeAdapter.raw(int status, String body) =>
      _FakeAdapter._(body, status);

  /// A connection-level failure — no response at all.
  factory _FakeAdapter.boom() => _FakeAdapter._('', 0, throws: true);

  final String _body;
  final int _status;
  final bool throws;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (throws) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused by the fake adapter',
      );
    }
    return ResponseBody.fromString(
      _body,
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
