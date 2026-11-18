// Responsive sweep for the surfaces that only exist *on top of* a screen:
// dialogs, sheets and loading skeletons.
//
// `screen_responsive_sweep_test.dart` sweeps nine whole screens, but it can
// only ever see them in their loaded, idle state — its fake APIs return data
// synchronously, so a skeleton is never on screen when the frame is measured,
// and a dialog is never open. Those two states are exactly where fixed pixel
// widths survive: a `SizedBox(width: 360)` in a dialog and a 280 px skeleton
// bubble both look fine on the 800×600 default surface and both are wider than
// a 320 px phone's content box.
//
// Same matrix shape as the screen sweep, trimmed to the cells that actually
// constrain: the narrow portrait width and the short landscape height, each in
// both locales at 1.0× and 1.3× text.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/tasks/tasks_screen.dart';
import 'package:saqqar_app/shared/fig/fig.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/chat/data/chat_features.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_source_sheet.dart';
import 'package:saqqar_app/features/chat/widgets/saqqar_tools_sheet.dart';
import 'package:saqqar_app/features/chat/widgets/live_env_warning_dialog.dart';
import 'package:saqqar_app/features/chat/widgets/message_bubble_skeleton.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_actions_sheet.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_card_skeleton.dart';
import 'package:saqqar_app/features/conversations/widgets/rename_conversation_dialog.dart';
import 'package:saqqar_app/features/vault/widgets/project_card_skeleton.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/widgets/chat_search_sheet.dart';
import 'package:saqqar_app/features/chat/widgets/task_wording_sheet.dart';
import 'package:saqqar_app/features/chat/widgets/voice_input_button.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_row_menu.dart';
import 'package:saqqar_app/shared/widgets/app_card_dialog.dart';
import 'package:saqqar_app/shared/widgets/blocking_progress_dialog.dart';
import 'package:saqqar_app/shared/widgets/confirm_dialog.dart';

import 'support/responsive_harness.dart';

/// An exempt plan: every gate open, so every tools row renders its widest.
const _allFeatures = PlanSnapshot(
  slug: 'max-20x',
  name: 'Business',
  exempt: true,
  day: _fullWindow,
  week: _fullWindow,
  month: _fullWindow,
  features: PlanFeatures(
    voice: true,
    postgres: true,
    github: true,
    serverShell: true,
  ),
);

const _fullWindow = UsageWindow(used: 0, cap: 100, pct: 0, remaining: 100);

/// A row carrying the longest realistic value in every slot: an Arabic title
/// that wraps, a preview that wraps again, and the project / environment
/// names off a real Odoo instance. The actions sheet reprints the title and
/// the environment as its header, so a short fixture would measure a header
/// that no user has.
ConversationSummary _conversation({required bool isArchived}) =>
    ConversationSummary(
      id: 'c1',
      title: 'محتاجه منك في فقرات كل مستخدم ايه الصلاحيات اللي عنده في الجروبات',
      createdAt: DateTime.utc(2026, 8, 4, 6, 40),
      updatedAt: DateTime.utc(2026, 8, 4, 6, 41),
      isArchived: isArchived,
      messageCount: 1349,
      lastMessagePreview:
          'تم. اتضاف 30 مستخدم في اللايف بنجاح (المعرّفات من 5 لـ 34)، وكلهم بالاسم',
      projectName: 'ALZOMMAN Trading & Contracting Establishment — Staging',
      environmentName:
          'ALZOMMAN Trading & Contracting Establishment — Staging Live',
      filesCount: 77,
    );

final _longConversation = _conversation(isArchived: false);
final _archivedConversation = _conversation(isArchived: true);

const _viewports = <({String name, Size size})>[
  (name: '320×568 tiny', size: Size(320, 568)),
  (name: '360×640 small', size: Size(360, 640)),
  (name: '568×320 landscape', size: Size(568, 320)),
];

const _locales = [Locale('en'), Locale('ar')];

