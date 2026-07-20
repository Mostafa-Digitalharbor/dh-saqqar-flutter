import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/shared/extensions/context_extensions.dart';

void main() {
  group('context.sharePositionOrigin', () {
    // iPad presents the system share sheet as a popover, and share_plus
    // rejects the call outright when the anchor rect is empty or outside the
    // source view — Share silently does nothing. iPhone and Android never
    // take that branch, so nothing but a test catches a regression here.

    testWidgets('anchors on the widget that triggered the share',
        (tester) async {
      late Rect origin;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => SizedBox(
                  width: 120,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => origin = context.sharePositionOrigin,
                    child: const Text('share'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('share'));
      await tester.pump();

      expect(origin.width, 120);
      expect(origin.height, 40);
      expect(origin.isEmpty, isFalse);
    });

    testWidgets('never yields an empty rect, even without a laid-out box',
        (tester) async {
      // An empty rect is precisely what share_plus refuses, so the fallback
      // has to produce a real one rather than deferring to null.
      late Rect origin;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              origin = context.sharePositionOrigin;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(origin.isEmpty, isFalse);
      expect(origin.width, greaterThan(0));
      expect(origin.height, greaterThan(0));
    });
  });
}
