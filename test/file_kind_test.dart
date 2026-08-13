// One extension table, and the disagreement it replaced.
//
// Five surfaces classified file extensions independently: the composer chip,
// the artifact tile, the in-app viewer, the message-bubble thumbnail and the
// Files picker's allow-list. They had drifted, and the drift was not cosmetic
// — the four that mattered gave three different answers for a single iPhone
// photo:
//
//   * the composer labelled `photo.heic` "HEIC" instead of "Image",
//   * the sent message drew it as a picture (its own list knew `heic`),
//   * the viewer refused it as "we can't display this file".
//
// The photo picker is `FileType.image`, so it hands back `.heic` on iOS
// whatever any allow-list says. These tests pin the union so a format can
// never again be known to one surface and not another.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/core/format/file_kind.dart';
import 'package:saqqar_app/features/chat/view/attachment_viewer_screen.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';

void main() {
  group('extensionOf', () {
    test('reads a filename, a bare extension or a dotted one', () {
      // Call sites have one or the other: `PlatformFile.extension` is bare,
      // an artifact's `name` is a filename. Neither should have to normalize.
      expect(FileKinds.extensionOf('Q3 report.XLSX'), 'xlsx');
      expect(FileKinds.extensionOf('xlsx'), 'xlsx');
      expect(FileKinds.extensionOf('.xlsx'), 'xlsx');
      expect(FileKinds.extensionOf(null), '');
      expect(FileKinds.extensionOf('  '), '');
    });

    test('a dotted filename keeps only the last segment', () {
      expect(FileKinds.extensionOf('addon.v2.tar.gz'), 'gz');
    });
  });

  group('the iPhone photo every surface disagreed about', () {
    const heic = 'IMG_4821.HEIC';

    test('is an image to the classifier', () {
      expect(FileKinds.isImage(heic), isTrue);
      expect(FileKinds.of(heic), FileKind.image);
    });

    test('is an image to the message bubble', () {
      const attachment = DemoAttachment(
        name: heic,
        kind: 'صورة',
        size: '2.4 MB',
        source: AttachmentSource.userUpload,
      );
      expect(attachment.isImage, isTrue);
    });

    test('opens as an image in the viewer', () {
      // Was `unsupported`: the viewer's private list knew `bmp` and not
      // `heic`, so the one format an iPhone camera actually produces was the
      // one it turned away.
      expect(
        AttachmentViewerScreen.kindFor(heic),
        AttachmentViewerKind.image,
      );
    });

    test('and heif, its sibling container, behaves identically', () {
      expect(FileKinds.isImage('live.heif'), isTrue);
      expect(
        AttachmentViewerScreen.kindFor('live.heif'),
        AttachmentViewerKind.image,
      );
    });
  });

  group('kinds', () {
    test('classify the formats the app actually handles', () {
      expect(FileKinds.of('sheet.xlsx'), FileKind.spreadsheet);
      expect(FileKinds.of('invoice.pdf'), FileKind.pdf);
      expect(FileKinds.of('export.csv'), FileKind.csv);
      expect(FileKinds.of('contract.docx'), FileKind.document);
      expect(FileKinds.of('payload.json'), FileKind.json);
      expect(FileKinds.of('run.log'), FileKind.text);
      expect(FileKinds.of('addon.zip'), FileKind.archive);
      expect(FileKinds.of('deck.pptx'), FileKind.other);
    });

    test('only archives get the 500 MB cap', () {
      // The size cap branches on this. Getting it wrong either rejects a
      // legitimate addon bundle or lets a 400 MB video through to a 413.
      for (final name in const ['a.zip', 'a.tar', 'a.gz', 'a.tgz']) {
        expect(FileKinds.isArchive(name), isTrue, reason: name);
      }
      for (final name in const ['a.xlsx', 'a.pdf', 'a.png', 'a.heic']) {
        expect(FileKinds.isArchive(name), isFalse, reason: name);
      }
    });

    test('text-renderable covers exactly what the viewer prints verbatim', () {
      expect(FileKind.text.isTextRenderable, isTrue);
      expect(FileKind.csv.isTextRenderable, isTrue);
      expect(FileKind.json.isTextRenderable, isTrue);
      // Office formats are zipped XML — printing them verbatim shows binary.
      expect(FileKind.spreadsheet.isTextRenderable, isFalse);
      expect(FileKind.document.isTextRenderable, isFalse);
      expect(FileKind.archive.isTextRenderable, isFalse);
      expect(FileKind.image.isTextRenderable, isFalse);
    });
  });

  group('badge', () {
    test('names the format, never the category', () {
      expect(FileKinds.badge('a.pdf'), UiStrings.formatPdf);
      expect(FileKinds.badge('a.xls'), UiStrings.formatXlsx);
      expect(FileKinds.badge('a.tsv'), UiStrings.formatCsv);
      expect(FileKinds.badge('a.doc'), UiStrings.formatDocx);
      expect(FileKinds.badge('a.json'), UiStrings.formatJson);
      expect(FileKinds.badge('a.tgz'), UiStrings.formatZip);
    });

    test('an unknown extension shows itself rather than "FILE"', () {
      expect(FileKinds.badge('deck.pptx'), 'PPTX');
      // Capped, so a pathological extension cannot stretch the chip.
      expect(FileKinds.badge('x.abcdefghij').length, 5);
    });

    test('no extension at all is the only case that falls back', () {
      expect(FileKinds.badge(''), UiStrings.formatUnknown);
      expect(FileKinds.badge(null), UiStrings.formatUnknown);
    });
  });

  group('the picker allow-list', () {
    test('offers every image format the classifier knows', () {
      // The asymmetry that caused the bug ran the other way — the picker
      // listed FEWER image formats than the app could classify — but either
      // direction is a surface disagreeing with the rest.
      for (final ext in FileKinds.image) {
        expect(
          FileKinds.pickerExtensions,
          contains(ext),
          reason: '$ext is classified as an image but cannot be picked',
        );
      }
    });

    test('every offered extension classifies as something', () {
      // An extension the picker offers but nothing recognises reaches the
      // composer as a bare uppercase badge with a generic icon.
      for (final ext in FileKinds.pickerExtensions) {
        expect(
          FileKinds.of(ext),
          isNot(FileKind.other),
          reason: '$ext is offered by the picker but classifies as `other`',
        );
      }
    });

    test('carries no duplicates', () {
      // It is assembled by spreading six sets; an extension that landed in
      // two of them would be listed twice to `file_picker`.
      expect(
        FileKinds.pickerExtensions.length,
        FileKinds.pickerExtensions.toSet().length,
      );
    });
  });
}
