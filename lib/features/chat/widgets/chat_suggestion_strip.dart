import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/chip_strip.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../../shared/widgets/tappable_surface.dart';
import '../../../shared/widgets/glass_card.dart';

/// Horizontal strip of quick-action suggestion chips shown directly above
/// the composer — mirrors the Saqqar Design System's ChatScreen
/// `SUGGESTIONS` row (card-bg pills, sparkle glyph, monospace-light copy).
///
/// Tapping a chip seeds the composer with the prompt (no auto-send) so the
/// user can edit before firing. The labels are representative Odoo
/// operations the agent commonly runs; once the API exposes per-chat
/// suggestions we'll swap the source without touching this visual.
class ChatSuggestionStrip extends StatelessWidget {
  const ChatSuggestionStrip({
    super.key,
    required this.visible,
    required this.onSelect,
  });

  /// `false` → collapses to zero height so the composer doesn't jump while
  /// recording / transcribing.
  final bool visible;

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final tr = context.tr;
    final prompts = [
      tr.suggestRestartWorker,
      tr.suggestReconciliationReport,
      tr.suggestPendingInvoices,
      tr.suggestSyncInventory,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.saqqar.surface
            .withValues(alpha: context.alpha(AppAlphaPairs.panelPlain)),
        border: Border(top: BorderSide(color: context.saqqar.border)),
      ),
      child: ResponsiveContent(
        maxWidth: AppLayoutWidths.chatShell,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s8,
          AppSpacing.s12,
          AppSpacing.s8,
        ),
        // Sizes to the chips rather than pinning `height: 34`, which clipped
        // Arabic descenders at large text scales with no overflow warning.
        child: ChipStrip(
          physics: const BouncingScrollPhysics(),
          children: [
            for (final p in prompts)
              _SuggestionChip(
                label: p,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(p);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TappableSurface(
      radius: AppRadius.pillR,
      onTap: onTap,
      child: GlassCard.flat(
        borderRadius: AppRadius.pillR,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.sparkles, size: AppIconSizes.dense, color: s.brandCyan),
            const SizedBox(width: AppSpacing.s6),
            Text(
              label,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: AppFontSizes.pillTitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
