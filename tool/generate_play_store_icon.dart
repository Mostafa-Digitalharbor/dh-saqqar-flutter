// Generates the 512×512 PNG that Google Play Store requires for the
// app listing's hero icon.
//
// Run: `dart run tool/generate_play_store_icon.dart`
//
// Writes to `play-store-assets/icon-512.png`.
//
// Source: `assets/img/saqqar-launcher.png` (1024×1024 — the same file
// `flutter_launcher_icons` uses to mint platform launcher icons). We
// downsample to 512 with `cubic` interpolation (sharper than `linear`
// for downscales) and **flatten any alpha onto white** so the PNG
// satisfies Play Store's "no transparent backgrounds" rule — Play
// silently rejects icons whose corner pixels are translucent.
//
// Re-run any time the launcher icon changes.

import 'dart:io';

import 'package:image/image.dart' as img;

const _target = 512;

void main() {
  const sourcePath = 'assets/img/saqqar-launcher.png';
  final source = File(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('✗ source missing: $sourcePath');
    stderr.writeln(
      '  Run `dart run tool/generate_launcher_icon.dart` first to mint it.',
    );
    exit(1);
  }
  final decoded = img.decodePng(source.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('✗ could not decode $sourcePath as PNG');
    exit(1);
  }

  // Downscale with cubic — softer than nearest, sharper than linear.
  // The 1024 → 512 step is a clean 2:1 so detail loss is minimal.
  final resized = img.copyResize(
    decoded,
    width: _target,
    height: _target,
    interpolation: img.Interpolation.cubic,
  );

  // Flatten alpha onto white. Play Store's listing icon spec forbids
  // any non-opaque pixels — even a single alpha=254 in a corner is
  // enough for Play Console to flag "Icon must not contain
  // transparency". Compositing against pure white keeps the launcher's
  // rounded white tile invisible (it already IS white) while killing
  // any sub-pixel alpha bleed.
  final flat = img.Image(
    width: _target,
    height: _target,
    numChannels: 3,
    backgroundColor: img.ColorRgb8(255, 255, 255),
  );
  img.compositeImage(
    flat,
    resized,
    dstX: 0,
    dstY: 0,
    blend: img.BlendMode.alpha,
  );

  final outDir = Directory('play-store-assets');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outPath = '${outDir.path}/icon-512.png';
  File(outPath).writeAsBytesSync(img.encodePng(flat));

  stdout.writeln('✓ wrote $outPath ($_target×$_target, no alpha)');
  stdout.writeln('');
  stdout.writeln('Upload to: Play Console → Store presence → Main store');
  stdout.writeln('listing → App icon');
}
