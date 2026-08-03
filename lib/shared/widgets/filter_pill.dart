import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// A selectable filter chip — cyan-tinted when active, calm surface when not.
///
/// Named `FilterPill` rather than `FilterChip` because `package:material`
/// already exports a `FilterChip`, and every file that draws one also imports
/// material.
///
/// ## Why this exists
///
/// The notifications inbox and the shared search-and-filters bar each carried
/// a private `_FilterChip` that had drifted apart in the small ways
/// copy-pasted widgets always do: one animated its selection, the other
/// snapped; one used `surface2`, the other `cardBg`; one rendered its
/// unselected label in `text`, the other in `muted`. Same control, same
/// gesture, two looks — the kind of divergence a design system exists to
/// prevent.
///
/// This consolidates on the richer of the two: the selection change is
/// animated, and the unselected fill is theme-aware, which is what keeps the
/// chip legible against both the light and dark backdrops it sits on.
///
/// The Chats screen's own filter chip is deliberately NOT folded in here —
/// it carries a leading icon and a count badge on a gradient fill, which is a
/// different control that happens to share a silhouette.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? s.brandCyan.withValues(alpha: context.isDark ? 0.16 : 0.12)
                : s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.86),
            borderRadius: AppRadius.pillR,
            border: Border.all(
              color:
                  selected ? s.brandCyan.withValues(alpha: 0.4) : s.cardBorder,
            ),
          ),
          // Single line + ellipsis: these sit in a horizontally scrolling
          // strip, but a long Arabic filter name at a large text scale can
          // still exceed the viewport on the narrow tier.
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: selected ? s.brandCyan : s.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
