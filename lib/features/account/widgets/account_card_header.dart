import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Shared heading for the cards on the Account tab.
///
/// The three cards each grew their own header: one had a purple icon, a title
/// and a subtitle; one had a muted icon and a title; one had no icon at all
/// and no subtitle. Stacked down a single screen that reads as three
/// unrelated components rather than one settings surface, and it's the sort
/// of drift that only shows up when you scroll past all of them at once.
///
/// The icon sits in a soft tinted tile rather than floating bare next to the
/// text — it gives every card the same optical left edge regardless of how
/// wide the glyph is, which is what actually makes a stack of cards line up.
class AccountCardHeader extends StatelessWidget {
  const AccountCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tint,
    this.trailing,
  });

  final IconData icon;
  final String title;

  /// One line of "what is this for". Cards that genuinely need no explanation
  /// (Preferences) omit it rather than padding out a sentence.
  final String? subtitle;

  /// Accent for the icon tile. Defaults to the brand cyan.
  final Color? tint;

  /// Optional end-aligned widget — the expand chevron on collapsible cards.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = tint ?? s.brandCyan;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppBoxSizes.sheetRow,
          height: AppBoxSizes.sheetRow,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppAlphas.a12),
            borderRadius: AppRadius.buttonR,
          ),
          child: Icon(icon, size: AppIconSizes.regular, color: color),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: AppLineHeights.heading,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.s3),
                Text(
                  subtitle!,
                  style: context.text.bodySmall
                      ?.copyWith(color: s.muted, height: AppLineHeights.label),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.s8), trailing!],
      ],
    );
  }
}