/// The app's own ceiling, imported rather than re-typed.
///
/// This file used to declare `[1.0, 1.3]` privately. `app.dart` clamps the OS
/// scaler to `0.85…1.4`, so 1.4 — not 1.3 — is the widest type a user can
/// actually produce, and the shared harness had already been corrected to say
/// so. The correction did not reach here, because the constant was maintained
/// in three places: the top 0.1 of the supported range stayed unswept for
/// every dialog, sheet and skeleton in this file, which are precisely the
/// surfaces with the least room to give.
const _textScales = kTextScales;

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
    theme: AppTheme.dark(locale),
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: widget!,
    ),
    home: Scaffold(body: child),
  );
}

/// The overflow-menu trigger, found by icon rather than by text — it has no
/// label, and its tooltip is localized.
final _menuIcon = find.byIcon(AppIcons.more);

/// Pumps [build] across the matrix and fails on the first layout error,
/// naming the cell and the widget that caused it.
///
/// Three ways to get the surface on screen:
///
///   * default — [build] IS the surface, pumped directly;
///   * [asDialog] — [build] is passed to `showDialog`, so `Dialog`'s own
///     `insetPadding` and min-width constraints are the ones under test;
///   * [openWith] — [build] renders a trigger that opens the surface itself.
///     Needed for anything whose `show()` owns state the test cannot
///     reconstruct: `ChatSearchSheet` creates and disposes its controller
///     there, `PopupMenuButton` routes its own overlay.
Future<void> _sweep(
  WidgetTester tester,
  Widget Function() build, {
  bool asDialog = false,
  Object? openWith,
}) async {
  for (final viewport in _viewports) {
    for (final locale in _locales) {
      for (final scale in _textScales) {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Tear the previous cell's tree down before building the next one.
        //
        // `pumpWidget` with a new `MaterialApp` reuses the same `Navigator`
        // element, so a route pushed in cell N — every dialog and every sheet
        // this file opens — was still mounted in cell N+1, and the next
        // "open" tap landed on the leftover overlay instead of the button
        // under it. Twelve cells deep, the sweep was measuring a stack of
        // twelve dialogs rather than one, and the tap warnings it printed
        // were the only sign. Pumping a bare `SizedBox` first unmounts
        // everything, so each cell starts from nothing.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        final culprits = <String>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          culprits.add(
            details
                .toString()
                .split('\n')
                .where((l) {
                  final t = l.trim();
                  return t.startsWith('The relevant error-causing widget') ||
                      t.contains('.dart:') && !t.contains('package:flutter/');
                })
                .take(3)
                .join(' | '),
          );
          previousOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousOnError);

        if (asDialog) {
          // Shown the way the app shows it, so `Dialog`'s own insetPadding and
          // min-width constraints are the ones under test — pumping the widget
          // bare would measure a layout the user never sees.
          await tester.pumpWidget(
            _harness(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => build(),
                  ),
                  child: const Text('open'),
                ),
              ),
              locale: locale,
              scale: scale,
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
        } else {
          await tester.pumpWidget(
            _harness(build(), locale: locale, scale: scale),
          );
          await tester.pump();
          if (openWith != null) {
            // `warnIfMissed: false` — the landscape row can push the trigger
            // partly out of the 320 px-tall viewport, and the surface still
            // opens. A miss that matters shows up as the layout error this
            // sweep is looking for, not as a tap warning.
            await tester.tap(
              openWith is Finder ? openWith : find.text(openWith as String),
              warnIfMissed: false,
            );
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 350));
        }

        FlutterError.onError = previousOnError;
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: 'layout error on ${viewport.name} · '
              '${locale.languageCode} · $scale× text — $error\n'
              '${culprits.join('\n')}',
        );
      }
    }
  }
}

