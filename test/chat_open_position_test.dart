// Where a chat lands when you open it, and what keeps it there.
//
// The answer has to be "on the newest message". Since the lane became a
// `reverse: true` list that is where it RESTS — offset 0 — so most of what
// this file used to hold is gone, and the reason it is gone is worth keeping:
//
//   The forward list reached the newest message with a one-shot
//   `jumpTo(maxScrollExtent)` on the first frame that had content
//   dimensions. On a lazy list that extent is an ESTIMATE — the rows laid
//   out so far, plus a guess for the rest — and rows were still arriving
//   behind it (the bounded initial fetch, then the page-ahead). Jumping to
//   an estimate that is about to grow lands short, and a one-shot never
//   corrects.
//
//   The user-visible result was a chat that opened on a message from a day
//   earlier with the newest content below the fold. It read as "it didn't
//   load", and the natural response was a pull-to-refresh — which is how it
//   was reported. Reproduced by force-stopping the app: a cold open landed
//   on Jul 26 in a chat whose newest message was Jul 27, while re-opening
//   warm (the session cache paints the full window, so the estimate is
//   good) landed correctly. That warm/cold split is why it looked
//   intermittent.
//
// A reversed list has no estimate in the path: the resting offset is 0
// whatever is or is not laid out, and rows arriving later append at the far
// end. The tests below pin that — including under exactly the late-arrival
// timing that broke the old approach — plus the one job still left for
// `_pinToBottomIfUnscrolled`: snapping back a few stray pixels while the
// user has not scrolled, and letting go the moment they do.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rowHeight = 100.0;
const _viewportHeight = 600.0;

/// A reversed lane whose rows arrive in stages, mirroring a chat opening:
/// the cached window paints first, the bounded fetch lands next, the
/// page-ahead after that.
class _OpeningLane extends StatefulWidget {
  const _OpeningLane({
    super.key,
    required this.controller,
    required this.initialRows,
    required this.userHasScrolled,
  });

  final ScrollController controller;
  final int initialRows;

  /// Mirrors `_ChatScreenState._userHasScrolled` — the pin lets go once the
  /// user takes over.
  final bool Function() userHasScrolled;

  @override
  State<_OpeningLane> createState() => _OpeningLaneState();
}

class _OpeningLaneState extends State<_OpeningLane> {
  late int _count = widget.initialRows;

  /// More history lands — the same shape as a page arriving after the first
  /// paint.
  void rowsArrive(int n) {
    setState(() => _count += n);
    // Mirrors the screen: the pin runs post-frame on every build until the
    // user's first drag.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pin());
  }

  /// `_ChatScreenState._pinToBottomIfUnscrolled`, verbatim in shape.
  void _pin() {
    if (widget.userHasScrolled()) return;
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    if (position.pixels.abs() < 1.0) return;
    controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      reverse: true,
      itemCount: _count,
      itemBuilder: (context, index) => SizedBox(
        height: _rowHeight,
        child: Text('row-$index', textDirection: TextDirection.ltr),
      ),
    );
  }
}

void main() {
  Future<
      ({
        ScrollController controller,
        GlobalKey<_OpeningLaneState> key,
        void Function(bool) setScrolled,
      })> pumpLane(
    WidgetTester tester, {
    int rows = 8,
  }) async {
    final controller = ScrollController();
    final key = GlobalKey<_OpeningLaneState>();
    var scrolled = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, _viewportHeight)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: _viewportHeight,
            child: _OpeningLane(
              key: key,
              controller: controller,
              initialRows: rows,
              userHasScrolled: () => scrolled,
            ),
          ),
        ),
      ),
    );
    return (
      controller: controller,
      key: key,
      setScrolled: (bool v) => scrolled = v,
    );
  }

  testWidgets('a chat opens on the newest message', (tester) async {
    final lane = await pumpLane(tester);

    expect(lane.controller.offset, 0);
    expect(find.text('row-0'), findsOneWidget);
  });

  testWidgets('it stays on the newest message when rows arrive late',
      (tester) async {
    // THE regression. This is the exact timing that broke the forward list:
    // the lane paints with a short window, and the real history lands a
    // frame or two later. There the estimate had already been jumped to and
    // the one-shot never corrected, leaving the user a screenful short.
    final lane = await pumpLane(tester, rows: 4);
    expect(lane.controller.offset, 0);

    lane.key.currentState!.rowsArrive(40);
    await tester.pump();
    lane.key.currentState!.rowsArrive(100);
    await tester.pumpAndSettle();

    expect(
      lane.controller.offset,
      0,
      reason: 'history arriving after the first paint appends at the far end '
          'of a reversed list, so the newest message stays exactly where it '
          'was — with no extent estimate anywhere in the path.',
    );
    expect(find.text('row-0'), findsOneWidget);
  });

  testWidgets('the pin snaps back a stray offset while the user has not '
      'scrolled', (tester) async {
    // The job `_pinToBottomIfUnscrolled` still has: a rebuild can leave the
    // lane a few pixels off the newest message — a bounce settling, or a row
    // resizing as its markdown finishes laying out.
    final lane = await pumpLane(tester);

    lane.controller.jumpTo(12);
    await tester.pump();
    expect(lane.controller.offset, 12);

    lane.key.currentState!.rowsArrive(5);
    await tester.pumpAndSettle();

    expect(lane.controller.offset, 0,
        reason: 'an unscrolled lane belongs on the newest message');
  });

  testWidgets('the pin lets go on the first drag', (tester) async {
    // Without this the lane would drag the user back to the newest message
    // every time a poll rebuilt it — which is worse than opening in the
    // wrong place, because it happens repeatedly and fights the user.
    final lane = await pumpLane(tester, rows: 40);

    lane.setScrolled(true);
    lane.controller.jumpTo(_rowHeight * 10);
    await tester.pump();

    lane.key.currentState!.rowsArrive(50);
    await tester.pumpAndSettle();

    expect(
      lane.controller.offset,
      _rowHeight * 10,
      reason: 'once the user is driving, arriving rows must not move them',
    );
  });

  testWidgets('a lane too short to scroll is left alone', (tester) async {
    // Two messages on a tall phone: `maxScrollExtent` is 0 and there is
    // nothing to pin to. The pin must not thrash.
    final lane = await pumpLane(tester, rows: 2);
    await tester.pumpAndSettle();

    expect(lane.controller.offset, 0);
    expect(lane.controller.position.maxScrollExtent, 0);
    expect(find.text('row-0'), findsOneWidget);
    expect(find.text('row-1'), findsOneWidget);
  });
}
