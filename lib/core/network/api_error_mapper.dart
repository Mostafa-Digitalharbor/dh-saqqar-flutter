import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../error/app_failure.dart';
import '../i18n/app_localizations.dart';
import '../i18n/app_strings.dart';
import 'api_exception.dart';

/// Converts thrown errors → typed [AppFailure], and typed [AppFailure] →
/// localized user-facing strings.
///
/// Two-step pipeline by design:
///
///   1. **Cubit side** (no `BuildContext`): `ApiErrorMapper.toFailure(e)`
///      classifies the exception into one of the [AppFailure] subtypes.
///      The cubit stores that on its state.
///
///   2. **View side**: `ApiErrorMapper.message(context, failure)` reads
///      the user's current locale and returns the localized message. The
///      view either renders it inline (form field) or as a toast.
///
/// The split is load-bearing for two reasons:
///   * Cubits stay free of Flutter widgets, so they're unit-testable.
///   * If the user switches locale after the cubit emitted, the next
///     rebuild renders the message in the new locale automatically.
///
/// Adding a new error category → edit [AppFailure] + add the `switch`
/// arm in [message] + add one i18n key per locale. That's it — every
/// feature picks up the new wording the next time it surfaces the error.
class ApiErrorMapper {
  ApiErrorMapper._();

  // ── Classification (cubit-side) ─────────────────────────────────────

