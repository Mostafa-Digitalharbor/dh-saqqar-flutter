import 'dart:io';

import '../../../core/format/byte_size.dart';
import '../../../core/format/file_kind.dart';
import '../../../core/i18n/app_strings.dart';
import '../data/chat_view_models.dart';

/// One file on its way into the composer, from whichever source produced it.
///
/// The two sources hand back different types — `file_picker` gives a
/// `PlatformFile`, the share sheet gives a bare `File` — so they are narrowed
/// to this before the rules below see them. Neither type is imported here,
/// which is what keeps this file testable without a plugin.
typedef AttachmentCandidate = ({
  String name,
  String? path,
  int size,
  String? extension,
});

/// A file the caps turned away, and the cap it exceeded.
///
/// Carries the number so the message can name it — "‘x.zip’ is over 500 MB"
/// tells the user which limit they hit and therefore what to do; a bare
/// "file too large" leaves them guessing whether 30 MB or 300 MB is the line.
typedef RejectedAttachment = ({String name, int capMb});

/// What a batch of candidates resolved to.
class StagedAttachments {
  const StagedAttachments({
    required this.chips,
    required this.files,
    required this.rejected,
  });

  /// Composer chips, in the order the caller supplied them.
  final List<ChatAttachment> chips;

  /// The same files, for the upload. Index-aligned with [chips] — the
  /// screen's failure path removes from both by the same index.
  final List<File> files;

  /// Candidates the caps turned away. Empty on the happy path.
  final List<RejectedAttachment> rejected;

  bool get isEmpty => files.isEmpty;
}

/// The size rules for anything entering the composer, and the chip-building
/// that goes with them.
///
/// Extracted from `_ChatScreenState`, where the same loop was written twice —
/// once in `_stagePickedFiles` for the paperclip and once in
/// `_consumeShareIntake` for files shared in from another app. They built
/// byte-identical [ChatAttachment]s and diverged on the thing that matters:
///
/// **the share path had no cap check at all.**
///
/// So a 200 MB video shared from Photos was staged, uploaded, and rejected by
/// the server with a 413 — surfaced as the generic upload failure — while the
/// exact same file chosen through the paperclip was refused up front with a
/// message naming the limit. Same file, same destination, two different
/// answers, and the worse one arrived after the upload had already run.
///
/// One implementation means the caps cannot apply to only one door.
class AttachmentStaging {
  AttachmentStaging._();

  /// Cap for archives. Addon zips are legitimately large, and the server
  /// accepts them up to here.
  static const archiveCapMb = 500;

  /// Cap for everything else. Matches the server, which 413s above it.
  static const defaultCapMb = 25;

  /// The cap that applies to [extension], in megabytes.
  static int capMbFor(String? extension) =>
      FileKinds.isArchive(extension) ? archiveCapMb : defaultCapMb;

  /// Validates [candidates] against the caps and builds the composer chips.
  ///
  /// [tr] is taken as a value rather than read from a context so this stays a
  /// pure function — it is only needed for the human-readable size on the
  /// chip and the "image" kind word.
  ///
  /// A candidate with no usable path is skipped silently rather than
  /// rejected: it is not too large, there is simply nothing to upload, and
  /// telling the user their file is "too large" would be wrong.
  static StagedAttachments validate(
    Iterable<AttachmentCandidate> candidates,
    AppStrings tr,
  ) {
    final chips = <ChatAttachment>[];
    final files = <File>[];
    final rejected = <RejectedAttachment>[];

    for (final candidate in candidates) {
      final path = candidate.path;
      if (path == null || path.isEmpty) continue;

      final capMb = capMbFor(candidate.extension);
      if (candidate.size > capMb * kBytesPerMb) {
        rejected.add((name: candidate.name, capMb: capMb));
        continue;
      }

      chips.add(
        ChatAttachment(
          name: candidate.name,
          kind: FileKinds.isImage(candidate.extension)
              ? tr.fileKindImage
              : FileKinds.badge(candidate.extension),
          size: humanBytes(candidate.size, tr),
          imageUrl: FileKinds.isImage(candidate.extension) ? path : null,
          localPath: path,
        ),
      );
      files.add(File(path));
    }

    return StagedAttachments(chips: chips, files: files, rejected: rejected);
  }

  /// Narrows a shared-in [File] to an [AttachmentCandidate].
  ///
  /// `lengthSync` rather than the async `length()` on purpose: the share
  /// path's `setState` has to land in the SAME microtask as the
  /// `deliverTo` notification, before any rebuild can intervene. The async
  /// version used to lose the setState when the bootstrap's `context.go`
  /// recreated the chat page mid-await, and the file only appeared after
  /// leaving and re-entering the chat (2026-05-23 tester report).
  ///
  /// A length that cannot be read falls back to 0 rather than throwing: some
  /// content-URIs do not expose one until they are streamed, and blocking a
  /// whole shared batch on one unreadable entry is worse than a chip whose
  /// subtitle reads "0 B". Note that 0 also passes every cap, which is the
  /// right call — an unknown size is not evidence of an oversized file, and
  /// the server still has the final say.
  static AttachmentCandidate candidateFromFile(File file) {
    final name = file.path.split(RegExp(r'[\\/]')).last;
    int size;
    try {
      size = file.lengthSync();
    } catch (_) {
      size = 0;
    }
    return (
      name: name,
      path: file.path,
      size: size,
      extension: name.contains('.') ? name.split('.').last : '',
    );
  }
}
