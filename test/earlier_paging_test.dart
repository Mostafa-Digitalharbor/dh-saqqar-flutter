// Pins the scroll-up paging policy that replaced the "Load earlier messages"
// button.
//
// The button was self-limiting: nothing happened unless the user tapped it.
// Automatic paging removes that safety, and the two ways it can go wrong are
// both invisible in a screenshot — it either loops (re-requesting the same
// page on every frame of a drag) or it silently never fires and the user hits
// the top of the transcript with no button left to press. Every case below is
// one of those, written down.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/earlier_paging.dart';

/// Healthy steady state: user is scrolling up in a settled chat that still
/// has buffered rows. Each test overrides only what it is about.
EarlierPageAction decide({
  bool automatic = true,
  bool alreadyLoading = false,
  bool scrollRestored = true,
  bool lastAttemptFailed = false,
  int shownCount = 10,
  int loadedCount = 40,
  bool hasMoreOlder = true,
}) =>
    decideEarlierPage(
      automatic: automatic,
      alreadyLoading: alreadyLoading,
      scrollRestored: scrollRestored,
      lastAttemptFailed: lastAttemptFailed,
      shownCount: shownCount,
      loadedCount: loadedCount,
      hasMoreOlder: hasMoreOlder,
    );

void main() {
  _flingDeadEndTests();
  _overscrollNudgeTests();

  group('cheapest path first', () {
    test('reveals buffered rows without touching the network', () {
      // The cubit loads 40 messages up front but the lane renders 10, so the
      // first few pages must be instant and offline. Going to the server here
      // would put a spinner in front of data already in memory.
      expect(decide(shownCount: 10, loadedCount: 40),
          EarlierPageAction.revealBuffered);
    });

    test('fetches once rendering has caught up with what is loaded', () {
      expect(decide(shownCount: 40, loadedCount: 40),
          EarlierPageAction.fetchOlder);
    });
  });

  group('termination — the infinite-loop cases', () {
    test('stops at the start of the conversation', () {
      // Everything loaded is drawn and the server has nothing older. The user
      // is parked at the top, so the scroll handler keeps calling in on every
      // frame; anything but `none` here is a request loop.
      expect(
        decide(shownCount: 40, loadedCount: 40, hasMoreOlder: false),
        EarlierPageAction.none,
      );
    });

    test('stays quiet while a load is already in flight', () {
      // A single upward flick produces scroll notifications on every frame.
      // Without this, one gesture queues dozens of overlapping loads.
      expect(decide(alreadyLoading: true), EarlierPageAction.none);
      expect(
        decide(alreadyLoading: true, shownCount: 40, loadedCount: 40),
        EarlierPageAction.none,
      );
    });

    test('a manual tap is also ignored mid-load', () {
      // Double-tapping retry must not run two fetches.
      expect(
        decide(automatic: false, alreadyLoading: true),
        EarlierPageAction.none,
      );
    });
  });

  group('chat open must not page in history nobody asked for', () {
    test('holds until the one-shot scroll restore has run', () {
      // A freshly-built list sits at offset 0 until the restore jumps it to
      // the latest message — indistinguishable from "scrolled to the top".
      expect(decide(scrollRestored: false), EarlierPageAction.none);
    });

    test('a manual tap still works before the restore', () {
      // The guard exists to filter a transient the user didn't cause. An
      // explicit tap is not that.
      expect(
        decide(automatic: false, scrollRestored: false),
        EarlierPageAction.revealBuffered,
      );
    });
  });

  group('failure latch', () {
    test('auto-loading stands down after a failure', () {
      // Otherwise a chat that is offline or hitting a 500 re-requests on
      // every scroll frame for as long as the user sits near the top.
      expect(decide(lastAttemptFailed: true), EarlierPageAction.none);
    });

    test('the retry tap is exempt — it is the way back in', () {
      expect(
        decide(automatic: false, lastAttemptFailed: true),
        EarlierPageAction.revealBuffered,
      );
      expect(
        decide(
          automatic: false,
          lastAttemptFailed: true,
          shownCount: 40,
          loadedCount: 40,
        ),
        EarlierPageAction.fetchOlder,
      );
    });
  });

  group('degenerate inputs', () {
    test('an empty transcript asks for nothing', () {
      expect(
        decide(shownCount: 0, loadedCount: 0, hasMoreOlder: false),
        EarlierPageAction.none,
      );
    });

    test('an empty window over a server that has more still fetches', () {
      // Cold open where the snapshot came back empty but the server reports
      // older history — the user must not be stranded on a blank lane.
      expect(
        decide(shownCount: 0, loadedCount: 0),
        EarlierPageAction.fetchOlder,
      );
    });

    test('a window wider than what is loaded does not count as buffered', () {
      // `shownCount` is clamped to `loadedCount` by the caller, but if that
      // ever drifts the answer must fall through to the server rather than
      // reveal rows that do not exist.
      expect(
        decide(shownCount: 50, loadedCount: 40),
        EarlierPageAction.fetchOlder,
      );
    });
  });

  group('the retry pill is an error state and nothing else', () {
    // The product requirement, stated directly: the user should never be told
    // "Load earlier messages" while the app is perfectly capable of loading
    // them. Showing it whenever history existed meant every long chat wore
    // that label at the top of the lane forever, and it reads as the
    // transcript having stopped — the exact opposite of the reassurance it was
    // meant to give.
    test('hidden while paging is healthy, however much history remains', () {
      expect(
        showEarlierRetry(
          isNewChat: false,
          hasRenderedMessages: true,
          lastAttemptFailed: false,
        ),
        isFalse,
      );
    });

    test('shown once a page has failed — the one case the user can act on',
        () {
      expect(
        showEarlierRetry(
          isNewChat: false,
          hasRenderedMessages: true,
          lastAttemptFailed: true,
        ),
        isTrue,
      );
    });

    test('never on an empty lane, where it would be the only thing on screen',
        () {
      expect(
        showEarlierRetry(
          isNewChat: false,
          hasRenderedMessages: false,
          lastAttemptFailed: true,
        ),
        isFalse,
      );
    });

    test('never in a brand-new chat, which has no history to fail at', () {
      expect(
        showEarlierRetry(
          isNewChat: true,
          hasRenderedMessages: true,
          lastAttemptFailed: true,
        ),
        isFalse,
      );
    });
  });
}

