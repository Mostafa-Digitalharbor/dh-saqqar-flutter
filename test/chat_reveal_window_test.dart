// The chat lane renders a window over the loaded transcript, and that window
// grows as the user pages back. The rule is four numbers and three
// derivations, and it used to be spread across `_ChatScreenState` as three
// `static const`s, two mutable fields and two getters — with the slice
// arithmetic written out a third time at the render site, where nothing tied
// it to the other two.
//
// None of it was wrong. It just could not be read in one place, and it could
// not be exercised at all without pumping a chat screen against a fake cubit.
// `ChatRevealWindow` is the same policy as arithmetic, which is what these
// tests hold it to.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_reveal_window.dart';

List<int> _rows(int n) => [for (var i = 0; i < n; i++) i];

void main() {
  const opening = ChatRevealWindow.opening();

  group('a freshly opened chat', () {
    test('opens on a screenful of history, not a starting pistol', () {
      // The window opens WIDER than it steps. A chat that opened on ten rows
      // put the user at the top, already paging, before they had read
      // anything — on a transcript of mostly tool rows that is a screen and
      // a bit.
      expect(opening.limit, 50);
      expect(opening.revealCount, 0);
    });

    test('has revealed nothing yet', () {
      expect(opening.nextStep, ChatRevealWindow.initialStepRows);
    });
  });

  group('the step doubles as the user keeps going', () {
    test('50, 100, 200, 400 — the gesture is the signal', () {
      // Near the newest message the user is READING and a small step is
      // enough. Ten reveals deep they have stopped reading and started
      // looking for something, and a small step makes them do it fifty rows
      // at a time.
      var w = opening;
      final steps = <int>[];
      for (var i = 0; i < 4; i++) {
        steps.add(w.nextStep);
        w = w.revealedFrom(w.limit);
      }

      expect(steps, [50, 100, 200, 400]);
    });

    test('and then stops doubling', () {
      // Past the cap the timeline pass — which IS linear in the window —
      // costs more per reveal than the reveal saves.
      var w = opening;
      for (var i = 0; i < 12; i++) {
        w = w.revealedFrom(w.limit);
      }

      expect(w.nextStep, ChatRevealWindow.maxStepRows);
    });

    test('the cap holds however deep the user goes', () {
      var w = opening;
      for (var i = 0; i < 40; i++) {
        w = w.revealedFrom(w.limit);
        expect(w.nextStep, lessThanOrEqualTo(ChatRevealWindow.maxStepRows));
      }
    });
  });

  group('revealing grows from what is on screen', () {
    test('a full window grows by exactly the next step', () {
      final w = opening.revealedFrom(50);

      expect(w.limit, 100);
    });

    test('a window wider than the transcript does not compound', () {
      // The window opens at 50 over a chat that may hold three. Growing from
      // `limit` would jump to 53 and reveal nothing; growing from what is
      // actually shown reveals a real page.
      final shown = opening.shownOf(3);
      final w = opening.revealedFrom(shown);

      expect(shown, 3);
      expect(w.limit, 53);
    });

    test('shownOf never claims more rows than exist', () {
      expect(opening.shownOf(0), 0);
      expect(opening.shownOf(3), 3);
      expect(opening.shownOf(50), 50);
      expect(opening.shownOf(5000), 50);
    });
  });

  group('the rendered slice', () {
    test('is the MOST RECENT rows, not the first ones', () {
      // The lane reads newest-last. Taking from the front would show the
      // start of the conversation and call it "current".
      final all = _rows(120);

      expect(opening.slice(all).first, 70);
      expect(opening.slice(all).last, 119);
    });

    test('is the whole transcript when it fits', () {
      final all = _rows(12);

      expect(opening.slice(all), all);
    });

    test('handles the exact-fit boundary without dropping a row', () {
      final all = _rows(50);

      expect(opening.slice(all), hasLength(50));
      expect(opening.slice(all).first, 0);
    });

    test('an empty transcript slices to empty rather than throwing', () {
      expect(opening.slice(<int>[]), isEmpty);
    });

    test('widens exactly as far as the reveal says', () {
      final all = _rows(400);
      final w = opening.revealedFrom(50); // limit 100

      expect(w.slice(all), hasLength(100));
      expect(w.slice(all).first, 300);
    });
  });

  group('prefetch headroom', () {
    test('keeps the next reveal in hand, twice over', () {
      // At one reveal of headroom a user scrolling briskly drains the bank
      // faster than a single in-flight request refills it, and the lane
      // stops — the exact failure this margin exists to prevent.
      expect(opening.prefetchHeadroom, opening.nextStep * 2);
    });

    test('grows with the step, so a deep reader keeps the same cushion', () {
      var w = opening;
      for (var i = 0; i < 3; i++) {
        w = w.revealedFrom(w.limit);
      }

      expect(w.prefetchHeadroom, w.nextStep * 2);
      expect(w.prefetchHeadroom, greaterThan(opening.prefetchHeadroom));
    });

    test('asks for a page while there is still slack', () {
      // limit 50, headroom 100 → anything under 150 loaded should prefetch.
      expect(opening.needsPrefetch(149), isTrue);
      expect(opening.needsPrefetch(150), isFalse);
      expect(opening.needsPrefetch(1000), isFalse);
    });

    test('asks for a page when the window has caught up entirely', () {
      expect(opening.needsPrefetch(50), isTrue);
      expect(opening.needsPrefetch(0), isTrue);
    });
  });

  group('value semantics', () {
    test('two windows in the same state are equal', () {
      expect(opening.revealedFrom(50), opening.revealedFrom(50));
      expect(
        opening.revealedFrom(50).hashCode,
        opening.revealedFrom(50).hashCode,
      );
    });

    test('revealing returns a NEW window rather than mutating', () {
      // The screen assigns it inside `setState`; a mutating reveal would
      // change the value before the framework saw the old one.
      final grown = opening.revealedFrom(50);

      expect(opening.limit, 50);
      expect(grown.limit, 100);
      expect(grown, isNot(opening));
    });
  });
}
