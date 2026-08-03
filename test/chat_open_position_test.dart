// Where a chat lands when you open it.
//
// The answer has to be "on the newest message", and getting there is not the
// one-liner it looks like. `_ChatScreenState._restoreScrollIfNeeded` is a
// one-shot `jumpTo(maxScrollExtent)` fired on the first frame that has content
// dimensions. On a lazy list `maxScrollExtent` at that moment is an ESTIMATE —
// built from the handful of rows laid out so far plus a guess for the rest —
// and rows are still arriving behind it (the bounded initial fetch, then the
// page-ahead). Jumping to an estimate that is about to grow lands short, and a
// one-shot never corrects.
//
// The user-visible result is a chat that opens on a message from a day earlier
// with the newest content below the fold. It reads as "it didn't load", and
// the natural response is a pull-to-refresh — which is how it was reported.
// Reproduced by force-stopping the app: cold open landed on Jul 26 in a chat
// whose newest message was Jul 27, while re-opening it warm (session cache
// paints the full window, so the estimate is good) landed correctly. That
// warm/cold split is why it looks intermittent.
//
// The fix re-pins to the bottom every frame until the user's first drag. These
// tests hold both halves: that it lands on the newest row despite content
// arriving late, and that it lets go the moment the user takes over — a pin
// that outstayed its welcome would make the chat impossible to scroll back
// through, which is a worse bug than the one being fixed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rowHeight = 100.0;
const _viewportHeight = 500.0;

/// A lane that grows at the TAIL after the first frame, mirroring a chat whose
/// rows are still landing when the open-scroll fires.
class _ArrivingList extends StatefulWidget {
  const _ArrivingList({
    super.key,
    required this.controller,
    required this.initialRows,
    required this.repin,
  });

  final ScrollController controller;
  final int initialRows;

  /// False reproduces the one-shot restore that lands short.
  final bool repin;

  @override
  State<_ArrivingList> createState() => _ArrivingListState();
}

class _ArrivingListState extends State<_ArrivingList> {
  late int _rows = widget.initialRows;
  bool _restored = false;

  /// Mirrors `_ChatScreenState._userHasScrolled`.
  bool _userHasScrolled = false;

  /// Every jump this harness performed, so a test can prove the pin stopped.
  final List<double> jumps = [];

  void addRows(int n) => setState(() => _rows += n);

  /// Mirrors `_restoreScrollIfNeeded` — one-shot, fires once dimensions exist.
  void _restoreOnce() {
    if (_restored) return;
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent <= 0) {
      _restored = true;
      return;
    }
    _restored = true;
    widget.controller.jumpTo(position.maxScrollExtent);
    jumps.add(position.maxScrollExtent);
  }

  /// Mirrors `_pinToBottomIfUnscrolled`.
  void _pin() {
    if (_userHasScrolled) return;
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (!position.hasContentDimensions) return;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    if ((position.pixels - max).abs() < 1.0) return;
    widget.controller.jumpTo(max);
    jumps.add(max);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreOnce();
      if (widget.repin) _pin();
    });

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: _viewportHeight,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              // Drag details only — our own corrective `jumpTo` opens a scroll
              // activity too, and treating that as the user taking over would
              // hand control away on the very frame we opened.
              if (notification.dragDetails != null) _userHasScrolled = true;
              return false;
            },
            child: ListView.builder(
              controller: widget.controller,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _rows,
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

void main() {
  group('opening a chat lands on the newest message', () {
    testWidgets('a one-shot restore lands short when rows arrive after it',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_ArrivingListState>();
      await tester.pumpWidget(
        _ArrivingList(
          key: key,
          controller: controller,
          initialRows: 8,
          repin: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.position.pixels, controller.position.maxScrollExtent);

      // The rest of the bounded fetch lands, then the page-ahead.
      key.currentState!.addRows(12);
      await tester.pumpAndSettle();

      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent),
        reason: 'the regression: the newest rows are now below the fold and '
            'nothing will ever scroll down to them',
      );
    });

    testWidgets('re-pinning holds the bottom as rows arrive', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_ArrivingListState>();
      await tester.pumpWidget(
        _ArrivingList(
          key: key,
          controller: controller,
          initialRows: 8,
          repin: true,
        ),
      );
      await tester.pumpAndSettle();

      key.currentState!.addRows(12);
      await tester.pumpAndSettle();

      expect(controller.position.pixels, controller.position.maxScrollExtent);
      expect(find.text('row-19'), findsOneWidget);
    });

    testWidgets('the pin lets go on the first drag', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_ArrivingListState>();
      await tester.pumpWidget(
        _ArrivingList(
          key: key,
          controller: controller,
          initialRows: 20,
          repin: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.position.pixels, controller.position.maxScrollExtent);

      // The user scrolls back through history.
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();

      final afterDrag = controller.position.pixels;
      expect(
        afterDrag,
        lessThan(controller.position.maxScrollExtent),
        reason: 'the drag moved us up the transcript',
      );

      // A poll tick rebuilds, and more history lands above. Neither may yank
      // the user back to the newest message.
      key.currentState!.addRows(5);
      await tester.pumpAndSettle();

      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent),
        reason: 'a pin that outstayed its welcome would make scrolling back '
            'impossible — worse than the bug it fixes',
      );
    });

    testWidgets('a lane too short to scroll is left alone', (tester) async {
      // Two rows in a 500px viewport: nothing to scroll, so there is no bottom
      // to pin to. The viewport-fill path owns this case; jumping here would
      // just churn.
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_ArrivingListState>();
      await tester.pumpWidget(
        _ArrivingList(
          key: key,
          controller: controller,
          initialRows: 2,
          repin: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.position.maxScrollExtent, 0.0);
      expect(key.currentState!.jumps, isEmpty);
    });
  });
}
