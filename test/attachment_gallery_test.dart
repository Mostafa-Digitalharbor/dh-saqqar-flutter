// Swiping between the pictures of a group in the fullscreen viewer.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/view/attachment_viewer_screen.dart';

/// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(const Locale('en')),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppStrings.supported,
  home: child,
);

void main() {
  late File file;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('gallery_test');
    file = File('${dir.path}/b.png')..writeAsBytesSync(_png);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  Widget viewer({int index = 1}) => _host(
    AttachmentViewerScreen(
      file: file,
      name: 'b.png',
      gallery: const [
        ViewerImage(name: 'a.png', url: 'https://example.invalid/a.png'),
        ViewerImage(name: 'b.png', url: 'https://example.invalid/b.png'),
        ViewerImage(name: 'c.png', url: 'https://example.invalid/c.png'),
      ],
      galleryIndex: index,
    ),
  );

  testWidgets('opens on the tapped picture and counts the group', (
    tester,
  ) async {
    await tester.pumpWidget(viewer());
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);
  });

  testWidgets('swiping turns the page and updates the name', (tester) async {
    await tester.pumpWidget(viewer());
    await tester.pump();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('c.png'), findsOneWidget);
  });

  testWidgets('a single picture shows 1 / 1 and still renders', (tester) async {
    await tester.pumpWidget(
      _host(AttachmentViewerScreen(file: file, name: 'b.png')),
    );
    await tester.pump();
    expect(find.text('1 / 1'), findsOneWidget);
  });
}