// ── The fast-fling dead end ──────────────────────────────────────────────
//
// Reported by the user: flinging quickly to the top of a long chat parks you
// against the edge with older messages still unloaded, and the only way
// forward is to scroll down and back up. Two mechanisms combine to produce it.
//
//   1. The fling outruns the fetch, so by the time the page lands the user is
//      already at `extentBefore == 0` and the row the correction wanted to
//      re-anchor against has been culled by the lazy list. No correction is
//      applied and the list does not move — which is what "it froze" looks
//      like from the outside.
//   2. Resting against the edge produces no scroll events, so the latched load
//      trigger is never re-armed by position.
//
// `prependGrowthTarget` covers (1) with metrics that are always available, and
// `topEdgeNudgeTarget` covers (2) by easing off the edge — which also emits
// the notification that re-arms the trigger.

void _flingDeadEndTests() {
  // A `prependGrowthTarget` was tested here — a fallback correction derived
  // from the growth in `maxScrollExtent`. Its unit tests all passed, because
  // they asserted the arithmetic the author intended rather than the premise
  // it rested on.
  //
  // The premise was false. `ListView.builder` ESTIMATES its extent from the
  // children built so far and revises that estimate in both directions, so
  // "growth" is not "content inserted above". Captured on a real device across
  // one burst of fast flings:
  //
  //   3617 → 7251 → 5494 → 9404 → 19802 → 12332 → 12125 → 26240 → 28428
  //        → 19293 → 37380 → 29506 → 181096
  //
  // The last step produced a correction of 152,048 px and threw the reader to
  // the end of the conversation. Both function and tests are gone; the nudge
  // below covers the case, bounded by construction.
  //
  // Worth keeping as a note rather than deleting silently: the lesson is that
  // a green unit test says nothing about whether the quantity you are reading
  // means what you think it means.

  group('topEdgeNudgeTarget — leaving the dead edge', () {
    const slack = 8.0;
    const fraction = 0.6;
    const viewport = 800.0;

    double? nudge({
      required double pixels,
      required double extentBefore,
      double maxScrollExtent = 5000,
      double viewportDimension = viewport,
      bool hasMoreToReveal = true,
    }) =>
        topEdgeNudgeTarget(
          pixels: pixels,
          extentBefore: extentBefore,
          maxScrollExtent: maxScrollExtent,
          viewportDimension: viewportDimension,
          hasMoreToReveal: hasMoreToReveal,
          slack: slack,
          bumpFraction: fraction,
        );

    test('pinned at the edge with more to read → eases down a few messages',
        () {
      // 0.6 of an 800 px viewport — a handful of messages, not a page.
      expect(nudge(pixels: 0, extentBefore: 0), 480);
    });

    test('a few pixels off the edge still counts as pinned', () {
      // Overscroll settle and sub-pixel rounding both leave a hair of offset;
      // treating that as "not pinned" would skip the nudge on most devices.
      expect(nudge(pixels: 4, extentBefore: 4), 484);
    });

    test('comfortably off the edge → left alone', () {
      // The correction landed. Moving the list here would yank a reader who
      // is not stuck at all.
      expect(nudge(pixels: 900, extentBefore: 900), isNull);
    });

    test('the true start of the conversation → left alone', () {
      // The one case where nudging is actively wrong: it would shove the user
      // away from the first message, to uncover nothing.
      expect(
        nudge(pixels: 0, extentBefore: 0, hasMoreToReveal: false),
        isNull,
      );
    });

    group('it must never dump the reader at the end of the chat', () {
      // Reported by the user against the first version, which clamped to
      // `maxScrollExtent`: "sometimes it takes me all the way down to the end
      // of the chat, and that's not acceptable." Whenever the rendered
      // transcript was shorter than the bump — routine, since a page reveals a
      // bounded number of rows — the clamp resolved to the very bottom and
      // threw the reader out of the history they were in.

      test('a lane no taller than the viewport → left alone', () {
        // Nothing scrolls, so there is no dead edge to leave.
        expect(
          nudge(pixels: 0, extentBefore: 0, maxScrollExtent: 800),
          isNull,
        );
        expect(
          nudge(pixels: 0, extentBefore: 0, maxScrollExtent: 0),
          isNull,
        );
      });

      test('a lane barely taller than the viewport bumps only that much', () {
        // 900 px of content in an 800 px viewport leaves exactly 100 px of
        // travel, and the nudge takes all of it — which still leaves a full
        // screen below, so it is not the end of the chat.
        //
        // (This assertion originally expected `null`. That was the author
        // guessing rather than reading: a small bump here is both safe and
        // useful, since it leaves the edge and emits the notification that
        // re-arms the load trigger.)
        expect(
          nudge(pixels: 0, extentBefore: 0, maxScrollExtent: 900),
          100,
        );
      });

      test('a short-but-scrollable lane stops a screenful above the end', () {
        // 1200 px of content: the bump would reach 480, but the ceiling is
        // 1200 − 800 = 400, so it stops there and a full screen of transcript
        // remains below.
        expect(
          nudge(pixels: 0, extentBefore: 0, maxScrollExtent: 1200),
          400,
        );
      });

      test('the landing point always leaves a full screen below it', () {
        // The invariant, swept rather than spot-checked — this is the property
        // the bug violated, and it has to hold for every lane length.
        for (final maxExtent in const [900.0, 1200.0, 1600.0, 3000.0, 9000.0]) {
          final target = nudge(
            pixels: 0,
            extentBefore: 0,
            maxScrollExtent: maxExtent,
          );
          if (target == null) continue;
          expect(
            maxExtent - target,
            greaterThanOrEqualTo(viewport),
            reason: 'a $maxExtent px lane landed at $target, leaving less than '
                'a screen below — that reads as being thrown to the newest '
                'message',
          );
        }
      });
    });

    test('the bump scales with the screen', () {
      // A fraction, not a pixel constant: the same gesture should feel the
      // same on a small phone and a tablet.
      expect(nudge(pixels: 0, extentBefore: 0, viewportDimension: 400), 240);
      expect(nudge(pixels: 0, extentBefore: 0, viewportDimension: 1000), 600);
    });
  });
}

