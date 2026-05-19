import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/ui_strings.dart';
import '../i18n/app_strings.dart';
import 'api_exception.dart';

/// Converts every [DioException] into an [ApiException] so the upper layers
/// don't have to know Dio.
///
/// The backend envelope is `{ "ok": false, "error": "human msg" }` per
/// SAQQAR_MOBILE_API.md §14, with optional `auth: false` on 401 and
/// `retry_after: <seconds>` on 429. We read `error` first, fall back to
/// the DRF default `detail`, then field errors.
class ErrorInterceptor extends Interceptor {
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

  static ApiException _mapToApiException(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;

    String message = AppStrings(
      const Locale(UiStrings.localeEnglishCode),
    ).defaultApiError;
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
      const reservedKeys = {
        'ok',
        'error',
        'detail',
        'code',
        'auth',
        'retry_after',
      };
      final fieldKeys = data.keys.where((k) => !reservedKeys.contains(k));
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
    if (retryAfter == null) {
      final headerValue = err.response?.headers.value('retry-after');
      if (headerValue != null) {
        retryAfter = int.tryParse(headerValue);
      }
    }

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
      message: message,
      statusCode: status,
      code: code,
      fieldErrors: fieldErrors,
      retryAfterSeconds: retryAfter,
    );
  }
}
