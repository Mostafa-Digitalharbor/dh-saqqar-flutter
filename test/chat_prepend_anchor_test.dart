// Validates the scroll-anchoring technique the chat uses when older messages
// are paged in above the viewport.
//
// The chat list is a normal top-to-bottom `ListView.builder`, so inserting
// older rows at the head pushes everything the user is reading down the
// screen by the height of what was added. While paging was driven by a
// button that was merely ugly. With automatic paging it is disqualifying:
// the user stays pinned near offset 0, which immediately satisfies the
// trigger again, and the list walks itself to the start of the conversation
// in one gesture.
//
// `_ChatScreenState` corrects for this by keying one row, recording where that
// row sits before the insert, and moving the offset by however far the row
// actually moved. Three things about that are worth pinning, and none of them
// can be checked by reading the code:
//
//   1. it really does hold the reading position;
//   2. the anchor row has to be laid out for it to work at all — which is
//      what ties the trigger distance to the list's `cacheExtent`; and
//   3. `jumpTo` **cancels an in-flight drag**, so the correction cannot be
//      applied while the user's finger is down. This is the constraint that
//      shapes `_afterScrollSettles`, and the least obvious of the three.
//
// The chat screen itself needs a dozen providers and sits behind login, so
// this exercises the same technique against the real `Scrollable` machinery
// on a list with known row heights, where the arithmetic is exact.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rowHeight = 100.0;
const _viewportHeight = 600.0;

/// A list that grows at the HEAD, mirroring the chat lane. Rows carry stable
/// ids so a prepend shifts every index — exactly as prepending older messages
/// does — and `find.text('row-N')` refers to the same content before and
/// after.
class _PrependingList extends StatefulWidget {
  const _PrependingList({
    required this.controller,
    required this.initialRows,
    this.cacheExtent = 1500,
  });

  final ScrollController controller;
  final int initialRows;

  /// Matches the chat lane by default. Overridden by the test that shows what
  /// the metrics-based anchor does when the prepended rows fall outside it.
  final double cacheExtent;

  @override
  State<_PrependingList> createState() => _PrependingListState();
}

class _PrependingListState extends State<_PrependingList> {
  late int _oldestId = 0;
  late int _count = widget.initialRows;

  /// Mirrors `_ChatScreenState._scrollAnchorKey` / `_scrollAnchorId`.
  final GlobalKey _anchorKey = GlobalKey();
  int? _pinnedAnchorId;

  int get _anchorId => _pinnedAnchorId ?? _oldestId;

  double? _anchorY() {
    final context = _anchorKey.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final viewport =
        widget.controller.position.context.storageContext.findRenderObject();
    if (viewport is! RenderBox) return null;
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  /// Prepends [n] older rows and re-anchors, using the same
  /// measure-before / correct-after shape as the chat screen.
  void prependOlder(int n) {
    final controller = widget.controller;
    final anchorYBefore = _anchorY();

    setState(() {
      _pinnedAnchorId = _anchorId;
      _oldestId -= n;
      _count += n;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final position = controller.position;
      if (!position.hasContentDimensions) return;
      final anchorYAfter = _anchorY();
      if (anchorYBefore != null && anchorYAfter != null) {
        final shift = anchorYAfter - anchorYBefore;
        if (shift.abs() >= 0.5) {
          controller.jumpTo(
            (position.pixels + shift).clamp(0.0, position.maxScrollExtent),
          );
        }
      }
      setState(() => _pinnedAnchorId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      itemCount: _count,
      itemExtent: _rowHeight,
      // Load-bearing for anchoring: the anchor row sits just above the
      // viewport, and a row outside the cache extent has no render object to
      // measure. The chat triggers 600 px from the top, well inside its 1500.
      cacheExtent: widget.cacheExtent,
      itemBuilder: (context, index) {
        final id = _oldestId + index;
        final row = Text('row-$id');
        return id == _anchorId
            ? KeyedSubtree(key: _anchorKey, child: row)
            : row;
      },
    );
  }
}

Future<_PrependingListState> _pump(
  WidgetTester tester,
  ScrollController controller, {
  double cacheExtent = 1500,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, _viewportHeight));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _PrependingList(
          controller: controller,
          initialRows: 20,
          cacheExtent: cacheExtent,
        ),
      ),
    ),
  );
  return tester.state<_PrependingListState>(find.byType(_PrependingList));
}

