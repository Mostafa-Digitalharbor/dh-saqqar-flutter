import 'package:flutter/material.dart';

import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';
import 'tappable_surface.dart';

/// One tappable action inside a bottom sheet: a tinted circular glyph, a
/// label, an optional second line, and an optional trailing chevron.
///
/// ## Why this exists
///
/// Four sheets each carried their own private `_ActionRow` / `_OptionRow` /
/// `_ToolRow` class — the attachment picker, a message's long-press menu,
/// the tools sheet and the conversation actions sheet. All four built the
/// identical tree:
///
/// ```text
/// TappableSurface(onTap:)
///   Padding(symmetric(horizontal: s6, vertical: s12))
///     Row
///       Container 34x34, circle, <tint> at 10% ── Icon(size: regular)
///       SizedBox(width: s14)
///       Expanded(Text(label, w600))
/// ```
///
/// down to the same six spacing constants. They differed only in which
/// colour tinted the glyph and whether a subtitle or a chevron was present
/// — three parameters, spread across four files as four class definitions.
///
/// That is the shape duplication takes in a widget tree: not copied logic,
/// but four independent chances for a sheet row to drift half a step out of
/// line with the other three, in an app where the user opens two of these
/// sheets in a row and reads them as one menu.
class SheetActionRow extends StatelessWidget {
  const SheetActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tint,
    this.glyphColor,
    this.labelColor,
    this.showChevron = false,
  });

  final IconData icon;
  final String label;

  /// Nullable so a disabled row keeps the standard "no ripple" behaviour
  /// from [TappableSurface] rather than needing its own branch.
  final VoidCallback? onTap;

  /// Optional second line under [label].
  final String? subtitle;

  /// The circular ground behind the glyph, rendered at
  /// [AppAlphas.a10]. Defaults to the theme's `muted` — a neutral row.
  /// Pass `brandCyan` for an affirmative action, `danger` for a
  /// destructive one.
  final Color? tint;

  /// The glyph itself. Defaults to the theme's `text` rather than to
  /// [tint], because the two are independent in practice: the
  /// attachment picker draws a cyan glyph on a cyan ground, while a
  /// message's action menu draws a plain glyph on a muted one.
  final Color? glyphColor;

  /// The label. Defaults to the theme's `text`; a destructive row
  /// passes `danger` so the wording carries the warning too, not just
  /// the icon.
  final Color? labelColor;

  /// Shows a direction-aware chevron at the end — for a row that opens
  /// another surface rather than performing its action inline.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final ground = tint ?? s.muted;
    final glyph = glyphColor ?? s.text;
    final label_ = labelColor ?? s.text;

    return TappableSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            Container(
              width: AppBoxSizes.sheetRow,
              height: AppBoxSizes.sheetRow,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ground.withValues(alpha: AppAlphas.a10),
              ),
              child: Icon(icon, size: AppIconSizes.regular, color: glyph),
            ),
            const SizedBox(width: AppSpacing.s14),
            // Expanded, not Flexible: the label has to claim the row's slack
            // so a long Arabic action name ellipsises instead of pushing the
            // chevron off the end.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: context.text.bodyMedium?.copyWith(
                      color: label_,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(color: s.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(
                context.chevronForward,
                size: AppIconSizes.small,
                color: s.muted,
              ),
          ],
        ),
      ),
    );
  }
}
