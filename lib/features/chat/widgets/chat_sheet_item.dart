import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';

/// A single tappable row used inside the chat "more" sheet (rename, share,
/// archive, delete, plus the three top entry points: action center,
/// approvals, artifacts). Optional [color] tints both icon and label.
///
/// When [comingSoon] is true the row is rendered in muted styling with a
/// "Soon" chip in the trailing slot, signalling that the wired action
/// hasn't shipped yet. The row stays tappable so the caller can still
/// surface a "ships in next build" toast — fully disabling the InkWell
/// reads as "broken" to users, which is worse than an honest "not yet".
class ChatSheetItem extends StatelessWidget {
  const ChatSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.trailing,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final base = color ?? s.text;
    final c = comingSoon ? s.muted : base;
    final effectiveTrailing = comingSoon
        ? _ComingSoonChip(label: context.tr.comingSoonBadge)
        : trailing;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 28, child: Icon(icon, size: 19, color: c)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.text.bodyMedium?.copyWith(
                    color: c,
                    fontWeight: comingSoon ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              if (effectiveTrailing != null) effectiveTrailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: s.cardBorder),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: s.muted,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
