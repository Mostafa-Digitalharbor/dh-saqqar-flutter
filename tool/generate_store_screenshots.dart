// Prepares the raw device captures in `play-store-assets/assets/` for upload
// to the Google Play listing.
//
// Run: `dart run tool/generate_store_screenshots.dart`
//
// For each source it:
//   • strips the alpha channel → 24-bit RGB PNG (Play prefers screenshots
//     with no transparency; a stray alpha channel can trip validation),
//   • renames it to an ordered, human-readable name,
//   • sorts phone vs tablet into `play-store-assets/screenshots/{phone,tablet}/`.
//
// Dimensions are left untouched — the phone caps are 1080×2400 and the tablet
// caps 2560×1600, both inside Play's 320–3840 px-per-side limits.

import 'dart:io';

import 'package:image/image.dart' as img;

// Source filename → output basename (defines upload order via the number).
const _phone = <String, String>{
  'Screenshot_1783481354.png': 'phone-1-signin',
  'Screenshot_1783481648.png': 'phone-2-chats',
  'Screenshot_1783481794.png': 'phone-3-conversation',
  'Screenshot_1783481807.png': 'phone-4-projects',
};

const _tablet = <String, String>{
  'Screenshot_1783487147.png': 'tablet-1-signin',
  'Screenshot_1783487354.png': 'tablet-2-chats',
  'Screenshot_1783487319.png': 'tablet-3-conversation',
  'Screenshot_1783487219.png': 'tablet-4-projects',
};

void main() {
  const srcDir = 'play-store-assets/assets';
  _process(srcDir, _phone, 'play-store-assets/screenshots/phone');
  _process(srcDir, _tablet, 'play-store-assets/screenshots/tablet');
  stdout.writeln('');
  stdout.writeln('Upload to: Play Console → Store presence → Main store');
  stdout.writeln('listing → Phone / Tablet screenshots');
}

void _process(String srcDir, Map<String, String> map, String outDir) {
  Directory(outDir).createSync(recursive: true);
  map.forEach((srcName, outBase) {
    final srcFile = File('$srcDir/$srcName');
    if (!srcFile.existsSync()) {
      stderr.writeln('✗ missing: ${srcFile.path}');
      return;
    }
    final decoded = img.decodePng(srcFile.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('✗ could not decode: ${srcFile.path}');
      return;
    }
    // Copy into a 3-channel (no-alpha) image so the PNG encodes as 24-bit RGB.
    final flat = img.Image(width: decoded.width, height: decoded.height);
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        flat.setPixelRgb(x, y, p.r, p.g, p.b);
      }
    }
    final outPath = '$outDir/$outBase.png';
    File(outPath).writeAsBytesSync(img.encodePng(flat));
    stdout.writeln('✓ $outPath (${flat.width}x${flat.height}, no alpha)');
  });
}
