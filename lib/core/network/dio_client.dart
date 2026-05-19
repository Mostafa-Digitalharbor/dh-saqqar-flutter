import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'api_endpoints.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import 'logging_interceptor.dart';

/// Builds the app's single [Dio] instance.
///
/// DI: provided at app boot via `RepositoryProvider<Dio>` (see `main.dart`).
/// Repositories (`AuthApi`, `ProjectsApi`, …) take it via constructor and
/// are themselves provided one layer up so cubits can read them cheaply
/// with `context.read<AuthApi>()`.
///
/// Interceptor order is load-bearing:
///   1. AuthInterceptor — attaches Bearer + clears the token on 401
///      (queued so concurrent requests share the same outcome).
///   2. LoggingInterceptor — logs the *final* outgoing request (after the
///      auth header is attached) and the *first-seen* response/error
///      before anything else can rewrite them.
///   3. ErrorInterceptor — normalizes DioException → ApiException for the
///      UI layer. Sits last so the logger has already printed the raw body.
Dio buildDio(
  SecureTokenStore store, {
  void Function()? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(store, onUnauthorized: onUnauthorized),
    LoggingInterceptor(),
    ErrorInterceptor(),
  ]);

  return dio;
}
