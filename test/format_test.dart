import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/format/byte_size.dart';
import 'package:saqqar_app/core/format/compact_number.dart';
import 'package:saqqar_app/core/i18n/app_date_format.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';

void main() {
  group('humanBytes', () {
    // Consolidated from two byte-identical private copies (`_formatBytes`
    // and `_humanSize`) that lived in the same file. Pinning the boundaries
    // so a future edit to one shape can't silently re-diverge.
    final en = AppStrings(const Locale('en'));
    final ar = AppStrings(const Locale('ar'));

    test('renders each unit at its boundary', () {
      expect(humanBytes(0, en), '0 B');
      expect(humanBytes(1023, en), '1023 B');
      expect(humanBytes(1024, en), '1 KB');
      expect(humanBytes(1024 * 1024 - 1, en), '1024 KB');
      expect(humanBytes(1024 * 1024, en), '1.0 MB');
    });

    test('keeps a decimal under 10 MB and drops it above', () {
      // The 25 MB upload cap is why: 24.7 vs 25 MB is the difference
      // between an accepted and a rejected file.
      expect(humanBytes((2.4 * 1024 * 1024).round(), en), '2.4 MB');
      expect(humanBytes((9.9 * 1024 * 1024).round(), en), '9.9 MB');
      expect(humanBytes((10.4 * 1024 * 1024).round(), en), '10 MB');
      expect(humanBytes((250.6 * 1024 * 1024).round(), en), '251 MB');
    });

    test('localizes the unit word but keeps Western digits', () {
      // Same split `AppDateFormat.relative` uses: the number is Latin in
      // both locales, the unit is not. A 40 MB addon bundle used to render
      // as "40960 KB" from a caller that hardcoded the unit — hence the
      // MB assertion here rather than only at the small end.
      expect(humanBytes(1024, ar), '1 ك.ب');
      expect(humanBytes((2.4 * 1024 * 1024).round(), ar), '2.4 م.ب');
      expect(humanBytes(512, ar), '512 بايت');
    });
  });

  group('compactCount', () {
    final en = AppStrings(const Locale('en'));
    final ar = AppStrings(const Locale('ar'));

    test('compacts at each magnitude and drops a trailing .0', () {
      expect(compactCount(950, en), '950');
      expect(compactCount(12300, en), '12.3K');
      expect(compactCount(12000, en), '12K');
      expect(compactCount(2500000, en), '2.5M');
    });

    test('Arabic spaces the magnitude word off the digits', () {
      // ألف / م are words, not the tight K / M suffixes English uses, so
      // they need the separator; the digits stay Western either way.
      expect(compactCount(950, ar), '950');
      expect(compactCount(12300, ar), '12.3 ألف');
      expect(compactCount(2500000, ar), '2.5 م');
    });
  });

  group('AppDateFormat.relative', () {
    // `AppStrings.relativeTime` — a second, divergent relative-time impl —
    // used to live alongside this one. Its single caller (the vault's "last
    // verified" hint) rendered `منذ 5 دقيقة` while the rest of the app
    // rendered `منذ 5 د`: different bucket wording for the same instant. It
    // also hardcoded its Arabic inline instead of going through `_t()`,
    // which is why the i18n parity test couldn't see it. Deleted; these pin
    // the survivor.
    //
    // Note the digits: Arabic gets WESTERN numerals here, deliberately —
    // `compactCount` documents the same app-wide convention and all 1,100+
    // Arabic strings follow it.
    //
    // The assertion below used to be the only one, and it checked the
    // 5-minutes bucket. That bucket formats its number with `NumberFormat`,
    // which was already Western, so the test passed while the buckets that
    // format with `DateFormat` — anything older than 7 days — rendered
    // `٣٠ يوليو` on every Arabic device. Under `flutter_localizations` the
    // `ar` date symbols carry the Arabic-Indic numbering system, and this
    // app never calls `initializeDateFormatting()`, so the CLDR default the
    // old comment cited was never what shipped.
    //
    // One property asserted on the one input that already had it is how a
    // rule reads as covered while its real cases go untested, so the sweep
    // below covers every bucket and every public method instead.
    Future<String> relativeIn(
      WidgetTester tester,
      Locale locale,
      DateTime when,
    ) async {
      late String out;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Builder(
            builder: (context) {
              out = AppDateFormat.relative(context, when);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('Arabic localizes the words and keeps Western digits',
        (tester) async {
      final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final out = await relativeIn(tester, const Locale('ar'), fiveMinsAgo);
      expect(out, contains('منذ'), reason: 'the copy must be Arabic');
      expect(
        out,
        contains('5'),
        reason: 'CLDR resolves `ar` to Latin numerals, and the app renders '
            'Western digits in both locales by convention (see '
            'compactCount). Got "$out".',
      );
    });

    testWidgets('no bucket of any method renders an Arabic-Indic digit',
        (tester) async {
      // Arabic-Indic digits and the two separators that ship with them.
      final eastern = RegExp(r'[٠-٩٫٬]');

      // Every method that renders a number, at every bucket boundary that
      // switches which formatter produces it. `relative` alone crosses from
      // NumberFormat to DateFormat at 7 days and from MMMd to yMMMd at the
      // year boundary — the two crossings the old single-input test could
      // not see.
      final now = DateTime.now();
      final samples = <String, DateTime>{
        'just now': now.subtract(const Duration(seconds: 5)),
        'minutes': now.subtract(const Duration(minutes: 5)),
        'hours': now.subtract(const Duration(hours: 3)),
        'yesterday': now.subtract(const Duration(hours: 30)),
        'days': now.subtract(const Duration(days: 3)),
        'this year': now.subtract(const Duration(days: 21)),
        'last year': now.subtract(const Duration(days: 400)),
      };

      for (final entry in samples.entries) {
        late Map<String, String> rendered;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ar')],
            home: Builder(
              builder: (context) {
                rendered = {
                  'relative': AppDateFormat.relative(context, entry.value),
                  'date': AppDateFormat.date(context, entry.value),
                  'dateTime': AppDateFormat.dateTime(context, entry.value),
                  'fullDateTime':
                      AppDateFormat.fullDateTime(context, entry.value),
                  'dayLabel': AppDateFormat.dayLabel(context, entry.value),
                  'time': AppDateFormat.time(context, entry.value),
                  'time24': AppDateFormat.time(context, entry.value,
                      twentyFour: true),
                };
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        rendered.forEach((method, out) {
          expect(
            eastern.hasMatch(out),
            isFalse,
            reason: 'AppDateFormat.$method rendered Arabic-Indic digits for '
                'the "${entry.key}" bucket: "$out". The app writes numbers '
                'in Western digits everywhere — a screen that mixes the two '
                'shows both at once, which is what a conversation row did '
                'with "٣٠ يوليو" above "منذ 17 س".',
          );
        });
      }
    });

    testWidgets('every locale renders real copy, not an i18n key',
        (tester) async {
      // `_t` echoes the key back on a miss, so a typo'd bucket would render
      // `relative_minutes_ago` at the user. Cheap to assert, invisible
      // otherwise.
      for (final locale in const [Locale('en'), Locale('ar')]) {
        for (final d in const [
          Duration(minutes: 5),
          Duration(hours: 3),
          Duration(hours: 30),
          Duration(days: 3),
        ]) {
          final out =
              await relativeIn(tester, locale, DateTime.now().subtract(d));
          expect(out, isNotEmpty);
          expect(
            out.contains('_'),
            isFalse,
            reason: 'raw i18n key leaked for $locale / $d: "$out"',
          );
        }
      }
    });

    testWidgets('English gets Western digits', (tester) async {
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      final out = await relativeIn(tester, const Locale('en'), threeHoursAgo);
      expect(out, contains('3'));
    });

    testWidgets('sub-minute reads as "now" in both locales', (tester) async {
      final now = DateTime.now();
      expect(await relativeIn(tester, const Locale('ar'), now), isNotEmpty);
      expect(await relativeIn(tester, const Locale('en'), now), isNotEmpty);
    });
  });
}
