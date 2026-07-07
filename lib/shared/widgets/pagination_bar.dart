import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../extensions/context_extensions.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.visibleCount,
    required this.totalCount,
    required this.itemLabel,
    required this.onPrevious,
    required this.onNext,
    this.onFirst,
  });

  final int page;
  final int pageCount;
  final int visibleCount;
  final int totalCount;
  final String itemLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Optional "jump back to the first page" action. When supplied, a
  /// double-chevron button appears at the START of the controls — but ONLY
  /// once the user has moved past page 1 (`page > 1`); it stays hidden on the
  /// first page so nothing changes there. `null` (the default) keeps the bar
  /// exactly as it was for any other caller.
  final VoidCallback? onFirst;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    if (totalCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr.itemCount(visibleCount, totalCount, itemLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: s.muted),
            ),
          ),
          // "Back to first page" — hidden on page 1, appears from page 2
          // onward (and on every page after). Only when the caller opted in
          // by passing [onFirst].
          if (onFirst != null && page > 1)
            IconButton(
              tooltip: context.tr.firstPage,
              onPressed: onFirst,
              icon: const Icon(AppIcons.chevronsLeft),
            ),
          IconButton(
            tooltip: context.tr.previousPage,
            onPressed: onPrevious,
            icon: const Icon(AppIcons.chevronLeft),
          ),
          Text(
            context.tr.pageCount(page, pageCount),
            style: context.text.labelMedium?.copyWith(
              color: s.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: context.tr.nextPage,
            onPressed: onNext,
            icon: const Icon(AppIcons.chevronRight),
          ),
        ],
      ),
    );
  }
}
