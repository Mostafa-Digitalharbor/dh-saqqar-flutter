// The size caps that decide what reaches the composer, and the chips built
// from whatever survives them.
//
// This logic used to be written twice inside `_ChatScreenState` — once for
// the paperclip (`_stagePickedFiles`) and once for files shared in from
// another app (`_consumeShareIntake`). The two built byte-identical
// `ChatAttachment`s and disagreed on the thing that mattered: the share path
// never checked a cap.
//
// So the same 200 MB video got two different answers depending on which door
// it came through — refused up front with a message naming the limit via the
// paperclip, or staged, uploaded, and rejected by the server with a 413 via
// the share sheet. The second answer is the worse one twice over: it arrives
// after the upload has already run, and it reaches the user as the generic
// upload failure rather than as "this file is over 500 MB".
//
// `both doors apply the same cap` below is the test that keeps them one rule.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/format/byte_size.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/chat/view_model/attachment_staging.dart';

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  AttachmentCandidate candidate({
    required String name,
    required int size,
    String? extension,
    String? path,
  }) =>
      (
        name: name,
        path: path ?? '/tmp/$name',
        size: size,
        extension: extension ?? (name.contains('.') ? name.split('.').last : ''),
      );

  int mb(num n) => (n * kBytesPerMb).round();

  group('caps', () {
    test('a document at the cap is accepted and one byte over is not', () {
      final staged = AttachmentStaging.validate([
        candidate(name: 'at-cap.pdf', size: mb(25)),
        candidate(name: 'over-cap.pdf', size: mb(25) + 1),
      ], en);

      expect(staged.chips.map((c) => c.name), ['at-cap.pdf']);
      expect(staged.rejected.map((r) => r.name), ['over-cap.pdf']);
      expect(staged.rejected.single.capMb, AttachmentStaging.defaultCapMb);
    });

    test('an archive gets the larger cap', () {
      // Addon zips are legitimately big; refusing them at 25 MB would block
      // the single most common thing an Odoo admin attaches.
      final staged = AttachmentStaging.validate([
        candidate(name: 'addon.zip', size: mb(200)),
        candidate(name: 'huge.zip', size: mb(501)),
      ], en);

      expect(staged.chips.map((c) => c.name), ['addon.zip']);
      expect(staged.rejected.single.name, 'huge.zip');
      expect(staged.rejected.single.capMb, AttachmentStaging.archiveCapMb);
    });

    test('the rejection names the cap it hit, not a generic limit', () {
      // "over 500 MB" tells the user what to do next; "too large" makes them
      // guess whether the line is 30 MB or 300.
      final staged = AttachmentStaging.validate([
        candidate(name: 'a.pdf', size: mb(30)),
        candidate(name: 'b.zip', size: mb(600)),
      ], en);

      expect(
        staged.rejected.map((r) => (r.name, r.capMb)),
        [('a.pdf', 25), ('b.zip', 500)],
      );
    });

    test('both doors apply the same cap', () {
      // THE regression test. The share path is the one that had no check at
      // all, so the same file is pushed through both narrowings and the
      // verdicts are compared.
      final tmp = Directory.systemTemp.createTempSync('saqqar-staging');
      addTearDown(() {
        try {
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        } on FileSystemException {
          // best-effort; the assertions below do not depend on cleanup
        }
      });

      // A real 26 MB file, so the share path's `lengthSync` reads a real
      // size rather than one a fake handed it.
      final oversized = File('${tmp.path}/report.pdf')
        ..writeAsBytesSync(List<int>.filled(mb(26), 0));

      final viaPaperclip = AttachmentStaging.validate(
        [candidate(name: 'report.pdf', size: mb(26))],
        en,
      );
      final viaShareSheet = AttachmentStaging.validate(
        [AttachmentStaging.candidateFromFile(oversized)],
        en,
      );

      expect(viaPaperclip.files, isEmpty);
      expect(
        viaShareSheet.files,
        isEmpty,
        reason: 'a file shared in from another app must hit the same cap as '
            'one chosen through the paperclip. Before AttachmentStaging this '
            'was staged and uploaded, and the user learned it was too big '
            'from a 413 rendered as a generic upload failure.',
      );
      expect(viaShareSheet.rejected.single.capMb, viaPaperclip.rejected.single.capMb);
    });
  });

  group('chips', () {
    test('an image carries a preview path and the translated kind word', () {
      final enChips = AttachmentStaging.validate(
        [candidate(name: 'shot.png', size: mb(1))],
        en,
      ).chips;
      final arChips = AttachmentStaging.validate(
        [candidate(name: 'shot.png', size: mb(1))],
        ar,
      ).chips;

      expect(enChips.single.imageUrl, '/tmp/shot.png',
          reason: 'the composer chip renders a thumbnail from this');
      expect(enChips.single.kind, en.fileKindImage);
      expect(arChips.single.kind, ar.fileKindImage,
          reason: '"Image" is a category word and translates; every other '
              'kind is a format identifier that reads the same in Arabic');
      expect(enChips.single.kind, isNot(arChips.single.kind));
    });

    test('a non-image gets a format badge and no preview', () {
      final chip = AttachmentStaging.validate(
        [candidate(name: 'books.xlsx', size: mb(2))],
        en,
      ).chips.single;

      expect(chip.imageUrl, isNull);
      expect(chip.kind, isNotEmpty);
      expect(chip.kind, isNot(en.fileKindImage));
    });

    test('the size subtitle is human-readable, not a byte count', () {
      final chip = AttachmentStaging.validate(
        [candidate(name: 'doc.pdf', size: mb(2.4))],
        en,
      ).chips.single;

      expect(chip.size, humanBytes(mb(2.4), en));
      expect(chip.size, contains('MB'));
    });

    test('chips and files stay index-aligned across a rejection', () {
      // The screen's upload-failure path removes from both lists by the same
      // index. If a rejected file shifted one and not the other, a failed
      // upload would drop the wrong chip.
      final staged = AttachmentStaging.validate([
        candidate(name: 'first.pdf', size: mb(1)),
        candidate(name: 'rejected.pdf', size: mb(99)),
        candidate(name: 'third.pdf', size: mb(1)),
      ], en);

      expect(staged.chips.map((c) => c.name), ['first.pdf', 'third.pdf']);
      expect(
        staged.files.map((f) => f.path.split('/').last),
        ['first.pdf', 'third.pdf'],
      );
      expect(staged.chips.length, staged.files.length);
    });
  });

  group('candidates with nothing to upload', () {
    test('a null or empty path is skipped, not rejected', () {
      // It is not too large — there is simply nothing there. Reporting it as
      // "too large" would be a lie the user cannot act on.
      final staged = AttachmentStaging.validate([
        (name: 'ghost.pdf', path: null, size: mb(1), extension: 'pdf'),
        (name: 'blank.pdf', path: '', size: mb(1), extension: 'pdf'),
        candidate(name: 'real.pdf', size: mb(1)),
      ], en);

      expect(staged.chips.map((c) => c.name), ['real.pdf']);
      expect(staged.rejected, isEmpty);
    });

    test('an unreadable length falls back to 0 and passes the caps', () {
      // Some content-URIs do not expose a length until they are streamed. An
      // unknown size is not evidence of an oversized file, and blocking the
      // batch on one unreadable entry is worse than a "0 B" subtitle — the
      // server still has the final say.
      final missing = File('${Directory.systemTemp.path}/does-not-exist.pdf');
      final c = AttachmentStaging.candidateFromFile(missing);

      expect(c.size, 0);
      expect(c.extension, 'pdf');
      expect(AttachmentStaging.validate([c], en).files, hasLength(1));
    });

    test('an empty batch produces an empty result rather than throwing', () {
      final staged = AttachmentStaging.validate(const [], en);
      expect(staged.isEmpty, isTrue);
      expect(staged.rejected, isEmpty);
    });
  });

  group('candidateFromFile', () {
    test('splits the name off either separator', () {
      // Android hands back POSIX paths, Windows tooling hands back
      // backslashes, and a name that kept its directory prefix would render
      // the whole path in the chip.
      expect(
        AttachmentStaging.candidateFromFile(File('/data/user/0/x/report.pdf'))
            .name,
        'report.pdf',
      );
      expect(
        AttachmentStaging.candidateFromFile(File(r'C:\Users\x\report.pdf'))
            .name,
        'report.pdf',
      );
    });

    test('a name with no dot yields an empty extension, not a crash', () {
      final c = AttachmentStaging.candidateFromFile(File('/tmp/README'));
      expect(c.name, 'README');
      expect(c.extension, '');
      expect(AttachmentStaging.capMbFor(c.extension),
          AttachmentStaging.defaultCapMb);
    });
  });
}
