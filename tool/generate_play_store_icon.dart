// Generates the 512×512 PNG that Google Play Store requires for the app
// listing's hero icon.
//
// Run: `dart run tool/generate_play_store_icon.dart`
//
// Writes to `play-store-assets/icon-512.png`.
//
// Source: `play-store-assets/app-icon.png` — the new brand icon (a navy
// rounded tile with the hex "S/✓" mark) exported on a WHITE background with a
// soft drop shadow. Play listing icons look best full-bleed, so we:
//   1. Locate the navy tile by colour (blue-leaning pixels — ignores the
//      white page and neutral-grey shadow) and crop to its bounds.
//   2. Flood-fill the rounded-corner gaps + shadow from the crop's border and
//      repaint them with the tile navy; the enclosed white/cyan mark is walled
//      off by the dark tile so it's untouched.
//   3. Overscan slightly and centre-crop to 512 so the tile bleeds to every
//      edge (Play adds its own rounded mask, so square corners are correct).
//   4. Encode as opaque 24-bit RGB (Play rejects any transparency).
//
// Re-run any time the source icon changes.

import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

const _target = 512;
const _overscan = 1.06;
const _bgLumaCutoff = 120; // white page + light shadow sit above this

int _luma(img.Pixel p) => (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();

void main() {
  const sourcePath = 'play-store-assets/app-icon.png';
  final source = File(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('✗ source missing: $sourcePath');
    exit(1);
  }
  final src = img.decodePng(source.readAsBytesSync());
  if (src == null) {
    stderr.writeln('✗ could not decode $sourcePath as PNG');
    exit(1);
  }

  final w = src.width;
  final h = src.height;

  // ── 1. Tile bounds by colour + representative navy for the fill.
  bool isTile(img.Pixel p) => (p.b - p.r) > 14 && p.b > 55;
  var minX = w, minY = h, maxX = -1, maxY = -1;
  var navR = 0, navG = 0, navB = 0, navN = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      if (!isTile(p)) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (p.b < 120) {
        // darker navy only (skip bright cyan)
        navR += p.r.toInt();
        navG += p.g.toInt();
        navB += p.b.toInt();
        navN++;
      }
    }
  }
  if (maxX < 0) {
    stderr.writeln('✗ no navy tile detected in $sourcePath');
    exit(1);
  }
  final navy = navN > 0
      ? img.ColorRgb8(
          (navR / navN).round(), (navG / navN).round(), (navB / navN).round())
      : img.ColorRgb8(0x0B, 0x24, 0x4C);

  // ── 2. Crop to the tile's bounding square (pad shorter axis with navy).
  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;
  final s = cropW > cropH ? cropW : cropH;
  final tile = img.Image(
    width: s,
    height: s,
    numChannels: 3,
    backgroundColor: navy,
  );
  img.compositeImage(
    tile,
    src,
    dstX: -minX + ((s - cropW) / 2).round(),
    dstY: -minY + ((s - cropH) / 2).round(),
  );

  // ── 3. Flood-fill light corner gaps / shadow from the border → navy.
  final isBg = List<bool>.filled(s * s, false);
  final queue = Queue<int>();
  void consider(int x, int y) {
    if (x < 0 || y < 0 || x >= s || y >= s) return;
    final idx = y * s + x;
    if (isBg[idx]) return;
    if (_luma(tile.getPixel(x, y)) >= _bgLumaCutoff) {
      isBg[idx] = true;
      queue.add(idx);
    }
  }

  for (var i = 0; i < s; i++) {
    consider(i, 0);
    consider(i, s - 1);
    consider(0, i);
    consider(s - 1, i);
  }
  while (queue.isNotEmpty) {
    final idx = queue.removeFirst();
    final x = idx % s;
    final y = idx ~/ s;
    consider(x - 1, y);
    consider(x + 1, y);
    consider(x, y - 1);
    consider(x, y + 1);
  }
  for (var i = 0; i < s * s; i++) {
    if (isBg[i]) tile.setPixelRgb(i % s, i ~/ s, navy.r, navy.g, navy.b);
  }

  // ── 4. Overscan + centre-crop to 512 so the tile bleeds full-frame.
  final big = (_target * _overscan).round();
  final scaled = img.copyResize(
    tile,
    width: big,
    height: big,
    interpolation: img.Interpolation.cubic,
  );
  final inset = ((big - _target) / 2).round();
  final out = img.copyCrop(
    scaled,
    x: inset,
    y: inset,
    width: _target,
    height: _target,
  );

  final outDir = Directory('play-store-assets');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  const outPath = 'play-store-assets/icon-512.png';
  File(outPath).writeAsBytesSync(img.encodePng(out));

  stdout.writeln('✓ wrote $outPath ($_target×$_target, full-bleed navy, '
      'no alpha)');
  stdout.writeln('');
  stdout.writeln('Upload to: Play Console → Store presence → Main store');
  stdout.writeln('listing → App icon');
}
