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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/i18n/view_model/locale_cubit.dart';
import 'package:saqqar_app/core/theme/app_colors.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/view_model/theme_cubit.dart';
import 'package:saqqar_app/features/auth/view/auth_flow_screen.dart'
    show AuthFrame;
import 'package:saqqar_app/features/chat/widgets/attachment_image_grid.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_open.dart';
import 'package:saqqar_app/features/chat/widgets/chat_context.dart';
import 'package:saqqar_app/shared/fig/fig.dart' show FigTopFade;
import 'package:saqqar_app/features/chat/widgets/chat_load_earlier_header.dart';
import 'package:saqqar_app/features/home/home_screen.dart' show Orb;
import 'package:saqqar_app/features/launch/launch_splash_screen.dart'
    show SplashBackdrop;
import 'package:saqqar_app/features/setup/setup_screens.dart'
    show ConnectionTabs, EnvMode, EnvTypePicker, FigDropdown;
import 'package:saqqar_app/features/account/widgets/account_card_header.dart';
import 'package:saqqar_app/features/auth/widgets/auth_header_actions.dart';
import 'package:saqqar_app/features/billing/widgets/plan_feature_line.dart';
import 'package:saqqar_app/features/chat/data/app_pulse_payloads.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/widgets/accent_card_chrome.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/accountant_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/factory_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/finance_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/hr_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/inventory_pulse_card.dart';
import 'package:saqqar_app/features/chat/data/pulse_actions.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_action_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_bands_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_helpers.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_counter_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_raw_items.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/purchasing_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/quality_guard_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/chat_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/chat_grouped_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/task_wording_card.dart';
import 'package:saqqar_app/features/chat/widgets/task_wording_hint_bar.dart';
import 'package:saqqar_app/features/chat/widgets/task_wording_sheet.dart';
import 'package:saqqar_app/features/chat/widgets/continue_run_button.dart';
import 'package:saqqar_app/features/chat/widgets/message_token_chip.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart'
    show MessageTokens;
import 'package:saqqar_app/features/chat/data/approval_grouping.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart'
    show Approval, ApprovalActionType, ApprovalStatus;
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
import 'package:saqqar_app/features/account/widgets/plan_badge.dart';
import 'package:saqqar_app/features/account/widgets/profile_hero.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/chat/widgets/chat_markdown.dart';
import 'package:saqqar_app/features/chat/widgets/chat_sheet.dart';
import 'package:saqqar_app/features/chat/widgets/chat_skeleton_list.dart';
import 'package:saqqar_app/features/chat/widgets/email_approval_preview.dart';
import 'package:saqqar_app/features/chat/widgets/message_bubble.dart';

import 'support/responsive_harness.dart' show SeededAuthCubit;
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

