// What happens to the reading position when older messages are paged in.
//
// The chat lane is a `reverse: true` `ListView.builder`: offset 0 is the
// NEWEST message and older history grows away from the user. Older rows
// therefore land at HIGH indices — the far end, off-screen in the direction
// the user is heading — and the viewport does not move.
//
// That is the whole claim, and it is worth pinning against the real
// `Scrollable` machinery rather than trusted from the docs, because the
// version this file replaces existed to work around the opposite:
//
//   The lane used to be a forward list, so inserting older rows at the head
//   pushed everything the user was reading DOWN by the height of what was
//   added. `_ChatScreenState` corrected for it by keying one row, measuring
//   where that row sat before the insert, and jumping the offset by however
//   far it had actually moved. That correction had two failure modes of its
//   own: the anchor row has to still be laid out for it to work at all (a
//   fast fling culls it), and `jumpTo` **cancels an in-flight drag**, so it
//   could not be applied while the user's finger was down — which is why the
//   reveal had to wait for the scroll to settle before it could happen.
//
// Both of those are gone. The tests below assert that they are gone, in the
// two shapes that used to break: a settled list, and a list mid-drag.
//
// `chat_screen.dart` itself needs a dozen providers and sits behind login, so
// this exercises the same list configuration on rows of known height, where
// the arithmetic is exact.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rowHeight = 100.0;
const _viewportHeight = 600.0;

/// A reversed list that grows at the TAIL, mirroring the chat lane.
///
/// Rows are labelled by index with 0 = newest, so `find.text('row-N')` refers
/// to the same content before and after a page lands and its on-screen
/// position can be compared directly.
class _ReversedChatLane extends StatefulWidget {
  const _ReversedChatLane({
    super.key,
    required this.controller,
    required this.initialRows,
  });

  final ScrollController controller;
  final int initialRows;

  @override
  State<_ReversedChatLane> createState() => _ReversedChatLaneState();
}

class _ReversedChatLaneState extends State<_ReversedChatLane> {
  /// Rows are labelled by index, and index 0 is the NEWEST. A page of history
  /// only ever appends, so a row keeps its label — and therefore its
  /// `find.text` — across a load.
  late int _count = widget.initialRows;

  /// Adds [n] older rows — no measuring, no correction, no waiting for the
  /// scroll to stop. This is the entire production code path.
  void loadOlder(int n) => setState(() => _count += n);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      reverse: true,
      itemCount: _count,
      itemBuilder: (context, index) {
        // index 0 = newest, matching the screen: a higher index is OLDER.
        return SizedBox(
          height: _rowHeight,
          child: Text('row-$index', textDirection: TextDirection.ltr),
        );
      },
    );
  }
}

void main() {
  Future<
      ({
        ScrollController controller,
        GlobalKey<_ReversedChatLaneState> key,
      })> pumpLane(
    WidgetTester tester, {
    int rows = 40,
  }) async {
    final controller = ScrollController();
    final key = GlobalKey<_ReversedChatLaneState>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, _viewportHeight)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: _viewportHeight,
            child: _ReversedChatLane(
              key: key,
              controller: controller,
              initialRows: rows,
            ),
          ),
        ),
      ),
    );
    return (controller: controller, key: key);
  }

  /// Where `row-<index>` currently sits in the viewport, or null if it is not
  /// laid out.
  double? rowY(WidgetTester tester, int index) {
    final finder = find.text('row-$index');
    if (finder.evaluate().isEmpty) return null;
    return tester.getTopLeft(finder).dy;
  }

  testWidgets('a chat opens on its newest message with no scrolling',
      (tester) async {
    // The forward list had to schedule a post-frame jump to
    // `maxScrollExtent` for this, against an extent that was still an
    // estimate while rows below the fold were unbuilt — so it landed short
    // and needed a second pass. A reversed list simply rests here.
    final lane = await pumpLane(tester);

    expect(lane.controller.offset, 0);
    expect(find.text('row-0'), findsOneWidget,
        reason: 'row-0 is the newest message and must be on screen at rest');
  });

  testWidgets('paging in older rows leaves the reading position untouched',
      (tester) async {
    final lane = await pumpLane(tester);

    // Scroll a few screenfuls into history.
    lane.controller.jumpTo(_rowHeight * 12);
    await tester.pump();

    final offsetBefore = lane.controller.offset;
    final anchorBefore = rowY(tester, 12);
    expect(anchorBefore, isNotNull,
        reason: 'the row under test must be laid out for the comparison to '
            'mean anything');

    lane.key.currentState!.loadOlder(100);
    await tester.pump();

    expect(
      lane.controller.offset,
      offsetBefore,
      reason: 'a page of older rows lands at the far end of a reversed list, '
          'so the scroll offset cannot move. In the forward list this is the '
          'assertion that needed a measure-and-jump correction to hold.',
    );
    expect(
      rowY(tester, 12),
      anchorBefore,
      reason: 'and the row the user was reading keeps its exact pixel',
    );
  });

  testWidgets('a page landing mid-drag does not cancel the gesture',
      (tester) async {
    // The constraint that shaped the old design: `jumpTo` disposes the active
    // drag (`ScrollPositionWithSingleContext.beginActivity`), so the list
    // stopped dead under the user's finger. The old code avoided it by
    // deferring the reveal until the scroll settled — which is why rows
    // appeared only after the flick had decayed.
    final lane = await pumpLane(tester);

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();

    final midDragOffset = lane.controller.offset;
    expect(midDragOffset, greaterThan(0));

    // The page lands while the finger is still down.
    lane.key.currentState!.loadOlder(100);
    await tester.pump();

    expect(lane.controller.offset, midDragOffset,
        reason: 'the insert must not move the list mid-gesture');

    // The gesture must still be live.
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    expect(
      lane.controller.offset,
      greaterThan(midDragOffset),
      reason: 'the drag must keep driving the list after the page landed. '
          'This is what allows the reveal to happen immediately instead of '
          'waiting for the scroll to settle.',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('older rows really are reachable after paging', (tester) async {
    // The position not moving would also be true of a page that never
    // rendered, so this checks the rows actually arrived and can be scrolled
    // to — the counterpart assertion that keeps the one above honest.
    final lane = await pumpLane(tester, rows: 10);

    lane.key.currentState!.loadOlder(50);
    await tester.pump();

    lane.controller.jumpTo(_rowHeight * 45);
    await tester.pump();

    expect(find.text('row-45'), findsOneWidget,
        reason: 'a row from the newly paged-in range must be reachable');
  });

  testWidgets('scrolling back to the newest message is offset zero',
      (tester) async {
    // `_ChatScreenState._newestOffset`. In the forward list this was
    // `maxScrollExtent`, which moves as unbuilt rows are laid out.
    final lane = await pumpLane(tester);
    lane.key.currentState!.loadOlder(200);
    await tester.pump();

    lane.controller.jumpTo(_rowHeight * 100);
    await tester.pump();
    expect(find.text('row-0'), findsNothing);

    lane.controller.jumpTo(0);
    await tester.pump();

    expect(find.text('row-0'), findsOneWidget);
  });
}
