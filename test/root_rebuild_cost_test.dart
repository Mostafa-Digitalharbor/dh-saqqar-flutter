// The root of the app must not rebuild itself while the keyboard animates.
//
// `MaterialApp.router`'s `builder` in `app.dart` wraps everything the user
// ever sees — AppUpdateGate → AppLockGate → ShareIntentBootstrap → the
// keyboard-dismiss recognizer — and clamps the OS text scale on the way
// through. It used to do that with `MediaQuery.of(context)` + `copyWith`,
// which registers a dependency on EVERY MediaQuery field on the context that
// runs the builder — `viewInsets` included.
//
// `viewInsets` is the keyboard. So opening it re-ran the builder on every
// frame of the animation, re-creating all four gate widgets each time, at the
// very top of the tree. `MediaQuery.withClampedTextScaling` produces the same
// clamp but reads MediaQuery inside its own `Builder`, below where `child`
// was already built — so the same keyboard frame stops at that Builder.
//
// These tests pin both halves: the clamp still happens, and the subtree below
// it does not rebuild when a non-text-scale MediaQuery field changes. The
// second is the one that fails if anyone "tidies" the helper back into a
// manual `copyWith`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts its own builds. Stands in for the gate stack in `app.dart` — what
/// matters is only whether the element below the clamp was rebuilt.
class _RebuildCounter extends StatefulWidget {
  // Deliberately NOT const-constructed at the call sites below. A `const`
  // instance is canonicalized, so both shapes would hand the element the
  // identical widget object and both would skip the rebuild — the test would
  // pass while measuring nothing. The real gate stack in `app.dart` takes a
  // runtime `child`, so it is a fresh object on every builder run; this
  // mirrors that.
  // ignore: prefer_const_constructors_in_immutables
  _RebuildCounter();

  static int builds = 0;

  @override
  State<_RebuildCounter> createState() => _RebuildCounterState();
}

class _RebuildCounterState extends State<_RebuildCounter> {
  @override
  Widget build(BuildContext context) {
    _RebuildCounter.builds++;
    return const SizedBox.shrink();
  }
}

/// The shape `app.dart` ships: the subtree is constructed by the outer
/// builder and handed to the helper as an already-built `child`.
Widget _clampedRoot() => MaterialApp(
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.4,
        child: _RebuildCounter(),
      ),
      home: const SizedBox.shrink(),
    );

/// The shape it replaced, kept here as the control. Without it, "0 rebuilds"
/// is a number with nothing to compare against — this is what proves the test
/// can actually tell the two apart.
Widget _manualClampRoot() => MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler
                .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4),
          ),
          child: _RebuildCounter(),
        );
      },
      home: const SizedBox.shrink(),
    );

/// Raises the soft keyboard, one animation frame's worth.
Future<void> _openKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.resetViewInsets);
  await tester.pump();
}

void main() {
  setUp(() => _RebuildCounter.builds = 0);

  group('the keyboard does not rebuild the app root', () {
    testWidgets('a viewInsets change rebuilds nothing below the clamp',
        (tester) async {
      await tester.pumpWidget(_clampedRoot());
      final afterFirstFrame = _RebuildCounter.builds;

      await _openKeyboard(tester);

      expect(
        _RebuildCounter.builds,
        afterFirstFrame,
        reason: 'the gate stack under the clamp was rebuilt by a keyboard '
            'frame — the text-scale clamp is reading MediaQuery on the '
            "builder's own context again",
      );
    });

    testWidgets('the manual copyWith it replaced DOES rebuild — control',
        (tester) async {
      await tester.pumpWidget(_manualClampRoot());
      final afterFirstFrame = _RebuildCounter.builds;

      await _openKeyboard(tester);

      expect(
        _RebuildCounter.builds,
        greaterThan(afterFirstFrame),
        reason: 'if this stops rebuilding, the test above has stopped '
            'measuring anything and both shapes would pass',
      );
    });
  });

  group('the clamp itself still applies', () {
    Future<TextScaler> scalerUnder(WidgetTester tester, double osScale) async {
      late TextScaler seen;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(osScale)),
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.4,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('an accessibility 3x setting is capped at 1.4', (tester) async {
      // The reason the clamp exists: the chat bubble and tab bar have
      // fixed-height surfaces that an uncapped 3x tears apart.
      expect((await scalerUnder(tester, 3.0)).scale(10), 14.0);
    });

    testWidgets('a very small setting is lifted to 0.85', (tester) async {
      expect((await scalerUnder(tester, 0.5)).scale(10), 8.5);
    });

    testWidgets('a scale inside the range is left alone', (tester) async {
      expect((await scalerUnder(tester, 1.2)).scale(10), closeTo(12.0, 0.001));
    });
  });
}
