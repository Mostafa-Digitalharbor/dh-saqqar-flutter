// One-shot icon generator for Saqqar.
//
// Run: `dart run tool/generate_app_icon.dart`
//
// Writes two PNGs into `assets/img/`:
//   - saqqar-icon.png            (1024×1024, full bleed — used for iOS / web)
//   - saqqar-icon-foreground.png (1024×1024, transparent bg — used as the
//                                  Android adaptive foreground + as the
//                                  splash mark)
//
// Design intent:
//   - Bold white "S" monogram on a centered cyan→purple radial glow over a
//     deep navy plate. The S is two annular half-rings stacked, sized so the
//     mark reads cleanly down to 48 px (Play legacy) and up to 1024 px (App
//     Store). On launcher screens the white S on the navy plate scans
//     instantly as "Saqqar" next to the wordmark label.
//
// Re-run any time the brand changes; both PNGs are deterministic.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _size = 1024;

// Brand palette — keep in sync with lib/core/theme/app_colors.dart.
final _navyDeep = img.ColorRgb8(0x03, 0x07, 0x12); // #030712
final _navyMid = img.ColorRgb8(0x0F, 0x17, 0x22); // #0F1722
final _cyan = img.ColorRgb8(0x06, 0xB6, 0xD4); // #06B6D4
final _purple = img.ColorRgb8(0x8B, 0x5C, 0xF6); // #8B5CF6
final _white = img.ColorRgb8(0xFF, 0xFF, 0xFF);

