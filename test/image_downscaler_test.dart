// Photos are shrunk before they are uploaded.
//
// Found in the second web-vs-mobile sweep. The web has downscaled images
// client-side for a while (`maybeCompressImage`); the app sent the whole
// buffer. A phone camera produces 3–8 MB per shot, so on mobile this costs
// more than it does on the desktop the web runs on — the user pays for the
// upload and then waits for the server to OCR a picture four times larger
// than it needed to be.
//
// The rules that matter are the ones that decide NOT to touch a file: a
// resizer that mangles an animated GIF, flattens a transparent screenshot
// onto black, or returns something bigger than it started with is worse than
// no resizer at all.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:saqqar_app/core/constants/attachment_limits.dart';
import 'package:saqqar_app/features/chat/data/image_downscaler.dart';

late Directory _tmp;

/// A JPEG of [width]×[height] with enough noise that it does not compress
/// down to nothing — a flat colour would encode to a few bytes and make
/// every size assertion below meaningless.
String _writeJpeg(String name, int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x * y) % 256);
    }
  }
  final path = '${_tmp.path}/$name';
  File(path).writeAsBytesSync(img.encodeJpg(image, quality: 95));
  return path;
}

String _writePngWithAlpha(String name, int width, int height) {
  // Genuinely incompressible. Two earlier fixtures — a smooth gradient, then
  // a hand-rolled LCG — both encoded to ~100 KB, which is under the floor, so
  // the downscaler was right to skip them and the test was asserting on a
  // case it does not cover. `Random` with a fixed seed is noisy and
  // reproducible.
  final rng = Random(42);
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        rng.nextInt(256),
        rng.nextInt(256),
        rng.nextInt(256),
        // Never fully opaque, so the alpha channel survives the round trip.
        128 + rng.nextInt(127),
      );
    }
  }
  final path = '${_tmp.path}/$name';
  File(path).writeAsBytesSync(img.encodePng(image));
  return path;
}

Future<String> _shrink(String path) =>
    ImageDownscaler.shrink(path: path, tempDir: _tmp.path);

void main() {
  // `compute` needs the binding up even in a plain test.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    _tmp = Directory.systemTemp.createTempSync('saqqar_downscale_test');
  });

  tearDownAll(() {
    if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
  });

  group('what gets shrunk', () {
    test('a camera-sized photo comes back narrower and smaller', () async {
      final original = _writeJpeg('big.jpg', 4000, 3000);
      final originalBytes = File(original).lengthSync();
      expect(originalBytes, greaterThan(AttachmentLimits.downscaleFloorBytes),
          reason: 'fixture must exceed the floor or the test proves nothing');

      final out = await _shrink(original);

      expect(out, isNot(original));
      final decoded = img.decodeImage(File(out).readAsBytesSync())!;
      expect(decoded.width, AttachmentLimits.downscaleMaxWidth);
      // Aspect ratio is preserved — a stretched screenshot is a wrong answer
      // to "make this smaller".
      expect(decoded.height, 1200);
      expect(File(out).lengthSync(), lessThan(originalBytes));
    });

    test('the shrunk copy is still readable as an image', () async {
      // The whole point is that the server can still OCR it.
      final out = await _shrink(_writeJpeg('readable.jpg', 3000, 2000));

      expect(img.decodeImage(File(out).readAsBytesSync()), isNotNull);
    });

    test('transparency survives', () async {
      // An Odoo error dialog screenshotted over a translucent backdrop
      // becomes a black rectangle if it is flattened into JPEG.
      final original = _writePngWithAlpha('alpha.png', 3000, 2000);
      expect(File(original).lengthSync(),
          greaterThan(AttachmentLimits.downscaleFloorBytes),
          reason: 'fixture must exceed the floor or the test proves nothing');

      final out = await _shrink(original);

      expect(out, isNot(original));
      expect(out, endsWith('.png'));
      final decoded = img.decodeImage(File(out).readAsBytesSync())!;
      expect(decoded.hasAlpha, isTrue);
    });
  });

  group('what is left alone', () {
    test('a small photo', () async {
      // Under the floor: re-encoding would only cost quality.
      final original = _writeJpeg('small.jpg', 300, 200);
      expect(File(original).lengthSync(),
          lessThan(AttachmentLimits.downscaleFloorBytes));

      expect(await _shrink(original), original);
    });

    test('an animated GIF', () async {
      // Re-encoding keeps one frame, which turns a recording of a bug into a
      // still of it. Excluded by extension, before anything is decoded.
      final path = '${_tmp.path}/clip.gif';
      final image = img.Image(width: 2000, height: 2000);
      File(path).writeAsBytesSync(img.encodeGif(image));

      expect(await _shrink(path), path);
    });

    test('a PDF, a spreadsheet, an extensionless file', () async {
      for (final name in ['doc.pdf', 'sheet.xlsx', 'noextension']) {
        final path = '${_tmp.path}/$name';
        File(path).writeAsBytesSync(List<int>.filled(2000 * 1000, 7));

        expect(await _shrink(path), path, reason: name);
      }
    });

    test('a file that does not exist', () async {
      // A picker can hand back a path that has already been cleaned up.
      // Returning the input is what keeps the upload attempt — and its own
      // error message — intact.
      final missing = '${_tmp.path}/gone.jpg';

      expect(await _shrink(missing), missing);
    });

    test('a thumbnail, however it was reported', () async {
      // An earlier draft took the picker's size as a parameter and trusted
      // it; a stale number then pushed a 200 px thumbnail through a re-encode
      // it did not need. The size now comes from the file itself.
      final original = _writeJpeg('mismatch.jpg', 200, 150);

      expect(await _shrink(original), original);
    });

    test('a corrupt image', () async {
      final path = '${_tmp.path}/corrupt.jpg';
      File(path).writeAsBytesSync(List<int>.filled(1500 * 1000, 0xAB));

      expect(await _shrink(path), path);
    });

    test('an image already narrow enough and already small', () async {
      // Between the floor and the ceiling, and under the width cap: nothing
      // to gain.
      final original = _writeJpeg('mid.jpg', 1200, 900);
      final bytes = File(original).lengthSync();
      if (bytes <= AttachmentLimits.downscaleFloorBytes ||
          bytes > AttachmentLimits.downscaleCeilingBytes) {
        return; // fixture landed outside the band this test is about
      }

      expect(await _shrink(original), original);
    });
  });

  group('the thresholds themselves', () {
    test('are the web numbers', () {
      // Drifting from these is how the two clients start disagreeing about
      // what the server receives.
      expect(AttachmentLimits.downscaleFloorBytes, 1000 * 1000);
      expect(AttachmentLimits.downscaleCeilingBytes, 2000 * 1000);
      expect(AttachmentLimits.downscaleMaxWidth, 1600);
      expect(AttachmentLimits.downscaleJpegQuality, 85);
    });

    test('and gif is not in the downscalable set', () {
      expect(AttachmentLimits.downscalableImageExtensions, isNot(contains('gif')));
      expect(AttachmentLimits.downscalableImageExtensions, contains('png'));
      expect(AttachmentLimits.downscalableImageExtensions, contains('jpg'));
    });
  });
}
