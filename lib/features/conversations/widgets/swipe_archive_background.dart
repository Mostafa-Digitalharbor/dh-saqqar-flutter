import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';

/// Coloured background revealed behind a conversation row while the
/// user is dragging it horizontally to archive (or un-archive). Shape
/// matches the card — same 18 px radius — so the swipe motion reads as
/// "the row peeling back to expose an action" instead of a generic
/// dismiss colour.
///
/// Used for both [Dismissible.background] (start → end drag) and
/// [Dismissible.secondaryBackground] (end → start drag); the [alignment]
/// argument flips the icon + label to whichever edge the gesture is
/// pulling from.
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
    // Active rows get a warm amber wash (archive = "move out of the
    // way"). Archived rows get a cyan wash (unarchive = "bring back to
    // active" — same brand cyan as the FAB / send button so the gesture
    // visually signals "back into the main flow").
    final base = archived ? s.brandCyan : s.warning;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.18),
        borderRadius: AppRadius.modalR,
        border: Border.all(color: base.withValues(alpha: 0.40)),
      ),
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived ? AppIcons.unarchive : AppIcons.archive,
              color: base,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              archived ? context.tr.swipeUnarchive : context.tr.swipeArchive,
              style: context.text.labelMedium?.copyWith(
                color: base,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Danger-tinted background revealed while the user drags a conversation
/// row toward the delete direction (physical left). Same shape + motion as
/// [SwipeArchiveBackground] so both gestures read as "the row peeling back
/// to expose an action" — only the palette (danger red), icon (trash) and
/// label differ, signalling the destructive outcome before the confirm
/// dialog appears.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, required this.alignment});

  final AlignmentDirectional alignment;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final base = s.danger;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.18),
        borderRadius: AppRadius.modalR,
        border: Border.all(color: base.withValues(alpha: 0.40)),
      ),
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.trash, color: base, size: 20),
            const SizedBox(width: 8),
            Text(
              context.tr.swipeDelete,
              style: context.text.labelMedium?.copyWith(
                color: base,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
