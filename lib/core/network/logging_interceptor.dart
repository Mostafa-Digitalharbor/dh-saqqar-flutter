import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Pretty-prints every Dio request, response, and error to the dev console.
///
/// Active only in debug builds — release builds get a no-op interceptor so
/// production users don't pay the formatting cost or leak sensitive payloads
/// to crash reporters that capture stdout.
///
/// Output shape (one line `debugPrint` per request/response so the IDE log
/// view doesn't truncate):
///
/// ```
/// ┌── REQUEST ────────────────────────────────────────────
/// │ POST https://saqqaar.com/api/v1/auth/login/
/// │ headers: { Authorization: Bearer ***, Content-Type: application/json }
/// │ body: { "email": "user@example.com", "password": "***" }
/// └───────────────────────────────────────────────────────
///
/// ┌── RESPONSE 200 (185ms) ───────────────────────────────
/// │ POST /api/v1/auth/login/
/// │ body: { "ok": true, "token": "***", ... }
/// └───────────────────────────────────────────────────────
/// ```
///
/// Sensitive fields (`password`, `old_password`, `new_password`, `token`,
/// `Authorization` header) are masked to `***` so logs can be shared / pasted
/// safely.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor();

  static const _bar = '──────────────────────────────────────────────';

  /// Cap on a single logged body, in characters.
  ///
  /// Only raw String bodies were being truncated; a Map/List body went
  /// through `JsonEncoder.withIndent` unbounded. The chat snapshot endpoint
  /// is polled every 1.5 s and returns the whole transcript, so a long
  /// conversation meant pretty-printing hundreds of KB of JSON on the UI
  /// isolate, ~40×/min, purely to write it to a console nobody is reading
  /// that closely. Debug-only cost, but debug is exactly where on-device
  /// performance gets judged — and an untruncated dump is also unreadable.
  static const _maxLoggedBodyChars = 800;

  // Stopwatches indexed by request hashCode so we can report request→response
  // latency. We don't hold the RequestOptions itself because Dio mutates it
  // between callbacks (e.g. `extra.didRetry`).
  final _stopwatches = <int, Stopwatch>{};

  static const _sensitiveBodyKeys = {
    'password',
    'old_password',
    'new_password',
    'token',
    'access_token',
    'refresh_token',
    // Credential-vault secrets. The schema-driven form ships these under a
    // `payload` wrapper with schema-named fields (xmlrpc → `secret`,
    // postgres/server_shell → `password`/SSH-key shaped). The whole
    // `payload` value is masked wholesale below; these entries cover the
    // same fields if a future endpoint sends them un-wrapped.
    'secret',
    'private_key',
    'passphrase',
  };

  /// Keys whose ENTIRE value is masked, structure and all — credential
  /// payloads carry live Odoo secrets under arbitrary schema-named fields,
  /// so redacting per-known-key isn't enough. A dev pasting a debug log must
  /// never leak a customer's DB password / SSH key.
  static const _opaqueBodyKeys = {'payload'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _stopwatches[identityHashCode(options)] = Stopwatch()..start();
      final buf = StringBuffer()
        ..writeln('┌── REQUEST ── $_bar')
        ..writeln('│ ${options.method} ${options.uri}');
      final headers = _redactHeaders(options.headers);
      if (headers.isNotEmpty) {
        buf.writeln('│ headers: ${_inline(headers)}');
      }
      if (options.queryParameters.isNotEmpty) {
        buf.writeln('│ query: ${_inline(options.queryParameters)}');
      }
      if (options.data != null && !_isFormData(options.data)) {
        buf.writeln('│ body: ${_formatBody(options.data, redact: true)}');
      } else if (_isFormData(options.data)) {
        buf.writeln('│ body: <FormData ${(options.data as FormData).files.length} file(s), '
            '${(options.data as FormData).fields.length} field(s)>');
      }
      buf.write('└── $_bar');
      debugPrint(buf.toString());
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final ms = _stopMs(response.requestOptions);
      final opts = response.requestOptions;
      final buf = StringBuffer()
        ..writeln('┌── RESPONSE ${response.statusCode} (${ms}ms) ── $_bar')
        ..writeln('│ ${opts.method} ${opts.path}');
      if (response.data != null) {
        buf.writeln('│ body: ${_formatBody(response.data, redact: true)}');
      }
      buf.write('└── $_bar');
      debugPrint(buf.toString());
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final ms = _stopMs(err.requestOptions);
      final status = err.response?.statusCode ?? '?';
      final opts = err.requestOptions;
      final buf = StringBuffer()
        ..writeln('┌── ERROR $status (${ms}ms) ── $_bar')
        ..writeln('│ ${opts.method} ${opts.path}')
        ..writeln('│ type: ${err.type.name}');
      if (err.response?.data != null) {
        buf.writeln('│ body: ${_formatBody(err.response!.data)}');
      } else if (err.message != null && err.message!.isNotEmpty) {
        buf.writeln('│ message: ${err.message}');
      }
      buf.write('└── $_bar');
      debugPrint(buf.toString());
    }
    handler.next(err);
  }

  // ────────────────────────────────────────────────────────────────────

  int _stopMs(RequestOptions options) {
    final sw = _stopwatches.remove(identityHashCode(options));
    return sw?.elapsedMilliseconds ?? 0;
  }

  bool _isFormData(Object? data) => data is FormData;

  String _formatBody(Object? body, {bool redact = false}) {
    if (body == null) return 'null';
    try {
      Object payload = body;
      if (redact) payload = _deepRedact(payload);
      if (payload is String) {
        // Probably a pre-encoded JSON string; try to pretty-print, else dump
        // the raw string.
        try {
          return _truncate(
            const JsonEncoder.withIndent('  ').convert(jsonDecode(payload)),
          );
        } catch (_) {
          return _truncate(payload);
        }
      }
      return _truncate(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (_) {
      return _truncate(body.toString());
    }
  }

  String _truncate(String text) {
    if (text.length <= _maxLoggedBodyChars) return text;
    final dropped = text.length - _maxLoggedBodyChars;
    return '${text.substring(0, _maxLoggedBodyChars)}… '
        '<$dropped more chars elided>';
  }

  /// Recursively walks Maps/Lists and replaces sensitive map values with
  /// `'***'` while preserving structure. Returns a new tree — never mutates
  /// the caller's data.
  Object _deepRedact(Object input) {
    if (input is Map) {
      final out = <String, Object?>{};
      input.forEach((k, v) {
        final key = k.toString();
        if (_sensitiveBodyKeys.contains(key.toLowerCase()) ||
            _opaqueBodyKeys.contains(key.toLowerCase())) {
          out[key] = '***';
        } else if (v is Map || v is List) {
          out[key] = _deepRedact(v as Object);
        } else {
          out[key] = v;
        }
      });
      return out;
    }
    if (input is List) {
      return input
          .map((e) => (e is Map || e is List) ? _deepRedact(e as Object) : e)
          .toList();
    }
    return input;
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final out = <String, dynamic>{};
    headers.forEach((k, v) {
      if (k.toLowerCase() == 'authorization') {
        // Keep the scheme prefix so we can see "Bearer" vs "Basic" but mask
        // the credential body.
        final value = v.toString();
        final space = value.indexOf(' ');
        out[k] = space > 0 ? '${value.substring(0, space)} ***' : '***';
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  String _inline(Map<String, dynamic> map) {
    final parts = map.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return '{ $parts }';
  }
}
