// Responsive sweep over the surfaces the user actually spends time in.
//
// `responsive_layout_test.dart` already pins three widgets that each had a
// specific, reproduced overflow bug — it is a regression file and should stay
// that way. This file is the complementary one: a *breadth* sweep that pumps
// the high-traffic chat and list surfaces across the whole device matrix so a
// new overflow is caught the day it is written rather than the day a user on
// a 320 px phone reports it.
//
// The matrix is (5 viewports × 2 locales × 2 text scales) = 20 layouts per
// surface. Each axis earns its place:
//
//   * **320×568** — the narrowest Android slice still in the support matrix,
//     and the width every unguarded `Row` breaks at first.
//   * **568×320** — landscape on that same phone. Nothing pins this app to
//     portrait, so any surface that centres a fixed-height column overflows
//     vertically here. This is the axis the earlier lock-screen bug lived on.
//   * **Arabic** — not just a mirror. Arabic strings in this app run longer
//     than their English counterparts, so AR is a stricter width test, and RTL
//     exercises the `Directional` variants of every padding and alignment.
//   * **1.3× text** — a common accessibility setting, not a stress value. It
//     compounds with Arabic: longer strings and taller glyphs at once.
//
// A failure here prints the exact viewport / locale / scale that broke, so the
// repro is the test name.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/chat/widgets/chat_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/chat_plan_banner.dart';
import 'package:saqqar_app/features/chat/widgets/chat_run_progress_card.dart';
import 'package:saqqar_app/features/chat/widgets/chat_typing_row.dart';
import 'package:saqqar_app/features/chat/widgets/empty_chat_suggestions.dart';
import 'package:saqqar_app/features/chat/widgets/message_row.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/features/account/widgets/account_link_group.dart';
import 'package:saqqar_app/features/account/widgets/stats_line.dart';
import 'package:saqqar_app/features/chat/view_model/running_agents_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_card.dart';
import 'package:saqqar_app/features/chat/widgets/artifact_pill.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_chip.dart';
import 'package:saqqar_app/features/chat/widgets/chat_suggestion_strip.dart';
import 'package:saqqar_app/features/conversations/widgets/gradient_fab.dart';
import 'package:saqqar_app/features/conversations/widgets/swipe_archive_background.dart';
import 'package:saqqar_app/shared/widgets/pagination_bar.dart';
import 'package:saqqar_app/shared/widgets/save_status_hint.dart';
import 'package:saqqar_app/features/chat/widgets/chat_artifact_tile.dart';
import 'package:saqqar_app/features/chat/widgets/chat_env_hint_banner.dart';
import 'package:saqqar_app/features/chat/widgets/chat_resume_banner.dart';
import 'package:saqqar_app/features/chat/widgets/tool_activity_card.dart';
import 'package:saqqar_app/features/conversations/widgets/conversations_empty_state.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/widgets/project_card.dart';

import 'support/responsive_harness.dart';

/// `ConversationCard` reads its pinned flag via
/// `context.select<ConversationsCubit, bool>`, so the card needs the cubit in
/// scope even though this file is only testing layout. The cubit is never
/// driven here — it just has to exist.
class _InertRepo implements ConversationsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

// ── Matrix ───────────────────────────────────────────────────────────────

typedef _Viewport = ({String name, Size size});

const _viewports = <_Viewport>[
  (name: '320×568 tiny', size: Size(320, 568)),
  (name: '360×640 small', size: Size(360, 640)),
  (name: '390×844 compact', size: Size(390, 844)),
  (name: '430×932 regular', size: Size(430, 932)),
  (name: '568×320 landscape', size: Size(568, 320)),
];

const _locales = <Locale>[Locale('en'), Locale('ar')];
/// The app's own ceiling, imported rather than re-typed — see the note beside
/// `kTextScales`. This file's private `[1.0, 1.3]` was the second of three
/// copies, and the one covering the individual bubbles, cards and chips.
const _textScales = kTextScales;

/// The real chat lane clamps its content to 760 px and pads 14 px a side, so
/// a bubble on a wide phone never gets the full viewport. Pumping into the
/// bare viewport would hand widgets *more* room than production and hide the
/// overflows this file exists to find.
Widget _chatLane(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
      ),
    );

