import 'package:equatable/equatable.dart';

/// Typed, exhaustive failure categories the app surfaces to the user.
///
/// Every cubit that can fail should emit an `AppFailure?` on its state
/// (never a raw `String`). The view layer maps the failure to a
/// localized, user-friendly message via [ApiErrorMapper.message] at
/// render time — that keeps cubits free of `BuildContext` AND guarantees
/// the message follows the user's current locale even if it changes
/// after the cubit emitted.
///
/// Adding a new failure category is a single edit here + a single
/// `switch` arm in [ApiErrorMapper.message] + one i18n key per locale.
sealed class AppFailure extends Equatable {
  const AppFailure();
}

// ── Transport-layer failures ────────────────────────────────────────────

/// No internet / DNS / handshake refused.
class NetworkFailure extends AppFailure {
  const NetworkFailure();
  @override
  List<Object?> get props => const [];
}

/// Connect / send / receive timeout.
class TimeoutFailure extends AppFailure {
  const TimeoutFailure();
  @override
  List<Object?> get props => const [];
}

/// The user (or the system) cancelled the request mid-flight.
class CancelledFailure extends AppFailure {
  const CancelledFailure();
  @override
  List<Object?> get props => const [];
}

// ── HTTP status failures ────────────────────────────────────────────────

/// 401. Stored bearer token was rejected — user must re-sign-in.
class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure();
  @override
  List<Object?> get props => const [];
}

/// 403. The action is recognized but not allowed for this user.
class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure();
  @override
  List<Object?> get props => const [];
}

/// 404. The resource doesn't exist (or belongs to another user — the
/// backend deliberately doesn't distinguish per SAQQAR_MOBILE_API.md §14).
class NotFoundFailure extends AppFailure {
  const NotFoundFailure();
  @override
  List<Object?> get props => const [];
}

/// 400 / 422. Per-field validation errors. Use [firstError] to surface
/// inline messages on specific form fields. The optional [message]
/// carries the top-level error string when the backend included one.
class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.fieldErrors = const {},
    this.message,
  });

  final Map<String, List<String>> fieldErrors;
  final String? message;

  /// Returns the first error string for [field] or `null` if no error
  /// landed on that field.
  String? firstError(String field) => fieldErrors[field]?.firstOrNull;

  @override
  List<Object?> get props => [fieldErrors, message];
}

/// 409. The action conflicts with current server state (email already
/// taken, conversation already running, etc.). [serverMessage] is the
/// backend's `error` field — already localized when the backend cares.
class ConflictFailure extends AppFailure {
  const ConflictFailure({this.serverMessage});
  final String? serverMessage;
  @override
  List<Object?> get props => [serverMessage];
}

/// 429. Rate limit hit. [retryAfterSeconds] comes from the body's
/// `retry_after` field or the `Retry-After` header; non-null when the
/// backend told us when to retry.
class RateLimitFailure extends AppFailure {
  const RateLimitFailure({this.retryAfterSeconds});
  final int? retryAfterSeconds;
  @override
  List<Object?> get props => [retryAfterSeconds];
}

/// 413. Upload exceeded the server's 25 MB cap.
class PayloadTooLargeFailure extends AppFailure {
  const PayloadTooLargeFailure();
  @override
  List<Object?> get props => const [];
}

/// 5xx. The server hit an internal problem.
class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode, this.serverMessage});
  final int? statusCode;
  final String? serverMessage;
  @override
  List<Object?> get props => [statusCode, serverMessage];
}

/// Default fallback for anything that doesn't fit the categories above.
/// [serverMessage] is the backend's `error` field when present.
class UnknownFailure extends AppFailure {
  const UnknownFailure({this.serverMessage});
  final String? serverMessage;
  @override
  List<Object?> get props => [serverMessage];
}
