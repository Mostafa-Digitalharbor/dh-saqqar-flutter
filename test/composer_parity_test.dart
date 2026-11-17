// The redesigned composer bar (figma-design / Chat-Screen).
//
// Layout: a dark glass card — "Ask me anything …" over a row of round
// controls:
//   [ 📎 attach ] [ ⛓ tools ]   —spacer—   [ 🎤 ] [ ↑ send ]
//
// Task prep / Auto-approve no longer sit in the bar: they moved to the ⋮
// "Saqqar Tools" sheet (see `tools_sheet.dart`), which is where the design
// puts them. Deep-think stays gone (web removed it) and there is no loose
// slash button.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/chat_composer.dart';

Future<void> _pumpComposer(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool withTools = true,
  bool voice = true,
  VoidCallback? onTools,
  VoidCallback? onAttach,
  VoidCallback? onSend,
  VoidCallback? onStartRecording,
  TextEditingController? controller,
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
      theme: AppTheme.dark(locale),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: controller ?? TextEditingController(),
            attachments: const [],
            onAttach: onAttach ?? () {},
            onTools: withTools ? (onTools ?? () {}) : null,
            onRemoveAttachment: (_) {},
            onPreviewAttachment: (_) {},
            onSend: onSend ?? () {},
            voiceEnabled: voice,
            taskPrep: false,
            taskPrepAvailable: true,
            autoApprove: false,
            onTaskPrepChanged: (_) {},
            onAutoApproveChanged: (_) {},
            onStartRecording: onStartRecording ?? () {},
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

  testWidgets('shows the placeholder and the four round controls',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.text('Ask me anything ...'), findsOneWidget);
    expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
    expect(find.byIcon(LucideIcons.workflow), findsOneWidget);
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowUpToLine), findsOneWidget);
  });

  testWidgets('the mode toggles no longer live in the bar', (tester) async {
    await _pumpComposer(tester);

    expect(find.text(en.taskPrep), findsNothing);
    expect(find.text(en.autoApprove), findsNothing);
  });

  testWidgets('no deep-think and no loose slash control', (tester) async {
    await _pumpComposer(tester);

    expect(find.text('Deep think'), findsNothing);
    expect(find.byIcon(AppIcons.sparkles), findsNothing);
    expect(find.byIcon(AppIcons.slash), findsNothing);
  });

  testWidgets('the paperclip fires onAttach', (tester) async {
    var attached = 0;
    await _pumpComposer(tester, onAttach: () => attached++);

    await tester.tap(find.byIcon(LucideIcons.paperclip));
    await tester.pump();

    expect(attached, 1);
  });

  testWidgets('the workflow button opens the tools menu', (tester) async {
    var opened = 0;
    await _pumpComposer(tester, onTools: () => opened++);

    await tester.tap(find.byIcon(LucideIcons.workflow));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a null onTools hides the tools button entirely',
      (tester) async {
    await _pumpComposer(tester, withTools: false);

    expect(find.byIcon(LucideIcons.workflow), findsNothing);
    expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
  });

  testWidgets('the mic is hidden when voice is locked on the plan',
      (tester) async {
    await _pumpComposer(tester, voice: false);

    expect(find.byIcon(LucideIcons.mic), findsNothing);
  });

  testWidgets('send is inert until there is something to send',
      (tester) async {
    var sent = 0;
    final controller = TextEditingController();
    await _pumpComposer(tester, onSend: () => sent++, controller: controller);

    await tester.tap(find.byIcon(LucideIcons.arrowUpToLine));
    await tester.pump();
    expect(sent, 0);

    controller.text = 'hello';
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.arrowUpToLine));
    await tester.pump();
    expect(sent, 1);
  });

  testWidgets('renders inside a 320 px viewport without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpComposer(tester, locale: const Locale('ar'));

    expect(tester.takeException(), isNull);
  });
}
