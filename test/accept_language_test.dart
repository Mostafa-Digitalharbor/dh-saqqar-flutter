// `Accept-Language` — the header that decides which language the SERVER
// answers in.
//
// Two things depend on it, and both used to be handled on this side:
//
//   1. `/plans/` carries descriptive copy (tagline, bullets, `price_note`,
//      even the tier `name`). It shipped English-only, so the app mirrored a
//      table of Arabic translations keyed by the server's English text. That
//      table decays silently — edit a bullet's English on the server and the
//      key stops matching, so an Arabic phone quietly shows English. The
//      backend added content negotiation on 2026-08-12; sending the header is
//      the whole client half.
//
//   2. Every failure envelope. `ApiErrorMapper` prefers the server's own
//      `error` string over its generic copy, because only the server can name
//      the actual cause. Without the header that sentence arrives in English
//      and gets shown, verbatim, to a reader who chose Arabic.
//
// So the property under test is not "a header is set" but "the header follows
// the user, at the moment of the request".

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/core/network/api_headers.dart';
import 'package:saqqar_app/core/network/language_interceptor.dart';

class _Recorder implements HttpClientAdapter {
  final headers = <Map<String, List<String>>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers.add({
      for (final e in options.headers.entries) e.key: ['${e.value}'],
    });
    return ResponseBody.fromString(
      jsonEncode(const {'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Recorder recorder;
  late Locale locale;
  late Dio dio;

  String? sentLanguage([int index = 0]) =>
      recorder.headers[index][ApiHeaders.acceptLanguage]?.single;

  setUp(() {
    recorder = _Recorder();
    locale = const Locale(UiStrings.localeArabicCode);
    dio = Dio(BaseOptions(baseUrl: 'http://x/'))
      ..httpClientAdapter = recorder
      ..interceptors.add(LanguageInterceptor(() => locale));
  });

  test('an Arabic reader asks the server for Arabic', () async {
    await dio.get<Map<String, dynamic>>('/api/v1/plans/');

    expect(sentLanguage(), UiStrings.localeArabicCode);
  });

  test('an English reader asks for English', () async {
    locale = const Locale(UiStrings.localeEnglishCode);

    await dio.get<Map<String, dynamic>>('/api/v1/plans/');

    expect(sentLanguage(), UiStrings.localeEnglishCode);
  });

  test('switching language changes the very next request', () async {
    // The reason the interceptor takes a callback rather than a value. A
    // locale captured at boot would pin every call for the rest of the
    // session to whatever language the app started in — which is exactly the
    // bug a user hits by installing in English and switching to Arabic.
    await dio.get<Map<String, dynamic>>('/api/v1/plans/');
    locale = const Locale(UiStrings.localeEnglishCode);
    await dio.get<Map<String, dynamic>>('/api/v1/plans/');

    expect(sentLanguage(0), UiStrings.localeArabicCode);
    expect(sentLanguage(1), UiStrings.localeEnglishCode);
  });

  test('only the primary tag is sent, never a region', () async {
    // The backend keys on the primary subtag. `ar-SA` would still match, but
    // a region we ship no copy for is only a way for the two sides to
    // disagree about what "Arabic" means.
    locale = const Locale('ar', 'SA');

    await dio.get<Map<String, dynamic>>('/api/v1/plans/');

    expect(sentLanguage(), UiStrings.localeArabicCode);
  });

  test('an explicit per-call header wins', () async {
    // The i18n bundle fetch names its own language in the path AND may want
    // to name it in the header; a blanket assignment would overwrite it.
    await dio.get<Map<String, dynamic>>(
      '/api/v1/i18n/en.json',
      options: Options(
        headers: {ApiHeaders.acceptLanguage: UiStrings.localeEnglishCode},
      ),
    );

    expect(sentLanguage(), UiStrings.localeEnglishCode);
  });
}