void main() {
  final outDir = Directory('assets/img');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final fullBleed = _renderIcon(transparentBackground: false);
  final foreground = _renderIcon(transparentBackground: true);

  File('${outDir.path}/saqqar-icon.png')
      .writeAsBytesSync(img.encodePng(fullBleed));
  File('${outDir.path}/saqqar-icon-foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln('✓ wrote assets/img/saqqar-icon.png (${_size}x$_size)');
  stdout.writeln(
    '✓ wrote assets/img/saqqar-icon-foreground.png (${_size}x$_size)',
  );
  stdout.writeln('');
  stdout.writeln('Next:');
  stdout.writeln('  dart run flutter_launcher_icons');
  stdout.writeln('  dart run flutter_native_splash:create');
}

img.Image _renderIcon({required bool transparentBackground}) {
  final canvas = img.Image(
    width: _size,
    height: _size,
    numChannels: 4,
    backgroundColor: transparentBackground
        ? img.ColorRgba8(0, 0, 0, 0)
        : img.ColorRgba8(
            _navyDeep.r.toInt(),
            _navyDeep.g.toInt(),
            _navyDeep.b.toInt(),
            255,
          ),
  );

  if (!transparentBackground) {
    _paintRoundedNavyPlate(canvas);
  }

  // Centred cyan glow — sits directly behind the monogram so the S looks
  // like it's lit from underneath rather than floating on flat navy.
  _paintRadialGlow(
    canvas,
    centerX: _size ~/ 2,
    centerY: _size ~/ 2,
    radius: (_size * 0.46).toInt(),
    color: _cyan,
    maxAlpha: transparentBackground ? 100 : 150,
  );

  // Centred purple secondary glow — same anchor point so the lighting reads
  // as a single source. Smaller radius, deeper colour adds a violet halo
  // around the S without dragging the optical centre off-axis.
  _paintRadialGlow(
    canvas,
    centerX: _size ~/ 2,
    centerY: _size ~/ 2,
    radius: (_size * 0.30).toInt(),
    color: _purple,
    maxAlpha: transparentBackground ? 70 : 110,
  );

  _paintMonogramS(canvas);

  return canvas;
}

/// Paints a rounded-square navy plate filling the canvas (full-bleed icon).
/// Corner radius matches iOS's home-screen mask (≈22%) so the artwork stays
/// inside even when the system clips to a circle / squircle.
void _paintRoundedNavyPlate(img.Image canvas) {
  // Two-tone: deep navy edges fading into a slightly lighter centre so the
  // icon doesn't read as a flat rectangle on any wallpaper.
  const cx = _size / 2;
  const cy = _size / 2;
  final maxDist = math.sqrt(2) * cx;
  final cornerRadius = (_size * 0.22).round();

  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      if (!_isInsideRoundedSquare(x, y, _size, cornerRadius)) {
        canvas.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      final dx = x - cx;
      final dy = y - cy;
      final t = math.sqrt(dx * dx + dy * dy) / maxDist;
      // Mid → deep gradient.
      final r = _lerp(_navyMid.r.toInt(), _navyDeep.r.toInt(), t);
      final g = _lerp(_navyMid.g.toInt(), _navyDeep.g.toInt(), t);
      final b = _lerp(_navyMid.b.toInt(), _navyDeep.b.toInt(), t);
      canvas.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

bool _isInsideRoundedSquare(int x, int y, int size, int radius) {
  final left = x < radius;
  final right = x >= size - radius;
  final top = y < radius;
  final bottom = y >= size - radius;
  if (left && top) return _inCornerCircle(x, y, radius, radius, radius);
  if (right && top) {
    return _inCornerCircle(x, y, size - radius - 1, radius, radius);
  }
  if (left && bottom) {
    return _inCornerCircle(x, y, radius, size - radius - 1, radius);
  }
  if (right && bottom) {
    return _inCornerCircle(
      x,
      y,
      size - radius - 1,
      size - radius - 1,
      radius,
    );
  }
  return true;
}

bool _inCornerCircle(int px, int py, int cx, int cy, int r) {
  final dx = px - cx;
  final dy = py - cy;
  return (dx * dx + dy * dy) <= r * r;
}

int _lerp(int a, int b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return (a + (b - a) * clamped).round();
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
  for (var y = math.max(0, centerY - radius);
      y < math.min(_size, centerY + radius);
      y++) {
    for (var x = math.max(0, centerX - radius);
        x < math.min(_size, centerX + radius);
        x++) {
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

/// Bold "S" monogram — two annular half-rings stacked so the openings flow
/// into each other. The upper ring's bottom-right quadrant is open; the
/// lower ring's top-left is open; the gap between their centres is tuned so
/// the strokes connect through the middle without overlapping.
///
/// Geometry (all relative to a 1024 canvas):
///   outerR = 0.205 → S is ~420 px wide overall
///   innerR = 0.135 → stroke thickness is ~145 px (reads at 48 px launcher)
///   loopOffset = (outerR + innerR) / 2 → stacks the rings so the inner
///                                          edges meet on the centre line
///
/// Fill is white with edge softening so the silhouette looks crisp at every
/// density without aliasing into the cyan glow underneath.
void _paintMonogramS(img.Image canvas) {
  const cx = _size / 2;
  const cy = _size / 2;
  const outerR = _size * 0.205;
  const innerR = _size * 0.135;
  const loopOffset = (outerR + innerR) / 2;

  const upCx = cx;
  const upCy = cy - loopOffset;
  const loCx = cx;
  const loCy = cy + loopOffset;

  // Bounding box covers both loops vertically + the wider of the two
  // horizontally. Saves us iterating the whole canvas per pixel.
  final minX = (cx - outerR - 2).floor().clamp(0, _size - 1);
  final maxX = (cx + outerR + 2).ceil().clamp(0, _size - 1);
  final minY = (upCy - outerR - 2).floor().clamp(0, _size - 1);
  final maxY = (loCy + outerR + 2).ceil().clamp(0, _size - 1);

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      // Upper ring — keep everything EXCEPT the bottom-right quadrant.
      // That quadrant is (x > upCx && y > upCy); the open gap there is what
      // lets the lower ring's stroke join the upper one through the middle.
      final dxU = x - upCx;
      final dyU = y - upCy;
      final dU = math.sqrt(dxU * dxU + dyU * dyU);
      final inUpper = dU >= innerR &&
          dU <= outerR &&
          !(x > upCx && y > upCy);

      // Lower ring — keep everything EXCEPT the top-left quadrant. Mirror
      // of the upper logic so the two open mouths face each other.
      final dxL = x - loCx;
      final dyL = y - loCy;
      final dL = math.sqrt(dxL * dxL + dyL * dyL);
      final inLower = dL >= innerR &&
          dL <= outerR &&
          !(x < loCx && y < loCy);

      if (!inUpper && !inLower) continue;

      // Edge AA — the strongest fade is the half-pixel right at the inner
      // and outer radii. 4-pixel soft band keeps the stroke crisp without
      // a jagged silhouette.
      double edge = 0;
      if (inUpper) {
        final eU = math.min(dU - innerR, outerR - dU);
        edge = math.max(edge, (eU / 4).clamp(0.0, 1.0));
      }
      if (inLower) {
        final eL = math.min(dL - innerR, outerR - dL);
        edge = math.max(edge, (eL / 4).clamp(0.0, 1.0));
      }
      _blendOver(canvas, x, y, _white, (255 * edge).round());
    }
  }
}

/// Standard "src over dst" alpha blend — needed because radial glows and
/// sparkle highlights overlap.
void _blendOver(img.Image canvas, int x, int y, img.Color src, int srcA) {
  if (srcA <= 0) return;
  final dst = canvas.getPixel(x, y);
  final dstA = dst.a.toInt();
  final outA = srcA + (dstA * (255 - srcA) ~/ 255);
  if (outA == 0) return;
  final outR = (src.r.toInt() * srcA +
              dst.r.toInt() * dstA * (255 - srcA) ~/ 255) ~/
          outA;
  final outG = (src.g.toInt() * srcA +
              dst.g.toInt() * dstA * (255 - srcA) ~/ 255) ~/
          outA;
  final outB = (src.b.toInt() * srcA +
              dst.b.toInt() * dstA * (255 - srcA) ~/ 255) ~/
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
