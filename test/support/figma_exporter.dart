// Walks a pumped screen's *render* tree and writes what it actually paints
// out as JSON, for the Figma plugin under `design/figma_plugin/` to rebuild.
//
// Why the render tree and not the widget tree: a widget says
// `Padding(padding: EdgeInsets.all(16))`, a RenderObject says "this box is at
// (16, 216) and is 398 × 72". Figma only understands the second one. Reading
// the layout back out of the same engine that draws it on the device is what
// makes the exported frame match the app rather than approximate it — every
// coordinate here survived the real constraint solve, at the real text scale,
// with the real font metrics.
//
// Scope: this captures *paint*, not semantics. A node is recorded only if it
// puts pixels on the screen — a fill, a border, a gradient, a shadow, text, or
// an image. The ~90 % of the tree that is `RenderPadding` / `RenderFlex` /
// `RenderConstrainedBox` exists to position those, and its positions are
// already baked into the coordinates below, so re-exporting it would give
// Figma hundreds of empty rectangles to no purpose.
//
// Emission order is depth-first, which is Flutter's own paint order, which is
// Figma's own child order — index 0 is furthest back in both. That is not a
// coincidence to rely on lightly, so it is asserted where it matters:
// `_walk` visits children through `visitChildren`, never a sorted copy.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Output location ──────────────────────────────────────────────────────

/// Where the JSON lands. Relative to the package root, which is `flutter
/// test`'s working directory.
const kExportDir = 'design/export';

/// Screenshots live in their own subfolder so the plugin's folder picker can
/// hand the JSON and the PNGs across in one selection while a human opening
/// `design/export/` still sees nine readable files rather than eighteen.
const _pngDir = 'png';

// ── Public API ───────────────────────────────────────────────────────────

/// One captured screen, ready to be handed to the plugin.
class ScreenCapture {
  ScreenCapture({
    required this.name,
    required this.width,
    required this.height,
    required this.locale,
    required this.brightness,
    required this.layers,
    required this.images,
    this.screenshot,
    this.screenshotScale = 1,
  });

  final String name;
  final double width;
  final double height;
  final String locale;
  final String brightness;
  final List<Map<String, Object?>> layers;

  /// `id` → base64 PNG. Kept beside the layers rather than inline so a logo
  /// reused on five screens is not five copies of the same bytes.
  final Map<String, String> images;

  /// The whole screen as Flutter actually rasterised it.
  ///
  /// This is the ground truth the reconstructed layers are checked against.
  /// Reconstruction can only carry what a `RenderObject` declares, so anything
  /// painted imperatively — a `CustomPainter`, a shader, a backdrop blur — is
  /// in this bitmap and nowhere else. The plugin lays it in as a locked
  /// backing layer so the editable layers always have the truth underneath
  /// them.
  final Uint8List? screenshot;

  /// Device pixels per logical pixel in [screenshot]. The bitmap is captured
  /// larger than the frame so it stays sharp, and the plugin scales it back
  /// down to the frame's logical size.
  final double screenshotScale;

  Map<String, Object?> toJson() => {
        'name': name,
        'width': width,
        'height': height,
        'locale': locale,
        'brightness': brightness,
        // A relative filename, not the bytes. A 2× PNG of a phone screen runs
        // to a few hundred KB, and base64 inside the same JSON as the layers
        // would triple every screen file and make them unreadable to anyone
        // debugging an export by eye.
        if (screenshot != null) 'screenshot': '$_pngDir/${_slug(name)}.png',
        'screenshotScale': screenshotScale,
        'layers': layers,
        'images': images,
      };
}

