import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';

/// Heuristic follow-up suggestions shown between the message list and the
/// composer once the agent finishes its turn. Tapping a chip seeds the
/// composer with the prompt so the user can edit before sending — no
/// auto-send (that would skip the chance to add context).
///
/// Three suggestions cover the most common follow-up shapes:
///   * "Tell me more" — open-ended elaboration.
///   * "Summarize this" — squeeze the agent's last answer to a paragraph.
///   * "Export as Excel" — the most-asked next step on a data answer.
///
/// Picked locally (not from the server) — keeps the chips snappy and
/// avoids a backend round-trip on every poll. Once the API exposes
/// per-message suggestions we'll swap the source without touching the
/// visual contract.
class QuickReplyStrip extends StatelessWidget {
  const QuickReplyStrip({
    super.key,
    required this.visible,
    required this.onSelect,
  });

  /// `false` → renders zero-height so the layout doesn't jump as
  /// messages stream. Wrapping in an [AnimatedSize] would be nicer but
  /// the chat list is already inside a Stack with a scroll button —
  /// keeping the strip stateless is cheaper and avoids fighting the
  /// scroll restore code.
  final bool visible;

  /// Called with the prompt the user picked. The chat screen feeds it
  /// into the composer text field (focus + caret-at-end) so the user
  /// can edit before sending.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final tr = context.tr;
    final s = context.saqqar;
    final prompts = <String>[
      tr.quickReplyMore,
      tr.quickReplySummarize,
      tr.quickReplyExport,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.55 : 0.85),
        border: Border(top: BorderSide(color: s.border)),
      ),
      child: ResponsiveContent(
        maxWidth: 980,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              for (final p in prompts) ...[
                _QuickReplyChip(
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

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.brandCyan.withValues(alpha: 0.34)),
          ),
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: s.brandCyan,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
