import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/shared/animations/floating_bob.dart';

/// Guards a whole CLASS of bug rather than one instance: a widget that
/// animates forever while the screen is at rest.
///
/// Measured on a real device, an idle Account screen produced ~62 frames per
/// second with nobody touching it. The UI thread never slept, which costs
/// battery continuously and leaves less headroom for the work that actually
/// matters when the user does interact. The causes were all decorative or
/// advisory animations driven by `repeat()`:
///
///   * `MarqueeText` scrolling labels (see marquee_text_test.dart)
///   * `FloatingBob` on the empty-conversations hero — an empty list is a
///     RESTING state, so this ran for as long as the screen was open
///   * the composer's active-mode badge, which pulses while deep-think or
///     auto-approve is on — both sticky settings, not transient states
///
/// The rule this file encodes: **transient states may animate forever;
/// resting states may not.** A spinner during a request is fine. A decoration
/// on a screen the user can sit on indefinitely is not.
///
/// `pumpAndSettle` is the assertion — it throws when frames are still being
/// scheduled after its timeout, which is exactly the failure mode.
void main() {
  Widget harness(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  group('FloatingBob settles', () {
    testWidgets('stops after its cycles instead of bobbing forever',
        (tester) async {
      await tester.pumpWidget(
        harness(
          const FloatingBob(
            cycles: 2,
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );
      // Times out against the old unbounded `repeat()`.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('parks at the rest position, not mid-bob', (tester) async {
      await tester.pumpWidget(
        harness(
          const FloatingBob(
            cycles: 1,
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      // Settling mid-bob would leave the hero visibly offset from where a
      // static build puts it.
      final transforms = tester.widgetList<Transform>(find.byType(Transform));
      for (final t in transforms) {
        expect(t.transform.getTranslation().y, closeTo(0, 0.01));
      }
    });

    testWidgets('honours Reduce Motion by not animating at all',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: harness(
              const FloatingBob(child: SizedBox(width: 40, height: 40)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
