// Trims the marketing renders in `live_assets/chat-gpt-assets/` down to the
// device frame and stamps a clean iOS-style status bar on each.
//
// Run: `dart run tool/frame_store_assets.dart`
// Output: `live_assets/chat-gpt-assets/out/`
//
// Two things happen per image:
//
//   1. CROP to the device. The renders sit on a gradient backdrop with a
//      headline and subtitle above the device; everything outside the frame's
//      border stroke is dropped. The stroke itself is kept — it is the edge of
//      the device, not decoration.
//
//   2. STATUS BAR. The iPad renders ship one already (a 6:34 clock plus a
//      location-services shield); the iPhone renders ship none at all. Both are
//      normalised to the same four elements and nothing else: 10:10 on the
//      left, then cellular bars, Wi-Fi and a full battery on the right. The
//      iPad's existing bar is painted out first so the shield cannot survive.
//
// Glyphs and icons are drawn as shapes rather than typed with a bitmap font:
// `package:image` ships only 14/24/48-px Arial, and the smallest of these
// images needs a ~50 px cap height, so a bitmap would have to be upscaled and
// would blur. Everything below is rendered into a 4× supersampled RGBA layer
// and box-filtered down, which anti-aliases the curves. The clock only ever
// reads "10:10", so the glyph set needed is just `1`, `0` and `:`.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _srcDir = 'live_assets/chat-gpt-assets';
const _outDir = 'live_assets/chat-gpt-assets/out';

/// Supersampling factor for the status-bar layer.
const _ss = 4;

void main() {
  final dir = Directory(_srcDir);
  final sources = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (sources.isEmpty) {
    stderr.writeln('✗ no PNGs in $_srcDir');
    exitCode = 1;
    return;
  }

  Directory(_outDir).createSync(recursive: true);

  for (final file in sources) {
    final name = file.uri.pathSegments.last;
    final decoded = img.decodePng(file.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('✗ could not decode $name');
      continue;
    }

    final box = _frameBounds(decoded);
    if (box == null) {
      stderr.writeln('✗ no device frame found in $name');
      continue;
    }

    final device = img.copyCrop(
      decoded,
      x: box.l,
      y: box.t,
      width: box.r - box.l + 1,
      height: box.b - box.t + 1,
    );

    // Measured BEFORE the shift below, so the bar keeps the position it would
    // otherwise have had and the app content moves away from it.
    final spec = _StatusBarSpec.forImage(device);
    _dropContent(device);
    _clearExistingBar(device, spec);
    _stampStatusBar(device, spec);

    final outPath = '$_outDir/$name';
    File(outPath).writeAsBytesSync(img.encodePng(device));
    stdout.writeln('✓ $name  ${decoded.width}x${decoded.height}'
        '  →  ${device.width}x${device.height}');
  }

  stdout.writeln('\nWrote ${sources.length} file(s) to $_outDir/');
}

// ── Frame detection ──────────────────────────────────────────────────────
//
// The device edge is a thin bright stroke on a darker backdrop, so it reads as
// a narrow ridge: brighter than the pixels a few px to either side. A plain
// brightness threshold picks up the white headline instead, and the top stroke
// additionally has to be told apart from that headline's accent underline —
// hence the "most of the width ridges on this row" test for the horizontals.

double _lum(img.Pixel p) => 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;

bool _ridgeAcross(img.Image im, int x, int y) {
  if (x < 9 || x >= im.width - 9) return false;
  final c = _lum(im.getPixel(x, y));
  return c - _lum(im.getPixel(x - 8, y)) > 25 &&
      c - _lum(im.getPixel(x + 8, y)) > 25;
}

bool _ridgeDown(img.Image im, int x, int y) {
  if (y < 9 || y >= im.height - 9) return false;
  final c = _lum(im.getPixel(x, y));
  return c - _lum(im.getPixel(x, y - 8)) > 25 &&
      c - _lum(im.getPixel(x, y + 8)) > 25;
}

