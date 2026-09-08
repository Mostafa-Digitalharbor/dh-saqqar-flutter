import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/attachment_limits.dart';
import '../../../core/logging/app_logger.dart';

/// Shrinks a photo before it is uploaded.
///
/// A phone camera produces 3–8 MB per shot and the app was sending that
/// whole buffer up so the server could OCR it — on mobile data, on a
/// connection the user is paying for, to answer a question that a 1600 px
/// copy answers identically. The web has downscaled client-side for a while
/// (`maybeCompressImage`); this is the same rule, with the same thresholds.
///
/// The decode/encode runs on a background isolate. A 12 MP decode is
/// hundreds of milliseconds of solid CPU, and on the UI isolate that is a
/// visibly frozen composer at exactly the moment the user just tapped
/// something.
///
/// Every failure path returns the original file. A photo that uploads at
/// full size is a slow upload; a photo that fails to upload because the
/// resizer threw is a broken feature, and the second is much worse.
class ImageDownscaler {
  const ImageDownscaler._();

  /// Returns a path to send: either [path] unchanged, or a smaller copy
  /// written under [tempDir].
  ///
  /// [tempDir] is resolved by the caller because `path_provider` is a
  /// platform channel and cannot be reached from a background isolate.
  static Future<String> shrink({
    required String path,
    required String tempDir,
  }) async {
    if (!_isDownscalableImage(path)) return path;

    // The file on disk is the only size that counts. An earlier draft took
    // the picker's reported size as a parameter and trusted it; a stale or
    // wrong number then sent a 200 px thumbnail through a re-encode it did
    // not need. `length()` is one syscall, and it cannot disagree with what
    // is about to be uploaded.
    final bytes = await _sizeOf(File(path));
    if (bytes <= AttachmentLimits.downscaleFloorBytes) return path;

    try {
      final result = await compute(
        _shrinkOnIsolate,
        _ShrinkRequest(path: path, tempDir: tempDir),
      );
      return result ?? path;
    } catch (e, st) {
      AppLogger.warn('ImageDownscaler', 'shrink failed for $path',
          error: e, stackTrace: st);
      return path;
    }
  }

  static Future<int> _sizeOf(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  /// Animated GIFs are excluded on purpose: re-encoding one keeps a single
  /// frame, which silently turns a recording of a bug into a still of it.
  static bool _isDownscalableImage(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = path.substring(dot + 1).toLowerCase();
    return AttachmentLimits.downscalableImageExtensions.contains(ext);
  }
}

@immutable
class _ShrinkRequest {
  const _ShrinkRequest({required this.path, required this.tempDir});

  final String path;
  final String tempDir;
}

/// Runs on a background isolate. Returns the new path, or null to keep the
/// original — including when the "smaller" copy came out bigger, which
/// happens with an already-optimised PNG.
String? _shrinkOnIsolate(_ShrinkRequest request) {
  final raw = File(request.path).readAsBytesSync();
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;

  // Measured from the bytes actually decoded, so the "did this help?" test
  // below compares like with like.
  final sourceBytes = raw.length;
  const maxWidth = AttachmentLimits.downscaleMaxWidth;
  // Already small enough in both dimensions that re-encoding would only
  // cost quality.
  if (decoded.width <= maxWidth &&
      sourceBytes <= AttachmentLimits.downscaleCeilingBytes) {
    return null;
  }

  final keepAlpha = decoded.hasAlpha;
  final resized = decoded.width > maxWidth
      ? img.copyResize(decoded, width: maxWidth)
      : decoded;

  // PNG for anything with transparency — an Odoo error dialog screenshotted
  // over a translucent backdrop turns into a black rectangle if it is
  // flattened into JPEG.
  final encoded = keepAlpha
      ? img.encodePng(resized)
      : img.encodeJpg(resized, quality: AttachmentLimits.downscaleJpegQuality);
  // An already-optimised PNG can come back bigger. Keeping the original
  // is the honest outcome; shipping the larger copy would be the resizer
  // making things worse and calling it a saving.
  if (encoded.length >= sourceBytes) return null;

  final stem = _stemOf(request.path);
  final out = File(
    '${request.tempDir}/${DateTime.now().microsecondsSinceEpoch}_'
    '$stem.${keepAlpha ? 'png' : 'jpg'}',
  );
  out.writeAsBytesSync(encoded);
  return out.path;
}

String _stemOf(String path) {
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final name = slash < 0 ? path : path.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  final stem = dot < 0 ? name : name.substring(0, dot);
  // Keep the filename recognisable in the transcript but safe as a path.
  return stem.replaceAll(RegExp(r'[^\w.-]'), '_');
}