/// Captures whatever [tester] currently has pumped.
///
/// Call after the pump has settled enough to be representative — the harness's
/// `pumpOnce` already does the two pumps that let a first frame's animations
/// land.
Future<ScreenCapture> captureScreen(
  WidgetTester tester, {
  required String name,
  required String locale,
  required Brightness brightness,
  Uint8List? screenshot,
  double screenshotScale = 1,
}) async {
  final root = tester.firstRenderObject<RenderBox>(find.byType(MaterialApp));
  final size = root.size;

  final layers = <Map<String, Object?>>[];
  final images = <String, ui.Image>{};
  final bounds = Offset.zero & size;

  _walk(
    node: root,
    root: root,
    clip: bounds,
    opacity: 1,
    out: layers,
    images: images,
    depth: 0,
  );

  final encoded = await _encodeImages(tester, images);

  return ScreenCapture(
    name: name,
    width: size.width,
    height: size.height,
    locale: locale,
    brightness: brightness == Brightness.dark ? 'dark' : 'light',
    layers: layers,
    images: encoded,
    screenshot: screenshot,
    screenshotScale: screenshotScale,
  );
}

/// PNG-encodes the collected images, in real async time.
///
/// `toByteData` hands its work to the engine and comes back on a real
/// callback, and `testWidgets` runs inside a fake clock that never advances
/// for those — awaiting one directly hangs the test until the ten-minute
/// timeout kills it, with no error to explain why. `runAsync` is the escape
/// hatch that lets a genuinely asynchronous call complete.
///
/// The whole step is best-effort. Under `flutter test` an `Image.asset` often
/// has not finished decoding by the frame we capture, so `node.image` is null
/// and there is nothing here to encode; the layer still exports as a correctly
/// placed and sized box. A logo that has to be dropped into Figma by hand is a
/// far better outcome than an export that dies on it.
Future<Map<String, String>> _encodeImages(
  WidgetTester tester,
  Map<String, ui.Image> images,
) async {
  if (images.isEmpty) return const {};

  final encoded = <String, String>{};
  await tester.runAsync(() async {
    for (final entry in images.entries) {
      try {
        final data = await entry.value
            .toByteData(format: ui.ImageByteFormat.png)
            .timeout(const Duration(seconds: 5));
        if (data != null) {
          encoded[entry.key] = base64Encode(data.buffer.asUint8List());
        }
      } on Object {
        // Disposed, undecodable, or slower than the budget — skip it.
      }
    }
  });
  return encoded;
}

/// Writes every capture into `design/export/`, one file per screen, plus an
/// `index.json` the plugin reads to know what to build.
///
/// One file per screen rather than one big document: a single screen's layers
/// already run to a few thousand lines, and the plugin imports them one at a
/// time so a failure names the screen it failed on.
/// Synchronous throughout, and that is not a style choice. `File.writeAsString`
/// completes on the real event loop, which `testWidgets`'s fake clock never
/// advances — awaiting one here hangs the generator after every screen has
/// already been captured, and the only symptom is the ten-minute test timeout.
/// The `*Sync` variants return without involving the loop at all.
void writeCaptures(List<ScreenCapture> captures) {
  Directory(kExportDir).createSync(recursive: true);
  Directory('$kExportDir/$_pngDir').createSync(recursive: true);

  const encoder = JsonEncoder.withIndent('  ');
  final index = <Map<String, Object?>>[];

  for (final capture in captures) {
    final slug = _slug(capture.name);
    final file = '$slug.json';
    File('$kExportDir/$file').writeAsStringSync(
      encoder.convert(capture.toJson()),
    );

    final png = capture.screenshot;
    if (png != null) {
      File('$kExportDir/$_pngDir/$slug.png').writeAsBytesSync(png);
    }

    index.add({
      'name': capture.name,
      'file': file,
      if (png != null) 'screenshot': '$_pngDir/$slug.png',
      'width': capture.width,
      'height': capture.height,
      'locale': capture.locale,
      'brightness': capture.brightness,
      'layers': capture.layers.length,
    });
  }

  File('$kExportDir/index.json').writeAsStringSync(
    encoder.convert({'screens': index}),
  );
}

String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

// ── The walk ─────────────────────────────────────────────────────────────

/// Depth cap. A pathological tree (nested scrollables inside slivers inside
/// overlays) can run deep, and past this point nothing new is being drawn —
/// it is chrome for chrome. Guards against a cycle turning the export into a
/// hang, which a `visitChildren` bug would otherwise do silently.
const _kMaxDepth = 200;