void main() {
  group('dialogs survive a narrow phone', () {
    testWidgets('RenameConversationDialog', (tester) async {
      await _sweep(
        tester,
        () => const RenameConversationDialog(initial: 'Quarterly close review'),
        asDialog: true,
      );
    });

    testWidgets('ConfirmDialog', (tester) async {
      await _sweep(
        tester,
        () => const ConfirmDialog(
          title: 'Delete this conversation?',
          body: 'This removes the transcript and every artifact attached to it. '
              'It cannot be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        ),
        asDialog: true,
      );
    });

    testWidgets('LiveEnvWarningDialog', (tester) async {
      await _sweep(
        tester,
        () => const LiveEnvWarningDialog(
          environmentName: 'production-eu-west-1',
          projectName: 'Digital Harbor ERP',
        ),
        asDialog: true,
      );
    });

    testWidgets('BlockingProgressDialog', (tester) async {
      await _sweep(tester, () => const BlockingProgressDialog(),
          asDialog: true);
    });
  });

  group('bottom sheets survive a narrow phone', () {
    testWidgets('AttachmentPickerSourceSheet', (tester) async {
      await _sweep(tester, () => const AttachmentPickerSourceSheet());
    });

    testWidgets('SaqqarToolsSheet with every tool unlocked', (tester) async {
      // Unlocked rather than locked: an enabled row carries the tool name, a
      // description and a trailing control, which is the widest the sheet
      // ever gets. Built 2026-08-04 in the web-parity push and never swept.
      await _sweep(
        tester,
        () => SaqqarToolsSheet(
          features: const ChatFeatures(_allFeatures),
          taskPrep: true,
          autoApprove: true,
          onTaskPrepChanged: (_) {},
          onAutoApproveChanged: (_) {},
        ),
      );
    });

    // The per-conversation ⋯ menu. Every action that is scoped to one chat —
    // rename, pin, archive, share, delete — lives only here, so an overflow
    // that eats a row takes the app's only route to that action with it.
    //
    // Its own comment already names the failure it is built against ("an
    // uncapped, unscrollable column overflows wherever the content is taller
    // than the window — landscape at ~320 px tall, or Arabic at 1.4×"), and
    // the fix is a `MediaQuery.sizeOf(context).height * 0.85` cap. Nothing
    // was holding that cap in place: the sheet was never swept, so the
    // landscape row it was written for had never actually been run against
    // it.
    testWidgets('ConversationActionsSheet', (tester) async {
      await _sweep(tester, () => ConversationActionsSheet(
            conversation: _longConversation,
            isPinned: true,
          ));
    });

    // Same sheet, archived: the archive row swaps to "Unarchive", which is
    // the longer word in both locales, and the pin row disappears — a
    // different row count against the same height cap.
    testWidgets('ConversationActionsSheet (archived, unpinned)',
        (tester) async {
      await _sweep(tester, () => ConversationActionsSheet(
            conversation: _archivedConversation,
            isPinned: false,
          ));
    });
  });

  group('loading skeletons survive a narrow phone', () {
    // The chat skeleton is the one with hardcoded bubble widths, and the
    // widest (280) is within 12 px of a 320 px screen's content box before the
    // bubble's own padding is counted.
    testWidgets('MessageBubbleSkeleton at its widest', (tester) async {
      await _sweep(
        tester,
        () => const Column(
          children: [
            MessageBubbleSkeleton(isUser: false, bubbleWidth: 280, linesCount: 3),
            MessageBubbleSkeleton(isUser: true, bubbleWidth: 260, linesCount: 2),
          ],
        ),
      );
    });

    testWidgets('ConversationCardSkeleton', (tester) async {
      await _sweep(tester, () => const ConversationCardSkeleton());
    });

    testWidgets('ProjectCardSkeleton', (tester) async {
      await _sweep(tester, () => const ProjectCardSkeleton());
    });
  });

  // ── The five overlays nothing was sweeping ─────────────────────────────
  //
  // Every dialog and sheet above was added to this file because it broke, or
  // because someone noticed it could. These five were simply never listed:
  // `ChatSearchSheet`, `TaskWordingSheet`, `RecordingOverlay`,
  // `ConversationRowMenu` and `AppCardDialog` render on the same 320 px
  // phones as everything else, and three of them are the ONLY route to the
  // action they carry — a row menu that overflows takes rename, pin, share,
  // archive and delete with it.
  //
  // `AppCardDialog` in particular sizes itself off `MediaQuery.sizeOf`, which
  // is exactly the kind of viewport arithmetic the default 800×600 test
  // surface never exercises: its `minHeight` floor can exceed the viewport on
  // the landscape row, and nothing was checking that the clamp survives it.
  group('the overlays that had no sweep at all', () {
    testWidgets('ChatSearchSheet', (tester) async {
      // Opened through its own `show`, because the controller lifecycle and
      // the `viewInsets` padding both live in there rather than in a widget
      // this test could build directly.
      final messages = <ChatMessage>[
        for (var i = 0; i < 12; i++)
          ChatMessage(
            role: i.isEven ? ChatMessageRole.user : ChatMessageRole.assistant,
            content: i.isEven
                ? 'محتاجه منك في فقرات كل مستخدم ايه الصلاحيات اللي عنده'
                : 'ALZOMMAN Trading & Contracting Establishment — Staging Live',
            time: '10:0$i',
            id: 'm$i',
          ),
      ];
      await _sweep(
        tester,
        () => Builder(
          builder: (context) => TextButton(
            onPressed: () => ChatSearchSheet.show(context, messages: messages),
            child: const Text('open'),
          ),
        ),
        openWith: 'open',
      );
    });

    testWidgets('TaskWordingSheet', (tester) async {
      await _sweep(
        tester,
        () => Builder(
          builder: (context) => TextButton(
            onPressed: () => TaskWordingSheet.show(
              context,
              // The composer hands over whatever is half-typed, so the field
              // opens at whatever length the user had already reached.
              initialQuery: kLongName,
            ),
            child: const Text('open'),
          ),
        ),
        openWith: 'open',
      );
    });

    testWidgets('ScheduleTaskSheet (Fig notch sheet)', (tester) async {
      await _sweep(
        tester,
        () => Builder(
          builder: (context) => TextButton(
            onPressed: () => showFigSheet<void>(
              context,
              builder: (_) => const ScheduleTaskSheet(),
            ),
            child: const Text('open'),
          ),
        ),
        openWith: 'open',
      );
    });

    // Replaces the composer's text field, so it is width-constrained by the
    // same row that holds the send button — and it carries a fixed-width
    // waveform plus a monospace timer, the two things least willing to shrink.
    testWidgets('RecordingOverlay recording', (tester) async {
      await _sweep(
        tester,
        () => RecordingOverlay(
          // Past ten minutes the timer is five glyphs, not four.
          elapsed: const Duration(minutes: 12, seconds: 34),
          transcribing: false,
          onStop: () {},
          onDiscard: () {},
        ),
      );
    });

    testWidgets('RecordingOverlay transcribing', (tester) async {
      await _sweep(
        tester,
        () => RecordingOverlay(
          elapsed: const Duration(seconds: 8),
          transcribing: true,
          onStop: () {},
          onDiscard: () {},
        ),
      );
    });

    // The kebab menu, opened. `PopupMenuButton` lays its items out against the
    // viewport, so a long Arabic label at 1.4× is the case that decides
    // whether "Unarchive" fits beside its icon.
    testWidgets('ConversationRowMenu opened', (tester) async {
      await _sweep(
        tester,
        () => Align(
          alignment: Alignment.topRight,
          child: ConversationRowMenu(
            onAction: (_) {},
            isPinned: true,
            isArchived: true,
          ),
        ),
        openWith: _menuIcon,
      );
    });

    // The shell the vault's two card dialogs share. Swept at the height
    // fraction its tallest caller uses, so the clamp is exercised against a
    // viewport shorter than its own `minHeight`.
    testWidgets('AppCardDialog at its tallest', (tester) async {
      await _sweep(
        tester,
        () => AppCardDialog(
          heightFactor: 0.8,
          minHeight: 320,
          maxHeight: 640,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < 8; i++)
                ListTile(title: Text('$kLongName $i')),
            ],
          ),
        ),
        asDialog: true,
      );
    });
  });
}
