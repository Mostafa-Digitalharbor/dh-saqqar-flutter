import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';

/// The wash revealed behind a conversation row while the user drags it.
///
/// Both swipe actions paint the same thing — a tinted panel with the card's
/// own corner, and an icon + label pinned to the edge the gesture is pulling
/// from — so the motion reads as "the row peeling back to expose an action"
/// rather than as a generic dismiss colour. Only the tint, the glyph and the
/// word change.
///
/// The two used to be written out separately, and had already drifted: one
/// carried a `margin: EdgeInsets.symmetric(vertical: 0)` that does nothing,
/// and the other did not. That is harmless on its own and is exactly how the
/// two backgrounds would eventually stop being the same shape — the user sees
/// them a second apart, dragging the same row in opposite directions.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.base,
    required this.icon,
    required this.label,
  });

  final AlignmentDirectional alignment;

  /// The action's colour. Tints the panel, its border, the glyph and the
  /// word, so the whole background reads as one signal.
  final Color base;

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.s20),
      decoration: BoxDecoration(
        color: base.withValues(alpha: AppAlphas.a18),
        borderRadius: AppRadius.modalR,
        border: Border.all(color: base.withValues(alpha: AppAlphas.a40)),
      ),
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: base, size: AppIconSizes.action),
            const SizedBox(width: AppSpacing.s8),
            // Flexible + ellipsis: the label is the only part of this row
            // whose width the app does not control, and at 1.4× in Arabic it
            // is the widest thing on a 320 px row.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  color: base,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppLetterSpacing.snug,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Background revealed while the user drags a conversation row toward the
/// archive direction.
///
/// Used for both [Dismissible.background] (start → end drag) and
/// [Dismissible.secondaryBackground] (end → start drag); the [alignment]
/// argument flips the icon + label to whichever edge the gesture is pulling
/// from.
class SwipeArchiveBackground extends StatelessWidget {
  const SwipeArchiveBackground({
    super.key,
    required this.alignment,
    required this.archived,
  });

  final AlignmentDirectional alignment;

  /// `true` for rows currently inside the Archived bucket — the action
  /// flips, so the label and icon flip with it (Unarchive ↑ instead of
  /// Archive ↓).
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return _SwipeBackground(
      alignment: alignment,
      // Active rows get a warm amber wash (archive = "move out of the way").
      // Archived rows get a cyan wash (unarchive = "bring back to active" —
      // the same brand cyan as the FAB and the send button, so the gesture
      // visually signals "back into the main flow").
      base: archived ? s.brandCyan : s.warning,
      icon: archived ? AppIcons.unarchive : AppIcons.archive,
      label: archived ? context.tr.swipeUnarchive : context.tr.swipeArchive,
    );
  }
}

/// Danger-tinted background revealed while the user drags a conversation row
/// toward the delete direction (physical left).
///
/// Same shape and motion as [SwipeArchiveBackground] — they share
/// [_SwipeBackground] — signalling the destructive outcome through palette,
/// glyph and word before the confirm dialog appears.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, required this.alignment});

  final AlignmentDirectional alignment;

  @override
  Widget build(BuildContext context) {
    return _SwipeBackground(
      alignment: alignment,
      base: context.saqqar.danger,
      icon: AppIcons.trash,
      label: context.tr.swipeDelete,
    );
  }
}
