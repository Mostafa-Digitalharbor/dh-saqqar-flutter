import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/shared/widgets/marquee_text.dart';

/// Guards the fix for a measured battery bug: two `MarqueeText`s on the
/// Account screen kept the app rendering ~62 frames per second while the user
/// sat there touching nothing. `repeat()` never ends, so the UI thread never
/// idled for as long as that screen was open.
///
/// `pumpAndSettle` is the assertion that matters here — it throws if the tree
/// is still scheduling frames after its timeout, which is precisely the old
/// behaviour. A marquee that settles passes; one that loops forever fails.
void main() {
  Widget harness(Widget child, {double width = 100}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      );

  group('MarqueeText settles instead of animating forever', () {
    testWidgets('an overflowing label stops after its cycles', (tester) async {
      await tester.pumpWidget(
        harness(
          const MarqueeText(
            text: 'a very long label that cannot possibly fit in this slot',
            maxCycles: 2,
          ),
        ),
      );
      // Would time out against the old `repeat()` implementation.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('alwaysScroll on short text also settles', (tester) async {
      // The Account hero opts into `alwaysScroll` for text that already fits;
      // that path must terminate too, since it was the actual source of the
      // 62fps idle burn.
      await tester.pumpWidget(
        harness(
          const MarqueeText(text: 'short', alwaysScroll: true, maxCycles: 2),
          width: 400,
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('text that fits renders a plain Text and never animates',
        (tester) async {
      await tester.pumpWidget(
        harness(const MarqueeText(text: 'hi'), width: 400),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Static fallback keeps a single copy; the marquee draws two.
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('a parent rebuild after settling does NOT restart it',
        (tester) async {
      // The first version of this fix passed every other test here and still
      // measured ~62fps on a real device. Reason: the "already running?" guard
      // checked `controller.isAnimating`, which is false once settled — so the
      // next parent rebuild started a fresh run, forever. `ProfileHero` watches
      // AuthCubit and PlanCubit, so rebuilds are routine, not exotic.
      //
      // Pumping a rebuild after settling is what makes this test able to fail.
      var label = 'a very long label that cannot possibly fit in this slot';
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                child: StatefulBuilder(
                  builder: (context, setter) {
                    setState = setter;
                    return MarqueeText(text: label, maxCycles: 2);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Rebuild with unchanged text/geometry, exactly as a cubit tick would.
      setState(() {});
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'An unrelated rebuild restarted the marquee — that is how the '
            'perpetual animation came back while looking fixed.',
      );

      // A genuine content change SHOULD start a fresh run, though.
      setState(() => label = 'a completely different and also very long label');
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'New text must animate so the user can read it.',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('it parks at the start rather than mid-scroll', (tester) async {
      await tester.pumpWidget(
        harness(
          const MarqueeText(
            text: 'a very long label that cannot possibly fit in this slot',
            maxCycles: 1,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Two copies are laid out for the seamless loop; the first must be back
      // at the reading position, not frozen halfway through a pass.
      final first = tester
          .widgetList<Transform>(find.byType(Transform))
          .firstWhere((t) => t.transform.getTranslation().x != 0,
              orElse: () => Transform(
                    transform: Matrix4.identity(),
                    child: const SizedBox.shrink(),
                  ));
      expect(
        first.transform.getTranslation().x,
        0,
        reason: 'Settling mid-scroll would leave the label visually clipped.',
      );
    });
  });
}
