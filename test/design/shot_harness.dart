import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';

/// Directory screenshots are written to (set `SHOT_DIR`).
String get shotDir =>
    Platform.environment['SHOT_DIR'] ?? 'build/shots';

bool _fontsLoaded = false;

Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load('HankenGrotesk', ['assets/fonts/HankenGrotesk-Variable.ttf']);
  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
  ]);
  await load('packages/lucide_icons_flutter/Lucide',
      ['packages/lucide_icons_flutter/assets/lucide.ttf']);
  _fontsLoaded = true;
}

/// Pumps [screen] in the app theme at 375×812 and writes `<name>.png`.
Future<void> shot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size size = const Size(375, 812),
  bool dark = false,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester)? after,
}) async {
  // Screenshots are an opt-in dev tool: set SHOT_DIR to render them.
  if (Platform.environment['SHOT_DIR'] == null) return;
  await loadFonts();
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
  tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(locale),
        darkTheme: AppTheme.dark(locale),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        supportedLocales: AppStrings.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(Scaffold).first);
    for (final a in const [
      'assets/design/bg_light.png',
      'assets/design/orb.png',
      'assets/design/avatar.png',
      'assets/design/empty_mailbox.png',
      'assets/design/empty_piggy.png',
      'assets/design/process_plane.png',
      'assets/design/success_check.png',
      'assets/design/social_apple.png',
      'assets/design/social_google.png',
    ]) {
      await precacheImage(AssetImage(a), ctx);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
  if (after != null) await after(tester);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$shotDir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
}

class Override {
  const Override();
}