  /// Categorizes an arbitrary thrown [error] into the [AppFailure]
  /// hierarchy. Safe to call with any object — returns [UnknownFailure]
  /// for things we can't classify.
  ///
  /// Handles the common case where the [ErrorInterceptor] stuffs the
  /// typed [ApiException] inside `DioException.error` — callers further
  /// up the stack only see the wrapping DioException, so unwrap it here
  /// in one place rather than asking every cubit to know about Dio.
  static AppFailure toFailure(Object? error) {
    if (error is AppFailure) return error;
    if (error is ApiException) return _fromApiException(error);
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return _fromApiException(inner);
      // A model's `fromJson` that throws while Dio is still on the stack
      // arrives wrapped — unwrap before falling back to transport
      // classification, or a schema change reads as a network error.
      if (_isParseError(inner)) return ParseFailure(detail: inner.toString());
      // Connection-level failures (no response, DNS, handshake) never
      // pass through the ErrorInterceptor wrap — classify from Dio's
      // own type so the user still sees the right network message.
      return _fromDioType(error);
    }
    // The response arrived fine and then didn't match our models: a field
    // changed type, a required key vanished, `attachments: []` became `{}`.
    // Without this these land in UnknownFailure → "Something went wrong",
    // the vaguest message we have, for the one failure with a specific and
    // actionable cause.
    if (_isParseError(error)) return ParseFailure(detail: error.toString());
    return const UnknownFailure();
  }

  /// Errors that mean "the body wasn't the shape we expect".
  ///
  /// `as`-cast failures surface as [TypeError] and are what a schema change
  /// actually throws; [FormatException] covers malformed JSON and the
  /// `int.parse`/`DateTime.parse` family.
  static bool _isParseError(Object? e) => e is TypeError || e is FormatException;

  static AppFailure _fromDioType(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const TimeoutFailure(),
      DioExceptionType.cancel => const CancelledFailure(),
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => const NetworkFailure(),
      // A raw DioException that skipped the ErrorInterceptor wrap (e.g.
      // `dio.download` for artifacts) still carries the HTTP status — use
      // it so a 404/403/500 gets its specific message instead of a flat
      // "something went wrong".
      DioExceptionType.badResponse => _fromStatus(e.response?.statusCode),
      DioExceptionType.badCertificate => const NetworkFailure(),
    };
  }

  /// Maps a bare HTTP status code to the matching [AppFailure]. Used for
  /// error paths that never went through the [ApiException] wrapping.
  static AppFailure _fromStatus(int? code) {
    return switch (code) {
      401 => const UnauthorizedFailure(),
      402 => const QuotaExceededFailure(),
      403 => const ForbiddenFailure(),
      404 => const NotFoundFailure(),
      409 => const ConflictFailure(),
      413 => const PayloadTooLargeFailure(),
      415 => const UnsupportedMediaFailure(),
      400 || 422 => const ValidationFailure(),
      429 => const RateLimitFailure(),
      final c when c != null && c >= 500 => ServerFailure(statusCode: c),
      _ => const UnknownFailure(),
    };
  }

  static AppFailure _fromApiException(ApiException e) {
    // Order matters — most specific first.
    if (e.statusCode == 413) return const PayloadTooLargeFailure();
    if (e.statusCode == 402) {
      return QuotaExceededFailure(
        serverMessage: e.message.isNotEmpty ? e.message : null,
      );
    }
    if (e.statusCode == 415) {
      return UnsupportedMediaFailure(
        serverMessage: e.message.isNotEmpty ? e.message : null,
      );
    }
    if (e.isUnauthorized) return const UnauthorizedFailure();
    if (e.isForbidden) return const ForbiddenFailure();
    if (e.isNotFound) return const NotFoundFailure();
    if (e.isConflict) return ConflictFailure(serverMessage: e.message);
    if (e.isRateLimited) {
      return RateLimitFailure(retryAfterSeconds: e.retryAfterSeconds);
    }
    // Validation only wins for 4xx. A 5xx that happens to carry an extra
    // string field (e.g. `trace_id`, `request_id`) gets those keys hoisted
    // into `fieldErrors` by the ErrorInterceptor — without this status guard
    // the server crash would surface to the user as a "check your input"
    // validation error and diverge from what Sentry (correctly) reports as a
    // 5xx. Let it fall through to the ServerFailure branch below instead.
    final is5xx = e.statusCode != null && e.statusCode! >= 500;
    if (!is5xx &&
        (e.isValidation ||
            (e.fieldErrors != null && e.fieldErrors!.isNotEmpty))) {
      return ValidationFailure(
        fieldErrors: e.fieldErrors ?? const {},
        message: e.message.isNotEmpty ? e.message : null,
      );
    }
    switch (e.kind) {
      case ApiExceptionKind.network:
        return const NetworkFailure();
      case ApiExceptionKind.timeout:
        return const TimeoutFailure();
      case ApiExceptionKind.cancelled:
        return const CancelledFailure();
      // The transport succeeded and the body was unreadable. `message` is
      // empty by construction here (there was no JSON to read an `error` key
      // out of), so this renders `tr.errorUnexpectedResponse` — the same copy
      // a schema mismatch gets, which is the same thing from the user's side.
      case ApiExceptionKind.parse:
        return const ParseFailure();
      case ApiExceptionKind.badResponse:
        if (e.statusCode != null && e.statusCode! >= 500) {
          return ServerFailure(
            statusCode: e.statusCode,
            serverMessage: e.message.isNotEmpty ? e.message : null,
          );
        }
        return UnknownFailure(
          serverMessage: e.message.isNotEmpty ? e.message : null,
        );
      case ApiExceptionKind.unknown:
        return UnknownFailure(
          serverMessage: e.message.isNotEmpty ? e.message : null,
        );
    }
  }

  // ── Localization (view-side) ────────────────────────────────────────

  /// Localized, user-friendly message for [failure]. Accepts either a
  /// raw exception or a pre-classified [AppFailure] for convenience.
  ///
  /// [actionContext] is an optional prefix that names the operation that
  /// failed (e.g. `tr.vaultCreateProjectFailed` → "Couldn't create the
  /// project"). When supplied, the result is
  /// `"<actionContext> · <error>"`, which reads naturally in both EN
  /// and AR thanks to the bidirectional middle-dot separator.
  static String message(
    BuildContext context,
    Object? failure, {
    String? actionContext,
  }) {
    final tr = context.tr;
    final f = toFailure(failure);
    final base = _baseMessage(tr, f);
    if (actionContext == null || actionContext.isEmpty) return base;
    return '$actionContext · $base';
  }

  /// Inline error for one form field, screened and localized.
  ///
  /// Use this instead of `failure.firstError('email')` at render time.
  /// `fieldErrors` is populated from arbitrary body keys by
  /// `ErrorInterceptor`, so unlike `AppFailure.message` it never passed
  /// through [AppStrings.presentableServerMessage] — meaning a DRF
  /// `IntegrityError: duplicate key value violates unique constraint
  /// "auth_user_email_key"` rendered verbatim, in English, under an Arabic
  /// text field.
  ///
  /// Returns null when there is no error on [field], or when what the
  /// server sent is unfit to show. Callers should treat null as "no inline
  /// error" and fall back to their own copy if the field is known bad —
  /// silence beats a traceback.
  static String? fieldMessage(
    BuildContext context,
    AppFailure? failure,
    String field,
  ) {
    if (failure is! ValidationFailure) return null;
    return context.tr.presentableServerMessage(failure.firstError(field));
  }

  /// Same as [message] but takes an [AppStrings] directly — useful from
  /// surfaces without a `BuildContext` (e.g. tests, background services).
  static String messageForLocale(
    AppStrings tr,
    Object? failure, {
    String? actionContext,
  }) {
    final f = toFailure(failure);
    final base = _baseMessage(tr, f);
    if (actionContext == null || actionContext.isEmpty) return base;
    return '$actionContext · $base';
  }

  static String _baseMessage(AppStrings tr, AppFailure failure) {
    // Server-supplied messages are developer-facing English. Route them
    // through [AppStrings.presentableServerMessage], which localizes the
    // common cases (auth, missing fields, bad request, …) for Arabic AND
    // screens out text no user should ever read — tracebacks, driver
    // exceptions, SQL constraint names.
    //
    // It returns null for both "the server said nothing" and "what it said
    // is unfit to show", which collapses two guards into one and lets each
    // arm keep the fallback that actually fits it: a 409 says "refresh and
    // try again", a 5xx says "server problem". A single shared fallback
    // would tell the user the wrong thing half the time.
    return switch (failure) {
      NetworkFailure() => tr.errorNetwork,
      TimeoutFailure() => tr.errorTimeout,
      CancelledFailure() => tr.errorCancelled,
      UnauthorizedFailure() => tr.errorUnauthorized,
      ForbiddenFailure() => tr.errorForbidden,
      NotFoundFailure() => tr.errorNotFound,
      ValidationFailure(message: final m) =>
        tr.presentableServerMessage(m) ?? tr.errorValidation,
      ConflictFailure(serverMessage: final m) =>
        tr.presentableServerMessage(m) ?? tr.errorConflict,
      RateLimitFailure(retryAfterSeconds: final s) =>
        s != null && s > 0 ? tr.errorRateLimitedWithRetry(s) : tr.errorRateLimited,
      PayloadTooLargeFailure() => tr.errorPayloadTooLarge,
      // Both prefer the server's wording — it's the only source that can
      // name the actual cap, reset time or accepted formats.
      QuotaExceededFailure(serverMessage: final m) =>
        tr.presentableServerMessage(m) ?? tr.errorQuotaExceeded,
      UnsupportedMediaFailure(serverMessage: final m) =>
        tr.presentableServerMessage(m) ?? tr.errorUnsupportedMedia,
      // Deliberately NOT `errorServer`: the server is up and answering, so
      // "try again later" would be a lie the user follows into an infinite
      // retry. `detail` stays out of the UI — it's a Dart type error.
      ParseFailure() => tr.errorUnexpectedResponse,
      ServerFailure(serverMessage: final m) =>
        tr.presentableServerMessage(m) ?? tr.errorServer,
      UnknownFailure(serverMessage: final m) =>
        tr.presentableServerMessage(m) ?? tr.errorUnknown,
    };
  }
}