/// A reply shaped like the ones the agent actually sends, and like the ones
/// that break a 320 px bubble.
///
/// `ChatMarkdown` renders model output, so its input is the only text in the
/// app nobody reviews before a user reads it. A fixture of `'# Hello'` would
/// prove the widget compiles and nothing else — every way this can go wrong
/// needs content that cannot wrap:
///
///   * a table wider than any phone (must scroll, not overflow),
///   * an unbroken URL and an unbroken token,
///   * a fenced code block with long lines,
///   * mixed Arabic and English in one paragraph, which is where the
///     bidirectional runs get their boundaries wrong,
///   * a deep nested list, whose indent is what eventually eats the row.
const _markdown =
    '''
# $kLongArabic

$kLongArabic **bold** و`inline_code_that_is_quite_long_indeed` و$kLongEnglish.

| Column | $kLongEnglish | Another long header | And one more |
| --- | --- | --- | --- |
| $kUnbreakable | $kLongArabic | 12345678901234567890 | value |

```dart
final aVeryLongIdentifier = someFunction(withA, few, arguments, thatDoNotWrap);
```

- level one $kLongArabic
  - level two $kLongEnglish
    - level three $kUnbreakable

> $kLongArabic

https://saqqaar.com/a/very/long/path/that/will/not/break/anywhere/at/all/x
''';

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

  ChatAttachment pic(int i) => ChatAttachment(
    name: 'photo$i.png',
    kind: 'IMAGE',
    size: '1 MB',
    imageUrl: 'https://example.invalid/$i.png',
    downloadUrl: 'https://example.invalid/$i.png',
    serverId: 'id$i',
  );

  final cases = <String, Widget Function()>{
    'DownloadingFileCard known': () => DownloadingFileCard(
      attachment: const ChatAttachment(
        name: kLongArabic,
        kind: 'PDF',
        size: '214 KB',
      ),
      progress: 0.42,
      onCancel: () {},
    ),
    'DownloadingFileCard unknown': () => DownloadingFileCard(
      attachment: const ChatAttachment(
        name: 'Review notes.pdf',
        kind: 'PDF',
        size: '214 KB',
      ),
      progress: indeterminateProgress,
      onCancel: () {},
    ),
    'ChatImageGrid two': () =>
        ChatImageGrid(attachments: [pic(1), pic(2)]),
    'ChatImageGrid three': () =>
        ChatImageGrid(attachments: [pic(1), pic(2), pic(3)]),
    'ChatImageGrid six shows +2': () =>
        ChatImageGrid(attachments: [for (var i = 0; i < 6; i++) pic(i)]),
    'AttachmentOpenTarget': () => AttachmentOpenTarget(
      attachment: pic(1),
      child: const Text(kLongArabic),
    ),
    'DownloadProgressOverlay known': () => const SizedBox(
      height: 80,
      child: DownloadProgressOverlay(progress: 0.4),
    ),
    'DownloadProgressOverlay unknown': () => const SizedBox(
      height: 80,
      child: DownloadProgressOverlay(progress: indeterminateProgress),
    ),
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
    'FigTopFade': () => const FigTopFade(child: Text(kLongArabic)),
    'ChatLoadEarlierHeader': () => ChatLoadEarlierHeader(onRetry: () async {}),
    'ChatDateSeparator': () =>
        ChatDateSeparator(date: DateTime.utc(2026, 8, 17)),
    'ChatSendButton': () => ChatSendButton(onPressed: () {}),
    'ChatSendButton stopping': () =>
        ChatSendButton(onPressed: () {}, onStop: () {}, stopping: true),
    'ConversationRowMenu': () => ConversationRowMenu(onAction: (_) {}),
    'ConversationRowMenu pinned+archived': () =>
        ConversationRowMenu(onAction: (_) {}, isPinned: true, isArchived: true),
    'CardChoiceChip selected': () =>
        CardChoiceChip(label: kLongArabic, selected: true, onTap: () {}),
    'CardChoiceChip unselected': () =>
        CardChoiceChip(label: kLongEnglish, selected: false, onTap: () {}),
    'CardFieldLabel': () => const CardFieldLabel(kLongArabic),
    'CardHeaderRow': () => const CardHeaderRow(
      icon: AppIcons.sparkles,
      title: kLongArabic,
      accent: AppColors.brandCyan,
    ),
    'InteractiveCardShell': () => const InteractiveCardShell(
      icon: AppIcons.sparkles,
      title: kLongArabic,
      children: [Text(kLongEnglish)],
    ),
    // ── Redesign (2026-11) ────────────────────────────────────────────────
    // Always mounted in a Scaffold body in the app, so it is handed a
    // bounded height here too (it owns its own scrolling).
    'AuthFrame': () => const SizedBox(
      height: 300,
      child: AuthFrame(
        title: kLongArabic,
        subtitle: kLongEnglish,
        children: [Text(kLongArabic), Text(kUnbreakable)],
      ),
    ),
    'ChatContextPill': () => ChatContextPill(
      company: kLongEnglish,
      environment: kLongArabic,
      isLive: true,
      readOnly: false,
      onTap: () {},
    ),
    'ConnectionTabs': () => ConnectionTabs(apiKey: false, onChanged: (_) {}),
    'ConnectionTabs dark api key': () =>
        ConnectionTabs(apiKey: true, dark: true, onChanged: (_) {}),
    'EnvTypePicker': () =>
        EnvTypePicker(value: EnvMode.live, onChanged: (_) {}),
    'EnvTypePicker dark read only': () =>
        EnvTypePicker(value: EnvMode.readOnly, dark: true, onChanged: (_) {}),
    'FigDropdown': () => FigDropdown(
      value: kLongArabic,
      options: const [kLongArabic, kLongEnglish],
      onChanged: (_) {},
    ),
    'Orb': () => const Orb(size: 74),
    'SplashBackdrop': () =>
        const SizedBox(width: 200, height: 200, child: SplashBackdrop()),
    'PlanFeatureLine': () => const PlanFeatureLine(label: kLongArabic),
    'PromptClarifyCard': () =>
        PromptClarifyCard(payload: _clarify, onSend: (_) {}, onSeed: (_) {}),
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

    // ── Added 2026-08-20 ──────────────────────────────────────────────────
    //
    // A sweep of `lib/features/**` for widgets no test ever *constructs*
    // (as opposed to merely naming in a comment) turned up six. Five are
    // below; `StorybookScreen` is a screen and is swept as one.
    //
    // Naming-in-a-comment is what hid them: three of the six appear in test
    // prose often enough that a grep for the class name reports them as
    // covered. `EmailApprovalPreview` is discussed thirteen times across the
    // suite and was built zero times.
    //
    // `ChatMarkdown` is the one that mattered most: it renders the agent's
    // reply, so its input is model output — the only text in the app nobody
    // reviews before a user sees it. It was the largest untested surface in
    // the chat and the easiest place for an unbounded line to overflow.
    'ChatMarkdown agent': () =>
        const ChatMarkdown(data: _markdown, isUser: false),
    'ChatMarkdown user': () =>
        const ChatMarkdown(data: _markdown, isUser: true),
    // Takes a bare `List<Widget>`, so the thing to feed it is content it has
    // no say over: a row that cannot wrap, under a title that cannot either.

    // Bounded on purpose. `ChatSkeletonList` IS a scrollable, and the harness
    // wraps every case in a `SingleChildScrollView` — a vertical viewport
    // inside a vertical viewport gets unbounded height and throws before it
    // can render anything. 300 fits inside the shortest cell in the matrix
    // (568×320 landscape), so the box is real at every viewport rather than
    // being clipped at one.
    //
    // Height is not what this widget can get wrong. The failure it is swept
    // for is a bubble that will not fit ACROSS a 320 px phone at 1.4× text in
    // Arabic, and that is measured exactly the same inside a bounded box.
    'ChatSkeletonList': () =>
        const SizedBox(height: 300, child: ChatSkeletonList()),
    'ChatSheet': () => const ChatSheet(
      title: kLongArabic,
      children: [Text(kLongEnglish), Text(kUnbreakable)],
    ),
    'EmailApprovalPreview': () => const EmailApprovalPreview(
      to: 'finance@example.com, accounts.payable@a-very-long-domain.com',
      subject: kLongArabic,
      body: kLongEnglish,
      cc: 'cc@example.com',
      bcc: 'bcc@example.com',
    ),
    'EmailApprovalPreview reply': () => const EmailApprovalPreview(
      to: kUnbreakable,
      subject: kLongEnglish,
      body: kLongArabic,
      isReply: true,
    ),
    // Both spans it is built for: a plain "You" and a widget-span mark.
    'MessageMeta text': () => const MessageMeta(
      leading: TextSpan(text: kLongArabic),
      time: '14:32',
      style: TextStyle(),
      dotColor: AppColors.brandCyan,
    ),
    'MessageMeta widget span': () => const MessageMeta(
      leading: WidgetSpan(child: Icon(AppIcons.sparkles)),
      time: kUnbreakable,
      style: TextStyle(),
      dotColor: AppColors.brandCyan,
      align: TextAlign.end,
    ),
    // `plan_badge_test.dart` is a whole file about this widget and never
    // builds it — it drives `PlanUsageCard` and asserts on what shows
    // through. The only literal `PlanBadge(` in that file is inside a
    // comment, which is precisely how it read as covered.
    'PlanBadge': () => const PlanBadge(name: kLongArabic),
    'PlanBadge dense': () => const PlanBadge(name: kLongEnglish, dense: true),
    // Task 1 (MOBILE_TASKS_2026-09.md) — the two fully-specified app-pulse
    // cards. Long Arabic customer/product names and an unbreakable order
    // number, because a real Odoo database is exactly where those come from.
    'FactoryPulseCard': () => FactoryPulseCard(
      payload: FactoryPulsePayload.parse({
        'kind': 'factory',
        'status': 'ok',
        'as_of': '2026-09-05',
        'mo_running': 12,
        'mo_late': 3,
        'mo_done_today': 5,
        'po_late': 2,
        'orders_at_risk': 4,
        'top_risks': [
          {
            'order': kUnbreakable,
            'customer': kLongArabic,
            'missing_lines': 3,
            'lead_days': 21,
            'worst_product': kLongEnglish,
          },
        ],
        'notes': [kLongArabic],
      })!,
    ),
    'FactoryPulseCard error': () => FactoryPulseCard(
      payload: FactoryPulsePayload.parse({
        'kind': 'factory',
        'status': 'error',
        'error': kLongArabic,
      })!,
    ),
    'InventoryPulseCard': () => InventoryPulseCard(
      payload: InventoryPulsePayload.parse({
        'kind': 'inventory',
        'status': 'ok',
        'as_of': '2026-09-05',
        'sales_days': 90,
        'product_count': 1840,
        'inventory_value': {'available': true, 'total': 984000.0},
        'low_stock': {'available': false},
        // Undocumented item shape, hostile content: a product name that
        // cannot wrap, an Arabic one that must, and a fact line long
        // enough to need its own ellipsis.
        'demand_shortage': {
          'available': true,
          'count': 4,
          'items': [
            {
              'product': kUnbreakable,
              'qty_on_hand': 0,
              'qty_needed': 1450,
              'state': kLongEnglish,
            },
            {'name': kLongArabic, 'days_late': 12},
            // No name field at all — the row still has to print.
            {'quantity': 4},
          ],
        },
        'stagnant_stock': {'available': true, 'count': 31, 'total': 120400.0},
        'overstock': {'available': true, 'count': 8, 'total': 65000.0},
        'fast_reorder': {'available': true, 'count': 6},
        'missing_data': {
          'available': true,
          'count': 22,
          // The doc shows `counts` empty; a real one is reason → count.
          'counts': {'no_cost': 8, 'no_lead_time': 14},
        },
        'notes': [kLongArabic],
        'priorities': [kLongEnglish, kUnbreakable],
      })!,
    ),
    // The five kinds built from a live payload (doc: "read the live payload
    // ... that is the authoritative shape") rather than the doc's own
    // top-level key list — see `app_pulse_payloads.dart`'s doc comments on
    // each parser for why. Same hostile-content treatment as factory/
    // inventory above.
    'FinancePulseCard': () => FinancePulseCard(
      payload: FinancePulsePayload.parse({
        'kind': 'finance',
        'status': 'ok',
        'as_of': '2026-09-06',
        'cash': {
          'balance': 12500.0,
          'journals': [kUnbreakable],
          'available': true,
        },
        'receivables': {
          'overdue': {'count': 3, 'total': 4200.0, 'available': true},
        },
        'payables': {
          'due_soon': {'count': 1, 'total': 900.0, 'available': true},
        },
        'drafts': {
          'vendor_bills': {'count': 0, 'available': true},
          'customer_invoices': {'count': 2, 'available': true},
        },
        'bank_reconciliation': {'count': 0, 'available': false},
        'liquidity_7d': {'status': 'covered', 'available': true},
        // Both band encodings in one card: a flat `{band: amount}` map
        // and a wrapper whose bands are rows.
        'collection_aging': {
          'available': true,
          'buckets': {'d0_30': 84000.0, '31_60': 12500.0, 'over_90': 3100.0},
        },
        'payment_horizon': {
          'available': true,
          'bands': [
            {'label': '0_7', 'amount': 4200.0, 'count': 12},
            {'label': kLongArabic, 'count': 3},
          ],
        },
        'priorities': [kLongArabic],
      })!,
    ),
    // A database that cannot answer the aging question says so — the
    // state that must never render as an empty row of zeroes.
    'FinancePulseCard aging unavailable': () => FinancePulseCard(
      payload: FinancePulsePayload.parse({
        'kind': 'finance',
        'collection_aging': {'available': false},
        'payment_horizon': {'available': false},
      })!,
    ),
    'PurchasingPulseCard': () => PurchasingPulseCard(
      payload: PurchasingPulsePayload.parse({
        'kind': 'purchasing',
        'status': 'ok',
        'open_rfqs': {'count': 4, 'available': true},
        'awaiting_approval': {'count': 0, 'available': false},
        'late_purchase_orders': {'count': 2, 'available': true},
        'late_incoming_receipts': {'count': 1, 'available': true},
        'to_bill': {'count': 0, 'available': true},
        'vendor_bills': {'count': 3, 'available': true},
        'vendor_delay_summary': [
          {'vendor': kUnbreakable, 'avg_delay_days': 9, 'orders': 4},
          {'partner': kLongArabic, 'late_receipts': 2},
        ],
        'priorities': [kLongArabic],
      })!,
    ),
    'HrPulseCard': () => HrPulseCard(
      payload: HrPulsePayload.parse({
        'kind': 'hr',
        'status': 'ok',
        'as_of': '2026-09-06',
        'window_days': 90,
        'counters': [
          {
            'key': 'contracts',
            'label': kLongArabic,
            'value': 1,
            'action': kLongArabic,
          },
        ],
        'operations': {
          'available': true,
          'active_employees': 9,
          'missing_managers': 9,
          'missing_work_email': 1,
          'items': [
            {'employee': kUnbreakable, 'reason': kLongArabic},
          ],
        },
        'recruitment': {
          'available': true,
          'count': 6,
          'items': [
            {'name': kLongArabic, 'stage': kLongEnglish, 'days_open': 34},
          ],
        },
        'payroll': {'available': false},
        'time_off': {'available': true, 'count': 0},
      })!,
    ),
    // Operations unavailable: the tiles have to say so rather than vanish.
    'HrPulseCard operations unavailable': () => HrPulseCard(
      payload: HrPulsePayload.parse({
        'kind': 'hr',
        'operations': {'available': false},
      })!,
    ),
    'AccountantPulseCard': () => AccountantPulseCard(
      payload: AccountantPulsePayload.parse({
        'kind': 'accountant',
        'status': 'ok',
        'month': '2026-08',
        'window_days': 365,
        'counters': [
          {
            'key': 'tax',
            'label': kLongArabic,
            'value': 1,
            'action': kLongEnglish,
          },
        ],
        // The audit trail behind the counter, collapsed by default.
        'blocks': {
          'tax': [
            {'move': kUnbreakable, 'amount': 1250.0, 'partner': kLongArabic},
          ],
        },
      })!,
    ),
    // The other documented shape: the five checks as their own keys, with
    // no rolled-up `counters` list at all.
    'AccountantPulseCard checks': () => AccountantPulseCard(
      payload: AccountantPulsePayload.parse({
        'kind': 'accountant',
        'no_reference': {'available': true, 'count': 4},
        'manual_on_control': 7,
        'edited_after_post': {'available': false},
        'self_cancelling': {
          'available': true,
          'count': 1,
          'items': [
            {'move': kLongArabic, 'amount': -300.0},
          ],
        },
        'multi_company': {'available': true, 'count': 0},
      })!,
    ),
    'QualityGuardPulseCard': () => QualityGuardPulseCard(
      payload: QualityGuardPulsePayload.parse({
        'kind': 'quality_guard',
        'status': 'ok',
        'as_of': '2026-09-06',
        'priorities': [kLongArabic],
        'quality_stats': {
          'out_of_spec': 2,
          'failed_checks': 1,
          'pending_checks': 0,
          'quality_alerts': 3,
          'missing_numeric_specs': 0,
        },
        'spec_stats': {
          'review_cases': 1,
          'invoice_swaps': 0,
          'delivery_swaps': 2,
          'high_risk_cases': 1,
          'cost_saving_total': 450.0,
          'deep_discounts': 5,
          'lower_cost_substitutes': 2,
          'documented_substitutes': 1,
          'undocumented_substitutes': 4,
          'discount_value_estimate': 18400.0,
        },
        'standard_odoo_only': true,
      })!,
    ),
    // The doc's own shape for the same card: all 16 numbers flat at the top
    // level rather than inside the two stat objects.
    'QualityGuardPulseCard flat': () => QualityGuardPulseCard(
      payload: QualityGuardPulsePayload.parse({
        'kind': 'quality_guard',
        'out_of_spec': 2,
        'failed_checks': 1,
        'pending_checks': 0,
        'quality_alerts': 3,
        'missing_numeric_specs': 7,
        'review_cases': 1,
        'deep_discounts': 5,
        'lower_cost_substitutes': 2,
        'documented_substitutes': 1,
        'undocumented_substitutes': 4,
        'high_risk_cases': 1,
        'cost_saving_total': 450.0,
        'discount_value_estimate': 18400.0,
        'standard_odoo_only': true,
      })!,
    ),
    'PulseCounterList': () => const PulseCounterList(
      counters: [
        PulseCounter(
          key: 'a',
          label: kLongArabic,
          value: 1,
          action: kLongEnglish,
        ),
        PulseCounter(key: 'b', label: kUnbreakable, value: null),
      ],
    ),
    // The trail disclosure: a counter whose rows are one tap away.
    'PulseCounterList with details': () => PulseCounterList(
      counters: const [PulseCounter(key: 'a', label: kLongArabic, value: 3)],
      detailsFor: (key) => const [
        {'move': kUnbreakable, 'amount': 1250.0},
        {'move': kLongArabic, 'amount': -80.5, 'posted': true},
      ],
    ),
    // The generic renderers behind every undocumented `items` array.
    'PulseRawItemsList': () => const PulseRawItemsList(
      title: kLongArabic,
      items: [
        {'product': kUnbreakable, 'qty': 14200, 'state': kLongEnglish},
        {'name': kLongArabic, 'days': 3.5},
        // Neither a map nor a name — the row still prints.
        'a bare string row',
        42,
      ],
    ),
    'PulseBandsList': () => const PulseBandsList(
      title: kLongArabic,
      bands: PulseBands(
        available: true,
        bands: [
          PulseBand(label: '0–30', amount: 84000, count: 12),
          PulseBand(label: kUnbreakable, count: 3),
          PulseBand(label: kLongArabic),
        ],
      ),
    ),
    'PulseBandsList unavailable': () => const PulseBandsList(
      title: kLongEnglish,
      bands: PulseBands(available: false),
    ),
    // The boxed metric and the row it lays out. The value is the widest a
    // real card produces — an ungrouped seven-figure inventory total — and
    // the labels are the longest the web's own wording reaches, so the box
    // is measured against what actually goes in it rather than "12 / OK".
    'PulseStatTile': () =>
        const PulseStatTile(value: '1,215,654.84', label: kLongArabic),
    'PulseStatTile unavailable': () => const PulseStatTile(
      value: kUnbreakable,
      label: kLongEnglish,
      color: Color(0xFFEF4444),
    ),
    'PulseStatGrid': () => const PulseStatGrid(
      tiles: [
        PulseStatTile(value: '1019', label: kLongArabic),
        PulseStatTile(value: '—', label: kLongEnglish),
        PulseStatTile(value: '0', label: kUnbreakable),
        PulseStatTile(value: '2,096', label: kLongArabic),
      ],
    ),
    // The web-parity action rows. Fed the longest copy the real cards can
    // carry — an Arabic title over an unbreakable order number over a
    // two-clause cause line, all above a button that must still fit.
    'PulseActionList': () => PulseActionList(
      actions: const [
        PulseAction(
          title: kLongArabic,
          main: kUnbreakable,
          cause: kLongEnglish,
          label: kLongArabic,
          prompt: 'p',
          primary: true,
        ),
        PulseAction(
          title: kLongEnglish,
          main: kLongArabic,
          label: kLongEnglish,
          prompt: 'p',
        ),
      ],
      onSend: (_) {},
    ),
    'PulseDeepActionChips': () => PulseDeepActionChips(
      actions: const [
        PulseAction(title: '', main: '', label: kLongArabic, prompt: 'p'),
        PulseAction(title: '', main: '', label: kUnbreakable, prompt: 'p'),
      ],
      onSend: (_) {},
    ),
    'PulseFreeTextAction': () => PulseFreeTextAction(
      kind: InteractiveCardKind.accountant,
      onSend: (_) {},
    ),
    // Watches AuthCubit and PlanCubit off the tree, so it needs both. The
    // plan is left at its `null` default deliberately — that is what the
    // hero renders during the first paint after sign-in, before
    // `/conversations/` has answered, and it is the state a seeded-only
    // fixture would never exercise.
    'ProfileHero': () => MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => SeededAuthCubit()),
        BlocProvider<PlanCubit>(create: (_) => PlanCubit()),
      ],
      child: const ProfileHero(),
    ),
    // Title/prompt are agent-generated and can contain a single unbroken
    // token (a filename, a dotted method path) — see the responsiveness
    // audit finding this covers.
    'ChatApprovalCard': () => ChatApprovalCard(
      approval: const ChatApproval(
        id: 'a1',
        title: kUnbreakable,
        prompt: '$kLongArabic $kUnbreakable $kLongEnglish',
        actionType: 'odoo_write',
        risk: 'high',
        status: ChatApprovalStatus.pending,
        payload: {
          'model': 'mrp.production',
          'method': 'write',
          'record_count': '42',
        },
      ),
      onApprove: () {},
      onReject: () {},
    ),
    // The grouped variant carries the same agent-generated prompt risk, plus
    // two numbered buttons side by side — "Reject all 12" next to "Approve
    // all 12" is the widest row on the card in either language.
    'ContinueRunButton': () => ContinueRunButton(onPressed: () {}),
    // Task wording. The card holds a real structured prompt — the draft the
    // server returns is many lines of Arabic with numbered steps, which is
    // the case that decides whether the box scrolls or the card overflows.
    'TaskWordingCard': () => TaskWordingCard(
      draft: '$kLongArabic\n1. $kLongArabic\n2. $kLongEnglish',
      loading: false,
      onUse: (_) {},
      onRun: (_) {},
      onClose: () {},
    ),
    // Two buttons plus a full sentence of Arabic on one bar — the row that
    // has to wrap rather than clip at 1.3x text on a 320 px screen.
    'TaskWordingHintBar': () =>
        TaskWordingHintBar(onOpen: () {}, onDismiss: () {}),
    'TaskWordingSheet': () => const TaskWordingSheet(initialQuery: kLongArabic),
    // The widest a cost chip gets: a million-token prompt, a long Arabic
    // tooltip behind it, inside a meta line that must still wrap.
    'MessageTokenChip': () => const MessageTokenChip(
      tokens: MessageTokens(
        input: 1234567,
        output: 98765,
        cachedInput: 1200000,
      ),
    ),
    'ChatGroupedApprovalCard': () => ChatGroupedApprovalCard(
      group: ApprovalGroup(
        key: 'odoo_write|create|mrp.production',
        approvals: [
          for (var i = 0; i < 12; i++)
            Approval(
              id: 'a$i',
              actionType: ApprovalActionType.odooWrite,
              status: ApprovalStatus.pending,
              prompt: '$kLongArabic $kUnbreakable',
              payload: const {'operation': 'create', 'model': 'mrp.production'},
            ),
        ],
      ),
      subtitle: '$kLongArabic $kUnbreakable $kLongEnglish',
      promptOf: (a) => '$kUnbreakable ${a.id}',
      onApproveAll: (_) {},
      onRejectAll: (_) {},
      onApproveOne: (_) {},
      onRejectOne: (_) {},
    ),
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
    testWidgets('sends when idle, and stops when a run is in flight', (
      tester,
    ) async {
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
        reason:
            'With an `onStop` wired the button is the STOP control — a run '
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

    testWidgets('a null onPressed is inert rather than silently live', (
      tester,
    ) async {
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
      await tester.tap(find.text('Cancel'));
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
      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      await tester.pump();
      expect(
        discards,
        1,
        reason:
            'Discard fired while transcribing — the upload is already in '
            'flight, so there is nothing left to discard.',
      );
    });

    testWidgets('renders the elapsed time, including past ten minutes', (
      tester,
    ) async {
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
    testWidgets('selected and unselected are visually distinct', (
      tester,
    ) async {
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
        ChatDateSeparator.needs(DateTime(2025, 8, 17), DateTime(2026, 8, 17)),
        isTrue,
      );
    });
  });

  // The twin of `every shared widget is pumped somewhere` in
  // `widget_conformance_shared_test.dart`. That rule has guarded
  // `lib/shared/widgets/` since 2026-08-18; `lib/features/**` had four times
  // as many widgets and no equivalent, which is how six of them reached
  // 2026-08-20 without a single test ever building one.
  //
  // The check is CONSTRUCTION, not mention. A name search would have called
  // all six covered: `EmailApprovalPreview` is named in thirteen test
  // comments, `ChatMarkdown` in four. Requiring an open paren after the name
  // is the difference between "some test talks about this" and "some test
  // renders it".
  //
  // …and requiring the paren is not enough on its own. The first version of
  // this rule scanned raw file text, so it passed with every `ChatMarkdown`
  // case commented out: `// 'ChatMarkdown': () => const ChatMarkdown(` still
  // matches. A rule written against comment-hidden coverage that reads
  // comments as coverage is no rule at all, so the sources are stripped
  // first. That failure showed up only because the rule was checked against
  // the bug it exists for, which is the check worth keeping.
  test('every feature widget is constructed by some test', () {
    /// Test source with `//` lines, `/* */` blocks and doc comments removed.
    String stripComments(String source) {
      final out = StringBuffer();
      var inBlock = false;
      for (final raw in const LineSplitter().convert(source)) {
        final trimmed = raw.trimLeft();
        if (inBlock) {
          final end = raw.indexOf('*/');
          if (end == -1) continue;
          inBlock = false;
          out.writeln(raw.substring(end + 2));
          continue;
        }
        if (trimmed.startsWith('//')) continue;
        final block = raw.indexOf('/*');
        if (block != -1 && !raw.substring(0, block).contains("'")) {
          final end = raw.indexOf('*/', block);
          if (end == -1) {
            inBlock = true;
            out.writeln(raw.substring(0, block));
          } else {
            out.writeln(raw.substring(0, block) + raw.substring(end + 2));
          }
          continue;
        }
        out.writeln(raw);
      }
      return out.toString();
    }

    final declared = <String, String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final m in RegExp(
        r'^class ([A-Z]\w+) extends State(?:less|ful)Widget',
        multiLine: true,
      ).allMatches(source)) {
        declared[m.group(1)!] = entity.path.replaceAll(r'\', '/');
      }
    }
    expect(declared, isNotEmpty, reason: 'The scan found no feature widgets.');

    final everyTest = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => stripComments(f.readAsStringSync()))
        .join('\n');

    // Deliberately not constructed, each with the reason.
    const exempt = <String, String>{
      'ChatFrame':
          'A full-screen frame (needs a bounded height and the tab bar); it is '
          'built by the chat screen sweep.',
      'StorybookScreen':
          'a developer-only gallery behind /_/storybook, not a product '
          'surface. It builds every other widget in the app, so pumping '
          'it here would re-run the whole matrix inside one test and '
          'report any failure against the gallery rather than against '
          'the widget that actually broke.',
      'ShareIntentBootstrap':
          'a platform-channel host, not a layout. `initState` subscribes to '
          'ReceiveSharingIntent and an iOS MethodChannel — neither of '
          'which exists under flutter_test — and `build` returns '
          'SizedBox.shrink() until a share is staged, so the matrix '
          'would be measuring an empty box. Its actual surface is '
          'ShareDestinationSheet, which the screen sweeps cover; the '
          'intake logic is covered by share_position_origin_test.dart.',
    };

    final missing =
        declared.keys
            .where((w) => !exempt.containsKey(w))
            .where(
              (w) => !RegExp(
                '$w'
                r'(?:\.\w+)?\s*\(',
              ).hasMatch(everyTest),
            )
            .toList()
          ..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'These feature widgets are never constructed by any test:\n'
          '${missing.map((w) => '  • $w  (${declared[w]})').join('\n')}\n\n'
          'Fix: add a case to `cases` above — that is one line for 5 '
          'viewports x 2 locales x 2 text scales plus the dark theme. Feed '
          'it kLongArabic / kUnbreakable, never a short label: a widget that '
          'has only ever seen "OK" is untested. A screen belongs in the '
          'screen sweeps instead. If it genuinely cannot be built '
          'standalone, add it to `exempt` WITH the reason.',
    );

    for (final name in exempt.keys) {
      expect(
        declared.keys,
        contains(name),
        reason:
            '`$name` is exempted here but no longer exists under '
            'lib/features. Drop the entry.',
      );
    }
  });
}