Widget _harness(Widget child, {required Locale locale, required double scale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: _locales,
    theme: AppTheme.light(locale),
    darkTheme: AppTheme.dark(locale),
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: widget ?? const SizedBox.shrink(),
    ),
    // `SingleChildScrollView` mirrors what every real screen wraps its body
    // in; without it a surface that is legitimately taller than a 320 px
    // landscape viewport reports a vertical overflow that production never
    // shows the user.
    home: Scaffold(body: SafeArea(child: SingleChildScrollView(child: child))),
  );
}

/// Pumps [build] at every cell of the matrix and fails on the first layout
/// exception, naming the cell.
Future<void> _sweep(
  WidgetTester tester,
  Widget Function() build, {
  bool laneClamped = true,
}) async {
  for (final viewport in _viewports) {
    for (final locale in _locales) {
      for (final scale in _textScales) {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final child = laneClamped ? _chatLane(build()) : build();
        await tester.pumpWidget(
          _harness(child, locale: locale, scale: scale),
        );
        // Deliberately `pump`, never `pumpAndSettle`: several of these
        // surfaces run perpetual animations (typing dots, the working pill),
        // so settling would time out and swallow the real failure.
        await tester.pump();
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: 'layout error at ${viewport.name} · '
              '${locale.languageCode} · $scale× text — $error',
        );
      }
    }
  }
}

// ── Fixtures ─────────────────────────────────────────────────────────────

const _longEn =
    'Reconcile the SAR ledger for Q3, then export a per-warehouse stock '
    'valuation report and email it to the finance team before close of '
    'business on Thursday.';

const _longAr =
    'قم بتسوية دفتر الأستاذ بالريال السعودي للربع الثالث، ثم صدّر تقرير '
    'تقييم المخزون لكل مستودع وأرسله إلى فريق المالية قبل نهاية يوم الخميس.';

ChatMessage _message(ChatMessageRole role, String content) => ChatMessage(
      id: 'm1',
      role: role,
      content: content,
      time: '10:24',
      createdAt: DateTime.utc(2026, 7, 25, 10, 24),
    );

/// A tool-result message. `ToolActivityCard` renders `toolName` as a header
/// chip next to the timestamp, so the long name is the interesting case.
ChatMessage _toolMessage(String toolName, String content) => ChatMessage(
      id: 'm2',
      role: ChatMessageRole.tool,
      content: content,
      toolName: toolName,
      time: '10:24',
      createdAt: DateTime.utc(2026, 7, 25, 10, 24),
    );

ChatArtifact _artifact(String name) => ChatArtifact(
      id: 'a1',
      name: name,
      kind: 'xlsx',
      size: '12.4 MB',
      conversation: 'Q3 ledger close and stock reconciliation',
      conversationId: 'c1',
      createdLabel: 'Jul 25',
    );

ChatAttachment _attachment(String name) => ChatAttachment(
      name: name,
      kind: 'pdf',
      size: '12.4 MB',
    );

Environment _env(String name, {bool isLive = false}) => Environment(
      id: 'env-$name',
      name: name,
      slug: name,
      isLive: isLive,
      readOnly: false,
      autoApprove: false,
      projectId: 'p1',
    );

Project _project(String name, List<Environment> environments) => Project(
      id: 'p1',
      name: name,
      slug: 'p1',
      environments: environments,
    );

ChatApproval _approval() => const ChatApproval(
      id: 'a1',
      title: 'Update 42 manufacturing orders',
      prompt: _longEn,
      actionType: 'odoo_write',
      risk: 'high',
      status: ChatApprovalStatus.pending,
      payload: {
        'model': 'mrp.production',
        'method': 'write',
        'record_count': '42',
      },
    );

PlanSnapshot _plan({int pct = 92}) => PlanSnapshot(
      slug: 'free',
      name: 'Free',
      exempt: false,
      day: UsageWindow(used: pct, cap: 100, pct: pct, remaining: 100 - pct),
      week: const UsageWindow(used: 10, cap: 500, pct: 2, remaining: 490),
      month: const UsageWindow(used: 20, cap: 2000, pct: 1, remaining: 1980),
      features: const PlanFeatures(voice: true),
    );

