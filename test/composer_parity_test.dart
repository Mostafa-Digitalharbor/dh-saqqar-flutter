// docs/WEB_UI_PARITY_GAPS.md §2 / §3 / §5 — the reshaped composer bar.
//
// Target layout, left → right:
//   [ ＋ tools ] [🎤]  —spacer—  [badges] [→ send]
//   [ Task prep ] [ Auto-approve ]
//
// No deep-think anywhere (web removed it), no loose slash button (folded into
// the ＋ sheet), and — since 2026-08-06 — no paperclip either.
//
// The paperclip used to be kept as a deliberate divergence from web, on the
// argument that hiding upload behind a menu costs a tap. That argument lost:
// the ＋ sheet's FIRST row is "Upload file", so the two controls sat next to
// each other firing the identical action. A user reading the bar sees two
// affordances and reasonably assumes they do different things.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/chat_composer.dart';

Future<void> _pumpComposer(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool taskPrep = false,
  bool taskPrepAvailable = true,
  bool withTools = true,
  ValueChanged<bool>? onTaskPrepChanged,
  VoidCallback? onTools,
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
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: TextEditingController(),
            attachments: const [],
            onAttach: () {},
            onTools: withTools ? (onTools ?? () {}) : null,
            onRemoveAttachment: (_) {},
            onPreviewAttachment: (_) {},
            onSend: () {},
            taskPrep: taskPrep,
            taskPrepAvailable: taskPrepAvailable,
            autoApprove: false,
            onTaskPrepChanged: onTaskPrepChanged ?? (_) {},
            onAutoApproveChanged: (_) {},
            onStartRecording: () {},
            onStopRecording: () {},
            onDiscardRecording: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  testWidgets('shows the ＋ tools button and the two mode toggles',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.byIcon(AppIcons.plus), findsOneWidget);
    expect(find.text(en.taskPrep), findsOneWidget);
    expect(find.text(en.autoApprove), findsOneWidget);
  });

  testWidgets('there is NO second upload control beside the ＋',
      (tester) async {
    // Upload lives in the ＋ sheet, once. A paperclip here would be a
    // duplicate door into the same room.
    await _pumpComposer(tester);

    expect(find.byIcon(AppIcons.attach), findsNothing);
  });

  testWidgets('no deep-think control survives anywhere in the bar',
      (tester) async {
    await _pumpComposer(tester);

    // The English label the toggle used to carry. Asserted through the
    // rendered tree rather than the source so a stray re-add of the widget
    // (with a new key) still trips this.
    expect(find.text('Deep think'), findsNothing);
    expect(find.byIcon(AppIcons.sparkles), findsNothing);
  });

  testWidgets('the loose slash button is gone (it moved into the ＋ sheet)',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.byIcon(AppIcons.slash), findsNothing);
  });

  testWidgets('tapping ＋ opens the tools menu', (tester) async {
    var opened = 0;
    await _pumpComposer(tester, onTools: () => opened++);

    await tester.tap(find.byIcon(AppIcons.plus));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a null onTools hides the ＋ entirely', (tester) async {
    await _pumpComposer(tester, withTools: false);

    expect(find.byIcon(AppIcons.plus), findsNothing);
    // The rest of the bar is unaffected — the send button still resolves.
    expect(find.text(en.taskPrep), findsOneWidget);
  });

  testWidgets('the Task-prep toggle reports its new value', (tester) async {
    final flips = <bool>[];
    await _pumpComposer(
      tester,
      taskPrep: false,
      onTaskPrepChanged: flips.add,
    );

    await tester.tap(find.text(en.taskPrep));
    await tester.pump();

    expect(flips, [true]);
  });

  testWidgets('an ineligible plan hides the toggle AND its active badge',
      (tester) async {
    // `taskPrep: true` with `taskPrepAvailable: false` is the state a user
    // lands in when the server says their plan lacks the feature but their
    // stored preference is on. Neither the toggle nor the "mode is engaged"
    // badge may claim otherwise.
    await _pumpComposer(
      tester,
      taskPrep: true,
      taskPrepAvailable: false,
    );

    expect(find.text(en.taskPrep), findsNothing);
    expect(find.byIcon(AppIcons.lightbulb), findsNothing);
    // Auto-approve is gated separately and must survive.
    expect(find.text(en.autoApprove), findsOneWidget);
  });

  testWidgets('an active Task prep shows the pulsing mode badge',
      (tester) async {
    await _pumpComposer(tester, taskPrep: true);

    // Two: the badge next to Send and the toggle's own glyph.
    expect(find.byIcon(AppIcons.lightbulb), findsNWidgets(2));
  });

  testWidgets('Arabic renders the exact web-team strings', (tester) async {
    await _pumpComposer(tester, locale: const Locale('ar'));

    expect(ar.taskPrep, 'تجهيز المهمة');
    expect(find.text(ar.taskPrep), findsOneWidget);
  });

  testWidgets('renders inside a 320 px viewport without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpComposer(tester, locale: const Locale('ar'), taskPrep: true);

    expect(tester.takeException(), isNull);
  });
}
