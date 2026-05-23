// Writes a fully-transparent PNG used as the Android 12+ splash icon.
// Android 12 forces an icon onto the splash; we don't want one (the
// in-app `LaunchSplashScreen` owns the zoom animation), so we feed it
// a transparent image plus a matching navy `icon_background_color` and
// the result is "navy backdrop, nothing visible until Flutter boots".
//
// Run: `dart run tool/generate_blank_splash_icon.dart`

import 'dart:io';

import 'package:image/image.dart' as img;

const _size = 480; // adaptive-icon recommended size

void main() {
  final dir = Directory('assets/img');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final blank = img.Image(
    width: _size,
    height: _size,
    numChannels: 4,
    backgroundColor: img.ColorRgba8(0, 0, 0, 0),
  );

  final out = File('${dir.path}/saqqar-splash-blank.png');
  out.writeAsBytesSync(img.encodePng(blank));

  stdout.writeln('✓ wrote ${out.path} (${_size}x$_size, transparent)');
  stdout.writeln('');
  stdout.writeln('Next: dart run flutter_native_splash:create');
}
