// Every failure the app can classify must reach the user as real, localized
// copy — in both locales, with no exceptions and no gaps.
//
// `api_error_localization_test.dart` already guards the seam a failure travels
// through, and it guards it well. What it cannot do is guarantee COVERAGE: its
// assertions name the failures a person thought to list, and the list stopped
// at eight of the sixteen `AppFailure` subtypes. `CancelledFailure`,
// `RateLimitFailure`, `PayloadTooLargeFailure`, `NotFoundFailure` and three
// more were never asserted in either locale.
//
// That gap is not theoretical. `AppFailure` is a sealed hierarchy precisely so
// that adding a category forces a `switch` arm in `ApiErrorMapper._baseMessage`
// — but the compiler only insists that an arm EXISTS. It cannot tell that the
// arm returns copy rather than an unresolved key, and it has nothing at all to
// say about whether the Arabic table was updated. A new failure type therefore
// ships compiling, passing, and rendering `error_something_new` to an Arabic
// user.
//
// So this file drives off the hierarchy itself rather than off a list someone
// maintains: it parses `app_failure.dart` for every subtype and fails if one
// is not exercised below. Adding a failure category without adding its copy
// now breaks the build in the file that describes the rule.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/network/api_error_mapper.dart';

void main() {
  final en = AppStrings(const Locale(UiStrings.localeEnglishCode));
  final ar = AppStrings(const Locale(UiStrings.localeArabicCode));

  /// One instance of every `AppFailure` subtype.
  ///
  /// Each is built in its *bare* form — no `serverMessage`, no
  /// `retryAfterSeconds`, no `fieldErrors`. That is deliberate and it is the
  /// whole point: every arm of `_baseMessage` prefers the server's own wording
  /// when there is any, so an instance carrying a `serverMessage` would render
  /// that string and prove nothing about the `error_*` table behind it. The
  /// bare form is also the one a user actually meets most — a bodiless 5xx, a
  /// dropped connection, a 404 — because those are exactly the responses with
  /// no wording to borrow.
  final failures = <String, AppFailure>{
    'NetworkFailure': const NetworkFailure(),
    'TimeoutFailure': const TimeoutFailure(),
    'CancelledFailure': const CancelledFailure(),
    'UnauthorizedFailure': const UnauthorizedFailure(),
    'ForbiddenFailure': const ForbiddenFailure(),
    'NotFoundFailure': const NotFoundFailure(),
    'ValidationFailure': const ValidationFailure(),
    'ConflictFailure': const ConflictFailure(),
    'RateLimitFailure': const RateLimitFailure(),
    'PayloadTooLargeFailure': const PayloadTooLargeFailure(),
    'QuotaExceededFailure': const QuotaExceededFailure(),
    'UnsupportedMediaFailure': const UnsupportedMediaFailure(),
    'ServerFailure': const ServerFailure(),
    'ParseFailure': const ParseFailure(),
    'SocialSignInFailure': const SocialSignInFailure(
      SocialSignInProblem.notConfigured,
    ),
    'UnknownFailure': const UnknownFailure(),
  };

  group('the failure hierarchy is covered exhaustively', () {
    test('every AppFailure subtype is exercised by this file', () {
      // Read from the SOURCE, not from a list here, so the day someone adds a
      // seventeenth failure this test fails rather than silently narrowing.
      final source =
          File('lib/core/error/app_failure.dart').readAsStringSync();
      final declared = RegExp(r'class (\w+) extends AppFailure')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        declared,
        isNotEmpty,
        reason: 'parse of app_failure.dart found no subtypes — did it move?',
      );

      final missing = declared.difference(failures.keys.toSet()).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'These `AppFailure` subtypes exist but are not exercised '
            'here, so nothing proves they render real copy in Arabic:\n'
            '${missing.join('\n')}\n\n'
            'Fix: add an instance to `failures` above. If it needs '
            'constructor arguments, pass the BARE form — the point is to '
            'reach the `error_*` table, not the server message that would '
            'shadow it.',
      );

      final stale = failures.keys.toSet().difference(declared).toList()..sort();
      expect(
        stale,
        isEmpty,
        reason: 'These are exercised here but no longer exist in '
            'app_failure.dart — drop them:\n${stale.join('\n')}',
      );
    });
  });

  group('every failure renders real copy in both locales', () {
    failures.forEach((name, failure) {
      test('$name resolves in English and Arabic', () {
        for (final tr in [en, ar]) {
          final message = ApiErrorMapper.messageForLocale(tr, failure);

          expect(
            message.trim(),
            isNotEmpty,
            reason: '$name rendered nothing. The user would see a blank '
                'toast, which reads as the app doing nothing at all.',
          );

          // `_t` echoes the key back when it resolves nowhere, so an
          // untranslated failure surfaces as `error_rate_limited` rather than
          // as a sentence. That is the exact shape a missing table entry
          // takes, and it is invisible to `flutter analyze`.
          expect(
            RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(message.trim()),
            isFalse,
            reason: '$name rendered "$message" — that is a raw i18n key, not '
                'copy. Add the entry to BOTH tables in app_strings.dart.',
          );
        }
      });
    });

    test('the Arabic copy is actually Arabic', () {
      // The failure that key-parity cannot see: an `_ar` entry that exists but
      // was copy-pasted from English passes every structural check and then
      // renders Latin text inside an otherwise-Arabic error toast.
      final arabicScript = RegExp(r'[؀-ۿ]');
      final offenders = <String>[];

      failures.forEach((name, failure) {
        final message = ApiErrorMapper.messageForLocale(ar, failure);
        if (!arabicScript.hasMatch(message)) {
          offenders.add('$name = $message');
        }
      });

      expect(
        offenders,
        isEmpty,
        reason: 'These failures render no Arabic script, so an Arabic user '
            'reads English when something goes wrong — the moment they are '
            'least able to cope with it:\n${offenders.join('\n')}',
      );
    });

    test('English and Arabic are genuinely different strings', () {
      // Catches the copy-paste that the script check above cannot: an Arabic
      // entry that duplicates its English source *and* happens to contain an
      // Arabic character (a mixed sentence, a borrowed brand name).
      final identical = <String>[];
      failures.forEach((name, failure) {
        final e = ApiErrorMapper.messageForLocale(en, failure);
        final a = ApiErrorMapper.messageForLocale(ar, failure);
        if (e == a) identical.add('$name = $e');
      });

      expect(
        identical,
        isEmpty,
        reason: 'These render the same string in both locales, which means '
            'the Arabic entry was never written:\n${identical.join('\n')}',
      );
    });
  });

  group('the action prefix composes without swallowing the cause', () {
    // Screens pass `actionContext` to say WHICH operation failed
    // ("Couldn't create the project · No internet connection…"). A prefix that
    // replaced the cause instead of joining it would leave the user knowing
    // what failed but not why, and the bug would look like correct output.
    test('every failure keeps its own message behind the prefix', () {
      for (final tr in [en, ar]) {
        failures.forEach((name, failure) {
          final bare = ApiErrorMapper.messageForLocale(tr, failure);
          final prefixed = ApiErrorMapper.messageForLocale(
            tr,
            failure,
            actionContext: tr.vaultActionCreateProjectFailed,
          );

          expect(
            prefixed,
            contains(bare),
            reason: '$name lost its cause when an action prefix was applied.',
          );
          expect(
            prefixed,
            startsWith(tr.vaultActionCreateProjectFailed),
            reason: '$name did not lead with the action that failed.',
          );
        });
      }
    });

    test('an empty prefix is not rendered as a dangling separator', () {
      // `''` and `null` both mean "no operation named". An empty string that
      // still took the join branch would render " · No internet connection",
      // which looks like a rendering bug to the one user who sees it.
      for (final tr in [en, ar]) {
        expect(
          ApiErrorMapper.messageForLocale(
            tr,
            const NetworkFailure(),
            actionContext: '',
          ),
          equals(ApiErrorMapper.messageForLocale(tr, const NetworkFailure())),
        );
      }
    });
  });

  group('the HTTP statuses the backend documents each get their own copy', () {
    // The mapper's job is to turn a status into something ACTIONABLE. A code
    // that falls through to `UnknownFailure` renders "Something went wrong.
    // Please try again." — which is wrong advice for most of these: retrying a
    // 402, a 413 or a 415 replays the same rejection forever.
    //
    // Driven through `toFailure` so it exercises the real classification path
    // rather than asserting against the switch it is meant to be checking.
    const expected = <int, Type>{
      401: UnauthorizedFailure,
      402: QuotaExceededFailure,
      403: ForbiddenFailure,
      404: NotFoundFailure,
      409: ConflictFailure,
      413: PayloadTooLargeFailure,
      415: UnsupportedMediaFailure,
      422: ValidationFailure,
      429: RateLimitFailure,
      500: ServerFailure,
      502: ServerFailure,
      503: ServerFailure,
      504: ServerFailure,
    };

    expected.forEach((code, type) {
      test('$code classifies as $type', () {
        final failure = ApiErrorMapper.toFailure(_badResponse(code));
        expect(failure.runtimeType, type);

        // And it must still say something, in both locales.
        for (final tr in [en, ar]) {
          expect(ApiErrorMapper.messageForLocale(tr, failure).trim(), isNotEmpty);
        }
      });
    });

    test('an unmapped 4xx still says something rather than nothing', () {
      // 418, 451, anything the backend grows later. It lands on
      // `UnknownFailure` by design — but "by design" has to mean copy, not a
      // blank toast.
      for (final code in [418, 451]) {
        final failure = ApiErrorMapper.toFailure(_badResponse(code));
        for (final tr in [en, ar]) {
          expect(
            ApiErrorMapper.messageForLocale(tr, failure).trim(),
            isNotEmpty,
            reason: 'HTTP $code rendered nothing.',
          );
        }
      }
    });
  });
}

/// A `DioException` carrying only a status code.
///
/// Built by hand rather than driven through a stub adapter because the
/// question here is narrow — "does this STATUS classify correctly" — and a
/// full transport round-trip would also exercise `ErrorInterceptor`, which
/// `api_error_localization_test.dart` already owns.
DioException _badResponse(int code) {
  final options = RequestOptions(path: '/');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: options, statusCode: code),
  );
}
