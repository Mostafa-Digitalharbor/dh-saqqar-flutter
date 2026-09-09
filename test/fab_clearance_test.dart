// A floating action button must never sit on top of the last row.
//
// Found on a Pixel 7 running the real app against production: scrolled to the
// very end of the Vault list, the final project card was under the "add
// project" pill, with its edit and delete buttons covered. Scrolling does not
// help — the list is already at its end — and those two buttons have no other
// entry point, so the last project on the account could not be renamed or
// deleted at all.
//
// `Scaffold` does not inset its body for a FAB; the scroll view has to reserve
// the room itself. `PageScaffold`'s own bottom padding is 28, and the pill is
// about 52 tall floating ~16 above the inset — so the shortfall was roughly
// 40 logical pixels on every screen that mounts one.
//
// No responsive sweep could have caught this: nothing overflows. The layout is
// valid; the paint order simply puts an opaque pill over a control. That is
// why this asserts geometry — where the last row ends versus where the FAB
// begins — rather than the absence of an exception.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/theme/app_sizes.dart';
import 'package:saqqar_app/shared/widgets/page_scaffold.dart';

import 'support/responsive_harness.dart';

/// A row tall enough to be recognisable in the geometry assertions, keyed so
/// the last one can be found.
Widget _row(int i) => SizedBox(
      key: ValueKey('row-$i'),
      height: 96,
      child: Center(child: Text('row $i')),
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpScaffold(
    WidgetTester tester, {
    required bool withFab,
    int rows = 12,
  }) async {
    await tester.pumpWidget(
      buildHarness(
        PageScaffold(
          title: 'Vault',
          floatingActionButton: withFab
              ? FloatingActionButton.extended(
                  onPressed: () {},
                  label: const Text('Add'),
                )
              : null,
          children: [for (var i = 0; i < rows; i++) _row(i)],
        ),
        locale: const Locale('en'),
        scale: 1,
        wrap: (app) => appChrome(app, prefs),
      ),
    );
    await tester.pump();
  }

  group('PageScaffold reserves room for its FAB', () {
    testWidgets('the last row clears the FAB on every supported viewport',
        (tester) async {
      for (final viewport in kViewports) {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpScaffold(tester, withFab: true);

        // Scroll to the very end — the only place the bug appears, because
        // anywhere else the row simply scrolls out from under the pill.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final lastRow = tester.getRect(find.byKey(const ValueKey('row-11')));
        final fab = tester.getRect(find.byType(FloatingActionButton));

        expect(
          lastRow.bottom,
          lessThanOrEqualTo(fab.top),
          reason: 'On ${viewport.name} the last row ends at ${lastRow.bottom} '
              'but the FAB starts at ${fab.top} — the row is underneath it, '
              'and the list is already scrolled to its end so the user has no '
              'way to uncover it.\n\n'
              'Fix: PageScaffold adds AppControlSizes.fabClearance to its '
              'bottom padding whenever a floatingActionButton is present. If '
              'the FAB grew, grow the token with it.',
        );
      }
    });

    testWidgets('a screen with no FAB is not given the extra padding',
        (tester) async {
      // The clearance is conditional on purpose: reserving 84 px under every
      // list in the app would leave a visible gap on the screens with no pill
      // to clear. Measured through `maxScrollExtent`, which is the scrollable
      // content height minus the viewport — so it moves by exactly the padding
      // that was added, whichever widget applies it.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<double> extentWith({required bool withFab}) async {
        await pumpScaffold(tester, withFab: withFab);
        return tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent;
      }

      final without = await extentWith(withFab: false);
      final withOne = await extentWith(withFab: true);

      expect(
        withOne - without,
        AppControlSizes.fabClearance,
        reason: 'The FAB clearance must be added only when a FAB is mounted, '
            'and must be exactly the token — not a second hand-tuned number.',
      );
    });
  });
}
