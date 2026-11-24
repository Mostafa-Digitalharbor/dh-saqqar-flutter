import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/chat_view_models.dart';

/// One file staged in the composer: the chip the user sees **and** the file
/// on disk that will be uploaded, as a single thing.
///
/// **Why this type exists.** The screen used to carry two lists —
/// `_attachments` (chips) and `_pendingFiles` (files) — and a doc comment
/// saying they "stay in sync by index". Nothing enforced that. Every site
/// that touched them had to remember to touch both, in the same order, and
/// the code showed it: removals ran `indexOf` on one list and then
/// `if (idx < other.length)` before touching the other, a rollback rebuilt
/// both from two separate snapshots, and the preview path opened with a
/// comment conceding a chip might have no file — "shouldn't happen given our
/// pick flow, but defensive".
///
/// Defensive guards against your own invariant are the invariant telling you
/// it is not one. Pairing the two values makes the alignment structural: there
/// is no index to keep, because there is one list.
///
/// A third alignment remains and is NOT solved here: the cubit's
/// `stagedAttachments`, which the remove path indexes positionally to find
/// the server-side id to drop. That one crosses a layer boundary and needs
/// the id carried on the row rather than inferred from a position — see
/// [StagedFile.uploadId], which is where it will land.
@immutable
class StagedFile {
  const StagedFile({
    required this.chip,
    required this.file,
    this.uploadId,
    this.phase = UploadPhase.done,
  });

  /// Display metadata the composer chip renders — name, size, kind.
  final ChatAttachment chip;

  /// The file on disk. The upload needs it, and so does the pre-send
  /// preview; the chip alone cannot produce it.
  final File file;

  /// Server-side id once the upload settles, or `null` while it is in
  /// flight or after it failed.
  ///
  /// The remove path finds the server row by this id rather than by position,
  /// so a file that failed (and therefore has no id) in the middle of a batch
  /// cannot shift every later removal onto the wrong row.
  final String? uploadId;

  /// Where this file is in its upload. Drives the state shown on its chip and
  /// whether Send is allowed.
  final UploadPhase phase;

  StagedFile withUploadId(String id) => StagedFile(
    chip: chip,
    file: file,
    uploadId: id,
    phase: UploadPhase.done,
  );

  StagedFile withPhase(UploadPhase next) =>
      StagedFile(chip: chip, file: file, uploadId: uploadId, phase: next);

  /// Identity is the **path**, not the chip.
  ///
  /// The chip is derived from the file — name, size and kind all come off it
  /// — so two rows over one path are the same row by construction, and
  /// `ChatAttachment` has no value equality of its own to lean on. Keying on
  /// the path is also what the rollback path needs: two files can share a
  /// display name (`report.pdf` from Downloads and from Documents) and
  /// dropping one must not drop the other.
  @override
  bool operator ==(Object other) =>
      other is StagedFile &&
      other.file.path == file.path &&
      other.uploadId == uploadId;

  @override
  int get hashCode => Object.hash(file.path, uploadId);

  @override
  String toString() => 'StagedFile(${chip.name}, ${file.path})';
}
