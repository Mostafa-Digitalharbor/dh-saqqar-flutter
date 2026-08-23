import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/view/attachment_viewer_screen.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_chip.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
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
    home: Scaffold(body: child),
  );
}

void main() {
  group('AttachmentViewerScreen.kindFor', () {
    test('routes images to the in-app image viewer', () {
      for (final name in const [
        'shot.png', 'photo.JPG', 'a.jpeg', 'anim.gif', 'x.webp', 'scan.bmp',
      ]) {
        expect(
          AttachmentViewerScreen.kindFor(name),
          AttachmentViewerKind.image,
          reason: name,
        );
      }
    });

    test('routes PDFs to the in-app PDF viewer', () {
      expect(
        AttachmentViewerScreen.kindFor('invoice.pdf'),
        AttachmentViewerKind.pdf,
      );
      // Extension match must be case-insensitive — the server echoes back
      // whatever the user's filesystem had.
      expect(
        AttachmentViewerScreen.kindFor('INVOICE.PDF'),
        AttachmentViewerKind.pdf,
      );
    });

    test('routes text-shaped documents to the in-app text viewer', () {
      for (final name in const [
        'export.csv', 'data.tsv', 'notes.txt', 'readme.md',
        'payload.json', 'run.log', 'q.sql',
      ]) {
        expect(
          AttachmentViewerScreen.kindFor(name),
          AttachmentViewerKind.text,
          reason: name,
        );
      }
    });

    test('leaves office formats and archives to the hand-off state', () {
      // These are zipped XML — rendering them needs an office engine the
      // app deliberately does not ship. They must not claim to be text,
      // or the viewer would show the user binary garbage.
      for (final name in const [
        'book.xlsx', 'book.xls', 'doc.docx', 'doc.doc',
        'addon.zip', 'bundle.tar', 'x.gz',
      ]) {
        expect(
          AttachmentViewerScreen.kindFor(name),
          AttachmentViewerKind.unsupported,
          reason: name,
        );
      }
    });

    test('treats a name with no extension as unsupported, not text', () {
      expect(
        AttachmentViewerScreen.kindFor('README'),
        AttachmentViewerKind.unsupported,
      );
      expect(
        AttachmentViewerScreen.kindFor(''),
        AttachmentViewerKind.unsupported,
      );
    });
  });

  group('AttachmentViewerScreen body', () {
    testWidgets('unsupported kinds offer a hand-off instead of failing',
        (tester) async {
      // Sync I/O on purpose: `testWidgets` runs the body in a fake-async
      // zone, so an awaited `createTemp()` never resolves and wedges the
      // whole test isolate.
      final dir = Directory.systemTemp.createTempSync('saqqar_viewer_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/book.xlsx')..writeAsBytesSync([1, 2, 3]);

      await tester.pumpWidget(_host(
        AttachmentViewerScreen(
          file: file,
          name: 'book.xlsx',
          kindLabel: 'XLSX',
          sizeLabel: '12 KB',
        ),
      ));
      await tester.pump();

      expect(find.text("Can't preview this file here"), findsOneWidget);
      expect(find.text('Open in another app'), findsWidgets);
      // The app bar still identifies the file so the user knows what they
      // are being asked to open elsewhere.
      expect(find.text('book.xlsx'), findsOneWidget);
      expect(find.text('XLSX · 12 KB'), findsOneWidget);
    });

    testWidgets('renders a text file inline', (tester) async {
      // Sync I/O on purpose: `testWidgets` runs the body in a fake-async
      // zone, so an awaited `createTemp()` never resolves and wedges the
      // whole test isolate.
      final dir = Directory.systemTemp.createTempSync('saqqar_viewer_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/export.csv')
        ..writeAsStringSync('id,name\n1,Widget\n');

      await tester.pumpWidget(_host(
        AttachmentViewerScreen(file: file, name: 'export.csv'),
      ));

      await tester.pump();

      expect(find.textContaining('id,name'), findsOneWidget);
      expect(find.textContaining('1,Widget'), findsOneWidget);
    });
  });

  group('ChatAttachment.isImage', () {
    test('recognises an image staged under a non-English locale', () {
      // Regression guard. `kind` is a LOCALIZED display label — the composer
      // fills it from `tr.fileKindImage`, which is "صورة" in Arabic. Matching
      // English tokens against it made every image attached on an Arabic
      // device render as a generic file square with "صورة" underneath, while
      // an English emulator looked fine.
      const arabic = ChatAttachment(
        name: 'screenshot.png',
        kind: 'صورة',
        size: '184 KB',
      );
      expect(arabic.isImage, isTrue);

      const english = ChatAttachment(
        name: 'screenshot.png',
        kind: 'Image',
        size: '184 KB',
      );
      expect(english.isImage, isTrue);
    });

    test('still trusts the server kind when the name has no extension', () {
      const fromApi = ChatAttachment(
        name: 'b3d1f0e2-no-extension',
        kind: 'IMAGE',
        size: '12 KB',
      );
      expect(fromApi.isImage, isTrue);
    });

    test('does not mistake a document for an image in any locale', () {
      for (final kind in const ['PDF', 'ملف', 'XLSX']) {
        expect(
          ChatAttachment(name: 'report.pdf', kind: kind, size: '1 MB').isImage,
          isFalse,
          reason: kind,
        );
      }
    });
  });

  group('AttachmentChip image details', () {
    testWidgets('an image attachment shows its name, kind and size',
        (tester) async {
      // Regression guard: the image variant used to render only the kind
      // pill and the size, so two screenshots were indistinguishable.
      await tester.pumpWidget(_host(
        const AttachmentChip(
          attachment: ChatAttachment(
            name: 'invoice-scan.png',
            kind: 'IMAGE',
            size: '184 KB',
            imageUrl: 'https://example.invalid/invoice-scan.png',
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('invoice-scan.png'), findsOneWidget);
      expect(find.text('IMAGE'), findsOneWidget);
      expect(find.text('184 KB'), findsOneWidget);
    });
  });
}
