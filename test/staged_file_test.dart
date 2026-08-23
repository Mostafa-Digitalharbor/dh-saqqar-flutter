// The composer's staged batch used to be TWO lists — chips and files — with
// a doc comment promising they "stay in sync by index" and nothing enforcing
// it. The promise leaked into every call site: removals ran `indexOf` on one
// list then `if (idx < other.length)` before touching the other, a rollback
// restored from two separate snapshots, and the preview path opened by
// conceding a chip might have no file at all.
//
// `StagedFile` pairs them, so the alignment is structural rather than
// remembered. These tests hold the pairing to the operations the screen
// actually performs on the batch.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/view_model/staged_file.dart';

ChatAttachment _chip(String name) => ChatAttachment(
      name: name,
      kind: 'PDF',
      size: '1 KB',
    );

StagedFile _staged(String name) => StagedFile(
      chip: _chip(name),
      file: File('/tmp/$name'),
    );

void main() {
  group('a staged row carries both halves', () {
    test('the chip and the file travel together', () {
      final row = _staged('invoice.pdf');

      expect(row.chip.name, 'invoice.pdf');
      expect(row.file.path, contains('invoice.pdf'));
    });

    test('the upload id starts absent and is added without losing the rest',
        () {
      final row = _staged('invoice.pdf');
      final uploaded = row.withUploadId('att_9');

      expect(row.uploadId, isNull);
      expect(uploaded.uploadId, 'att_9');
      expect(uploaded.chip, row.chip);
      expect(uploaded.file.path, row.file.path);
    });
  });

  group('removing one row', () {
    test('drops exactly one chip and one file, together', () {
      // The operation that used to need two removals and a length guard.
      final batch = [_staged('a.pdf'), _staged('b.pdf'), _staged('c.pdf')];

      batch.removeAt(1);

      expect([for (final s in batch) s.chip.name], ['a.pdf', 'c.pdf']);
      expect([for (final s in batch) s.file.path],
          ['/tmp/a.pdf', '/tmp/c.pdf']);
    });
  });

  group('rolling back a failed upload', () {
    test('drops only the rows from this round', () {
      // A failed upload must not take a previously-staged batch with it —
      // the user picked those on purpose and would have to re-attach.
      final earlier = [_staged('kept.pdf')];
      final thisRound = [_staged('failed-1.pdf'), _staged('failed-2.pdf')];
      final batch = [...earlier, ...thisRound];

      final dropped = {for (final s in thisRound) s.file.path};
      batch.removeWhere((s) => dropped.contains(s.file.path));

      expect([for (final s in batch) s.chip.name], ['kept.pdf']);
    });

    test('two files with the same name are still distinct rows', () {
      // Removal keys on the PATH, not the display name: a user can attach
      // `report.pdf` from Downloads and another from Documents, and dropping
      // one must not drop the other.
      final a = StagedFile(chip: _chip('report.pdf'), file: File('/dl/r.pdf'));
      final b = StagedFile(chip: _chip('report.pdf'), file: File('/doc/r.pdf'));
      final batch = [a, b];

      batch.removeWhere((s) => s.file.path == '/dl/r.pdf');

      expect(batch, hasLength(1));
      expect(batch.single.file.path, '/doc/r.pdf');
    });
  });

  group('restoring a snapshot', () {
    test('a copied batch survives the original being cleared', () {
      // The send path snapshots the batch, clears the live list, and puts the
      // snapshot back if the create/upload/send sequence fails.
      final live = [_staged('a.pdf'), _staged('b.pdf')];
      final snapshot = List<StagedFile>.from(live);

      live.clear();
      expect(snapshot, hasLength(2));

      live.addAll(snapshot);
      expect([for (final s in live) s.chip.name], ['a.pdf', 'b.pdf']);
    });
  });

  group('value semantics', () {
    test('same path compares equal — the path IS the identity', () {
      // The chip is derived from the file, so two rows over one path are the
      // same row. `ChatAttachment` has no value equality of its own, which is
      // exactly why identity keys on the path instead.
      expect(_staged('a.pdf'), _staged('a.pdf'));
      expect(_staged('a.pdf').hashCode, _staged('a.pdf').hashCode);
    });

    test('a different path is a different row', () {
      final a = StagedFile(chip: _chip('r.pdf'), file: File('/one/r.pdf'));
      final b = StagedFile(chip: _chip('r.pdf'), file: File('/two/r.pdf'));

      expect(a, isNot(b));
    });

    test('an uploaded row is not equal to the same row pre-upload', () {
      final row = _staged('a.pdf');

      expect(row.withUploadId('x'), isNot(row));
    });
  });
}
