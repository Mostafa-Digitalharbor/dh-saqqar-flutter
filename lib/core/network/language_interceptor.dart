import 'dart:ui';

import 'package:dio/dio.dart';

import 'api_headers.dart';

/// Tells the server which language to answer in.
///
/// Every request carries `Accept-Language: <ar|en>`, resolved from the user's
/// live locale preference — not from the locale that happened to be active at
/// boot, which is why this takes a callback rather than a value.
///
/// **Why it matters beyond pricing.** The backend shipped content negotiation
/// on `GET /plans/` (2026-08-12), so the descriptive plan copy — tagline,
/// bullets, `price_note`, even the tier `name` — now comes back Arabic for an
/// Arabic reader instead of English the app has to translate locally. The same
/// header also lets any endpoint localize the `error` string in the failure
/// envelope, which is the text `ApiErrorMapper` prefers over its own generic
/// copy: without the header an Arabic user reads a server error in English.
///
/// **Only the primary tag is sent** (`ar`, not `ar-SA`). The backend keys on
/// the primary subtag, and a region we don't ship copy for would only add a
/// way for the two sides to disagree.
///
/// Set on the request rather than in `BaseOptions` for two reasons: the value
/// changes at runtime when the user flips the language switch, and an explicit
/// per-call header (the i18n bundle fetch, say) must be able to win — hence
/// `putIfAbsent` rather than an assignment.
class LanguageInterceptor extends Interceptor {
  const LanguageInterceptor(this._locale);

  /// Resolves the locale in force right now. `PlatformStrings.locale` is the
  /// production implementation — it applies the stored preference, falls back
  /// to the system locale, and validates both against the locales we ship.
  final Locale Function() _locale;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(
      ApiHeaders.acceptLanguage,
      () => _locale().languageCode,
    );
    handler.next(options);
  }
}
