// The door pair, and why it is the one glyph the app reflects rather than
// swaps.
//
// An earlier RTL pass assumed Lucide's `logIn` and `logOut` were horizontal
// mirrors of each other and swapped them for Arabic. They are not. Lucide
// draws `log-out` as a door on the LEFT with the arrow travelling right, out
// of it; and `log-in` as a door on the RIGHT with the arrow *also* travelling
// right, into it — same arrow direction, door on opposite sides. So the swap
// did not mirror anything, it changed the meaning, and the Arabic build
// shipped an ENTER arrow on its Sign out button. Found by rendering both on a
// device and putting the crops side by side.
//
// The fix is `matchTextDirection`, which makes Flutter's own `Icon` widget
// apply the horizontal transform under RTL. These tests pin the two halves of
// that: the flag is set, and the code points still name the glyphs they
// claim to (they are spelled as literals because `IconData` must stay
// `const`, and a const expression cannot read a field off another const).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:saqqar_app/core/theme/app_icons.dart';

void main() {
  group('the door pair reflects itself', () {
    test('both declare matchTextDirection', () {
      // Without this the glyph is drawn identically in both directions, and
      // the only remaining ways to mirror it are the swap that was wrong or a
      // `Transform` at every call site.
      expect(AppIcons.signOut.matchTextDirection, isTrue);
      expect(AppIcons.signIn.matchTextDirection, isTrue);
    });

    test('the literal code points still name the Lucide glyphs', () {
      expect(AppIcons.signOut.codePoint, LucideIcons.logOut.codePoint,
          reason: 'AppIcons.signOut has drifted from LucideIcons.logOut');
      expect(AppIcons.signIn.codePoint, LucideIcons.logIn.codePoint,
          reason: 'AppIcons.signIn has drifted from LucideIcons.logIn');
      for (final icon in [AppIcons.signOut, AppIcons.signIn]) {
        expect(icon.fontFamily, LucideIcons.logOut.fontFamily);
        expect(icon.fontPackage, LucideIcons.logOut.fontPackage);
      }
    });

    test('they are not each other, which is what the swap assumed', () {
      // If this ever fails, one of them has been redefined and the whole
      // reasoning above needs re-checking.
      expect(AppIcons.signOut.codePoint, isNot(AppIcons.signIn.codePoint));
    });

    testWidgets('Flutter actually flips it under RTL', (tester) async {
      // The flag is only useful if the framework honours it. `Icon` wraps the
      // glyph in a `Transform` when the direction is RTL and the flag is set,
      // so the presence of that transform is the observable behaviour.
      Future<Matrix4?> transformFor(TextDirection direction) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: const Icon(AppIcons.signOut),
          ),
        );
        final transforms = tester
            .widgetList<Transform>(
              find.descendant(
                of: find.byType(Icon),
                matching: find.byType(Transform),
              ),
            )
            .toList();
        return transforms.isEmpty ? null : transforms.first.transform;
      }

      expect(await transformFor(TextDirection.ltr), isNull,
          reason: 'English must draw the glyph as Lucide authored it');

      final rtl = await transformFor(TextDirection.rtl);
      expect(rtl, isNotNull, reason: 'Arabic must draw the mirror');
      // A horizontal reflection: x negated, y untouched.
      expect(rtl!.entry(0, 0), -1.0);
      expect(rtl.entry(1, 1), 1.0);
    });

    testWidgets('a plain chevron is left alone', (tester) async {
      // The chevrons and arrows keep the accessor approach — there the left
      // and right constants ARE genuine mirrors, and naming the direction
      // reads better than transforming a glyph. This guards against someone
      // "fixing" them the same way and getting a double flip.
      for (final icon in [AppIcons.chevronRight, AppIcons.arrowRight]) {
        expect(icon.matchTextDirection, isFalse);
      }
    });
  });
}