({int l, int t, int r, int b})? _frameBounds(img.Image im) {
  final midY = im.height ~/ 2;
  var l = -1, r = -1;
  for (var x = 1; x < im.width ~/ 2; x++) {
    if (_ridgeAcross(im, x, midY)) {
      l = x;
      break;
    }
  }
  for (var x = im.width - 2; x > im.width ~/ 2; x--) {
    if (_ridgeAcross(im, x, midY)) {
      r = x;
      break;
    }
  }
  if (l < 0 || r < 0 || r - l < im.width ~/ 4) return null;

  final x0 = l + 120, x1 = r - 120;
  bool spansRow(int y) {
    var hits = 0, samples = 0;
    for (var x = x0; x <= x1; x += 4) {
      samples++;
      if (_ridgeDown(im, x, y)) hits++;
    }
    return samples > 0 && hits > samples * 0.6;
  }

  var t = -1, b = -1;
  for (var y = 1; y < im.height ~/ 2; y++) {
    if (spansRow(y)) {
      t = y;
      break;
    }
  }
  for (var y = im.height - 2; y > im.height ~/ 2; y--) {
    if (spansRow(y)) {
      b = y;
      break;
    }
  }
  if (t < 0 || b < 0 || b - t < im.height ~/ 4) return null;
  return (l: l, t: t, r: r, b: b);
}

// ── Status bar geometry ──────────────────────────────────────────────────

class _StatusBarSpec {
  _StatusBarSpec({
    required this.centerY,
    required this.capHeight,
    required this.sidePad,
    required this.clearFrom,
    required this.clearTo,
  });

  /// Vertical centre of the bar's content, in cropped-image pixels.
  final int centerY;

  /// Cap height of the clock digits; every other element is sized off this so
  /// the bar scales with the render instead of carrying per-device constants.
  final double capHeight;

  /// Inset from the device edge to the clock / battery.
  final int sidePad;

  /// Rows repainted with the screen background before drawing (the iPad's
  /// existing bar lives here). Equal values mean "nothing to erase".
  final int clearFrom;
  final int clearTo;

  /// Portrait renders (iPhone) arrive with an empty band between the device
  /// edge and the app header; landscape ones (iPad) already carry a bar that
  /// has to be replaced in place, so the two are told apart by aspect ratio.
  factory _StatusBarSpec.forImage(img.Image im) {
    final portrait = im.height > im.width;
    if (portrait) {
      // The band above the app header is empty on these renders, but its
      // height varies per screen — the conversation header sits higher than
      // the chats one — so it is measured rather than assumed. Sizing the
      // clock off a fixed fraction of the width instead put the bar hard
      // against the conversation screen's title.
      final headerTop = _contentTop(im);
      const topStroke = 6;
      final band = (headerTop - topStroke).toDouble();
      return _StatusBarSpec(
        centerY: (topStroke + band / 2).round(),
        capHeight: math.min(im.width * 0.0385, band * 0.46),
        sidePad: (im.width * 0.068).round(),
        clearFrom: 0,
        clearTo: 0,
      );
    }
    // Measured: the shipped bar's glyphs occupy ~y 205..235 of a 2105-px-tall
    // crop, and the app header begins at ~285.
    //
    // The band that gets erased tracks the SHIPPED bar; the replacement is
    // drawn higher up, nearer the top of the screen the way iPadOS puts it.
    // The two are separate on purpose — the erase has to land on the old
    // glyphs wherever they were, not wherever the new ones go.
    final oldCenter = (im.height * 0.1045).round();
    final half = (im.height * 0.0135).round();
    return _StatusBarSpec(
      centerY: (im.height * 0.0770).round(),
      capHeight: im.width * 0.0165,
      sidePad: (im.width * 0.029).round(),
      clearFrom: oldCenter - half,
      clearTo: oldCenter + half,
    );
  }
}