void main() {
  testWidgets('prepending older rows leaves the reading position untouched',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final list = await _pump(tester, controller);

    controller.jumpTo(500);
    await tester.pump();
    final anchoredRow = find.text('row-5');
    final yBefore = tester.getTopLeft(anchoredRow).dy;

    list.prependOlder(10);
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(anchoredRow).dy,
      moreOrLessEquals(yBefore, epsilon: 0.5),
      reason: 'the row the user was reading moved on screen — this is the '
          'jump that makes automatic paging feel broken, and the reason the '
          'list would immediately re-trigger from offset 0',
    );
    expect(controller.offset, moreOrLessEquals(500 + 10 * _rowHeight));
  });

  testWidgets('the anchor row must be laid out for the correction to happen',
      (tester) async {
    // The one precondition of the measured approach: you cannot measure a row
    // that has no render object. `cacheExtent: 0` puts the anchor (which sits
    // above the viewport) outside the built region, and the correction
    // correctly declines rather than guessing.
    //
    // This is why the chat's 600 px trigger and 1500 px `cacheExtent` are a
    // pair — the anchor is always well inside the built region when the
    // trigger fires. Tightening one without the other silently disables
    // anchoring, and `_onScrollChanged`'s re-arm hysteresis is what keeps that
    // degrading into "one extra page" instead of a runaway load.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final list = await _pump(tester, controller, cacheExtent: 0);

    controller.jumpTo(500);
    await tester.pump();
    list.prependOlder(10);
    await tester.pump();
    await tester.pump();

    expect(controller.offset, moreOrLessEquals(500));
  });

  testWidgets('correcting mid-drag cancels the gesture — why reveal defers',
      (tester) async {
    // This is the constraint that shapes `_afterScrollSettles`, recorded as a
    // test so nobody "simplifies" the reveal back to being eager.
    //
    // `ScrollPositionWithSingleContext.beginActivity` disposes the active
    // drag, and `jumpTo` goes through it. Correct the offset while the finger
    // is down and the list stops following it — the user's flick dies
    // mid-stroke and they have to lift and start again.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    controller.jumpTo(400);
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 60)); // drag down = scroll up
    await tester.pump();
    final offsetMidDrag = controller.offset;
    expect(offsetMidDrag, lessThan(400), reason: 'drag should scroll up');

    controller.jumpTo(offsetMidDrag + 100); // the unsafe correction
    await tester.pump();

    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(
      controller.offset,
      moreOrLessEquals(offsetMidDrag + 100),
      reason: 'if this ever starts moving, jumpTo became drag-safe and the '
          'reveal no longer needs to wait for the scroll to settle',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a settled list corrects cleanly, gesture intact afterwards',
      (tester) async {
    // The path the chat actually takes: the flick has decayed, the reveal
    // lands, the correction holds position, and the list is fully usable.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final list = await _pump(tester, controller);

    controller.jumpTo(400);
    await tester.pump();
    expect(controller.position.isScrollingNotifier.value, isFalse);

    final anchored = find.text('row-4');
    final yBefore = tester.getTopLeft(anchored).dy;

    list.prependOlder(10);
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(anchored).dy, moreOrLessEquals(yBefore, epsilon: 0.5));

    // And the list still scrolls normally afterwards.
    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(controller.offset, lessThan(1400));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a prepend that adds nothing leaves the offset alone',
      (tester) async {
    // Guards the `grew <= 0` early-out: a no-op page (server returned rows we
    // already had) must not nudge the user.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final list = await _pump(tester, controller);

    controller.jumpTo(300);
    await tester.pump();

    list.prependOlder(0);
    await tester.pump();
    await tester.pump();

    expect(controller.offset, moreOrLessEquals(300));
  });
}
