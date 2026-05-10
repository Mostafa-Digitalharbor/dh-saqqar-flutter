import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_store.dart';
import 'api_endpoints.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';

Dio _build(SecureTokenStore store) {
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

  dio.interceptors.addAll([AuthInterceptor(store, dio), ErrorInterceptor()]);

  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(secureTokenStoreProvider);
  return _build(store);
});
