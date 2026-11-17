// Per-message token cost — the chip beside an assistant reply's timestamp.
//
// Found in the full web-vs-mobile sweep. The server meters most assistant
// replies and sends `tokens: {input, output, cached_input}` (65 of 200
// messages in a real ZAD conversation); the web renders a chip with a hover
// breakdown, and the app parsed none of it.
//
// The arithmetic is the part worth pinning. `cached_input` is a SUBSET of
// `input`, not an addition to it — reading it the other way would print a
// number bigger than the one the user is billed for.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/format/compact_number.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/message_token_chip.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';

Message _msg(Object? tokens) => Message.fromJson(<String, dynamic>{
      'id': 'm1',
      'role': 'assistant',
      'content': 'done',
      'created_at': '2026-09-07T10:00:00Z',
      if (tokens != null) 'tokens': tokens,
    });

Future<void> _pumpChip(
  WidgetTester tester,
  MessageTokens tokens, {
  Locale locale = const Locale('en'),
}) async {
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
      theme: AppTheme.light(locale),
      home: Scaffold(body: Center(child: MessageTokenChip(tokens: tokens))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('reading the meter off the wire', () {
    test('the real shape the server sends', () {
      // Captured verbatim from a live conversation.
      final tokens = _msg(const {
        'input': 49634,
        'output': 895,
        'cached_input': 19456,
      }).tokens!;

      expect(tokens.input, 49634);
      expect(tokens.output, 895);
      expect(tokens.cachedInput, 19456);
      expect(tokens.total, 50529);
      // Cache is part of the input, so fresh is the remainder — not the sum.
      expect(tokens.fresh, 30178);
      expect(tokens.cacheHitPercent, 39);
    });

    test('an almost fully cached prompt', () {
      final tokens = _msg(const {
        'input': 51559,
        'output': 55,
        'cached_input': 51328,
      }).tokens!;

      expect(tokens.fresh, 231);
      expect(tokens.cacheHitPercent, 100);
    });

    test('no meter is not a free message', () {
      // Absent, empty, and explicitly zero all mean "the backend did not
      // meter this" — a chip reading 0 would claim the reply cost nothing.
      expect(_msg(null).tokens, isNull);
      expect(_msg(const <String, dynamic>{}).tokens, isNull);
      expect(_msg(const {'input': 0, 'output': 0}).tokens, isNull);
      expect(_msg(const {'cached_input': 500}).tokens, isNull);
    });

    test('a malformed meter never throws', () {
      // The parser runs over every message of every poll tick; one odd row
      // must not take the conversation with it.
      expect(_msg('lots').tokens, isNull);
      expect(_msg(const [1, 2]).tokens, isNull);
      expect(_msg(const {'input': 'abc', 'output': null}).tokens, isNull);
      // Numeric strings are still numbers.
      final coerced = _msg(const {'input': '100', 'output': '20'}).tokens!;
      expect(coerced.total, 120);
      // A double from JSON.
      final asDouble = _msg(const {'input': 10.0, 'output': 5.0}).tokens!;
      expect(asDouble.total, 15);
    });

    test('more cache than input never goes negative', () {
      // A backend reporting that is wrong; printing "-40" would be the
      // client repeating the mistake.
      final tokens = _msg(const {
        'input': 100,
        'output': 10,
        'cached_input': 140,
      }).tokens!;

      expect(tokens.fresh, 0);
    });

    test('a message with no prompt reports no cache rate', () {
      final tokens = _msg(const {'input': 0, 'output': 42}).tokens!;

      expect(tokens.cacheHitPercent, 0);
      expect(tokens.total, 42);
    });
  });

  group('what the chip shows', () {
    testWidgets('the total, compacted and localised', (tester) async {
      const tokens =
          MessageTokens(input: 49634, output: 895, cachedInput: 19456);

      final en = AppStrings(const Locale('en'));
      await _pumpChip(tester, tokens);
      expect(
        find.text(en.tokensChipLabel(compactCount(tokens.total, en))),
        findsOneWidget,
      );

      // Arabic gets Arabic units, not a hardcoded "k" — that is the whole
      // reason this does not reuse the web's formatter.
      await _pumpChip(tester, tokens, locale: const Locale('ar'));
      final ar = AppStrings(const Locale('ar'));
      expect(find.textContaining(ar.compactThousands), findsOneWidget);
      expect(find.textContaining('k'), findsNothing);
    });

    testWidgets('the breakdown is behind a tap, not in the transcript',
        (tester) async {
      const tokens =
          MessageTokens(input: 49634, output: 895, cachedInput: 19456);
      final tr = AppStrings(const Locale('en'));

      await _pumpChip(tester, tokens);

      // Not printed inline — the line under a message is not a billing table.
      expect(find.textContaining('Output:'), findsNothing);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(
        tooltip.message,
        contains(tr.tokensTotal(compactCount(tokens.total, tr))),
      );
      expect(tooltip.message, contains('Output'));
      expect(tooltip.triggerMode, TooltipTriggerMode.tap);
      // Long enough to read. The 1.5 s default is a one-line hint's budget;
      // this is three lines of six-digit numbers, and on a device it was gone
      // before they could be read.
      expect(
        tooltip.showDuration,
        greaterThanOrEqualTo(const Duration(seconds: 4)),
      );
    });

    testWidgets('a huge cost still fits its line', (tester) async {
      await _pumpChip(
        tester,
        const MessageTokens(
          input: 1234567,
          output: 98765,
          cachedInput: 1200000,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MessageTokenChip), findsOneWidget);
    });
  });
}
