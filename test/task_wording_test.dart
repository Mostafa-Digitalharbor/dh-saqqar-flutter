// Task wording — the app's half of the web's prompt bank.
//
// Found in the full web-vs-mobile sweep. The app offered four hardcoded
// starter prompts here, on a comment that read "the backend exposes no
// saved-prompt catalogue". `/api/v1/prompt-memory/` is that catalogue: it
// returns the user's own past tasks and, given rough text, an LLM rewrite of
// it. A live call on 2026-09-08 came back with this account's real history
// and a fully structured Arabic task prompt, so the phone was showing four
// generic examples in place of a working feature.
//
// Three things are worth pinning, and they are the three that would fail
// quietly: the ten-word bar that decides when to offer at all, the parser's
// treatment of a response with no draft, and the card handing back EDITED
// text rather than the draft it was given.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/prompt_memory_api.dart';
import 'package:saqqar_app/features/chat/data/task_wording_intent.dart';
import 'package:saqqar_app/features/chat/widgets/task_wording_card.dart';
import 'package:saqqar_app/features/chat/widgets/task_wording_hint_bar.dart';

/// A Dio whose one route answers with [body].
Dio _dioReturning(Map<String, dynamic> body, {void Function(Map<String, dynamic>)? onQuery}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  dio.httpClientAdapter = _FakeAdapter(body, onQuery);
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body, this.onQuery);

  final Map<String, dynamic> body;
  final void Function(Map<String, dynamic>)? onQuery;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onQuery?.call(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// [settle] is false for the loading state: its spinner animates forever, so
/// `pumpAndSettle` would sit there until the timeout rather than reporting
/// anything about the widget.
Future<void> _pump(WidgetTester tester, Widget child,
    {Locale locale = const Locale('en'), bool settle = true}) async {
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('when the offer appears at all', () {
    test('ten words is not a task; eleven is', () {
      // The web's exact bar. One word either side of it, so a change to the
      // threshold cannot pass unnoticed.
      final ten = List.filled(10, 'word').join(' ');
      final eleven = List.filled(11, 'word').join(' ');

      expect(looksLikeLongTaskPrompt(ten), isFalse);
      expect(looksLikeLongTaskPrompt(eleven), isTrue);
    });

    test('a real Arabic task crosses it', () {
      expect(
        looksLikeLongTaskPrompt(
          'اعرض المنتجات الراكدة في مخزونك خلال فترة الحركة الحالية، ورتبها '
          'حسب قيمة المخزون واقترح تصفية أو مراجعة سعر بدون تعديل.',
        ),
        isTrue,
      );
    });

    test('nothing to offer on an empty or short composer', () {
      expect(looksLikeLongTaskPrompt(''), isFalse);
      expect(looksLikeLongTaskPrompt('   '), isFalse);
      expect(looksLikeLongTaskPrompt('كام مستخدم عندي؟'), isFalse);
    });

    test('someone who already asked for it is not asked again', () {
      // Offering "shall I structure this?" to a user who typed "رتب المهمة"
      // is the app not listening. The web suppresses the same way.
      expect(
        isTaskWordingCommand('رتب المهمة: اعمل تقرير مبيعات الشهر الماضي'),
        isTrue,
      );
      expect(isTaskWordingCommand('structure task'), isTrue);
      expect(
        looksLikeLongTaskPrompt(
          'رتبلي التاسك ده عشان عايز اعمل تقرير مبيعات عن الشهر اللي فات '
          'بالتفصيل',
        ),
        isFalse,
      );
    });

    test('spelling variants of the same Arabic word are one word', () {
      // The normaliser is why 'المهمه' and 'المهمة' both match. Without it
      // the command check misses whichever spelling the user happens to use.
      expect(normalizePromptIntent('المهمة'), normalizePromptIntent('المهمه'));
      expect(normalizePromptIntent('أحمد'), normalizePromptIntent('احمد'));
      expect(isTaskWordingCommand('صياغة المهمة'), isTrue);
      expect(isTaskWordingCommand('صياغه المهمه'), isTrue);
    });

    test('dismissal is per-text, not forever', () {
      // Same text keys the same; a different task asks again. A single
      // "dismissed" boolean would silence the feature after one decline.
      const a = 'اعمل تقرير مبيعات مفصل عن الشهر اللي فات لكل فرع على حدة';
      const b = 'راجع فواتير الموردين غير المدفوعة ورتبها حسب تاريخ الاستحقاق';
      expect(taskWordingHintKey(a), taskWordingHintKey('  $a  '));
      expect(taskWordingHintKey(a), isNot(taskWordingHintKey(b)));
      expect(taskWordingHintKey(''), isEmpty);
    });

    test('Arabic-Indic digits survive normalisation', () {
      // The obvious way to write the diacritic range with literal characters
      // spans U+064B-U+0670, which quietly includes U+0660-U+0669 -- the
      // Arabic-Indic digits. Stripping those drops every figure out of a task
      // before its words are counted, and makes two tasks that differ only in
      // a number share one dismissal key: declining the offer on one silences
      // it on the other.
      expect(normalizePromptIntent('٥ فروع'),
          contains('٥'));
      expect(
        taskWordingHintKey('اعمل تقرير لـ ٥ فروع'),
        isNot(taskWordingHintKey('اعمل تقرير لـ ٧ فروع')),
      );
      // And the diacritics it is actually for are still removed.
      expect(normalizePromptIntent('مَهمّة'),
          normalizePromptIntent('مهمة'));
    });

    test('a very long task keys on its head, not its tail', () {
      final long = 'ا' * 400;
      expect(taskWordingHintKey(long).length, 180);
    });
  });

  group('reading the catalogue off the wire', () {
    test('the real shape the server sends', () async {
      // Captured from `GET /api/v1/prompt-memory/` on 2026-09-08.
      final api = PromptMemoryApi(_dioReturning({
        'ok': true,
        'prompts': [
          {
            'id': 'bf004ba4',
            'source': 'memory',
            'title': 'ضيف منتج جديد اي اسم واي سعر',
            'description': 'محفوظ من مهمة سابقة',
            'prompt_template': 'ضيف منتج جديد اي اسم واي سعر',
            'use_count': 2,
          },
        ],
        'draft': {
          'id': 'draft-925d1130ad2e',
          'source': 'draft',
          'title': 'صياغة مقترحة للمهمة',
          'description': 'توضّح نوع المهمة الحقيقي.',
          'prompt_template': 'الهدف: رصد المنتجات ذات المخزون المنخفض.',
        },
        'total_saved': 42,
      }));

      final result = await api.fetch(lang: 'ar', query: 'مخزون قليل');

      expect(result.draft, isNotNull);
      expect(result.draft!.isDraft, isTrue);
      expect(result.draft!.promptTemplate,
          'الهدف: رصد المنتجات ذات المخزون المنخفض.');
      expect(result.matches, hasLength(1));
      // The draft must not also be counted as a saved match — it would be
      // offered twice under two different headings.
      expect(result.matches.every((m) => !m.isDraft), isTrue);
    });

    test('the query actually reaches the server', () async {
      // `q` is what produces the draft. Dropping it turns the feature into a
      // list of old prompts, which is exactly the state this replaced.
      Map<String, dynamic>? seen;
      final api = PromptMemoryApi(_dioReturning(
        {'ok': true, 'prompts': <Object>[], 'draft': null},
        onQuery: (q) => seen = q,
      ));

      await api.fetch(lang: 'ar', query: '  مخزون قليل  ', conversationId: 'c1');

      expect(seen!['q'], 'مخزون قليل');
      expect(seen!['lang'], 'ar');
      expect(seen!['conversation_id'], 'c1');
    });

    test('an empty query is omitted rather than sent blank', () async {
      Map<String, dynamic>? seen;
      final api = PromptMemoryApi(_dioReturning(
        {'ok': true, 'prompts': <Object>[]},
        onQuery: (q) => seen = q,
      ));

      await api.fetch(lang: 'en', query: '   ');

      expect(seen!.containsKey('q'), isFalse);
      expect(seen!.containsKey('conversation_id'), isFalse);
    });

    test('no draft is not an error', () async {
      // The server can rank saved prompts and still fail to write a draft.
      // The card falls back to the rough text, so the user always has
      // something to edit.
      final api = PromptMemoryApi(_dioReturning({
        'ok': true,
        'prompts': <Object>[],
        'draft': null,
      }));

      final result = await api.fetch(lang: 'en', query: 'anything');

      expect(result.draft, isNull);
      expect(result.matches, isEmpty);
    });

    test('a malformed row is skipped, not fatal', () async {
      // This parser runs over server-generated content; one odd row must not
      // take the sheet down.
      final api = PromptMemoryApi(_dioReturning({
        'ok': true,
        'prompts': [
          'not a map',
          {'id': 'x', 'source': 'memory'}, // no text at all
          {'id': 'y', 'source': 'memory', 'prompt': 'short form'},
        ],
        'draft': {'id': 'd', 'source': 'draft', 'prompt_template': '   '},
      }));

      final result = await api.fetch(lang: 'en');

      // A prompt with no text is a row that does nothing when tapped.
      expect(result.matches, hasLength(1));
      expect(result.matches.single.promptTemplate, 'short form');
      // Whitespace-only draft is no draft.
      expect(result.draft, isNull);
    });
  });

  group('the card above the composer', () {
    testWidgets('hands back what the user edited, not the draft it was given',
        (tester) async {
      // The whole point of the review step. Sending `widget.draft` would
      // silently discard the correction the user just typed.
      String? used;
      await _pump(
        tester,
        TaskWordingCard(
          draft: 'Draft the server wrote',
          loading: false,
          onUse: (t) => used = t,
          onRun: (_) {},
          onClose: () {},
        ),
      );

      await tester.enterText(find.byType(TextField), 'What I actually meant');
      await tester.tap(find.text(AppStrings(const Locale('en')).promptUseDraft));
      await tester.pump();

      expect(used, 'What I actually meant');
    });

    testWidgets('both actions are dead while the draft is still being written',
        (tester) async {
      // Approving a draft that has not arrived would send an empty message.
      var fired = 0;
      await _pump(
        tester,
        TaskWordingCard(
          draft: '',
          loading: true,
          onUse: (_) => fired++,
          onRun: (_) => fired++,
          onClose: () {},
        ),
        settle: false,
      );

      final tr = AppStrings(const Locale('en'));
      expect(find.text(tr.promptPreparing), findsOneWidget);
      // No editable box yet — nothing to approve.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text(tr.promptUseDraft));
      await tester.tap(find.text(tr.promptRunNow));
      await tester.pump();

      expect(fired, 0);
    });

    testWidgets('a late draft fills an untouched box', (tester) async {
      // The card opens empty and the draft lands seconds later.
      Widget card(String draft, bool loading) => TaskWordingCard(
            draft: draft,
            loading: loading,
            onUse: (_) {},
            onRun: (_) {},
            onClose: () {},
          );

      await _pump(tester, card('rough text', true), settle: false);
      await _pump(tester, card('the structured version', false));

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'the structured version',
      );
    });

    testWidgets('but never overwrites an edit already in progress',
        (tester) async {
      // A poll-driven rebuild must not wipe what the user is typing.
      Widget card(String draft) => TaskWordingCard(
            draft: draft,
            loading: false,
            onUse: (_) {},
            onRun: (_) {},
            onClose: () {},
          );

      await _pump(tester, card('first draft'));
      await tester.enterText(find.byType(TextField), 'my own words');
      await _pump(tester, card('second draft'));

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'my own words',
      );
    });

    testWidgets('renders in Arabic, in Arabic', (tester) async {
      final ar = AppStrings(const Locale('ar'));
      await _pump(
        tester,
        TaskWordingCard(
          draft: 'الهدف: رصد المنتجات ذات المخزون المنخفض.',
          loading: false,
          onUse: (_) {},
          onRun: (_) {},
          onClose: () {},
        ),
        locale: const Locale('ar'),
      );

      expect(find.text(ar.promptBankTitle), findsOneWidget);
      expect(find.text(ar.promptCardIntro), findsOneWidget);
      expect(find.text(ar.promptUseDraft), findsOneWidget);
      expect(find.text(ar.promptRunNow), findsOneWidget);
      expect(ar.promptBankTitle, isNot(AppStrings(const Locale('en')).promptBankTitle));
    });
  });

  group('the offer bar', () {
    testWidgets('offers and dismisses without touching the message',
        (tester) async {
      var opened = 0;
      var dismissed = 0;
      final tr = AppStrings(const Locale('en'));

      await _pump(
        tester,
        TaskWordingHintBar(
          onOpen: () => opened++,
          onDismiss: () => dismissed++,
        ),
      );

      expect(find.text(tr.promptHintLong), findsOneWidget);

      await tester.tap(find.text(tr.promptHintOpen));
      await tester.pump();
      expect(opened, 1);

      // "Continue normally" has to stay available — the bar is an offer, and
      // a user who wants to send what they wrote must be able to.
      await tester.tap(find.text(tr.promptHintDismiss));
      await tester.pump();
      expect(dismissed, 1);
    });
  });
}
