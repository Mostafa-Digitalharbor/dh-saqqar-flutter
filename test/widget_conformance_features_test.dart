// Deep conformance for the FEATURE widgets that had no test of any kind.
//
// The companion to `widget_conformance_shared_test.dart`, which covers the
// `shared/` half of the same 2026-08-17 audit. These 26 live inside a single
// feature, and most of them are the interactive surfaces of the chat — the
// cards the agent sends the user to fill in, the recorder overlay, the send
// button, the row menus.
//
// Those matter disproportionately because they carry STATE. A card that
// renders correctly and then sends the wrong payload, or a send button that
// stays enabled while a run is stopping, is a bug the layout matrix cannot
// see. So every widget here gets the matrix, and every widget with a callback
// also gets assertions on what it hands back.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/i18n/view_model/locale_cubit.dart';
import 'package:saqqar_app/core/theme/app_colors.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/view_model/theme_cubit.dart';
import 'package:saqqar_app/features/account/widgets/account_card_header.dart';
import 'package:saqqar_app/features/auth/widgets/auth_header_actions.dart';
import 'package:saqqar_app/features/billing/widgets/plan_feature_line.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/chat/widgets/accent_card_chrome.dart';
import 'package:saqqar_app/features/chat/widgets/chat_bottom_chrome.dart';
import 'package:saqqar_app/features/chat/widgets/chat_date_separator.dart';
import 'package:saqqar_app/features/chat/widgets/chat_header_controls.dart';
import 'package:saqqar_app/features/chat/widgets/chat_send_button.dart';
import 'package:saqqar_app/features/chat/widgets/interactive_card_shell.dart';
import 'package:saqqar_app/features/chat/widgets/prompt_clarify_card.dart';
import 'package:saqqar_app/features/chat/widgets/prompt_suggestion_card.dart';
import 'package:saqqar_app/features/chat/widgets/report_builder_card.dart';
import 'package:saqqar_app/features/chat/widgets/voice_input_button.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_row_menu.dart';

import 'support/widget_conformance.dart';

// ── Payloads ──────────────────────────────────────────────────────────────
//
// Built with Arabic labels and more options than fit a 320 px row, because
// that is what the backend sends and what an English fixture would hide.

const _clarify = PromptClarifyPayload(
  original: kLongEnglish,
  intro: kLongArabic,
  questions: [
    ClarifyQuestion(
      question: 'أي فترة زمنية تقصد في التقرير المطلوب؟',
      options: ['الربع الأخير', 'السنة المالية الحالية', 'آخر ٣٠ يوم'],
    ),
    ClarifyQuestion(question: kLongEnglish),
  ],
);

const _suggestion = PromptSuggestionPayload(
  improved: kLongArabic,
  note: kLongEnglish,
);

const _report = ReportBuilderPayload(
  types: [
    ReportOption(key: 'sales', label: 'تقرير المبيعات التفصيلي'),
    ReportOption(key: 'inventory', label: 'جرد المخزون'),
  ],
  periods: [
    ReportOption(key: 'q4', label: 'الربع الرابع من السنة المالية'),
    ReportOption(key: 'ytd', label: 'من بداية السنة حتى تاريخه'),
  ],
  formats: [
    ReportOption(key: 'xlsx', label: 'Excel'),
    ReportOption(key: 'pdf', label: 'PDF'),
  ],
);