void _walk({
  required RenderObject node,
  required RenderBox root,
  required Rect clip,
  required double opacity,
  required List<Map<String, Object?>> out,
  required Map<String, ui.Image> images,
  required int depth,
}) {
  if (depth > _kMaxDepth) return;

  var childOpacity = opacity;
  var childClip = clip;

  if (node is RenderBox && node.hasSize && node.attached) {
    final rect = _globalRect(node, root);

    if (rect != null) {
      // Fully outside what the viewport shows. A `ListView` keeps a screen's
      // worth of rows built above and below the visible window (its cache
      // extent), and those rows have real, correct, *offscreen* coordinates.
      // Exporting them would hand Figma a frame with rows stacked past its own
      // height — visually wrong in a way that looks like a layout bug rather
      // than an export bug.
      if (!rect.overlaps(clip)) return;

      if (node is RenderOpacity) {
        childOpacity = opacity * node.opacity;
      } else if (node is RenderAnimatedOpacity) {
        childOpacity = opacity * node.opacity.value;
      }

      // A clipping box narrows what its subtree can contribute.
      if (node is RenderClipRect ||
          node is RenderClipRRect ||
          node is RenderClipOval ||
          node is RenderClipPath) {
        childClip = clip.intersect(rect);
      }

      final layer = _describe(node, rect, childOpacity, images);
      if (layer != null) out.add(layer);
    }
  }

  node.visitChildren((child) {
    _walk(
      node: child,
      root: root,
      clip: childClip,
      opacity: childOpacity,
      out: out,
      images: images,
      depth: depth + 1,
    );
  });
}

/// The node's rect in root coordinates.
///
/// Returns null for anything the transform makes non-representable as an
/// axis-aligned box — a rotated or zero-scaled node. Those exist (the splash
/// wordmark scales up from 0.25), and a degenerate rect written out as
/// `w: 0, h: 0` would land in Figma as an invisible layer nobody can select
/// to delete.
Rect? _globalRect(RenderBox node, RenderBox root) {
  final Matrix4 transform;
  try {
    transform = node.getTransformTo(root);
  } on Object {
    // `getTransformTo` throws if the node is not in the same tree as root —
    // an overlay entry mid-teardown, for instance.
    return null;
  }
  if (transform.determinant() == 0) return null;

  final rect = MatrixUtils.transformRect(transform, Offset.zero & node.size);
  if (!rect.isFinite || rect.width <= 0.01 || rect.height <= 0.01) return null;
  return rect;
}

// ── Node → layer ─────────────────────────────────────────────────────────

/// Turns one painting RenderObject into a layer, or null if it paints nothing.
Map<String, Object?>? _describe(
  RenderBox node,
  Rect rect,
  double opacity,
  Map<String, ui.Image> images,
) {
  if (opacity <= 0.01) return null;

  final base = <String, Object?>{
    'name': _creatorName(node),
    'x': _round(rect.left),
    'y': _round(rect.top),
    'w': _round(rect.width),
    'h': _round(rect.height),
    if (opacity < 0.999) 'opacity': _round(opacity),
  };

  if (node is RenderParagraph) return _text(node, base);
  if (node is RenderImage) return _image(node, base, images);
  if (node is RenderDecoratedBox) return _decorated(node.decoration, base);
  if (node is RenderPhysicalModel) return _physical(node, base);
  if (node is RenderPhysicalShape) return _physicalShape(node, base);
  if (node is RenderCustomPaint) return _customPaint(node, base);

  final flat = _coloredBoxFill(node);
  if (flat != null) {
    return {...base, 'type': 'rect', 'fill': _hex(flat), 'radius': 0};
  }

  return null;
}

