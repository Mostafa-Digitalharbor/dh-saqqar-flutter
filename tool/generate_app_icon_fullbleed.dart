// One-shot: turn `assets/img/app-icon.png` (the blue SAQQÂR tile that
// currently sits on a white background) into a FULL-BLEED launcher icon
// where the navy/blue fills the whole canvas and NO white remains.
//
// Run: `dart run tool/generate_app_icon_fullbleed.dart`
//
// Strategy:
//   1. Decode the source.
//   2. Find the bounding box of the non-white / non-transparent pixels
//      (the rounded blue tile).
//   3. Crop to that box, then scale it UP with a small overscan so the
//      rounded corners spill off the edges of the 1024² canvas — this
//      pushes the white corner triangles out of frame and the navy
//      bleeds edge-to-edge.
//   4. Sample the tile's own corner navy as the fill colour so any
//      sub-pixel gap at the very edges stays navy, never white.
//
// Writes the three files pubspec's flutter_launcher_icons block expects:
//   - assets/img/app-icon-full.png        (1024², opaque, full-bleed)
//   - assets/img/app-icon-bg.png          (1024², solid navy)
//   - assets/img/app-icon-foreground.png  (1024², full-bleed symbol)

import 'dart:io';

import 'package:image/image.dart' as img;

const _size = 1024;
const _overscan = 1.34; // >1 so the rounded corners spill off-frame → no white
const _symbolScale = 0.84; // <1 leaves a navy margin so the symbol breathes

void main() {
  final dir = Directory('assets/img');
  final srcFile = File('${dir.path}/app-icon.png');
  if (!srcFile.existsSync()) {
    stderr.writeln('✗ source missing: ${srcFile.path}');
    exit(1);
  }
  final src = img.decodePng(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('✗ could not decode ${srcFile.path}');
    exit(1);
  }

  // --- 1. bounding box of the NAVY ring of the tile ---
  // Match the dark navy specifically (blue-dominant + dark) so the white
  // symbol inside, the white background, and the faint drop shadow are
  // all ignored. The navy forms the tile's perimeter, so its bbox == the
  // tile bbox.
  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final a = p.a.toInt(), r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      if (a < 64) continue;
      final isNavy = b > 55 && b > r + 15 && b > g + 10 && r < 130 && g < 130;
      if (!isNavy) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) {
    stderr.writeln('✗ found no non-white content');
    exit(1);
  }
  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;
  final cropped = img.copyCrop(src, x: minX, y: minY, width: cropW, height: cropH);
  stdout.writeln('• tile bbox: ${cropW}x$cropH at ($minX,$minY)');

  // Sample the navy near the tile centre-edge for the fill colour.
  final navy = cropped.getPixel(cropW ~/ 2, 4);
  final fill = img.ColorRgb8(navy.r.toInt(), navy.g.toInt(), navy.b.toInt());

  // --- 2. scale up with overscan, then centre-crop to 1024² ---
  // Cropping the centre out of an over-sized square throws the rounded
  // corners (and any white around them) outside the frame, leaving the
  // navy face edge-to-edge.
  final scaled = (_size * _overscan).round();
  final big = img.copyResize(
    cropped,
    width: scaled,
    height: scaled,
    interpolation: img.Interpolation.cubic,
  );
  final off = ((scaled - _size) / 2).round();
  final center = img.copyCrop(big, x: off, y: off, width: _size, height: _size);

  // Key out the symbol (white strokes + cyan tick) from its navy field so
  // we can place it, at any size, on a single uniform navy background with
  // no visible seam. Navy pixels become transparent; the anti-aliased
  // edges keep partial alpha so the strokes stay smooth.
  final symbol = img.Image(width: _size, height: _size, numChannels: 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final p = center.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      final isWhite = r > 150 && g > 150 && b > 150;
      final isCyan = r < 140 && g > 140 && b > 150;
      if (isWhite || isCyan) {
        symbol.setPixelRgba(x, y, r, g, b, 255);
      } else {
        symbol.setPixelRgba(x, y, r, g, b, 0); // navy → transparent
      }
    }
  }

  // Shrink the symbol so it breathes inside a full-bleed navy field.
  final inner = (_size * _symbolScale).round();
  final shrunk = img.copyResize(
    symbol,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.cubic,
  );
  final pad = ((_size - inner) / 2).round();
  final full = img.Image(width: _size, height: _size, numChannels: 3);
  img.fill(full, color: fill); // uniform navy — no seam, no white
  img.compositeImage(full, shrunk,
      dstX: pad, dstY: pad, blend: img.BlendMode.alpha);
  File('${dir.path}/app-icon-full.png').writeAsBytesSync(img.encodePng(full));

  // --- 3. adaptive background: solid navy ---
  final bg = img.Image(width: _size, height: _size, numChannels: 3);
  img.fill(bg, color: fill);
  File('${dir.path}/app-icon-bg.png').writeAsBytesSync(img.encodePng(bg));

  // --- 4. adaptive foreground: same full-bleed tile (navy, no white) ---
  File('${dir.path}/app-icon-foreground.png')
      .writeAsBytesSync(img.encodePng(full));

  stdout.writeln('✓ wrote app-icon-full.png / app-icon-bg.png / app-icon-foreground.png');
  stdout.writeln('  fill navy = rgb(${fill.r},${fill.g},${fill.b})');
  stdout.writeln('Next: dart run flutter_launcher_icons');
}