/// Pushes the app's own UI down the screen so it is not crowded by the status
/// bar stamped above it. Portrait renders only — the tablet ones already have
/// room between the bar and the app header.
///
/// The canvas cannot grow (it is the device), so the shift is absorbed by the
/// empty strip between the bottom of the app's UI and the home indicator: rows
/// above that strip slide down into it, and the vacated rows at the top are
/// refilled from the clean background row just above them. The home indicator
/// and the frame's bottom edge never move — shifting the whole image instead
/// would have pushed both off the canvas.
void _dropContent(img.Image im) {
  if (im.height <= im.width) return;

  // Start ABOVE the first bright row, not on it. A control's container outline
  // is only a few luminance levels above the backdrop — the bell's rounded
  // button begins ~12 px before its icon does — so slicing at the bright row
  // left the outline's top edge behind and the shifted copy ghosted beneath it.
  // The margin is bounded below by the end of the frame's rounded corner
  // (~y 24), which must not be dragged down or it distorts into a taller arc.
  const cornerSafeY = 30;
  final margin = (im.height * 0.0115).round();
  final fromY = math.max(cornerSafeY, _contentTop(im) - margin);

  // Measured: the app's UI ends by ~2620 and the home indicator sits at ~2745
  // on a 2845-px-tall crop, leaving an empty strip in between on all four
  // screens. Absorb inside it, with margin so the indicator is never touched.
  final absorbY = (im.height * 0.9448).round();
  final amount = (im.height * 0.0158).round();
  if (absorbY + amount >= im.height || fromY >= absorbY) return;

  // Bottom-up, so rows still to be read are not overwritten first.
  for (var y = absorbY - 1; y >= fromY; y--) {
    for (var x = 0; x < im.width; x++) {
      final p = im.getPixel(x, y);
      im.setPixelRgba(
          x, y + amount, p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
    }
  }

  // Refill the vacated rows by replicating the clean background row just above
  // them — that strip is flat, and copying it keeps the frame's side strokes.
  final srcY = (fromY - 4).clamp(0, im.height - 1);
  for (var y = fromY; y < fromY + amount; y++) {
    for (var x = 0; x < im.width; x++) {
      final p = im.getPixel(x, srcY);
      im.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
    }
  }
}

/// First row below the device edge carrying real UI — the top of the app's own
/// header. Everything above it is empty screen the status bar can occupy.
/// Edges are inset so the frame's border stroke and rounded corners are not
/// mistaken for content.
int _contentTop(img.Image im) {
  final inset = (im.width * 0.07).round();
  final limit = (im.height * 0.20).round();
  for (var y = 10; y < limit; y++) {
    for (var x = inset; x < im.width - inset; x++) {
      if (_lum(im.getPixel(x, y)) > 110) return y;
    }
  }
  return (im.height * 0.05).round();
}

/// Repaints the old status-bar rows so the replaced clock and the location
/// shield leave nothing behind.
///
/// Each column is rebuilt by interpolating between the clean row just above the
/// band and the clean one just below it, rather than flooded with one sampled
/// colour: the screen backdrop carries a faint gradient, so a flat fill left a
/// visible rectangle exactly where the old bar had been.
void _clearExistingBar(img.Image im, _StatusBarSpec spec) {
  if (spec.clearTo <= spec.clearFrom) return;
  // Inset horizontally so the device's own border stroke survives.
  const edge = 6;
  final aboveY = (spec.clearFrom - 10).clamp(0, im.height - 1);
  final belowY = (spec.clearTo + 10).clamp(0, im.height - 1);
  final span = (spec.clearTo - spec.clearFrom).toDouble();
  for (var x = edge; x < im.width - edge; x++) {
    final a = im.getPixel(x, aboveY);
    final b = im.getPixel(x, belowY);
    for (var y = spec.clearFrom; y <= spec.clearTo; y++) {
      final t = span == 0 ? 0.0 : (y - spec.clearFrom) / span;
      im.setPixelRgb(
        x,
        y,
        (a.r + (b.r - a.r) * t).round(),
        (a.g + (b.g - a.g) * t).round(),
        (a.b + (b.b - a.b) * t).round(),
      );
    }
  }
}

// ── Drawing ──────────────────────────────────────────────────────────────

void _stampStatusBar(img.Image im, _StatusBarSpec spec) {
  final cap = spec.capHeight * _ss;
  final layer = img.Image(width: im.width * _ss, height: im.height * _ss, numChannels: 4);
  final cy = spec.centerY * _ss;
  final white = img.ColorRgba8(255, 255, 255, 255);

  // Clock, left.
  _drawClock(layer, x: spec.sidePad * _ss, centerY: cy, cap: cap, color: white);

  // Right cluster, laid out right-to-left: battery, Wi-Fi, cellular.
  final gap = cap * 0.42;
  var right = (im.width - spec.sidePad) * _ss;

  final batteryW = cap * 1.62;
  final batteryH = cap * 0.80;
  _drawBattery(
    layer,
    right: right.toDouble(),
    centerY: cy.toDouble(),
    w: batteryW,
    h: batteryH,
    color: white,
  );
  right -= (batteryW + cap * 0.20 + gap).round();

  final wifiW = cap * 1.16;
  _drawWifi(
    layer,
    right: right.toDouble(),
    centerY: cy.toDouble(),
    w: wifiW,
    color: white,
  );
  right -= (wifiW + gap).round();

  final barsW = cap * 1.12;
  _drawSignal(
    layer,
    right: right.toDouble(),
    centerY: cy.toDouble(),
    w: barsW,
    h: cap * 0.78,
    color: white,
  );

  final down = img.copyResize(
    layer,
    width: im.width,
    height: im.height,
    interpolation: img.Interpolation.average,
  );
  img.compositeImage(im, down);
}

/// "10:10" — the only string this bar ever shows, so the glyph set is `1`,
/// `0` and `:` drawn as shapes (see the file header for why not a font).
void _drawClock(
  img.Image im, {
  required int x,
  required int centerY,
  required double cap,
  required img.Color color,
}) {
  final stroke = cap * 0.155;
  final digitW = cap * 0.56;
  final advance = digitW + cap * 0.15;
  var cursor = x.toDouble();

  void one() {
    // Stem on the right of the advance, with SF-style angled entry flag.
    final stemX = cursor + digitW * 0.62;
    _fillRoundRect(im, stemX - stroke / 2, centerY - cap / 2, stroke,
        cap, stroke / 2, color);
    // Flag: a short bar rising to the left of the stem top.
    _fillQuad(
      im,
      [
        _P(stemX - stroke / 2, centerY - cap / 2),
        _P(stemX - stroke / 2, centerY - cap / 2 + stroke * 1.5),
        _P(stemX - digitW * 0.45, centerY - cap / 2 + stroke * 2.35),
        _P(stemX - digitW * 0.45, centerY - cap / 2 + stroke * 1.25),
      ],
      color,
    );
    cursor += advance;
  }

  void zero() {
    final rx = digitW / 2, ry = cap / 2;
    final cx = cursor + rx, cy = centerY.toDouble();
    _fillEllipseRing(im, cx, cy, rx, ry, stroke, color);
    cursor += advance;
  }

  void colon() {
    final r = stroke * 0.62;
    final cx = cursor + r;
    _fillCircleAA(im, cx, centerY - cap * 0.235, r, color);
    _fillCircleAA(im, cx, centerY + cap * 0.235, r, color);
    cursor += r * 2 + cap * 0.20;
  }

  one();
  zero();
  colon();
  one();
  zero();
}

/// Four rounded bars of increasing height, all filled — "full" cellular.
void _drawSignal(
  img.Image im, {
  required double right,
  required double centerY,
  required double w,
  required double h,
  required img.Color color,
}) {
  const count = 4;
  final barW = w / (count * 2 - 1);
  final gap = barW;
  final bottom = centerY + h / 2;
  for (var i = 0; i < count; i++) {
    final barH = h * (0.42 + 0.58 * (i / (count - 1)));
    final x = right - w + i * (barW + gap);
    _fillRoundRect(im, x, bottom - barH, barW, barH, barW * 0.34, color);
  }
}

/// Three arcs over a dot — "full" Wi-Fi.
void _drawWifi(
  img.Image im, {
  required double right,
  required double centerY,
  required double w,
  required img.Color color,
}) {
  final cx = right - w / 2;
  // Origin sits below the arcs; the dot is drawn at it.
  final originY = centerY + w * 0.30;
  final stroke = w * 0.135;
  for (var i = 0; i < 3; i++) {
    final radius = w * (0.20 + 0.20 * i);
    _fillArc(im, cx, originY, radius, stroke, color);
  }
  _fillCircleAA(im, cx, originY - w * 0.02, stroke * 0.70, color);
}

/// Outline, full white fill and terminal nub — "full" battery.
void _drawBattery(
  img.Image im, {
  required double right,
  required double centerY,
  required double w,
  required double h,
  required img.Color color,
}) {
  final left = right - w;
  final top = centerY - h / 2;
  final stroke = h * 0.12;
  final radius = h * 0.32;

  // Shell: draw the outer rounded rect then knock out the interior.
  _fillRoundRect(im, left, top, w, h, radius, color);
  _fillRoundRect(
    im,
    left + stroke,
    top + stroke,
    w - stroke * 2,
    h - stroke * 2,
    radius - stroke * 0.6,
    img.ColorRgba8(0, 0, 0, 0),
    replace: true,
  );

  // Full charge: the interior fill, inset by one more hairline.
  final pad = stroke * 1.6;
  _fillRoundRect(
    im,
    left + pad,
    top + pad,
    w - pad * 2,
    h - pad * 2,
    radius - pad * 0.6,
    color,
  );

  // Nub.
  final nubH = h * 0.34;
  _fillRoundRect(
    im,
    right + stroke * 0.6,
    centerY - nubH / 2,
    stroke * 1.5,
    nubH,
    stroke * 0.6,
    color,
  );
}

// ── Primitive fills (supersampled layer, so plain coverage tests suffice) ──

class _P {
  const _P(this.x, this.y);
  final double x;
  final double y;
}

void _setPx(img.Image im, int x, int y, img.Color c, {bool replace = false}) {
  if (x < 0 || y < 0 || x >= im.width || y >= im.height) return;
  if (replace) {
    im.setPixelRgba(x, y, c.r.toInt(), c.g.toInt(), c.b.toInt(), c.a.toInt());
  } else {
    im.setPixelRgba(x, y, c.r.toInt(), c.g.toInt(), c.b.toInt(), c.a.toInt());
  }
}

void _fillRoundRect(
  img.Image im,
  double x,
  double y,
  double w,
  double h,
  double r,
  img.Color color, {
  bool replace = false,
}) {
  final rr = math.max(0.0, math.min(r, math.min(w, h) / 2));
  final x0 = x.floor(), x1 = (x + w).ceil();
  final y0 = y.floor(), y1 = (y + h).ceil();
  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      final cx = px + 0.5, cy = py + 0.5;
      if (cx < x || cx > x + w || cy < y || cy > y + h) continue;
      // Corner test only inside the corner boxes.
      final dx = cx < x + rr ? x + rr - cx : (cx > x + w - rr ? cx - (x + w - rr) : 0.0);
      final dy = cy < y + rr ? y + rr - cy : (cy > y + h - rr ? cy - (y + h - rr) : 0.0);
      if (dx * dx + dy * dy > rr * rr) continue;
      _setPx(im, px, py, color, replace: replace);
    }
  }
}

