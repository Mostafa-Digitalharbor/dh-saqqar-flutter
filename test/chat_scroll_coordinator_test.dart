// The chat transcript's scroll + paging state machine.
//
// None of this was reachable from a test before `ChatScrollCoordinator` was
// pulled out of `_ChatScreenState`: every one of these behaviours needed a
// live `ChatCubit`, a repository, a disk cache and a 1.5 s poll timer to
// exercise, so the six interacting latches below were held in place by their
// comments and by whoever last scrolled a long chat on a real phone.
//
// The two bugs that shipped in here are both pinned as named cases:
//
//   * a lane too short to scroll could not auto-load, so it stayed short, so
//     it never auto-loaded — a live 1,282-message conversation rendered ONE
//     bubble and would not page back ("a lane that cannot scroll");
//   * auto-loading that had stood down after a failure could not be restarted
//     by scrolling, only by the retry pill ("a failed page").

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/features/chat/view_model/chat_reveal_window.dart';
import 'package:saqqar_app/features/chat/view_model/chat_scroll_coordinator.dart';

void main() {
  setUp(ChatScrollCoordinator.resetSavedOffsets);
  tearDown(ChatScrollCoordinator.resetSavedOffsets);

  group('paging decisions', () {
    test('a failed page latches, tells the screen, and reveals nothing',
        () async {
      // The window must NOT widen over rows that never arrived — that would
      // render blank space and read as data loss.
      final paging = _FakePaging(hasMoreOlder: true, failNext: true);
      var surfaced = 0;
      final lane = _coordinator(
        paging: paging,
        loaded: 50,
        onLoadFailure: () => surfaced++,
      );
      addTearDown(lane.dispose);

      await lane.loadEarlier();

      expect(paging.loadOlderCalls, 1);
      expect(lane.autoLoadEarlierFailed, isTrue);
      expect(surfaced, 1, reason: 'the user has to be told');
      expect(lane.window, const ChatRevealWindow.opening(),
          reason: 'nothing arrived, so nothing may be revealed');
    });

    test('a later automatic attempt stands down while the latch is set',
        () async {
      // Otherwise a chat that is offline re-requests a failing endpoint on
      // every scroll frame, forever.
      final paging = _FakePaging(hasMoreOlder: true, failNext: true);
      final lane = _coordinator(paging: paging, loaded: 50);
      addTearDown(lane.dispose);

      await lane.loadEarlier();
      await lane.loadEarlier(auto: true);

      expect(paging.loadOlderCalls, 1);
    });

    test('a deliberate retry is allowed through the latch, and clears it',
        () async {
      // A tap is the user saying "try again" — it must work even after
      // auto-loading has stood down.
      final paging = _FakePaging(hasMoreOlder: true, failNext: true);
      final lane = _coordinator(paging: paging, loaded: 50);
      addTearDown(lane.dispose);

      await lane.loadEarlier();
      expect(lane.autoLoadEarlierFailed, isTrue);

      paging.failNext = false;
      await lane.loadEarlier();

      expect(paging.loadOlderCalls, 2);
      expect(lane.autoLoadEarlierFailed, isFalse);
      expect(lane.window.limit, greaterThan(ChatRevealWindow.openingRows));
    });

    test('buffered rows are revealed without touching the network', () async {
      // The cheap tier: more is loaded than is shown, so the fix is arithmetic.
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 500);
      addTearDown(lane.dispose);

      await lane.loadEarlier();

      expect(paging.loadOlderCalls, 0);
      expect(lane.window.limit, 100, reason: '50 shown + a 50-row first step');
    });

    test('the start of a conversation is a stopping point, not a loop',
        () async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 50);
      addTearDown(lane.dispose);

      await lane.loadEarlier();

      expect(paging.loadOlderCalls, 0);
      expect(lane.window, const ChatRevealWindow.opening());
    });

    test('a new chat has no history and asks for none', () async {
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 50, isNewChat: true);
      addTearDown(lane.dispose);

      await lane.loadEarlier();
      lane.topUpPrefetch();

      expect(paging.loadOlderCalls, 0);
      expect(paging.prefetchCalls, 0);
    });

    test('overlapping calls collapse into one fetch', () async {
      // Scroll notifications arrive on essentially every frame of a drag.
      final paging = _FakePaging(hasMoreOlder: true, hold: true);
      final lane = _coordinator(paging: paging, loaded: 50);
      addTearDown(lane.dispose);

      final first = lane.loadEarlier();
      await lane.loadEarlier();
      await lane.loadEarlier();

      expect(paging.loadOlderCalls, 1);
      paging.release();
      await first;
    });

    test('prefetch stops at the start of the conversation', () {
      final exhausted = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: exhausted, loaded: 50);
      addTearDown(lane.dispose);

      lane.topUpPrefetch();

      expect(exhausted.prefetchCalls, 0);
    });

    test('prefetch asks once the bank runs low', () {
      // 50 shown of 60 loaded is 10 in hand against a 100-row headroom.
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 60);
      addTearDown(lane.dispose);

      lane.topUpPrefetch();

      expect(paging.prefetchCalls, 1);
    });

    test('prefetch stays quiet while the bank is deep', () {
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 5000);
      addTearDown(lane.dispose);

      lane.topUpPrefetch();

      expect(paging.prefetchCalls, 0);
    });
  });

  group('offsets', () {
    testWidgets('leaving at the newest message saves the sentinel, not a pixel',
        (tester) async {
      // Re-entering a chat you were reading live must land on what has
      // arrived since, not on the pixel the newest message used to occupy.
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);

      lane.persistOffset();
      lane.dispose();

      final restored = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, restored);
      restored.restoreIfNeeded();
      await tester.pump();

      expect(restored.controller.position.pixels, 0,
          reason: 'the sentinel means "wherever the newest message now is", '
              'which in a reversed lane is offset 0');
      restored.dispose();
    });

    testWidgets('a position in history comes back where it was',
        (tester) async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);

      lane.controller.jumpTo(600);
      await tester.pump();
      lane.persistOffset();
      lane.dispose();

      final restored = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, restored);
      restored.restoreIfNeeded();
      await tester.pump();

      expect(restored.controller.position.pixels, 600);
      restored.dispose();
    });

    testWidgets('a new chat neither saves nor restores', (tester) async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40, isNewChat: true);
      await _pumpLane(tester, lane);

      lane.controller.jumpTo(600);
      await tester.pump();
      lane.persistOffset();
      lane.restoreIfNeeded();

      expect(lane.hasRestoredScroll, isFalse);
      lane.dispose();
    });

    testWidgets('nothing saved lands on the NEWEST message, not the oldest',
        (tester) async {
      // In a reversed lane `maxScrollExtent` is the OLDEST loaded message.
      // The "nothing saved, so show them the latest" branch used to jump
      // there — correct for the forward list it was written against, exactly
      // backwards here. It was masked by the pin that runs immediately after,
      // but the jump still notified the scroll listener from `extentAfter ==
      // 0`, so every chat open fired an automatic page nobody asked for.
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);

      lane.restoreIfNeeded();
      await tester.pump();

      expect(lane.controller.position.pixels, 0,
          reason: 'offset 0 is the newest message in a reversed lane');
      expect(paging.loadOlderCalls, 0,
          reason: 'opening a chat must not pull a page of history');
      lane.dispose();
    });

    testWidgets('an offset survives the Scrollable being torn down first',
        (tester) async {
      // Flutter unmounts children before parents, so by the time the screen's
      // `dispose` runs the position is already detached and `hasClients` is
      // false. Reading it there — which is what this class used to do — saved
      // nothing, every time, and the whole feature silently did not exist.
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);
      lane.controller.jumpTo(450);
      await tester.pump();

      // Tear the lane out from under the coordinator, the way navigating away
      // does, and only then dispose it.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(lane.controller.hasClients, isFalse,
          reason: 'this is the state the real dispose path runs in');
      lane.dispose();

      final restored = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, restored);
      restored.restoreIfNeeded();
      await tester.pump();

      expect(restored.controller.position.pixels, 450);
      restored.dispose();
    });

    testWidgets('the reveal window comes back with the offset', (tester) async {
      // A pixel offset only means something against the list that produced
      // it. Re-opening rebuilds the lane at 50 rows, so an offset taken 200
      // rows deep used to clamp to the far end of the fresh window — not
      // where the user was, and the one position that immediately fires a
      // page. Measured on a live 2,917-message chat: left at 30 August, came
      // back on 9 September with a fetch already in flight.
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 500);
      await _pumpLane(tester, lane);

      await lane.loadEarlier();
      await lane.loadEarlier();
      final reached = lane.window;
      expect(reached.limit, greaterThan(ChatRevealWindow.openingRows));

      lane.controller.jumpTo(500);
      await tester.pump();
      lane.dispose();

      final reopened = _coordinator(paging: paging, loaded: 500);
      addTearDown(reopened.dispose);

      expect(reopened.window, reached,
          reason: 'the lane must be rebuilt the width it was left');
    });

    testWidgets('a conversation never opened starts at the opening window',
        (tester) async {
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 500);
      addTearDown(lane.dispose);
      await _pumpLane(tester, lane);

      expect(lane.window, const ChatRevealWindow.opening());
    });

    testWidgets('a new chat ignores a saved window entirely', (tester) async {
      // New chats share the sentinel id, so a leftover place from a previous
      // one must not decide how wide the next one opens.
      final paging = _FakePaging(hasMoreOlder: true);
      final seeded = _coordinator(paging: paging, loaded: 500);
      await _pumpLane(tester, seeded);
      await seeded.loadEarlier();
      seeded.dispose();

      final fresh =
          _coordinator(paging: paging, loaded: 500, isNewChat: true);
      addTearDown(fresh.dispose);

      expect(fresh.window, const ChatRevealWindow.opening());
    });

    testWidgets('the restore is a one-shot', (tester) async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);

      lane.restoreIfNeeded();
      await tester.pump();
      lane.controller.jumpTo(300);
      await tester.pump();
      // A poll tick rebuilds the screen; the restore must not re-jump and
      // yank the user out of what they were reading.
      lane.restoreIfNeeded();
      await tester.pump();

      expect(lane.controller.position.pixels, 300);
      lane.dispose();
    });
  });

  group('a lane that cannot scroll', () {
    testWidgets('still counts as restored, so it is allowed to page',
        (tester) async {
      // The circular guard: `loadEarlier(auto: true)` refuses to run until
      // the restore has happened, and the restore used to return early on a
      // lane with nothing to scroll. A short lane could not auto-load, so it
      // stayed short, so it never auto-loaded. Reproduced on a live
      // 1,282-message conversation whose most recent page was almost
      // entirely `tool` rows: ONE bubble on screen, and no way back.
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 1);
      await _pumpLane(tester, lane, rows: 1);

      lane.restoreIfNeeded();

      expect(lane.hasRestoredScroll, isTrue);

      lane.fillViewportIfNotScrollable();
      await tester.pump();

      expect(paging.loadOlderCalls, 1,
          reason: 'a lane with no scroll must still be able to ask for more');
      lane.dispose();
    });

    testWidgets('the fill is bounded, so an estimate stuck at zero terminates',
        (tester) async {
      // `maxScrollExtent` on a lazy list is an estimate. If it reads zero for
      // a frame after a page lands, an unbounded fill would ask forever.
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 1);
      await _pumpLane(tester, lane, rows: 1);
      lane.restoreIfNeeded();

      for (var i = 0; i < 20; i++) {
        lane.fillViewportIfNotScrollable();
        await tester.pump();
      }

      expect(paging.loadOlderCalls, lessThanOrEqualTo(6));
      lane.dispose();
    });

    testWidgets('a scrollable lane is left alone', (tester) async {
      final paging = _FakePaging(hasMoreOlder: true);
      final lane = _coordinator(paging: paging, loaded: 1);
      await _pumpLane(tester, lane);
      lane.restoreIfNeeded();

      lane.fillViewportIfNotScrollable();
      await tester.pump();

      expect(paging.loadOlderCalls, 0);
      lane.dispose();
    });
  });

  group('the jump-to-newest button', () {
    testWidgets('appears once the user is a screenful into history, once',
        (tester) async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      var notifications = 0;
      lane.addListener(() => notifications++);
      await _pumpLane(tester, lane);

      expect(lane.showScrollDown, isFalse);

      lane.controller.jumpTo(500);
      await tester.pump();
      expect(lane.showScrollDown, isTrue);

      final afterShow = notifications;
      lane.controller.jumpTo(600);
      await tester.pump();
      expect(notifications, afterShow,
          reason: 'still shown — a scroll frame must not repaint the screen');

      lane.controller.jumpTo(0);
      await tester.pump();
      expect(lane.showScrollDown, isFalse);
      lane.dispose();
    });
  });

  group('drag', () {
    testWidgets('a drag hands the lane to the user without a repaint',
        (tester) async {
      // A rebuild on the first frame of every drag would be a scroll-time
      // cost for no visual change — nothing in the tree is built from this.
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      var notifications = 0;
      lane.addListener(() => notifications++);
      await _pumpLane(tester, lane);

      lane.noteUserDrag();

      expect(lane.userHasScrolled, isTrue);
      expect(notifications, 0);
      lane.dispose();
    });

    testWidgets('the pin stops holding the lane once the user drags',
        (tester) async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);

      lane.controller.jumpTo(300);
      await tester.pump();
      lane.pinToNewestIfUnscrolled();
      await tester.pump();
      expect(lane.controller.position.pixels, 0,
          reason: 'an untouched lane follows the newest message');

      lane.noteUserDrag();
      lane.controller.jumpTo(300);
      await tester.pump();
      lane.pinToNewestIfUnscrolled();
      await tester.pump();
      expect(lane.controller.position.pixels, 300);
      lane.dispose();
    });
  });

  group('lifecycle', () {
    testWidgets('disposing saves the offset and releases the controller',
        (tester) async {
      final paging = _FakePaging(hasMoreOlder: false);
      final lane = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, lane);
      lane.controller.jumpTo(450);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      lane.dispose();

      final restored = _coordinator(paging: paging, loaded: 40);
      await _pumpLane(tester, restored);
      restored.restoreIfNeeded();
      await tester.pump();

      expect(restored.controller.position.pixels, 450,
          reason: 'dispose is the last chance to remember where they were');
      restored.dispose();
    });
  });
}