/// The flat fill behind `Container(color:)` and `ColoredBox`.
///
/// Worth its own branch because it is the single most common way the app puts
/// a colour on screen, and it does not go through `BoxDecoration` at all:
/// `Container` optimises a bare `color` into a `ColoredBox`, whose render
/// object is the private `_RenderColoredBox`. Without this, every plain
/// surface in the app — page backgrounds, list rows, sheet bodies — exported
/// as nothing, and the first run came back with 3 layers for the splash and 9
/// for the vault.
///
/// Matched by type name and read through `dynamic` because the class cannot be
/// named from outside `package:flutter`. The name check comes first so the
/// `dynamic` call — and the `NoSuchMethodError` it would throw on every other
/// node in the tree — happens only for the one type that answers it.
Color? _coloredBoxFill(RenderBox node) {
  if (node.runtimeType.toString() != '_RenderColoredBox') return null;
  try {
    final dynamic candidate = node;
    // ignore: avoid_dynamic_calls
    final value = candidate.color;
    return value is Color && value.a > 0 ? value : null;
  } on Object {
    return null;
  }
}

/// A marker for anything drawn straight onto the canvas.
///
/// A `CustomPainter` has no declarative shape to read — it is imperative draw
/// calls — so there is genuinely nothing to translate. Emitting a named,
/// correctly-placed marker instead of dropping it silently is the difference
/// between a designer seeing "the waveform goes here, draw it" and seeing an
/// unexplained gap in a frame that is otherwise exact.
Map<String, Object?>? _customPaint(
  RenderCustomPaint node,
  Map<String, Object?> base,
) {
  final painter = node.painter ?? node.foregroundPainter;
  if (painter == null) return null;

  final name = painter.runtimeType.toString();
  // Framework-internal painters — scrollbars, focus rings, Material ink — are
  // chrome the design file does not want a placeholder for.
  if (name.startsWith('_')) return null;

  return {...base, 'type': 'custom', 'painter': name};
}

/// The widget class that created this RenderObject — `SaqqarCard`, `ChipStrip`,
/// `Container`. Debug-only data, which is fine: `flutter test` runs in debug,
/// and this file never ships in a release build.
///
/// Layer names are the one thing a designer reads before anything else, and
/// "Rectangle 47" is what makes a generated Figma file unusable. Falling back
/// to the RenderObject type still beats that.
String _creatorName(RenderObject node) {
  final creator = node.debugCreator;
  if (creator is DebugCreator) {
    return creator.element.widget.runtimeType.toString();
  }
  return node.runtimeType.toString().replaceFirst('Render', '');
}

// ── Text ─────────────────────────────────────────────────────────────────

Map<String, Object?> _text(RenderParagraph node, Map<String, Object?> base) {
  final span = node.text;
  final style = span.style;
  final plain = span.toPlainText(includeSemanticsLabels: false);

  return {
    ...base,
    'type': 'text',
    'text': plain,
    'lines': _lines(node, plain, base),
    'align': node.textAlign.name,
    'dir': node.textDirection.name,
    if (node.maxLines != null) 'maxLines': node.maxLines,
    'font': {
      'family': style?.fontFamily ?? 'SpaceGrotesk',
      'fallback': style?.fontFamilyFallback ?? const <String>[],
      'size': _round(style?.fontSize ?? 14),
      'weight': _weight(style?.fontWeight),
      'italic': style?.fontStyle == FontStyle.italic,
      'letterSpacing': _round(style?.letterSpacing ?? 0),
      // Flutter's `height` is a multiple of font size; Figma wants pixels.
      // Null means "use the font's own metrics", which Figma spells AUTO.
      'lineHeight': style?.height == null
          ? null
          : _round(style!.height! * (style.fontSize ?? 14)),
      'color': _hex(style?.color, style?.decorationColor),
      if (style?.decoration == TextDecoration.underline) 'underline': true,
      if (style?.decoration == TextDecoration.lineThrough) 'strike': true,
    },
  };
}

/// Where each wrapped line actually sits, and what is on it.
///
/// Consumers that re-flow the text themselves — Figma's own text engine —
/// ignore this and use the box. SVG cannot: `<text>` does not wrap, so a
/// two-line label exported as one string runs straight off the side of the
/// frame. The line metrics come from the same shaper that drew the screen, so
/// the breaks are the ones the user sees rather than a guess at where a word
/// would fit.
///
/// `baseline` is the distance from the paragraph's top down to that line's
/// alphabetic baseline, which is exactly what SVG's `y` means.
/// Longest string worth walking character by character.
///
/// The walk is one `getOffsetForCaret` per character, and the app's text is
/// labels, titles and one-line previews — nothing near this. A chat message
/// pasted from a log could be, and re-shaping it 4,000 times to learn where
/// it wrapped is not worth the milliseconds; past the cap the consumer falls
/// back to the paragraph box, which is still correctly placed.
const _kMaxLineWalk = 400;

