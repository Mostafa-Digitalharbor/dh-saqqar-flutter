import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_source_sheet.dart';

/// Pumps a button that opens the sheet, and records what the sheet returned.
/// The sheet is a `showModalBottomSheet` result, so the only way to observe
/// its contract is through the future the opener awaits.
Future<AttachmentPickerSource?> _openAndTap(
  WidgetTester tester, {
  required Locale locale,
  required TargetPlatform platform,
  String? tapLabel,
}) async {
  AttachmentPickerSource? picked;
  var returned = false;

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(locale).copyWith(platform: platform),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                picked = await AttachmentPickerSourceSheet.show(context);
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  if (tapLabel != null) {
    await tester.tap(find.text(tapLabel));
    await tester.pumpAndSettle();
    expect(returned, isTrue, reason: 'sheet should have popped');
  }

  return picked;
}

void main() {
  group('AttachmentPickerSourceSheet', () {
    testWidgets('offers photos, camera and files on a phone', (tester) async {
      await _openAndTap(
        tester,
        locale: const Locale('en'),
        platform: TargetPlatform.iOS,
      );

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
    });

    testWidgets('each row returns its own source', (tester) async {
      for (final (label, expected) in const [
        ('Photos', AttachmentPickerSource.photos),
        ('Camera', AttachmentPickerSource.camera),
        ('Files', AttachmentPickerSource.files),
      ]) {
        final picked = await _openAndTap(
          tester,
          locale: const Locale('en'),
          platform: TargetPlatform.android,
          tapLabel: label,
        );
        expect(picked, expected, reason: '"$label" row');
      }
    });

    testWidgets('hides camera where there is none', (tester) async {
      // Desktop builds ship the same composer; `image_picker` has no camera
      // implementation there, so the row must not be reachable at all.
      await _openAndTap(
        tester,
        locale: const Locale('en'),
        platform: TargetPlatform.windows,
      );

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Camera'), findsNothing);
    });

    testWidgets('renders Arabic labels under the ar locale', (tester) async {
      await _openAndTap(
        tester,
        locale: const Locale('ar'),
        platform: TargetPlatform.android,
      );

      expect(find.text('الصور'), findsOneWidget);
      expect(find.text('الكاميرا'), findsOneWidget);
      expect(find.text('الملفات'), findsOneWidget);
    });
  });
}