// Overscroll is the normal resting state after a fling that reaches the top —
// measured at −2, −49, −62, −72 and −77 px on a real device — so the nudge has
// to be defined there, not just at exactly 0.
void _overscrollNudgeTests() {
  group('topEdgeNudgeTarget — measured from the edge, not from the bounce', () {
    double? nudge(double pixels) => topEdgeNudgeTarget(
          pixels: pixels,
          // `extentBefore` is clamped at 0 by the framework even while
          // `pixels` is negative, which is exactly how the pinned state is
          // recognised.
          extentBefore: 0,
          maxScrollExtent: 20000,
          viewportDimension: 300,
          hasMoreToReveal: true,
          slack: 8,
          bumpFraction: 0.6,
        );

    test('an identical gesture travels the same distance every time', () {
      // The bug this prevents is not a crash — it is that the same flick lands
      // somewhere slightly different on every attempt, which is what makes a
      // scroll feel unreliable. All of these are the same gesture; only the
      // bounce sample differs.
      for (final overscroll in const [-2.0, -49.0, -62.0, -72.0, -77.0]) {
        expect(
          nudge(overscroll),
          180,
          reason: 'a bounce sampled at $overscroll px must not change where '
              'the nudge lands',
        );
      }
    });

    test('resting exactly at the edge lands in the same place', () {
      expect(nudge(0), 180);
    });
  });
}
