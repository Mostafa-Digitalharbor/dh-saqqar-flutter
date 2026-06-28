import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';

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
            .withValues(alpha: context.isDark ? 0.55 : 0.85),
        border: Border(top: BorderSide(color: context.saqqar.border)),
      ),
      child: ResponsiveContent(
        maxWidth: 980,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              for (final p in prompts) ...[
                _SuggestionChip(
                  label: p,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(p);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: s.cardBg,
            borderRadius: AppRadius.pillR,
            border: Border.all(color: s.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.sparkles, size: 13, color: s.brandCyan),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