List<Map<String, Object?>> _lines(
  RenderParagraph node,
  String plain,
  Map<String, Object?> base,
) {
  if (plain.isEmpty || plain.length > _kMaxLineWalk) return const [];

  final lines = <Map<String, Object?>>[];
  var lineText = StringBuffer();
  double? lineTop;
  double? lineLeft;

  void flush(double? nextTop, double? nextLeft) {
    final text = lineText.toString();
    if (lineTop != null && text.trim().isNotEmpty) {
      lines.add({
        'text': text,
        'x': _round(lineLeft ?? 0),
        'top': _round(lineTop!),
      });
    }
    lineText = StringBuffer();
    lineTop = nextTop;
    lineLeft = nextLeft;
  }

  try {
    for (var i = 0; i < plain.length; i++) {
      if (plain[i] == '\n') {
        flush(null, null);
        continue;
      }

      final caret = node.getOffsetForCaret(TextPosition(offset: i), Rect.zero);

      // A new line starts wherever the caret drops. Half a pixel of tolerance
      // because sub-pixel baselines differ within a line on some faces.
      if (lineTop == null || (caret.dy - lineTop!).abs() > 0.5) {
        flush(caret.dy, caret.dx);
      }
      lineText.write(plain[i]);
    }
    flush(null, null);
  } on Object {
    // Shaping can throw on a tree torn down mid-walk. A partial answer is
    // still better than none — the caller falls back to the box for the rest.
    return lines;
  }

  return lines;
}

/// Flutter's `FontWeight` index maps to the CSS/Figma 100–900 scale.
int _weight(FontWeight? weight) {
  if (weight == null) return 400;
  return (FontWeight.values.indexOf(weight) + 1) * 100;
}

// ── Images ───────────────────────────────────────────────────────────────

Map<String, Object?>? _image(
  RenderImage node,
  Map<String, Object?> base,
  Map<String, ui.Image> images,
) {
  final image = node.image;
  if (image == null) return null;

  // Content-addressed enough: two RenderImages showing the same decoded
  // `ui.Image` share an identity hash, so the logo is encoded once.
  final id = 'img_${identityHashCode(image)}';
  images[id] = image;

  return {
    ...base,
    'type': 'image',
    'image': id,
    'fit': (node.fit ?? BoxFit.scaleDown).name,
    if (node.color != null) 'tint': _hex(node.color),
  };
}

// ── Boxes ────────────────────────────────────────────────────────────────

Map<String, Object?>? _decorated(
  Decoration decoration,
  Map<String, Object?> base,
) {
  if (decoration is BoxDecoration) return _boxDecoration(decoration, base);
  if (decoration is ShapeDecoration) return _shapeDecoration(decoration, base);
  return null;
}

Map<String, Object?>? _boxDecoration(
  BoxDecoration d,
  Map<String, Object?> base,
) {
  final fill = _hex(d.color);
  final gradient = _gradient(d.gradient);
  final shadows = _shadows(d.boxShadow);
  final stroke = _border(d.border);

  // Nothing painted: a `Container` used purely to carry a size or a child.
  if (fill == null && gradient == null && shadows.isEmpty && stroke == null) {
    return null;
  }

  return {
    ...base,
    'type': 'rect',
    if (fill != null) 'fill': fill,
    if (gradient != null) 'gradient': gradient,
    if (shadows.isNotEmpty) 'shadows': shadows,
    if (stroke != null) 'stroke': stroke,
    'radius': d.shape == BoxShape.circle
        ? 'circle'
        : _radius(d.borderRadius, base),
  };
}

