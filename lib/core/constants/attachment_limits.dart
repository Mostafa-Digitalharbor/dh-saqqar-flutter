/// Thresholds for what happens to a file between "picked" and "uploaded".
///
/// Separate from `AttachmentStaging`, which owns the *reject* caps (25 MB,
/// 500 MB for archives). These are the *downscale* thresholds — the point
/// where a photo is shrunk rather than refused — and they are the web's
/// numbers from `maybeCompressImage`, kept in one named place so the
/// downscaler and its tests cannot drift to two sets.
class AttachmentLimits {
  const AttachmentLimits._();

  /// Below this, a photo is already small and re-encoding only costs
  /// quality. 1 MB is the web's floor.
  static const int downscaleFloorBytes = 1000 * 1000;

  /// An image already narrower than [downscaleMaxWidth] is still re-encoded
  /// above this size — a 1200 px PNG can easily be 4 MB.
  static const int downscaleCeilingBytes = 2000 * 1000;

  /// Wide enough that Odoo screenshots stay readable and OCR still works;
  /// narrow enough that a 12 MP capture stops being a multi-megabyte upload.
  static const int downscaleMaxWidth = 1600;

  /// Visually lossless for screenshots and UI photography at this scale.
  static const int downscaleJpegQuality = 85;

  /// Extensions the downscaler will touch.
  ///
  /// `gif` is deliberately absent: re-encoding an animated GIF keeps one
  /// frame, which turns a recording of a bug into a still of it.
  static const Set<String> downscalableImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'tiff',
    'tif',
  };
}