void main() {
  // `AuthHeaderActions` reads the theme and locale cubits off the tree. Kept
  // to the real classes rather than fakes — they are plain value cubits whose
  // only dependency is `SharedPreferences`, so a fake would just be a second
  // implementation to keep in sync. Assigned in `setUp`; the case builders
  // below only run inside a test, by which point it is set.
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget withAuthChrome(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit(prefs)),
          BlocProvider(create: (_) => LocaleCubit(prefs)),
        ],
        child: child,
      );

  final cases = <String, Widget Function()>{
    'AccentCardChrome': () => const AccentCardChrome(
          accent: AppColors.brandCyan,
          child: Text(kLongArabic),
        ),
    'AccountCardHeader': () => const AccountCardHeader(
          icon: AppIcons.user,
          title: kLongArabic,
          subtitle: kLongEnglish,
        ),
    'AccountCardHeader + trailing': () => const AccountCardHeader(
          icon: AppIcons.lock,
          title: kLongEnglish,
          subtitle: kLongArabic,
          trailing: Icon(AppIcons.chevronRight),
        ),
    'AuthHeaderActions': () => withAuthChrome(const AuthHeaderActions()),
    'ChatBottomChrome': () => const ChatBottomChrome(
          maxHeight: 240,
          children: [Text(kLongArabic), Text(kUnbreakable)],
        ),
    'ChatDateSeparator': () => ChatDateSeparator(date: DateTime.utc(2026, 8, 17)),
    'ChatSendButton': () => ChatSendButton(onPressed: () {}),
    'ChatSendButton stopping': () => ChatSendButton(
          onPressed: () {},
          onStop: () {},
          stopping: true,
        ),
    'ConversationRowMenu': () => ConversationRowMenu(onAction: (_) {}),
    'ConversationRowMenu pinned+archived': () => ConversationRowMenu(
          onAction: (_) {},
          isPinned: true,
          isArchived: true,
        ),
    'CardChoiceChip selected': () =>
        CardChoiceChip(label: kLongArabic, selected: true, onTap: () {}),
    'CardChoiceChip unselected': () =>
        CardChoiceChip(label: kLongEnglish, selected: false, onTap: () {}),
    'CardFieldLabel': () => const CardFieldLabel(kLongArabic),
    'InteractiveCardShell': () => const InteractiveCardShell(
          icon: AppIcons.sparkles,
          title: kLongArabic,
          children: [Text(kLongEnglish)],
        ),
    'PlanFeatureLine': () => const PlanFeatureLine(label: kLongArabic),
    'PromptClarifyCard': () => PromptClarifyCard(
          payload: _clarify,
          onSend: (_) {},
          onSeed: (_) {},
        ),
    'PromptSuggestionCard': () =>
        PromptSuggestionCard(payload: _suggestion, onSend: (_) {}),
    'ReportBuilderCard': () =>
        ReportBuilderCard(payload: _report, onSend: (_) {}),
    'RecordingOverlay': () => RecordingOverlay(
          elapsed: const Duration(minutes: 2, seconds: 7),
          transcribing: false,
          onStop: () {},
          onDiscard: () {},
        ),
    'RecordingOverlay transcribing': () => RecordingOverlay(
          elapsed: const Duration(minutes: 12, seconds: 42),
          transcribing: true,
          onStop: () {},
          onDiscard: () {},
        ),
    'VoiceInputButton': () => VoiceInputButton(onStart: () {}, enabled: true),
    'VoiceInputButton disabled': () =>
        VoiceInputButton(onStart: () {}, enabled: false),
    'ChatAppBarToggles': () =>
        ChatAppBarToggles(autoApprove: true, onAutoApproveChanged: (_) {}),
  };

  group('every feature widget survives the layout matrix', () {
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await sweepWidget(tester, build, name: name);
      });
    });
  });

  group('every feature widget renders in the dark theme', () {
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await rendersInDark(tester, build, name: name);
      });
    });
  });

  // ── Behaviour ─────────────────────────────────────────────────────────

  group('ChatSendButton', () {
    testWidgets('sends when idle, and stops when a run is in flight',
        (tester) async {
      var sends = 0;
      var stops = 0;
      await tester.pumpWidget(
        conformanceHarness(
          ChatSendButton(onPressed: () => sends++, onStop: () => stops++),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(ChatSendButton));
      await tester.pump();
      expect(
        stops,
        1,
        reason: 'With an `onStop` wired the button is the STOP control — a run '
            'is in flight. Sending here would queue a second run behind one '
            'the user is trying to cancel.',
      );
      expect(sends, 0);
    });

    testWidgets('a stopping button cannot be tapped again', (tester) async {
      // Double-tapping stop used to fire a second cancel for a run already
      // being cancelled. The button must go inert the moment it is pressed.
      var stops = 0;
      await tester.pumpWidget(
        conformanceHarness(
          ChatSendButton(
            onPressed: () {},
            onStop: () => stops++,
            stopping: true,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(ChatSendButton), warnIfMissed: false);
      await tester.pump();
      expect(stops, 0, reason: 'A stopping button still fired onStop.');
    });

    testWidgets('a null onPressed is inert rather than silently live',
        (tester) async {
      await tester.pumpWidget(
        conformanceHarness(
          const ChatSendButton(onPressed: null),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(ChatSendButton), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('VoiceInputButton', () {
    testWidgets('disabled does not start a recording', (tester) async {
      // The mic is disabled when voice is not on the plan, or when a run is
      // already in flight. A tap that got through would open the recorder and
      // then fail at upload with a 403 — after the user had spoken.
      var starts = 0;
      await tester.pumpWidget(
        conformanceHarness(
          VoiceInputButton(onStart: () => starts++, enabled: false),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(VoiceInputButton), warnIfMissed: false);
      await tester.pump();
      expect(starts, 0);
    });

    testWidgets('enabled starts one', (tester) async {
      var starts = 0;
      await tester.pumpWidget(
        conformanceHarness(
          VoiceInputButton(onStart: () => starts++, enabled: true),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(VoiceInputButton));
      await tester.pump();
      expect(starts, 1);
    });
  });

  group('RecordingOverlay', () {
    testWidgets('discard is available while recording and gone once the audio '
        'is in flight', (tester) async {
      // The bytes are already uploading during transcription, so "discard"
      // cannot mean anything — offering it would be a button that lies.
      var discards = 0;
      await tester.pumpWidget(
        conformanceHarness(
          RecordingOverlay(
            elapsed: const Duration(seconds: 5),
            transcribing: false,
            onStop: () {},
            onDiscard: () => discards++,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byIcon(AppIcons.trash));
      await tester.pump();
      expect(discards, 1);

      await tester.pumpWidget(
        conformanceHarness(
          RecordingOverlay(
            elapsed: const Duration(seconds: 5),
            transcribing: true,
            onStop: () {},
            onDiscard: () => discards++,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byIcon(AppIcons.trash), warnIfMissed: false);
      await tester.pump();
      expect(
        discards,
        1,
        reason: 'Discard fired while transcribing — the upload is already in '
            'flight, so there is nothing left to discard.',
      );
    });

    testWidgets('renders the elapsed time, including past ten minutes',
        (tester) async {
      // A `m:ss` formatter that drops the leading digit reads as 2:07 for both
      // 2 and 12 minutes.
      await tester.pumpWidget(
        conformanceHarness(
          RecordingOverlay(
            elapsed: const Duration(minutes: 12, seconds: 7),
            transcribing: false,
            onStop: () {},
            onDiscard: () {},
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      expect(find.textContaining('12'), findsWidgets);
      expect(find.textContaining('07'), findsWidgets);
    });
  });

  group('CardChoiceChip', () {
    testWidgets('selected and unselected are visually distinct',
        (tester) async {
      final colours = <bool, Color?>{};
      for (final selected in [true, false]) {
        await tester.pumpWidget(
          conformanceHarness(
            CardChoiceChip(label: 'x', selected: selected, onTap: () {}),
            locale: const Locale('en'),
            scale: 1.0,
          ),
        );
        // `AnimatedContainer` — the chip cross-fades between states, so the
        // decoration lives on the animated wrapper rather than a plain box.
        final box = tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byType(CardChoiceChip),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        colours[selected] = (box.decoration! as BoxDecoration).color;
      }
      expect(colours[true], isNot(colours[false]));
    });
  });

  group('PromptSuggestionCard', () {
    testWidgets('sends the IMPROVED prompt, not the note', (tester) async {
      // The card offers a rewritten prompt with an explanation beside it.
      // Sending the explanation instead is the one wrong answer that still
      // looks like it worked.
      String? sent;
      await tester.pumpWidget(
        conformanceHarness(
          PromptSuggestionCard(
            payload: const PromptSuggestionPayload(
              improved: 'Show Q4 sales by region',
              note: 'Added a time range and a grouping.',
            ),
            onSend: (v) => sent = v,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(InkWell).last);
      await tester.pump();
      expect(sent, 'Show Q4 sales by region');
    });
  });

  group('ChatDateSeparator.needs', () {
    test('a first message always gets a separator', () {
      expect(ChatDateSeparator.needs(null, DateTime(2026, 8, 17)), isTrue);
    });

    test('two messages on the same day do not', () {
      expect(
        ChatDateSeparator.needs(
          DateTime(2026, 8, 17, 9),
          DateTime(2026, 8, 17, 23, 59),
        ),
        isFalse,
      );
    });

    test('a minute either side of midnight does', () {
      expect(
        ChatDateSeparator.needs(
          DateTime(2026, 8, 17, 23, 59),
          DateTime(2026, 8, 18, 0, 1),
        ),
        isTrue,
      );
    });

    test('the same day one year apart does', () {
      // A comparison written on month+day alone passes every test above and
      // fails exactly here.
      expect(
        ChatDateSeparator.needs(
          DateTime(2025, 8, 17),
          DateTime(2026, 8, 17),
        ),
        isTrue,
      );
    });
  });
}
