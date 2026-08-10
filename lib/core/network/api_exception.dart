/// Normalized error surface for the UI layer.
///
/// The Dio interceptor converts raw [DioException]s into [ApiException] so
/// repositories and controllers don't deal with transport-specific types.
class ApiException implements Exception {
  ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.fieldErrors,
    this.retryAfterSeconds,
  });

  final ApiExceptionKind kind;

  /// The backend's own `error` / `detail` text, or EMPTY when the response
  /// carried none (bodiless 5xx, nginx HTML, gateway timeout).
  ///
  /// Empty is meaningful — [ApiErrorMapper] reads it as "the server said
  /// nothing usable" and falls back to localized copy. Never seed this with
  /// a default message: that makes the fallback unreachable and pins the
  /// error to whatever language the default was written in.
  final String message;

  final int? statusCode;

  /// Machine-readable code from the backend (e.g. `invalid_credentials`).
  final String? code;

  /// Per-field validation errors from `400` responses (e.g. `{ "username": ["..."] }`).
  final Map<String, List<String>>? fieldErrors;

  /// Set on 429 — seconds to back off before retrying. Honors both the
  /// JSON body's `retry_after` and the `Retry-After` HTTP header.
  final int? retryAfterSeconds;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 400 || statusCode == 422;
  bool get isConflict => statusCode == 409;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';
}

enum ApiExceptionKind {
  network, // no internet / DNS / handshake
  timeout, // connect/receive/send timeout
  badResponse, // 4xx / 5xx
  cancelled, // request was cancelled

  /// The bytes arrived and were not the JSON they claimed to be — a proxy
  /// truncated the body, gzip cut off mid-object, or a Django debug page came
  /// back under an `application/json` header.
  ///
  /// Distinct from [network] because the advice differs and only one of them
  /// is actionable: "check your connection" sends a user to their router when
  /// the connection is fine and the server is the problem. Dio reports these
  /// as `DioExceptionType.unknown` with a `FormatException` inside and *no
  /// status code* — the response never finished parsing — so the kind is the
  /// only place the distinction can survive.
  parse,

  unknown,
}
