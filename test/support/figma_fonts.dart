// Loads the app's real typefaces into the test engine.
//
// `flutter test` ships with no fonts. Every family resolves to Ahem — the
// test font whose every glyph is a filled black box — so a screen rendered
// without this file comes out as rows of black rectangles where the text
// should be. That is not a rendering bug to debug; it is the documented
// default, and the only fix is to register the real files before the first
// pump.
//
// The icon fonts matter as much as the text ones. Lucide supplies nearly
// every glyph in the app and lives inside its package, so it loads through
// the `packages/<name>/` asset prefix rather than a local path.

import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Family name → the asset paths that make it up.
///
/// Weights are separate files for Tajawal and IBM Plex (four static faces
/// each) and a single variable file for Space Grotesk, exactly as
/// `pubspec.yaml` declares them —
/// `FontLoader` takes the same bytes either way and Flutter picks the axis.
const _families = <String, List<String>>{
  'SpaceGrotesk': ['assets/fonts/SpaceGrotesk-Variable.ttf'],
  'Tajawal': [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Medium.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
    'assets/fonts/Tajawal-ExtraBold.ttf',
  ],
  'IBMPlexSansArabic': [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ],
  'JetBrainsMono': [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Medium.ttf',
  ],
  // Icon fonts that live in a package register under their *qualified* name.
  //
  // `IconData` carries a `fontPackage`, and Flutter resolves that pair to the
  // family `packages/<package>/<family>` — not the bare family. Registering
  // these as plain 'Lucide' loads the file successfully and then never matches
  // a glyph, which is exactly as broken as not loading it, but silent: the
  // first run came back with every icon drawn as an empty square and no error
  // anywhere in the log.
  'packages/lucide_icons_flutter/Lucide': [
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  ],
  // The back chevron, which `AppTheme` pins app-wide via `actionIconTheme`.
  'packages/cupertino_icons/CupertinoIcons': [
    'packages/cupertino_icons/assets/CupertinoIcons.ttf',
  ],
  // Material's own glyphs ship inside the framework rather than a package, so
  // they carry no `fontPackage` and resolve by the bare family name.
  'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
};

/// Registers every family. Call once, from `setUpAll`.
///
/// Failures are swallowed per family: a missing optional icon font should cost
/// its glyphs, not the whole export. A missing *text* face is loud enough on
/// its own — the screenshots come out in boxes.
Future<void> loadAppFonts() async {
  for (final entry in _families.entries) {
    try {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    } on Object catch (error) {
      // ignore: avoid_print
      print('  ! font ${entry.key} did not load: $error');
    }
  }
}

/// Decodes every `Image` in the pumped tree.
///
/// `Image.asset` resolves its bytes asynchronously, and `testWidgets`'s fake
/// clock never runs the callback that completes the decode — so a first frame
/// paints the placeholder and every later frame paints it too. The screen is
/// not mid-load; it is stuck. The splash exported with an empty rounded plate
/// where the wordmark goes until this ran.
///
/// `precacheImage` populates the shared image cache, so the widgets pick the
/// bytes up on the next pump without being rebuilt.
Future<void> precacheImages(WidgetTester tester) async {
  final elements = find.byType(Image).evaluate().toList();
  if (elements.isEmpty) return;

  await tester.runAsync(() async {
    for (final element in elements) {
      final image = element.widget as Image;
      try {
        await precacheImage(image.image, element);
      } on Object {
        // A missing asset costs its own logo, not the export.
      }
    }
  });
  await tester.pump();
}

/// Renders whatever [tester] has pumped to a PNG.
///
/// Reads the pixels out of a `RepaintBoundary` the caller placed above the
/// app, which is the only way to get a real raster out of a widget test — and
/// it is a better source than a device screenshot for this job on two counts.
/// The app sets `FLAG_SECURE`, so Android's own `screencap` returns a black
/// frame; and this path needs no emulator, no signed-in account and no
/// network, so it reproduces exactly on any machine.
///
/// [pixelRatio] 2 matches a mid-range phone and keeps a 430 × 932 screen
/// around 200–400 KB — small enough to sit inside the JSON the plugin reads.
Future<Uint8List?> capturePng(
  WidgetTester tester,
  GlobalKey boundaryKey, {
  double pixelRatio = 2,
}) async {
  final object = boundaryKey.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;

  // Both calls hand work to the engine and return on a real callback, which
  // the fake clock in `testWidgets` never advances. Outside `runAsync` they
  // hang until the test times out.
  final bytes = await tester.runAsync<Uint8List?>(() async {
    final image = await object.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  return bytes;
}
