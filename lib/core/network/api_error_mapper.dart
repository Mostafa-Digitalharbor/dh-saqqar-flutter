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
      // Connection-level failures (no response, DNS, handshake) never
      // pass through the ErrorInterceptor wrap — classify from Dio's
      // own type so the user still sees the right network message.
      return _fromDioType(error);
    }
    return const UnknownFailure();
  }

  static AppFailure _fromDioType(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const TimeoutFailure(),
      DioExceptionType.cancel => const CancelledFailure(),
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => const NetworkFailure(),
      DioExceptionType.badResponse => const UnknownFailure(),
      DioExceptionType.badCertificate => const NetworkFailure(),
    };
  }

  static AppFailure _fromApiException(ApiException e) {
    // Order matters — most specific first.
    if (e.statusCode == 413) return const PayloadTooLargeFailure();
    if (e.isUnauthorized) return const UnauthorizedFailure();
    if (e.isForbidden) return const ForbiddenFailure();
    if (e.isNotFound) return const NotFoundFailure();
    if (e.isConflict) return ConflictFailure(serverMessage: e.message);
    if (e.isRateLimited) {
      return RateLimitFailure(retryAfterSeconds: e.retryAfterSeconds);
    }
    if (e.isValidation || (e.fieldErrors != null && e.fieldErrors!.isNotEmpty)) {
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
    // through [localizeServerMessage] so an Arabic UI shows a localized
    // line for the common cases (auth, missing fields, bad request, …)
    // instead of leaking English. Unknown messages pass through verbatim.
    return switch (failure) {
      NetworkFailure() => tr.errorNetwork,
      TimeoutFailure() => tr.errorTimeout,
      CancelledFailure() => tr.errorCancelled,
      UnauthorizedFailure() => tr.errorUnauthorized,
      ForbiddenFailure() => tr.errorForbidden,
      NotFoundFailure() => tr.errorNotFound,
      ValidationFailure(message: final m) =>
        (m != null && m.isNotEmpty) ? tr.localizeServerMessage(m) : tr.errorValidation,
      ConflictFailure(serverMessage: final m) =>
        (m != null && m.isNotEmpty) ? tr.localizeServerMessage(m) : tr.errorConflict,
      RateLimitFailure(retryAfterSeconds: final s) =>
        s != null && s > 0 ? tr.errorRateLimitedWithRetry(s) : tr.errorRateLimited,
      PayloadTooLargeFailure() => tr.errorPayloadTooLarge,
      ServerFailure(serverMessage: final m) =>
        (m != null && m.isNotEmpty) ? tr.localizeServerMessage(m) : tr.errorServer,
      UnknownFailure(serverMessage: final m) =>
        (m != null && m.isNotEmpty) ? tr.localizeServerMessage(m) : tr.errorUnknown,
    };
  }
}
