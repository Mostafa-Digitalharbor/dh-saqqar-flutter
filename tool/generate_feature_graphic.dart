// Generates the 1024×500 PNG that Google Play Store requires for the
// listing's "feature graphic" (the banner shown above the app on the
// store page + in featured placements).
//
// Run: `dart run tool/generate_feature_graphic.dart`
//
// Writes to `play-store-assets/feature-graphic.png`.
//
// Design intent: dark navy backdrop with the radial cyan→purple glow
// the in-app splash screen uses, then the SAQQAR wordmark centred on
// top in the white-stroke variant. Mirrors the launch experience so
// the store listing reads as a continuous brand surface, not a
// separately-art-directed asset.
//
// Re-run any time the wordmark or palette changes.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _width = 1024;
const _height = 500;

// Brand palette — keep in sync with lib/core/theme/app_colors.dart.
final _navyDeep = img.ColorRgb8(0x03, 0x07, 0x12); // #030712
final _navyMid = img.ColorRgb8(0x0F, 0x17, 0x22); // #0F1722
final _cyan = img.ColorRgb8(0x06, 0xB6, 0xD4); // #06B6D4
final _purple = img.ColorRgb8(0x8B, 0x5C, 0xF6); // #8B5CF6

void main() {
  const sourceLogoPath = 'play-store-assets/logo-light.png';
  final logoFile = File(sourceLogoPath);
  if (!logoFile.existsSync()) {
    stderr.writeln('✗ source missing: $sourceLogoPath');
    exit(1);
  }
  final logo = img.decodePng(logoFile.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('✗ could not decode $sourceLogoPath as PNG');
    exit(1);
  }

  final canvas = img.Image(
    width: _width,
    height: _height,
    numChannels: 4,
    backgroundColor: img.ColorRgba8(
      _navyDeep.r.toInt(),
      _navyDeep.g.toInt(),
      _navyDeep.b.toInt(),
      255,
    ),
  );

  _paintBackground(canvas);
  _paintRadialGlow(
    canvas,
    centerX: _width ~/ 2,
    centerY: _height ~/ 2,
    radius: (_height * 0.85).toInt(),
    color: _cyan,
    maxAlpha: 90,
  );
  _paintRadialGlow(
    canvas,
    centerX: _width ~/ 2,
    centerY: _height ~/ 2,
    radius: (_height * 0.55).toInt(),
    color: _purple,
    maxAlpha: 60,
  );
  _paintLogo(canvas, logo);

  final outDir = Directory('play-store-assets');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outPath = '${outDir.path}/feature-graphic.png';
  File(outPath).writeAsBytesSync(img.encodePng(canvas));

  stdout.writeln('✓ wrote $outPath (${_width}x$_height)');
  stdout.writeln('');
  stdout.writeln('Upload to: Play Console → Store presence → Main store');
  stdout.writeln('listing → Feature graphic');
}

/// Two-tone gradient: slightly lighter navy in the centre, deep navy at
/// the edges. Without this the backdrop reads as a flat rectangle —
/// the gradient adds depth even before the radial glow lands on top.
void _paintBackground(img.Image canvas) {
  const cx = _width / 2;
  const cy = _height / 2;
  final maxDist = math.sqrt(cx * cx + cy * cy);

  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final t = math.sqrt(dx * dx + dy * dy) / maxDist;
      final r = _lerp(_navyMid.r.toInt(), _navyDeep.r.toInt(), t);
      final g = _lerp(_navyMid.g.toInt(), _navyDeep.g.toInt(), t);
      final b = _lerp(_navyMid.b.toInt(), _navyDeep.b.toInt(), t);
      canvas.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

void _paintRadialGlow(
  img.Image canvas, {
  required int centerX,
  required int centerY,
  required int radius,
  required img.Color color,
  required int maxAlpha,
}) {
  final r2 = radius * radius;
  final minY = math.max(0, centerY - radius);
  final maxY = math.min(_height, centerY + radius);
  final minX = math.max(0, centerX - radius);
  final maxX = math.min(_width, centerX + radius);
  for (var y = minY; y < maxY; y++) {
    for (var x = minX; x < maxX; x++) {
      final dx = x - centerX;
      final dy = y - centerY;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) continue;
      final t = math.sqrt(d2) / radius;
      final alpha = ((1 - t) * (1 - t) * maxAlpha).round();
      _blendOver(canvas, x, y, color, alpha);
    }
  }
}

/// Centres the wordmark on the canvas at a size that leaves comfortable
/// breathing room on every edge (Play crops feature graphics for some
/// placements — keeping the artwork inside ~70 % of the canvas avoids
/// the wordmark being chopped). The dark-variant logo is white on
/// transparent, so it composites cleanly over the radial glow without
/// any colour cast.
void _paintLogo(img.Image canvas, img.Image logo) {
  // The brand logo is dark navy ink (+ cyan accents) on transparent — built
  // for LIGHT backgrounds. On our dark navy banner the navy ink would vanish,
  // so recolour it for dark: dark ink → white, cyan accents kept as cyan.
  final light = _recolorForDark(logo);

  // Target ~45% of the canvas height for the wordmark — large enough to be
  // the unmistakable hero, small enough to leave a safe margin top and bottom
  // for Play's variable cropping.
  final targetH = (_height * 0.42).round();
  final aspect = light.width / light.height;
  final targetW = (targetH * aspect).round();
  final resized = img.copyResize(
    light,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );
  final dx = ((_width - resized.width) / 2).round();
  final dy = ((_height - resized.height) / 2).round();
  img.compositeImage(
    canvas,
    resized,
    dstX: dx,
    dstY: dy,
    blend: img.BlendMode.alpha,
  );
}

/// Returns a copy of [logo] recoloured for a dark backdrop: near-black / navy
/// ink is mapped to white, while cyan/teal accent pixels are pushed to the
/// bright brand cyan so the check-mark accent still pops. Alpha is preserved
/// so the mark composites cleanly over the glow.
img.Image _recolorForDark(img.Image logo) {
  final out = img.Image.from(logo);
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      final a = p.a.toInt();
      if (a == 0) continue;
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      // Cyan/teal accent: green + blue clearly dominate red.
      final isCyan = g > 110 && b > 110 && r < g - 30 && r < b - 30;
      if (isCyan) {
        out.setPixelRgba(x, y, _cyan.r.toInt(), _cyan.g.toInt(),
            _cyan.b.toInt(), a);
      } else {
        out.setPixelRgba(x, y, 255, 255, 255, a);
      }
    }
  }
  return out;
}

int _lerp(int a, int b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return (a + (b - a) * clamped).round();
}

/// Standard "src over dst" alpha blend so radial glows layer correctly
/// over the gradient backdrop.
void _blendOver(img.Image canvas, int x, int y, img.Color src, int srcA) {
  if (srcA <= 0) return;
  final dst = canvas.getPixel(x, y);
  final dstA = dst.a.toInt();
  final outA = srcA + (dstA * (255 - srcA) ~/ 255);
  if (outA == 0) return;
  final outR =
      (src.r.toInt() * srcA + dst.r.toInt() * dstA * (255 - srcA) ~/ 255) ~/
          outA;
  final outG =
      (src.g.toInt() * srcA + dst.g.toInt() * dstA * (255 - srcA) ~/ 255) ~/
          outA;
  final outB =
      (src.b.toInt() * srcA + dst.b.toInt() * dstA * (255 - srcA) ~/ 255) ~/
          outA;
  canvas.setPixelRgba(
    x,
    y,
    outR.clamp(0, 255),
    outG.clamp(0, 255),
    outB.clamp(0, 255),
    outA.clamp(0, 255),
  );
}
