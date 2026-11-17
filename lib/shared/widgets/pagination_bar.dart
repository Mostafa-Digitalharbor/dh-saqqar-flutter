import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../extensions/context_extensions.dart';
import '../extensions/responsive_breakpoints.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';

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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.inputR,
        border: Border.all(color: s.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Text(
            context.tr.itemCount(visibleCount, totalCount, itemLabel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: s.muted),
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: _controls(context),
          );

          // On the narrow tier the summary and the controls cannot share a
          // line: two 48 px tap targets plus "Page 128 of 1024" already fill
          // a 320 px row, which left the summary at zero width and still
          // overflowed by 48 px at 1.3× text. Stack them instead — the
          // summary reads full-width and the controls sit under it.
          if (breakpointForWidth(constraints.maxWidth).isCompactOrBelow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                summary,
                const SizedBox(height: AppSpacing.s6),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: controls,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.s8),
              // Capped rather than made flexible so the summary keeps its
              // greedy `Expanded` share whenever the controls are narrow —
              // two flex children would split the row evenly and truncate
              // the summary early beside a short "Page 1 of 2".
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.6,
                ),
                child: controls,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _controls(BuildContext context) {
    final s = context.saqqar;
    return [
      // "Back to first page" — hidden on page 1, appears from page 2 onward
      // (and on every page after). Only when the caller opted in by passing
      // [onFirst].
      if (onFirst != null && page > 1)
        IconButton(
          tooltip: context.tr.firstPage,
          onPressed: onFirst,
          icon: Icon(context.chevronsBack),
        ),
      IconButton(
        tooltip: context.tr.previousPage,
        onPressed: onPrevious,
        icon: Icon(context.chevronBack),
      ),
      // Shrinks into whatever the cap leaves rather than pushing the row
      // wider — "Page 128 of 1024" is the widest thing here at large text
      // scales, and it is the part that can be abbreviated safely.
      Flexible(
        child: Text(
          context.tr.pageCount(page, pageCount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: context.text.labelMedium?.copyWith(
            color: s.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        tooltip: context.tr.nextPage,
        onPressed: onNext,
        icon: Icon(context.chevronForward),
      ),
    ];
  }
}