ConversationSummary _summary({required String title, required String preview}) =>
    ConversationSummary(
      id: 'c1',
      title: title,
      createdAt: DateTime.utc(2026, 7, 25, 9),
      updatedAt: DateTime.utc(2026, 7, 25, 10),
      isArchived: false,
      messageCount: 24,
      lastMessagePreview: preview,
      isRunning: true,
      projectName: 'ALZOMMAN Group Holding',
      environmentName: 'Production Staging Server',
    );

// ── Tests ────────────────────────────────────────────────────────────────

void main() {
  group('Chat lane surfaces', () {
    testWidgets('user bubble with a long single-line-hostile prompt',
        (tester) async {
      await _sweep(
        tester,
        () => Builder(
          builder: (context) => MessageRow(
            message: _message(
              ChatMessageRole.user,
              Localizations.localeOf(context).languageCode == 'ar'
                  ? _longAr
                  : _longEn,
            ),
            isFirstOfGroup: true,
            isLastOfGroup: true,
            isRunning: false,
          ),
        ),
      );
    });

    testWidgets('assistant bubble carrying markdown + a wide code block',
        (tester) async {
      // A fenced block cannot wrap, so it is the single most reliable way to
      // push a bubble past a 320 px lane. It must scroll horizontally inside
      // its own box rather than overflow the message.
      await _sweep(
        tester,
        () => MessageRow(
          message: _message(
            ChatMessageRole.assistant,
            '**Done.** Here is the query I ran:\n\n'
            '```sql\n'
            'SELECT partner_id, SUM(amount_total) FROM account_move '
            'WHERE state = \'posted\' GROUP BY partner_id ORDER BY 2 DESC;\n'
            '```\n\n'
            '| Warehouse | Value |\n|---|---|\n| Riyadh Central | 1,204,338 |',
          ),
          isFirstOfGroup: true,
          isLastOfGroup: true,
          isRunning: false,
        ),
      );
    });

    testWidgets('approval card', (tester) async {
      await _sweep(
        tester,
        () => ChatApprovalCard(
          approval: _approval(),
          onApprove: () {},
          onReject: () {},
        ),
      );
    });

    testWidgets('typing row with the longest status label', (tester) async {
      await _sweep(
        tester,
        () => const ChatTypingRow(
          firstOfGroup: true,
          statusLabel: 'Generating the stock valuation report…',
        ),
      );
    });

    testWidgets('run progress card, determinate and indeterminate',
        (tester) async {
      await _sweep(
        tester,
        () => const ChatRunProgressCard(
          progress: ChatRunProgress(
            phase: RunProgressPhase.rendering,
            current: 1840,
            total: 5200,
            rows: 5200,
            fileName: 'stock-valuation-per-warehouse-2026-Q3.xlsx',
          ),
        ),
      );
      await _sweep(
        tester,
        () => const ChatRunProgressCard(
          progress: ChatRunProgress(phase: RunProgressPhase.fetching),
        ),
      );
    });
  });

  group('Composer-adjacent banners', () {
    testWidgets('plan banner at near-limit and over-limit', (tester) async {
      await _sweep(
        tester,
        () => ChatPlanBanner(
          plan: _plan(),
          exceededWindow: null,
          onUpgrade: () {},
        ),
        laneClamped: false,
      );
      await _sweep(
        tester,
        () => ChatPlanBanner(
          plan: _plan(pct: 100),
          exceededWindow: QuotaWindow.day,
          onUpgrade: () {},
        ),
        laneClamped: false,
      );
    });

    testWidgets('empty-chat suggestion grid', (tester) async {
      await _sweep(
        tester,
        () => EmptyChatSuggestions(onSuggestionTap: (_) {}),
        laneClamped: false,
      );
    });
  });

  group('Account identity card', () {
    testWidgets('workspace stats survive four-digit counts everywhere',
        (tester) async {
      // The counts are real-account sized: the account this was designed
      // against has 2,368 approvals and 813 artifacts. Four of those plus
      // their labels have to share a 320 px row, and the labels are longer in
      // Arabic. The layout answers by dropping to 2×2 below ~304 px — this
      // pins that it never overflows and never breaks a label mid-word.
      await _sweep(
        tester,
        () => const StatsLine(
          conversations: 136,
          credentials: 17,
          approvals: 2368,
          artifacts: 813,
        ),
        laneClamped: false,
      );
    });

    testWidgets('account link group survives the tight cases', (tester) async {
      // The Account destinations used to be bare full-width pills carrying one
      // word each; they now carry an icon tile, a title, a description and a
      // chevron on the same row. That is four things competing for a 320 px
      // line, and the descriptions are sentences — longer in Arabic than in
      // English, and longer again at 1.3× scale. Density is exactly what this
      // sweep exists to catch, so the denser layout has to be pinned here.
      await _sweep(
        tester,
        () => Builder(
          builder: (context) {
            final isArabic =
                Localizations.localeOf(context).languageCode == 'ar';
            return AccountLinkGroup(
              title: isArabic ? 'مساحة العمل' : 'Workspace',
              subtitle: isArabic
                  ? 'أدوات تشتغل على أودو مباشرة.'
                  : 'Tools that work on your Odoo directly.',
              icon: AppIcons.grid,
              links: [
                AccountLink(
                  icon: Icons.grid_view_rounded,
                  title: isArabic ? 'تطبيقات صقّار' : 'Saqqar Apps',
                  subtitle: isArabic
                      ? 'إعدادات موجّهة تشغّلها بضغطة واحدة.'
                      : 'Guided setups you can run in one tap.',
                  onTap: () {},
                ),
                AccountLink(
                  icon: Icons.table_chart_outlined,
                  title: isArabic ? 'مستكشف البيانات' : 'Data explorer',
                  subtitle: isArabic
                      ? 'اقرأ نماذجك وسجلاتك مباشرة.'
                      : 'Read your models and records directly.',
                  onTap: () {},
                ),
              ],
            );
          },
        ),
        laneClamped: false,
      );
    });

    testWidgets('and degenerate counts', (tester) async {
      await _sweep(
        tester,
        () => const StatsLine(
          conversations: 0,
          credentials: 0,
          approvals: 0,
          artifacts: 0,
        ),
        laneClamped: false,
      );
      await _sweep(
        tester,
        () => const StatsLine(
          conversations: 999999,
          credentials: 999999,
          approvals: 999999,
          artifacts: 999999,
        ),
        laneClamped: false,
      );
    });
  });

  group('Conversations list', () {
    testWidgets('card with long title, preview, project and env tags',
        (tester) async {
      await _sweep(
        tester,
        () => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ConversationsCubit(repository: _InertRepo()),
            ),
            BlocProvider(create: (_) => RunningAgentsCubit()),
          ],
          child: Builder(
            builder: (context) {
              final isArabic =
                  Localizations.localeOf(context).languageCode == 'ar';
              return ConversationCard(
                conversation: _summary(
                  title: isArabic
                      ? 'إقفال دفتر الأستاذ وتسوية المخزون للربع الثالث'
                      : 'Q3 ledger close and stock reconciliation',
                  preview: isArabic ? _longAr : _longEn,
                ),
                pendingApprovals: 12,
                filesCount: 7,
                onTap: () {},
                onAction: (_) {},
              );
            },
          ),
        ),
        laneClamped: false,
      );
    });

    testWidgets('empty state', (tester) async {
      await _sweep(
        tester,
        () => ConversationsEmptyState(onStart: () {}),
        laneClamped: false,
      );
    });
  });

  // Surfaces that carry SERVER-SUPPLIED names. Every fixture below uses a
  // hostile-but-real value — an Odoo model path, a Windows-style export
  // filename, a customer's full legal name — because these are the widths
  // the app cannot choose and therefore cannot get wrong.
  group('Server-named surfaces', () {
    testWidgets('artifact tile with a long generated filename', (tester) async {
      await _sweep(
        tester,
        () => ChatArtifactTile(
          artifact: _artifact(
            'stock_valuation_per_warehouse_2026_Q3_final_reviewed.xlsx',
          ),
          onOpen: () {},
        ),
      );
    });

    testWidgets('attachment chip with a long filename', (tester) async {
      await _sweep(
        tester,
        () => AttachmentChip(
          attachment: _attachment(
            'purchase_order_confirmation_ALZOMMAN_2026_07_25.pdf',
          ),
        ),
      );
      await _sweep(
        tester,
        () => AttachmentChip(
          attachment: _attachment('invoice.pdf'),
          compact: true,
        ),
      );
    });

    testWidgets('tool activity card with a long tool name and payload',
        (tester) async {
      await _sweep(
        tester,
        () => ToolActivityCard(
          message: _toolMessage(
            'odoo.execute_kw.stock.quant.read_group',
            '{"model": "stock.quant", "domain": [["location_id.usage", "=", '
                '"internal"]], "fields": ["quantity", "product_id"]}',
          ),
        ),
      );
    });

    testWidgets('environment hint banner, idle and busy', (tester) async {
      await _sweep(tester, () => ChatEnvHintBanner(onUseMyDatabase: () {}));
      await _sweep(
        tester,
        () => ChatEnvHintBanner(onUseMyDatabase: () {}, busy: true),
      );
    });

    testWidgets('resume banner, idle and busy', (tester) async {
      await _sweep(tester, () => ChatResumeBanner(onResume: () {}));
      await _sweep(
        tester,
        () => ChatResumeBanner(onResume: () {}, busy: true),
      );
    });

    testWidgets('project card with a long name and several environments',
        (tester) async {
      await _sweep(
        tester,
        () => ProjectCard(
          project: _project(
            'ALZOMMAN Group Holding — Riyadh Distribution',
            [_env('Production', isLive: true), _env('Staging'), _env('Dev')],
          ),
          environments: [
            _env('Production', isLive: true),
            _env('Staging'),
            _env('Dev'),
          ],
          onEnvTap: (_) {},
          onTap: () {},
        ),
        laneClamped: false,
      );
    });
  });

  // Small chrome that renders a translated label inside a `Row` with no
  // flex on it. Individually cheap; collectively these are where a longer
  // Arabic string at 1.3× text runs out of room first.
  group('Labelled chrome', () {
    testWidgets('pagination bar at four-digit counts', (tester) async {
      await _sweep(
        tester,
        () => Builder(
          builder: (context) => PaginationBar(
            page: 128,
            pageCount: 1024,
            visibleCount: 50,
            totalCount: 51200,
            itemLabel: context.tr.conversations,
            onPrevious: () {},
            onNext: () {},
          ),
        ),
        laneClamped: false,
      );
    });

    testWidgets('save status hint in every tone', (tester) async {
      for (final tone in SaveStatusTone.values) {
        await _sweep(
          tester,
          () => Builder(
            builder: (context) => SaveStatusHint(
              label: tone == SaveStatusTone.saved
                  ? context.tr.statusSaved
                  : context.tr.statusNoChanges,
              tone: tone,
            ),
          ),
          laneClamped: false,
        );
      }
    });

    testWidgets('new-conversation FAB', (tester) async {
      await _sweep(
        tester,
        () => Builder(
          builder: (context) => Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GradientFab(
              onPressed: () {},
              label: context.tr.newConversation,
            ),
          ),
        ),
        laneClamped: false,
      );
    });

    testWidgets('swipe backgrounds', (tester) async {
      for (final archived in [false, true]) {
        await _sweep(
          tester,
          () => SizedBox(
            height: 96,
            child: SwipeArchiveBackground(
              alignment: AlignmentDirectional.centerStart,
              archived: archived,
            ),
          ),
          laneClamped: false,
        );
      }
      await _sweep(
        tester,
        () => const SizedBox(
          height: 96,
          child:
              SwipeDeleteBackground(alignment: AlignmentDirectional.centerEnd),
        ),
        laneClamped: false,
      );
    });

    testWidgets('artifact pill with a long filename', (tester) async {
      await _sweep(
        tester,
        () => ArtifactPill(
          attachment: _attachment(
            'stock_valuation_per_warehouse_2026_Q3_final.xlsx',
          ),
          onOpen: () {},
        ),
      );
    });

    testWidgets('chat suggestion strip', (tester) async {
      await _sweep(
        tester,
        () => ChatSuggestionStrip(visible: true, onSelect: (_) {}),
        laneClamped: false,
      );
    });
  });
}
