import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/ui_strings.dart';
import '../i18n/app_strings.dart';
import 'api_exception.dart';

/// Converts every [DioException] into an [ApiException] so the upper layers
/// don't have to know Dio.
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

    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) message = data['detail'] as String;
      if (data['code'] is String) code = data['code'] as String;

      // Per-field DRF validation errors.
      final fieldKeys = data.keys.where((k) => k != 'detail' && k != 'code');
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
    );
  }
}