void _fillEllipseRing(
  img.Image im,
  double cx,
  double cy,
  double rx,
  double ry,
  double stroke,
  img.Color color,
) {
  final irx = rx - stroke, iry = ry - stroke;
  final x0 = (cx - rx).floor(), x1 = (cx + rx).ceil();
  final y0 = (cy - ry).floor(), y1 = (cy + ry).ceil();
  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      final dx = px + 0.5 - cx, dy = py + 0.5 - cy;
      final outer = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry);
      if (outer > 1) continue;
      if (irx > 0 && iry > 0) {
        final inner = (dx * dx) / (irx * irx) + (dy * dy) / (iry * iry);
        if (inner < 1) continue;
      }
      _setPx(im, px, py, color);
    }
  }
}

void _fillCircleAA(
  img.Image im,
  double cx,
  double cy,
  double r,
  img.Color color,
) {
  final x0 = (cx - r).floor(), x1 = (cx + r).ceil();
  final y0 = (cy - r).floor(), y1 = (cy + r).ceil();
  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      final dx = px + 0.5 - cx, dy = py + 0.5 - cy;
      if (dx * dx + dy * dy <= r * r) _setPx(im, px, py, color);
    }
  }
}

/// Annular sector centred on straight-up, used for the Wi-Fi arcs.
void _fillArc(
  img.Image im,
  double cx,
  double cy,
  double radius,
  double stroke,
  img.Color color,
) {
  const spreadDeg = 45.0;
  final inner = radius - stroke / 2, outer = radius + stroke / 2;
  final x0 = (cx - outer).floor(), x1 = (cx + outer).ceil();
  final y0 = (cy - outer).floor(), y1 = (cy + outer).ceil();
  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      final dx = px + 0.5 - cx, dy = py + 0.5 - cy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < inner || d > outer) continue;
      // Angle from straight-up, in degrees.
      final ang = math.atan2(dx, -dy) * 180 / math.pi;
      if (ang.abs() > spreadDeg) continue;
      _setPx(im, px, py, color);
    }
  }
}

void _fillQuad(img.Image im, List<_P> pts, img.Color color) {
  var minX = pts.first.x, maxX = pts.first.x;
  var minY = pts.first.y, maxY = pts.first.y;
  for (final p in pts) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  for (var py = minY.floor(); py <= maxY.ceil(); py++) {
    for (var px = minX.floor(); px <= maxX.ceil(); px++) {
      if (_inPoly(pts, px + 0.5, py + 0.5)) _setPx(im, px, py, color);
    }
  }
}

bool _inPoly(List<_P> pts, double x, double y) {
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final xi = pts[i].x, yi = pts[i].y, xj = pts[j].x, yj = pts[j].y;
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}
