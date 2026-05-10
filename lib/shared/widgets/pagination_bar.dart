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
  });

  final int page;
  final int pageCount;
  final int visibleCount;
  final int totalCount;
  final String itemLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

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