/// One coordinator over a fake paging source.
///
/// [loaded] is the count of loaded-but-maybe-unrevealed visible messages —
/// the number the real screen reads off its adapter memo.
ChatScrollCoordinator _coordinator({
  required _FakePaging paging,
  required int loaded,
  bool isNewChat = false,
  VoidCallback? onLoadFailure,
}) =>
    ChatScrollCoordinator(
      conversationId: 'conv-1',
      isNewChat: isNewChat,
      loadedVisibleCount: () => loaded,
      paging: () => paging,
      onLoadFailure: onLoadFailure ?? () {},
    );

/// Attaches [lane] to a real reversed `ListView`, so `extentBefore`,
/// `maxScrollExtent` and `hasContentDimensions` are the values a real
/// transcript would report rather than numbers a fake made up.
Future<void> _pumpLane(
  WidgetTester tester,
  ChatScrollCoordinator lane, {
  int rows = 40,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: lane.controller,
          reverse: true,
          itemCount: rows,
          itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The four members the coordinator needs, and a count of who asked.
class _FakePaging implements ChatPagingSource {
  _FakePaging({
    required this.hasMoreOlder,
    this.failNext = false,
    this.hold = false,
  });

  @override
  bool hasMoreOlder;

  /// Makes the next [loadOlder] come back as a failure, the way the cubit
  /// reports one: by leaving it on the state rather than throwing.
  bool failNext;

  /// Keeps [loadOlder] in flight until [release], so overlapping calls can be
  /// observed collapsing.
  bool hold;

  int loadOlderCalls = 0;
  int prefetchCalls = 0;
  bool _failed = false;
  final _gate = Completer<void>();

  @override
  bool get lastLoadFailed => _failed;

  @override
  Future<void> loadOlder({int? rows}) async {
    loadOlderCalls++;
    if (hold) await _gate.future;
    _failed = failNext;
  }

  @override
  Future<void> prefetchOlder({int? rows}) async {
    prefetchCalls++;
  }

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }
}