Map<String, Object?>? _shapeDecoration(
  ShapeDecoration d,
  Map<String, Object?> base,
) {
  final fill = _hex(d.color);
  final gradient = _gradient(d.gradient);
  final shadows = _shadows(d.shadows);
  if (fill == null && gradient == null && shadows.isEmpty) return null;

  final shape = d.shape;
  Object? radius = 0;
  Map<String, Object?>? stroke;

  if (shape is RoundedRectangleBorder) {
    radius = _radius(shape.borderRadius, base);
    stroke = _side(shape.side);
  } else if (shape is StadiumBorder) {
    radius = 'circle';
    stroke = _side(shape.side);
  } else if (shape is CircleBorder) {
    radius = 'circle';
    stroke = _side(shape.side);
  }

  return {
    ...base,
    'type': 'rect',
    if (fill != null) 'fill': fill,
    if (gradient != null) 'gradient': gradient,
    if (shadows.isNotEmpty) 'shadows': shadows,
    if (stroke != null) 'stroke': stroke,
    'radius': radius,
  };
}

Map<String, Object?>? _physical(
  RenderPhysicalModel node,
  Map<String, Object?> base,
) {
  final fill = _hex(node.color);
  if (fill == null) return null;
  return {
    ...base,
    'type': 'rect',
    'fill': fill,
    'radius': node.shape == BoxShape.circle
        ? 'circle'
        : _radius(node.borderRadius, base),
    if (node.elevation > 0)
      'shadows': [_elevationShadow(node.elevation, node.shadowColor)],
  };
}

Map<String, Object?>? _physicalShape(
  RenderPhysicalShape node,
  Map<String, Object?> base,
) {
  final fill = _hex(node.color);
  if (fill == null) return null;
  return {
    ...base,
    'type': 'rect',
    'fill': fill,
    // The clipper's radius is not readable through a public API; Material's
    // own shapes are the common case and they are rectangles.
    'radius': 0,
    if (node.elevation > 0)
      'shadows': [_elevationShadow(node.elevation, node.shadowColor)],
  };
}

/// Material's elevation is a curve over three separate shadows; one
/// approximation is closer than dropping it, and this is the same shape
/// `kElevationToShadow` uses at the low end.
Map<String, Object?> _elevationShadow(double elevation, Color color) => {
      'color': _hex(color.withValues(alpha: color.a * 0.28)),
      'dx': 0,
      'dy': _round(elevation),
      'blur': _round(elevation * 2.5),
      'spread': 0,
    };

// ── Decoration parts ─────────────────────────────────────────────────────

/// Corner radii as `[topLeft, topRight, bottomRight, bottomLeft]`.
///
/// The app's pill radius is 999, which is larger than the box — Figma clamps
/// that per-corner, so it is clamped here too, to half the *shorter* side,
/// which is what "fully round" means for a non-square box.
Object _radius(BorderRadiusGeometry? geometry, Map<String, Object?> base) {
  if (geometry == null) return 0;
  final r = geometry.resolve(TextDirection.ltr);
  final w = (base['w'] as num).toDouble();
  final h = (base['h'] as num).toDouble();
  final cap = (w < h ? w : h) / 2;

  double clamp(double v) => v < 0 ? 0 : (v > cap ? cap : v);

  return [
    _round(clamp(r.topLeft.x)),
    _round(clamp(r.topRight.x)),
    _round(clamp(r.bottomRight.x)),
    _round(clamp(r.bottomLeft.x)),
  ];
}

/// Borders, uniform or not.
///
/// Not-uniform is the interesting case and it is not rare: the app draws
/// single-side hairlines (a section divider, the composer's top rule) as a
/// `Border(top: BorderSide(...))`. Collapsing that to a uniform stroke would
/// box in surfaces that are meant to be open on three sides.
Map<String, Object?>? _border(BoxBorder? border) {
  if (border == null) return null;

  final BorderSide top, right, bottom, left;
  if (border is Border) {
    top = border.top;
    right = border.right;
    bottom = border.bottom;
    left = border.left;
  } else if (border is BorderDirectional) {
    top = border.top;
    right = border.end;
    bottom = border.bottom;
    left = border.start;
  } else {
    return null;
  }

  final sides = [top, right, bottom, left];
  if (sides.every((s) => s.style == BorderStyle.none || s.width == 0)) {
    return null;
  }

  final uniform = sides.every(
    (s) => s.color == top.color && s.width == top.width && s.style == top.style,
  );

  if (uniform) return _side(top);

  return {
    'color': _hex(sides.firstWhere((s) => s.width > 0).color),
    'top': _round(top.style == BorderStyle.none ? 0 : top.width),
    'right': _round(right.style == BorderStyle.none ? 0 : right.width),
    'bottom': _round(bottom.style == BorderStyle.none ? 0 : bottom.width),
    'left': _round(left.style == BorderStyle.none ? 0 : left.width),
  };
}

