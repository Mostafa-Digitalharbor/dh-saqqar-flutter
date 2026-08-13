/// HTTP header names and fixed header values the client sends.
///
/// Wire-protocol identifiers, not copy — they are never translated and never
/// vary by locale, so they live here rather than in `app_strings`. Named in
/// one place so `buildDio`, `AuthInterceptor` and `LanguageInterceptor` can't
/// drift on capitalisation or spelling (`Accept-Language` vs `accept-language`
/// is the same header to a server, but two different keys in Dio's map — and
/// setting both sends it twice).
class ApiHeaders {
  ApiHeaders._();

  static const String accept = 'Accept';
  static const String acceptLanguage = 'Accept-Language';
  static const String authorization = 'Authorization';
  static const String retryAfter = 'retry-after';

  static const String applicationJson = 'application/json';

  /// Scheme prefix for the bearer token, including the trailing space.
  static const String bearerPrefix = 'Bearer ';
}
