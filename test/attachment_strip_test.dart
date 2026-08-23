import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_chip.dart';
import 'package:saqqar_app/features/chat/widgets/chat_composer.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';

List<ChatAttachment> _images(int count) => [
      for (var i = 0; i < count; i++)
        ChatAttachment(
          name: 'shot-$i.png',
          // Arabic label on purpose: this is what a real Arabic device
          // stages, and it must not change the layout.
          kind: 'صورة',
          size: '${100 + i} KB',
        ),
    ];

Widget _composerHost(List<ChatAttachment> attachments) {
  const locale = Locale('ar');
  return MaterialApp(
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
          attachments: attachments,
          onAttach: () {},
          onRemoveAttachment: (_) {},
          onPreviewAttachment: (_) {},
          onSend: () {},
          taskPrep: false,
          autoApprove: false,
          onTaskPrepChanged: (_) {},
          onAutoApproveChanged: (_) {},
          onStartRecording: () {},
          onStopRecording: () {},
          onDiscardRecording: () {},
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // A phone-shaped viewport: the wrap-vs-row difference only shows up
    // once the thumbnails outgrow one line.
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 3.0;
    addTearDown(view.reset);
  });

  group('composer staging tray', () {
    testWidgets('lays many attachments out in one horizontal scroller',
        (tester) async {
      // A `Wrap` here reflowed into extra runs every few thumbnails, so
      // staging 10 files grew the composer vertically and pushed the
      // conversation off screen.
      await tester.pumpWidget(_composerHost(_images(10)));
      await tester.pump();

      final list = find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(ListView),
      );
      expect(list, findsOneWidget);
      expect(tester.widget<ListView>(list).scrollDirection, Axis.horizontal);

      // Every staged chip shares one baseline — proof they sit in a single
      // row rather than wrapping onto several.
      final chips = find.byType(AttachmentChip);
      expect(chips, findsWidgets);
      final tops = <double>{
        for (final e in chips.evaluate())
          (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
      };
      expect(tops.length, 1, reason: 'chips wrapped onto multiple rows');
    });

    testWidgets('tray height does not grow with the attachment count',
        (tester) async {
      Future<double> heightFor(int count) async {
        await tester.pumpWidget(_composerHost(_images(count)));
        await tester.pump();
        return tester.getSize(find.byType(ChatComposer)).height;
      }

      final withTwo = await heightFor(2);
      final withTwenty = await heightFor(20);
      expect(withTwenty, withTwo);
    });

    testWidgets('an Arabic-labelled image still renders its thumbnail path',
        (tester) async {
      // The composer decides thumbnail-vs-file-glyph from `isImage`, which
      // used to be derived from the localized `kind`. Under `ar` that made
      // every staged photo draw as a file square.
      await tester.pumpWidget(_composerHost(_images(1)));
      await tester.pump();

      expect(_images(1).single.isImage, isTrue);
      expect(find.byType(AttachmentChip), findsOneWidget);
    });
  });
}
