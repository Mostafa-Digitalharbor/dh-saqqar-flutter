// An over-quota send must say *why*, not "couldn't send".
//
// Backend change of 2026-08-03 (`MOBILE_BACKEND_OPEN_ITEMS.md` §3.1): sending
// a message with the daily cap already spent now answers **402** instead of
// accepting it with a 200 and then never producing a reply. Before that, the
// only signal was a banner elsewhere on the screen — the send itself looked
// like it had worked, and the user sat waiting for an answer that was never
// coming.
//
// This pins the client half: a 402 has to reach the user as the quota message
// the server sent, localized, and not collapse into the generic
// "Something went wrong". It is asserted at the mapper because that is the one
// place every surface — chat toast, composer tooltip, banner — reads from.
//
// Not verifiable end-to-end on demand: exhausting a real daily cap costs a
// day's tokens, and the QA account is `exempt: true` on Business. This is the
// level at which it *can* be held.

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/network/api_error_mapper.dart';
import 'package:saqqar_app/core/network/api_exception.dart';

ApiException _quota({String message = ''}) => ApiException(
      kind: ApiExceptionKind.badResponse,
      message: message,
      statusCode: 402,
    );

void main() {
  group('402 from POST /conversations/<id>/messages/', () {
    test('classifies as a quota failure, not a generic one', () {
      final f = ApiErrorMapper.toFailure(_quota(message: 'Daily cap reached.'));
      expect(f, isA<QuotaExceededFailure>());
      expect((f as QuotaExceededFailure).serverMessage, 'Daily cap reached.');
    });

    test('a 402 with no body still reads as a quota problem', () {
      // The server is not obliged to send prose. Falling back to "Something
      // went wrong" here would lose the one fact the user needs.
      final f = ApiErrorMapper.toFailure(_quota());
      expect(f, isA<QuotaExceededFailure>());
      expect((f as QuotaExceededFailure).serverMessage, isNull);
    });

    for (final locale in const ['en', 'ar']) {
      test('renders a quota-specific message in $locale', () {
        final tr = AppStrings(Locale(locale));
        final generic = ApiErrorMapper.messageForLocale(
          tr,
          const UnknownFailure(),
        );
        final quota = ApiErrorMapper.messageForLocale(
          tr,
          ApiErrorMapper.toFailure(_quota()),
        );

        expect(quota, isNotEmpty);
        expect(
          quota,
          isNot(generic),
          reason: 'an over-quota send must not read like an unknown error',
        );
        expect(quota, tr.errorQuotaExceeded);
      });
    }

    test('a server-supplied reason wins over our default', () {
      final tr = AppStrings(const Locale('en'));
      final msg = ApiErrorMapper.messageForLocale(
        tr,
        ApiErrorMapper.toFailure(_quota(message: 'Weekly cap reached.')),
      );
      expect(msg, contains('Weekly cap reached'));
    });
  });
}
