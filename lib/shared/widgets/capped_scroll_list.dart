import 'package:flutter/material.dart';

import '../../core/theme/app_sizes.dart';

/// A list capped in height, not item count, and scrollable inside that cap.
///
/// The recurring shape for "review this before you approve/lose it" lists
/// inside a card: a delete's affected records, a pulse card's ranked risks.
/// Height-capping rather than count-capping matters because truncating with
/// "…and N more" would hide exactly the rows the user opened the card to
/// check, and letting the list grow freely would push the card's own
/// buttons off screen. Extracted after `ChatApprovalCard`'s
/// `_DeleteRecordList` and `app_pulse/pulse_ranked_list.dart`'s
/// `PulseRankedList` independently rebuilt this same
/// `ConstrainedBox` + `Scrollbar` + `ListView` combination.
class CappedScrollList extends StatelessWidget {
  const CappedScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.maxHeight = AppSheetHeights.approvalPayloadMax,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Null renders a plain [ListView.builder] with no gap between rows
  /// (e.g. the delete-record list); non-null switches to
  /// [ListView.separated] (e.g. a pulse card's hairline-divided rows).
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final separator = separatorBuilder;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        child: separator == null
            ? ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: itemCount,
                separatorBuilder: separator,
                itemBuilder: itemBuilder,
              ),
      ),
    );
  }
}
