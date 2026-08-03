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
