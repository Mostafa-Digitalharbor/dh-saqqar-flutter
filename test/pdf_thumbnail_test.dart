import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/shared/widgets/skeleton_block.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_chip.dart';
import 'package:saqqar_app/features/chat/widgets/pdf_thumbnail.dart';
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
    home: Scaffold(body: Center(child: child)),
  );
}

/// Smallest valid PNG — a 1×1 transparent pixel. Real bytes rather than
/// junk so `Image.memory` decodes instead of tripping its error builder.
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Whether this host has no pdfx backend at all — i.e. it is Linux.
///
/// `pdfx` ships no Linux implementation: `assertHasPdfSupport()` throws
/// `PlatformNotSupportedException` across an async gap that
/// `_PdfThumbnailState._render`'s catch does not receive, so the error lands
/// on the test zone instead. On Windows and macOS pdfx reports support and the
/// call dies later on the absent platform channel, which the widget's catch
/// DOES handle — which is why these passed on a dev machine and failed the
/// first time CI ran them on `ubuntu-latest`. (They had never run there: the
/// `dart format` gate failed ahead of them on every previous run.)
///
/// Skipped rather than "fixed", because Linux is not a platform this app
/// ships on — Android and iOS are, and both have a real pdfx backend. What
/// these would exercise on a Linux host is a code path no user can reach.
/// They still run on every developer machine, which is where the regression
/// they guard (widget setup dying before the renderer is called) gets caught.
///
/// The other four tests in this file seed the cache and never touch pdfx, so
/// they keep running everywhere.
/// A plain `bool`, not a reason string: `testWidgets` types `skip` as `bool?`
/// (only the bare `test()` accepts a String). The reason lives above.
final bool _noPdfxOnHost = Platform.isLinux;

void main() {
  setUp(PdfThumbnail.clearCache);

  group('isPdfName', () {
    test('matches only real PDF filenames, case-insensitively', () {
      expect(isPdfName('invoice.pdf'), isTrue);
      expect(isPdfName('INVOICE.PDF'), isTrue);
      expect(isPdfName('a.b.pdf'), isTrue);
      expect(isPdfName('notes.txt'), isFalse);
      expect(isPdfName('pdf'), isFalse, reason: 'no extension');
      expect(isPdfName('trailing.'), isFalse);
      expect(isPdfName(''), isFalse);
    });
  });

  group('PdfThumbnail', () {
    testWidgets('shows a shimmer while rendering, never the failure glyph',
        (tester) async {
      // The whole point of this state. Showing the glyph during the render
      // made a loading document look like one that could not be previewed,
      // and the page then replaced it a couple of seconds later.
      await tester.pumpWidget(_host(
        const PdfThumbnail(
          path: '/still/rendering.pdf',
          width: 72,
          height: 72,
          placeholder: Text('glyph'),
        ),
      ));
      await tester.pump();

      expect(find.byType(SkeletonBlock), findsOneWidget);
      expect(find.text('glyph'), findsNothing);
      expect(tester.takeException(), isNull);
    }, skip: _noPdfxOnHost);

    testWidgets('falls back to the placeholder once rendering has failed',
        (tester) async {
      // A thumbnail is decoration — failing to produce one must never take
      // out the chip that hosts it.
      PdfThumbnail.debugSeedCache('/unrenderable.pdf', null);

      await tester.pumpWidget(_host(
        const PdfThumbnail(
          path: '/unrenderable.pdf',
          width: 72,
          height: 72,
          placeholder: Text('glyph'),
        ),
      ));
      await tester.pump();

      expect(find.text('glyph'), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the rendered page once it arrives', (tester) async {
      PdfThumbnail.debugSeedCache('/rendered.pdf', _onePixelPng);

      await tester.pumpWidget(_host(
        const PdfThumbnail(
          path: '/rendered.pdf',
          width: 72,
          height: 72,
          placeholder: Text('glyph'),
        ),
      ));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('glyph'), findsNothing);
      expect(find.byType(SkeletonBlock), findsNothing);
    });

    testWidgets('actually reaches the renderer instead of dying on setup',
        (tester) async {
      // Regression guard. The render used to read MediaQuery from inside
      // initState, which throws in debug ("was called before initState()
      // completed"). The broad catch swallowed it and cached a null, so
      // every PDF fell back to the placeholder and looked identical to a
      // PDF that simply could not be drawn — the renderer was never called.
      //
      // Asserting only "shows the placeholder" cannot tell those apart, so
      // assert on WHY it failed: reaching pdfx and finding no platform
      // implementation is correct here; failing during widget setup is not.
      await tester.pumpWidget(_host(
        const PdfThumbnail(
          path: '/definitely/not/a/real.pdf',
          width: 72,
          height: 72,
          placeholder: Text('glyph'),
        ),
      ));
      await tester.pump();

      // Counted synchronously on entry to the renderer, so this does not
      // depend on the platform channel resolving inside the test zone.
      expect(
        PdfThumbnail.renderAttempts,
        1,
        reason: 'widget setup failed before the renderer was ever called',
      );
    }, skip: _noPdfxOnHost);
  });

  group('AttachmentChip PDF preview', () {
    testWidgets('a staged PDF asks for a first-page thumbnail',
        (tester) async {
      await tester.pumpWidget(_host(
        const AttachmentChip(
          compact: true,
          attachment: ChatAttachment(
            name: 'invoice.pdf',
            kind: 'PDF',
            size: '240 KB',
            localPath: '/tmp/invoice.pdf',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(PdfThumbnail), findsOneWidget);
    }, skip: _noPdfxOnHost);

    testWidgets('a server-side PDF does not, having nothing local to render',
        (tester) async {
      // Rendering would require downloading the file first; drawing a
      // thumbnail is not a good enough reason to spend the user's data.
      await tester.pumpWidget(_host(
        const AttachmentChip(
          compact: true,
          attachment: ChatAttachment(
            name: 'invoice.pdf',
            kind: 'PDF',
            size: '240 KB',
            downloadUrl: 'https://example.invalid/invoice.pdf',
            serverId: 'abc',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(PdfThumbnail), findsNothing);
    });

    testWidgets('a non-PDF document keeps the generic glyph', (tester) async {
      await tester.pumpWidget(_host(
        const AttachmentChip(
          compact: true,
          attachment: ChatAttachment(
            name: 'book.xlsx',
            kind: 'XLSX',
            size: '12 KB',
            localPath: '/tmp/book.xlsx',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(PdfThumbnail), findsNothing);
    });
  });
}
