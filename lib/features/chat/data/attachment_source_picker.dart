import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/format/file_kind.dart';
import '../../../core/logging/app_logger.dart';
import '../view_model/attachment_staging.dart';
import '../widgets/attachment_source_sheet.dart';
import 'image_downscaler.dart';

/// What one trip to a native picker produced.
///
/// Sealed rather than a nullable list, because "the user backed out" and
/// "the OS refused" are different events that need different UI and were
/// previously distinguished by a `null` plus a `catch` in the middle of a
/// 4,000-line `State` class.
sealed class AttachmentPickResult {
  const AttachmentPickResult();
}

/// Files the user chose, already downscaled and ready for the size caps.
class AttachmentsPicked extends AttachmentPickResult {
  const AttachmentsPicked(this.candidates);
  final List<AttachmentCandidate> candidates;
}

/// The user dismissed the picker, or chose nothing. Not an error — the UI
/// must stay silent, which is why it is not folded in with [AttachmentPickFailed].
class AttachmentPickCancelled extends AttachmentPickResult {
  const AttachmentPickCancelled();
}

/// The OS refused camera access — the permission prompt was declined, or it
/// is off in Settings. Needs its own message: "try again" is advice that
/// cannot work until the user visits Settings.
class AttachmentPickDenied extends AttachmentPickResult {
  const AttachmentPickDenied();
}

/// The plugin or the device failed for some other reason.
class AttachmentPickFailed extends AttachmentPickResult {
  const AttachmentPickFailed();
}

/// Everything between "the user tapped a source" and "here are the files".
///
/// ## Why this is not in the chat screen
///
/// These four methods were part of `_ChatScreenState`, which is how they
/// ended up untestable: reaching them meant pumping the whole chat screen,
/// with its cubit, its providers, its poll timer and three platform channels
/// — so nothing tested the camera's permission branch, the downscaler's
/// extension rewrite, or the "picker returned a file with no path" case, all
/// of which are pure functions of their inputs.
///
/// Nothing here touches a `BuildContext`, a `setState` or a string the user
/// reads. It answers one question — *which files* — and the screen decides
/// what to say about the answer. That split is also what let the paperclip
/// path and the share-intake path finally share their staging tail, which
/// they had been duplicating.
class AttachmentSourcePicker {
  const AttachmentSourcePicker();

  /// Opens the native picker for [source] and returns what came back.
  ///
  /// Every branch funnels through [_downscale], so a photo from the gallery
  /// and a photo from the camera are treated identically — which is the
  /// property that keeps the size caps honest whichever way a file arrived.
  Future<AttachmentPickResult> pick(AttachmentPickerSource source) async {
    return switch (source) {
      AttachmentPickerSource.photos => _fromPhotos(),
      AttachmentPickerSource.camera => _fromCamera(),
      AttachmentPickerSource.files => _fromFiles(),
    };
  }

  /// Native photo library (PHPicker on iOS, the photo picker on Android) —
  /// no `allowedExtensions`, because `FileType.image` already restricts the
  /// dialog and pairing the two throws in `file_picker`.
  Future<AttachmentPickResult> _fromPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return const AttachmentPickCancelled();
    }
    return AttachmentsPicked(await _downscale(result.files));
  }

  /// Single shot straight from the camera. `file_picker` is PHPicker/SAF
  /// backed and can't reach the camera, hence `image_picker` here.
  /// `imageQuality` re-encodes to keep a 12 MP capture under the 25 MB cap.
  Future<AttachmentPickResult> _fromCamera() async {
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: _cameraQuality,
      );
    } on PlatformException catch (e, st) {
      AppLogger.warn(_tag, 'camera capture failed', error: e, stackTrace: st);
      // The user declined the permission prompt (or has it off in Settings);
      // anything else is a real device/plugin failure.
      return e.code == _deniedCode
          ? const AttachmentPickDenied()
          : const AttachmentPickFailed();
    }
    if (shot == null) return const AttachmentPickCancelled();
    final length = await shot.length();
    return AttachmentsPicked(
      await _downscale([
        PlatformFile(name: shot.name, path: shot.path, size: length),
      ]),
    );
  }

  /// Documents: the original allow-list, minus nothing. Images stay in the
  /// list so a user who keeps screenshots in Files can still reach them.
  ///
  /// The list is [FileKinds.pickerExtensions] rather than a literal here —
  /// it was the fifth independent copy of the extension table, and the one
  /// that could reject a file the other four were happy to classify.
  Future<AttachmentPickResult> _fromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileKinds.pickerExtensions,
      withData: false,
      // Multi-select shipped in 1.0.2 after testers asked for "أرفق أكتر
      // من ملف لنفس الشات". The composer renders one chip per file and
      // Send batches them into a single multipart upload.
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return const AttachmentPickCancelled();
    }
    return AttachmentsPicked(await _downscale(result.files));
  }

  /// Replaces any oversized photo with a downscaled copy, keeping the
  /// original filename so the transcript still reads the way the user
  /// expects.
  ///
  /// Non-images, small images and anything the resizer declines come back
  /// untouched — [ImageDownscaler.shrink] returns the input path in every one
  /// of those cases, so this loop has no branches of its own beyond the
  /// "picker gave us no path" case (which happens on some cloud providers).
  Future<List<AttachmentCandidate>> _downscale(
    List<PlatformFile> picked,
  ) async {
    final tempDir = (await getTemporaryDirectory()).path;
    final out = <AttachmentCandidate>[];
    for (final p in picked) {
      final path = p.path;
      if (path == null) {
        out.add((
          name: p.name,
          path: null,
          size: p.size,
          extension: p.extension,
        ));
        continue;
      }
      final shrunk = await ImageDownscaler.shrink(path: path, tempDir: tempDir);
      if (shrunk == path) {
        out.add((
          name: p.name,
          path: path,
          size: p.size,
          extension: p.extension,
        ));
        continue;
      }
      final size = await File(shrunk).length();
      AppLogger.info(_tag, 'downscaled ${p.name}: ${p.size} bytes to $size');
      out.add((
        name: p.name,
        path: shrunk,
        size: size,
        // The re-encode may have changed the container (a 12 MP PNG comes
        // back as JPEG), and the extension drives the kind icon and the cap.
        extension: shrunk.split('.').last,
      ));
    }
    return out;
  }

  static const _tag = 'ChatAttachments';

  /// `image_picker`'s re-encode quality. High enough that a document
  /// photographed to be read stays readable, low enough that a 12 MP capture
  /// lands well under the cap.
  static const _cameraQuality = 85;

  /// `image_picker`'s code for "the user said no to the camera".
  static const _deniedCode = 'camera_access_denied';
}
