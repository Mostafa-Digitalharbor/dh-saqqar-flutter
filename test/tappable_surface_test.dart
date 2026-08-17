// `TappableSurface` exists to make one invariant structural: the ink clip and
// the splash shape are the SAME radius.
//
// Before it, that pairing was held by 38 call sites each remembering to type
// the same token twice — once on the `Material` that clips the ink, once on
// the `InkWell` that shapes the splash. When the two disagree the ripple
// paints past the corner it should be clipped to, and it does so only while a
// finger is down: no screenshot shows it, no static check sees it, and a
// reviewer reading the diff sees two plausible radius tokens.
//
// So the widget's contract is worth a test of its own rather than relying on
// the screens that use it. Those prove it renders; this proves it renders the
// thing that was hard to get right.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/theme/app_radius.dart';
import 'package:saqqar_app/shared/widgets/tappable_surface.dart';

void main() {
  /// The `Material` and `InkWell` that `TappableSurface` builds — not the ones
  /// `MaterialApp` puts above them.
  (Material, InkWell) partsOf(WidgetTester tester) => (
        tester.widget<Material>(
          find
              .descendant(
                of: find.byType(TappableSurface),
                matching: find.byType(Material),
              )
              .first,
        ),
        tester.widget<InkWell>(find.byType(InkWell)),
      );

  Future<void> pump(WidgetTester tester, Widget surface) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: surface)));
  }

  testWidgets('the clip radius and the splash radius are the same object',
      (tester) async {
    await pump(
      tester,
      TappableSurface(
        radius: AppRadius.cardR,
        onTap: () {},
        child: const SizedBox(width: 40, height: 40),
      ),
    );

    final (material, ink) = partsOf(tester);
    expect(material.borderRadius, AppRadius.cardR);
    expect(ink.borderRadius, AppRadius.cardR);
    expect(
      material.borderRadius,
      ink.borderRadius,
      reason: 'The ink clip and the splash disagree — the ripple would paint '
          'outside the rounded corner.',
    );
  });

  testWidgets('the default radius is applied to both halves too',
      (tester) async {
    // The default is the path most call sites take, so it needs the same
    // proof as the explicit one — a default wired to only one half would be
    // invisible in every test that passes a radius.
    await pump(
      tester,
      TappableSurface(
        onTap: () {},
        child: const SizedBox(width: 40, height: 40),
      ),
    );

    final (material, ink) = partsOf(tester);
    expect(material.borderRadius, AppRadius.buttonR);
    expect(ink.borderRadius, AppRadius.buttonR);
  });

  testWidgets('the Material is transparent so it never hides what is behind it',
      (tester) async {
    // The surfaces this wraps sit on gradients, glass cards and tinted
    // containers. An opaque Material would paint a grey rectangle over all of
    // them, which is the other half of why the incantation is what it is.
    await pump(
      tester,
      TappableSurface(
        onTap: () {},
        child: const SizedBox(width: 40, height: 40),
      ),
    );

    final (material, _) = partsOf(tester);
    expect(material.color, Colors.transparent);
  });

  testWidgets('it forwards taps', (tester) async {
    var taps = 0;
    await pump(
      tester,
      TappableSurface(
        onTap: () => taps++,
        child: const SizedBox(width: 40, height: 40),
      ),
    );

    await tester.tap(find.byType(TappableSurface));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a null onTap disables the ink response rather than swallowing it',
      (tester) async {
    // Disabled controls pass `null` instead of branching to a different
    // widget. `InkWell` renders no splash for a null callback, which is the
    // behaviour those call sites are relying on.
    await pump(
      tester,
      const TappableSurface(
        onTap: null,
        child: SizedBox(width: 40, height: 40),
      ),
    );

    final (_, ink) = partsOf(tester);
    expect(ink.onTap, isNull);
    // Tapping must not throw.
    await tester.tap(find.byType(TappableSurface));
    await tester.pump();
  });

  testWidgets('a long press is forwarded when one is given', (tester) async {
    var longPresses = 0;
    await pump(
      tester,
      TappableSurface(
        onTap: () {},
        onLongPress: () => longPresses++,
        child: const SizedBox(width: 40, height: 40),
      ),
    );

    await tester.longPress(find.byType(TappableSurface));
    await tester.pump();
    expect(longPresses, 1);
  });
}
