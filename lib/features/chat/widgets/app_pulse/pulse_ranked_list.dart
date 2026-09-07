import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';

/// A capped, scrollable list of ranked rows — factory's `top_risks` today,
/// and the shape any future kind's ranked array reaches for.
///
/// Generalizes `chat_approval_card.dart`'s `_DeleteRecordList`: same
/// height-capped-not-count-capped reasoning (a card must not push its own
/// content off-screen, and truncating a risk list silently would hide the
/// exact rows the user opened the card to see), but takes a row WIDGET per
/// item rather than a single string — these cards' rows carry several
/// fields each, not one line.
///
/// Deliberately generic over [T] rather than tied to any one kind's payload
/// type: the doc's own warning is that these seven payloads are "not the
/// same shape", so the one thing worth sharing across kinds is this
/// chrome — the actual row content stays kind-specific.
class PulseRankedList<T> extends StatelessWidget {
  const PulseRankedList({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
  });

  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: AppSheetHeights.approvalPayloadMax),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (context, _) => Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                  color: s.border,
                ),
                itemBuilder: (context, i) => itemBuilder(context, items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
