// One-shot launcher icon generator — composes the SAQQÂR wordmark into
// a 1024×1024 launcher icon with a white rounded-square background.
//
// Run: `dart run tool/generate_launcher_icon.dart`
//
// Writes two PNGs into `assets/img/`:
//   - saqqar-launcher.png            (1024×1024, white rounded bg +
//                                     centered wordmark with breathing
//                                     room — used for iOS / legacy
//                                     Android / web)
//   - saqqar-launcher-foreground.png (1024×1024, transparent bg with
//                                     the wordmark sized for Android
//                                     adaptive foreground — wordmark
//                                     fits inside the central 66 %
//                                     safe zone so launcher masks
//                                     never clip it)
//
// Source: `assets/img/saqqar-logo-light.png` — the navy + cyan wordmark.
// The image is shrunk to ~58 % of the canvas width with white margin so
// the wordmark sits comfortably inside the launcher tile instead of
// crowding the edges (user request: "make it smaller, inside a square
// with soft rounded corners and white background").

import 'dart:io';

import 'package:image/image.dart' as img;

const _size = 1024;
const _cornerRadius = 180; // ≈ 18% of canvas → soft rounded square
const _wordmarkWidthRatio = 1.00; // wordmark goes edge-to-edge for max legibility
const _adaptiveSafeRatio = 0.86; // Android adaptive — past the 66% safe zone,
                                 // but modern launcher masks (Pixel / One UI /
                                 // MIUI) don't crop that aggressively and the
                                 // wordmark needs the extra width to read.

void main() {
  final outDir = Directory('assets/img');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final sourcePath = '${outDir.path}/saqqar-logo-light.png';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('✗ source missing: $sourcePath');
    stderr.writeln(
      '  Drop the SAQQÂR navy wordmark there first, then re-run this.',
    );
    exit(1);
  }
  final source = img.decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('✗ could not decode $sourcePath as PNG');
    exit(1);
  }

  // White-bg rounded square for iOS / legacy Android / web.
  final fullBleed = _compose(
    source: source,
    transparentBackground: false,
    wordmarkWidthRatio: _wordmarkWidthRatio,
  );
  File('${outDir.path}/saqqar-launcher.png')
      .writeAsBytesSync(img.encodePng(fullBleed));

  // Transparent foreground for Android adaptive. Wordmark sized to the
  // safe zone (66% of canvas) so the launcher mask never clips it.
  final foreground = _compose(
    source: source,
    transparentBackground: true,
    wordmarkWidthRatio: _adaptiveSafeRatio * _wordmarkWidthRatio,
  );
  File('${outDir.path}/saqqar-launcher-foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln('✓ wrote assets/img/saqqar-launcher.png ($_size×$_size)');
  stdout.writeln(
    '✓ wrote assets/img/saqqar-launcher-foreground.png ($_size×$_size)',
  );
  stdout.writeln('');
  stdout.writeln('Next:');
  stdout.writeln('  dart run flutter_launcher_icons');
  stdout.writeln('  dart run flutter_native_splash:create');
}

img.Image _compose({
  required img.Image source,
  required bool transparentBackground,
  required double wordmarkWidthRatio,
}) {
  // Start with a transparent canvas; paint the white rounded square on
  // top when the icon needs an opaque background.
  final canvas = img.Image(
    width: _size,
    height: _size,
    numChannels: 4,
    backgroundColor: img.ColorRgba8(0, 0, 0, 0),
  );

  if (!transparentBackground) {
    _paintWhiteRoundedSquare(canvas);
  }

  // Resize the wordmark down to the target width, preserving aspect
  // ratio. Linear-interp keeps the small cyan accent dots crisp.
  final targetW = (_size * wordmarkWidthRatio).round();
  final scale = targetW / source.width;
  final targetH = (source.height * scale).round();
  final resized = img.copyResize(
    source,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.linear,
  );

  // Center.
  final dx = ((_size - resized.width) / 2).round();
  final dy = ((_size - resized.height) / 2).round();
  img.compositeImage(
    canvas,
    resized,
    dstX: dx,
    dstY: dy,
    blend: img.BlendMode.alpha,
  );

  return canvas;
}

/// Paints a soft-rounded white square filling the whole canvas. Pixels
/// outside the rounded corners stay transparent so iOS / legacy Android
/// see "white tile, rounded corners" instead of a plain square.
void _paintWhiteRoundedSquare(img.Image canvas) {
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      if (_insideRoundedSquare(x, y, _size, _cornerRadius)) {
        canvas.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }
}

bool _insideRoundedSquare(int x, int y, int size, int radius) {
  final left = x < radius;
  final right = x >= size - radius;
  final top = y < radius;
  final bottom = y >= size - radius;
  if (left && top) return _inCorner(x, y, radius, radius, radius);
  if (right && top) return _inCorner(x, y, size - radius - 1, radius, radius);
  if (left && bottom) {
    return _inCorner(x, y, radius, size - radius - 1, radius);
  }
  if (right && bottom) {
    return _inCorner(x, y, size - radius - 1, size - radius - 1, radius);
  }
  return true;
}

bool _inCorner(int px, int py, int cx, int cy, int r) {
  final dx = px - cx;
  final dy = py - cy;
  return (dx * dx + dy * dy) <= r * r;
}