Map<String, Object?>? _side(BorderSide side) {
  if (side.style == BorderStyle.none || side.width == 0) return null;
  return {'color': _hex(side.color), 'width': _round(side.width)};
}

/// Linear gradients, in the 0–1 space Figma's gradient transform wants.
///
/// Flutter's `Alignment` runs -1…1 with the origin at the box centre; Figma's
/// handles run 0…1 from the top-left. Radial and sweep gradients are recorded
/// with their stops but flagged, because their geometry does not survive the
/// same two-point mapping and the plugin renders them as a linear
/// approximation rather than silently placing them wrong.
Map<String, Object?>? _gradient(Gradient? gradient) {
  if (gradient == null) return null;

  List<String?> colors(List<Color> c) => c.map(_hex).toList();
  List<double> stops(Gradient g, int count) {
    final s = g.stops;
    if (s != null && s.length == count) return s.map(_round).toList();
    if (count == 1) return [0];
    return List.generate(count, (i) => _round(i / (count - 1)));
  }

  double u(double v) => _round((v + 1) / 2);

  if (gradient is LinearGradient) {
    final begin = gradient.begin.resolve(TextDirection.ltr);
    final end = gradient.end.resolve(TextDirection.ltr);
    return {
      'kind': 'linear',
      'from': [u(begin.x), u(begin.y)],
      'to': [u(end.x), u(end.y)],
      'colors': colors(gradient.colors),
      'stops': stops(gradient, gradient.colors.length),
    };
  }

  if (gradient is RadialGradient) {
    final c = gradient.center.resolve(TextDirection.ltr);
    return {
      'kind': 'radial',
      'center': [u(c.x), u(c.y)],
      'radius': _round(gradient.radius),
      'colors': colors(gradient.colors),
      'stops': stops(gradient, gradient.colors.length),
    };
  }

  if (gradient is SweepGradient) {
    return {
      'kind': 'sweep',
      'colors': colors(gradient.colors),
      'stops': stops(gradient, gradient.colors.length),
    };
  }

  return null;
}

List<Map<String, Object?>> _shadows(List<BoxShadow>? shadows) {
  if (shadows == null) return const [];
  return [
    for (final s in shadows)
      if (s.color.a > 0)
        {
          'color': _hex(s.color),
          'dx': _round(s.offset.dx),
          'dy': _round(s.offset.dy),
          // Flutter's `blurRadius` is a Gaussian sigma × 2; Figma's shadow
          // radius is the same "how far it spreads" quantity, so this is a
          // straight copy rather than a sigma conversion.
          'blur': _round(s.blurRadius),
          'spread': _round(s.spreadRadius),
          if (s.blurStyle != BlurStyle.normal) 'inner': true,
        },
  ];
}

// ── Primitives ───────────────────────────────────────────────────────────

/// `#RRGGBBAA`, alpha always written so the plugin never has to guess.
String? _hex(Color? color, [Color? fallback]) {
  final c = color ?? fallback;
  if (c == null) return null;
  final argb = c.toARGB32();
  final rgb = (argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
  final a = ((argb >> 24) & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#$rgb$a'.toUpperCase();
}

/// Two decimals. Sub-pixel precision is real — a 1.5 px hairline and a
/// centred 0.5 px offset both matter — but the 14 digits a raw double prints
/// are layout noise that triples the file size.
double _round(num v) => (v * 100).roundToDouble() / 100;
