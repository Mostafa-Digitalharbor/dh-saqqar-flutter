import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Converts every [DioException] into an [ApiException] so the upper layers
/// don't have to know Dio.
///
/// The backend envelope is `{ "ok": false, "error": "human msg" }` per
/// SAQQAR_MOBILE_API.md §14, with optional `auth: false` on 401 and
/// `retry_after: <seconds>` on 429. We read `error` first, fall back to
/// the DRF default `detail`, then field errors.
///
/// Two entry points, because the backend signals failure two ways:
///
///  * [onError] — non-2xx. Dio raises these itself.
///  * [onResponse] — **2xx carrying `ok: false`**. Dio treats these as
///    success, so without the check below they flow into the repositories
///    as if nothing went wrong. See [_envelopeFailure].
class ErrorInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final failure = _envelopeFailure(response);
    if (failure != null) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: failure,
        ),
        // `true` — the rejection is already an ApiException, so it must
        // travel the normal error path rather than being re-wrapped.
        true,
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: _mapToApiException(err),
        stackTrace: err.stackTrace,
      ),
    );
  }

  /// An [ApiException] when a 2xx response is actually a failure, else null.
  ///
  /// The envelope lets the server answer `200 {"ok": false, "error": "…"}`.
  /// Dio only throws on non-2xx, so these used to reach the repositories as
  /// successes. The two shapes that produced were both bad:
  ///
  ///  * `res.data!['projects'] as List? ?? []` → an EMPTY LIST, rendering
  ///    "You have no projects yet" as a statement of fact when the truth is
  ///    we couldn't ask. A false success hides the retry.
  ///  * a non-null cast on a missing key → `TypeError` → `ParseFailure` →
  ///    "unexpected response", discarding the `error` text the server sent.
  ///
  /// Catching it here rather than in a per-endpoint `_unwrap` helper means
  /// no call site can forget to check — the ~25 that already did are all
  /// covered by this one hook.
  static ApiException? _envelopeFailure(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) return null;

    final data = response.data;
    // Only an EXPLICIT `ok: false` counts. Endpoints that omit `ok`
    // entirely (most of them, on success) must keep flowing through.
    if (data is! Map<String, dynamic> || data['ok'] != false) return null;

    final body = _ParsedBody.from(data, response.headers);
    return ApiException(
      kind: ApiExceptionKind.badResponse,
      message: body.message,
      // The transport really did return 200; reporting it honestly keeps
      // `ApiErrorMapper`'s status-code branches from mis-classifying this
      // as a 4xx. It falls through to the generic localized copy unless
      // the server named a reason, which is the correct outcome.
      statusCode: status,
      code: body.code,
      fieldErrors: body.fieldErrors,
      retryAfterSeconds: body.retryAfter,
    );
  }

  static ApiException _mapToApiException(DioException err) {
    final body = _ParsedBody.from(err.response?.data, err.response?.headers);

    final kind = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiExceptionKind.timeout,
      DioExceptionType.badResponse => ApiExceptionKind.badResponse,
      DioExceptionType.cancel => ApiExceptionKind.cancelled,
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => ApiExceptionKind.network,
      _ => ApiExceptionKind.unknown,
    };

    return ApiException(
      kind: kind,
      message: body.message,
      statusCode: err.response?.statusCode,
      code: body.code,
      fieldErrors: body.fieldErrors,
      retryAfterSeconds: body.retryAfter,
    );
  }
}

/// The four fields worth salvaging from an error body, however it arrived.
///
/// Extracted so the 2xx-envelope path and the non-2xx path read the body
/// identically — a field parsed in one and not the other is exactly the
/// kind of asymmetry that makes an error message better on some endpoints
/// than others for no reason a user could understand.
class _ParsedBody {
  const _ParsedBody({
    required this.message,
    this.code,
    this.fieldErrors,
    this.retryAfter,
  });

  /// The backend's own text, or EMPTY when the response carried none.
  ///
  /// Deliberately starts EMPTY rather than seeding English copy.
  /// `ApiErrorMapper` reads an empty message as "the server said nothing
  /// usable" and substitutes the LOCALIZED `tr.errorServer` /
  /// `tr.errorUnknown` / `tr.errorConflict`. Seeding a default here would
  /// satisfy those `isNotEmpty` guards and pin every response with no JSON
  /// `error`/`detail` — an nginx 502 (HTML body), a gateway timeout, any
  /// bodiless 5xx — to English, including for Arabic users. Only text the
  /// backend actually sent belongs in this field.
  final String message;
  final String? code;
  final Map<String, List<String>>? fieldErrors;
  final int? retryAfter;

  static const _reservedKeys = {
    'ok',
    'error',
    'detail',
    'code',
    'auth',
    'retry_after',
  };

  factory _ParsedBody.from(dynamic data, Headers? headers) {
    String message = '';
    String? code;
    Map<String, List<String>>? fieldErrors;
    int? retryAfter;

    if (data is Map<String, dynamic>) {
      // Spec envelope: { ok: false, error: "..." }
      if (data['error'] is String) {
        message = data['error'] as String;
      } else if (data['detail'] is String) {
        // DRF fallback (some legacy endpoints).
        message = data['detail'] as String;
      }

      if (data['code'] is String) code = data['code'] as String;
      if (data['retry_after'] is num) {
        retryAfter = (data['retry_after'] as num).toInt();
      }

      // Per-field validation errors (DRF style: { "field": ["msg", ...] }).
      final fieldKeys = data.keys.where((k) => !_reservedKeys.contains(k));
      if (fieldKeys.isNotEmpty) {
        fieldErrors = {};
        for (final key in fieldKeys) {
          final v = data[key];
          if (v is List) {
            fieldErrors[key] = v.map((e) => e.toString()).toList();
          } else if (v is String) {
            fieldErrors[key] = [v];
          }
        }
        if (fieldErrors.isEmpty) fieldErrors = null;
      }
    }

    // Honor Retry-After header when the body omits it.
    retryAfter ??= int.tryParse(headers?.value('retry-after') ?? '');

    return _ParsedBody(
      message: message,
      code: code,
      fieldErrors: fieldErrors,
      retryAfter: retryAfter,
    );
  }
}
