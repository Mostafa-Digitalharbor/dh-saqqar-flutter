// Pins the re-arm rule for the chat's automatic "load earlier messages".
//
// The trigger is latched: it fires once, disarms, and waits to be re-armed
// so that a page landing while the user is still inside the trigger zone
// can't walk the list to the start of the conversation in one gesture.
//
// The subtle part is what re-arms it. The obvious answer — re-arm by
// position, once the user has scrolled back out of the zone — has a dead end
// that only shows up at the very top of the transcript: `extentAfter` is 0
// there and cannot climb back over the re-arm line, so the latch stays down
// forever and further upward swipes do nothing at all. Found on a live
// 816-message chat: the lane stopped paging with "Load earlier messages"
// still on screen, and six more swipes produced a pixel-identical frame.
//
// The fix pairs the position rule with a gesture rule — a fresh finger-down
// drag re-arms, because that is the user asking again. These tests hold both
// halves: that position alone dead-ends, that a drag start recovers it, and
// that the screen's own corrective `jumpTo` does not (it carries no drag
// details, and arming off our own correction would defeat the latch).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rowHeight = 100.0;
const _rowCount = 20;
const _viewportHeight = 600.0;

/// Mirrors the chat lane's latch exactly — same constants, same two rules,
/// same physics — against real `Scrollable` machinery, so `extentAfter`,
/// overscroll clamping and notification ordering are the framework's and not
/// a stand-in.
class _LatchedList extends StatefulWidget {
  const _LatchedList({
    required this.controller,
    required this.fires,
    required this.rearmOnDrag,
  });

  final ScrollController controller;

  /// One entry per automatic load the latch let through.
  final List<double> fires;

  /// False reproduces the position-only rule that dead-ends.
  final bool rearmOnDrag;

  @override
  State<_LatchedList> createState() => _LatchedListState();
}

class _LatchedListState extends State<_LatchedList> {
  /// `_ChatScreenState._autoLoadEarlierThreshold`.
  static const _threshold = 600.0;

  bool _armed = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScrollChanged);
    super.dispose();
  }

  void _onScrollChanged() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (position.extentAfter > _threshold * 2) _armed = true;
    if (_armed && position.extentAfter <= _threshold) {
      _armed = false;
      widget.fires.add(position.extentAfter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: _viewportHeight,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (widget.rearmOnDrag && notification.dragDetails != null) {
                _armed = true;
              }
              return false;
            },
            child: ListView.builder(
              controller: widget.controller,
              // The chat lane is reversed: offset 0 is the newest message and
              // `extentAfter` is how much loaded history is still ahead.
              reverse: true,
              // The chat lane's physics. Load-bearing here: at the top of a
              // clamping list a drag moves nothing, so no scroll notification
              // would be emitted at all and there would be no dead end to
              // reproduce. Bouncing physics lets the offset go past the edge,
              // which is what makes the stuck state reachable — and visible.
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _rowCount,
              itemBuilder: (context, index) => SizedBox(
                height: _rowHeight,
                child: Text('row-$index'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<ScrollController> _pumpAtBottom(
  WidgetTester tester, {
  required List<double> fires,
  required bool rearmOnDrag,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _LatchedList(
      controller: controller,
      fires: fires,
      rearmOnDrag: rearmOnDrag,
    ),
  );
  // A reversed lane already RESTS on the newest message — no jump needed,
  // which is the whole point of the flip. Settle one frame so the listener
  // has seen the resting metrics before the first swipe.
  await tester.pump();
  fires.clear();
  return controller;
}

/// One swipe deeper into history, settled. In a reversed lane a positive
/// `dy` drags content down, which travels toward older messages.
Future<void> _swipeUp(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(ListView), Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  group('automatic load-earlier latch', () {
    testWidgets('fires once on the way into the trigger zone', (tester) async {
      final fires = <double>[];
      await _pumpAtBottom(tester, fires: fires, rearmOnDrag: true);

      await _swipeUp(tester, 1400);

      expect(fires, hasLength(1));
      expect(fires.single, lessThanOrEqualTo(600.0));
    });

    testWidgets(
      'position-only re-arm dead-ends at the top of the transcript',
      (tester) async {
        final fires = <double>[];
        final controller = await _pumpAtBottom(
          tester,
          fires: fires,
          rearmOnDrag: false,
        );

        await _swipeUp(tester, 2000);
        expect(fires, hasLength(1), reason: 'first page requested');
        expect(controller.position.extentAfter, lessThan(100.0));

        // The user keeps asking. Every one of these moves the offset (bouncing
        // physics overscrolls past the edge), so the scroll listener does run
        // — it just never re-arms, because `extentAfter` is pinned at 0 and
        // can never exceed the re-arm line again.
        for (var i = 0; i < 4; i++) {
          await _swipeUp(tester, 400);
        }

        expect(
          fires,
          hasLength(1),
          reason: 'the regression: latch never re-arms, paging stops dead',
        );
      },
    );

    testWidgets('a fresh drag re-arms it at the top', (tester) async {
      final fires = <double>[];
      final controller = await _pumpAtBottom(
        tester,
        fires: fires,
        rearmOnDrag: true,
      );

      await _swipeUp(tester, 2000);
      expect(fires, hasLength(1));
      expect(controller.position.extentAfter, lessThan(100.0));

      await _swipeUp(tester, 400);
      expect(fires, hasLength(2), reason: 'the user asked again');

      await _swipeUp(tester, 400);
      expect(fires, hasLength(3), reason: 'and again');
    });

    testWidgets('one gesture cannot fire it twice', (tester) async {
      final fires = <double>[];
      await _pumpAtBottom(tester, fires: fires, rearmOnDrag: true);

      // A single long drag crosses the threshold and then keeps going,
      // producing scroll frames inside the zone the whole way. The latch has
      // to collapse those to one request; re-arming per frame instead of per
      // gesture is exactly the runaway the latch exists to prevent.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(fires, hasLength(1));
    });

    testWidgets('the screen\'s own corrective jump does not re-arm',
        (tester) async {
      final fires = <double>[];
      final controller = await _pumpAtBottom(
        tester,
        fires: fires,
        rearmOnDrag: true,
      );

      await _swipeUp(tester, 1400);
      expect(fires, hasLength(1));

      // `_reanchorAfterPrepend` corrects the offset with `jumpTo`, which opens
      // a scroll activity and emits a start notification carrying no drag
      // details. Arming off that would let a page's own correction request the
      // next page, unlatching the mechanism entirely.
      controller.jumpTo(0);
      await tester.pump();
      controller.jumpTo(120);
      await tester.pump();
      controller.jumpTo(0);
      await tester.pump();

      expect(fires, hasLength(1));
    });
  });
}
