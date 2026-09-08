import 'package:flutter/material.dart';

import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/capped_scroll_list.dart';

/// A capped, scrollable list of ranked rows — factory's `top_risks` today,
/// and the shape any future kind's ranked array reaches for.
///
/// Adds a title and an optional row separator on top of the shared
/// [CappedScrollList] primitive — `chat_approval_card.dart`'s
/// `_DeleteRecordList` wants the same height-capped-not-count-capped
/// scrolling but neither a title nor separators, which is why the capping
/// itself lives one level down rather than here.
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
          CappedScrollList(
            itemCount: items.length,
            separatorBuilder: (context, _) => Container(
              height: AppBorderWidths.hairline,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
              color: s.border,
            ),
            itemBuilder: (context, i) => itemBuilder(context, items[i]),
          ),
        ],
      ),
    );
  }
}
