import 'dart:ui';

import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'api_endpoints.dart';
import 'api_headers.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import 'language_interceptor.dart';
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
///   2. LanguageInterceptor — attaches `Accept-Language` from the user's
///      live locale, so the server answers (and errors) in their language.
///   3. LoggingInterceptor — logs the *final* outgoing request (after the
///      auth and language headers are attached) and the *first-seen*
///      response/error before anything else can rewrite them.
///   4. ErrorInterceptor — normalizes DioException → ApiException for the
///      UI layer. Sits last so the logger has already printed the raw body.
///
/// [localeResolver] is read per request, never cached: the user can flip the
/// language switch at any point and the next call must follow them. Omit it
/// only where no server copy is rendered (tests that assert on transport).
/// How long a request may spend on each phase before Dio gives up.
///
/// These reach the user directly: every one of them surfaces as
/// `AppFailure.timeout` and, from there, as the "the server took too long"
/// message. The connect budget is short because failing to reach the host
/// at all is usually a dead network and the user is better served by a fast
/// error than a long spinner; the send and receive budgets are longer
/// because an agent turn legitimately takes seconds.
class _Timeouts {
  _Timeouts._();
  static const connect = Duration(seconds: 15);
  static const send = Duration(seconds: 30);
  static const receive = Duration(seconds: 30);
}

Dio buildDio(
  SecureTokenStore store, {
  void Function()? onUnauthorized,
  Locale Function()? localeResolver,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: _Timeouts.connect,
      sendTimeout: _Timeouts.send,
      receiveTimeout: _Timeouts.receive,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {ApiHeaders.accept: ApiHeaders.applicationJson},
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(store, onUnauthorized: onUnauthorized),
    if (localeResolver != null) LanguageInterceptor(localeResolver),
    LoggingInterceptor(),
    ErrorInterceptor(),
  ]);

  return dio;
}
