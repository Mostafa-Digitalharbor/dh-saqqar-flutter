import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';

/// One of two long-running report phases reported by the backend in
/// `conversation.run_progress.phase`:
///   - [fetching] → "building_report" (current/total rows known when total
///                  > 0). Render a determinate bar with "Fetching N/M".
///   - [rendering] → "rendering_report" (no mid-write hook from
///                   xlsxwriter / python-docx / reportlab). Render an
///                   indeterminate bar with "Writing file… N rows".
enum RunProgressPhase { fetching, rendering }

/// View-model for [ChatRunProgressCard] — what the card needs to draw, not
/// what the server sends.
///
/// Named `ChatRunProgress`, not `RunProgress`, because
/// `conversation_models.dart` already exports an API model by that name with
/// a *different* shape (a free-form `phase` string and a `label`, no `rows` /
/// `fileName`). Two same-named types in one app is a trap: any file needing
/// both had to reach for an import prefix, and a file importing only one
/// could silently bind to the wrong one and still compile. `chat_screen.dart`
/// adapts the API model into this one in `_liveRunProgress`.
class ChatRunProgress {
  const ChatRunProgress({
    required this.phase,
    this.current,
    this.total,
    this.rows,
    this.fileName,
  });

  final RunProgressPhase phase;
  final int? current;
  final int? total;
  final int? rows;
  final String? fileName;

  /// Determinate iff we know both `current` and `total`. Otherwise the
  /// bar renders as an indeterminate sweep.
  bool get isDeterminate =>
      phase == RunProgressPhase.fetching &&
      current != null &&
      total != null &&
      total! > 0;

  double? get fraction {
    if (!isDeterminate) return null;
    return (current! / total!).clamp(0.0, 1.0);
  }
}

/// Inline progress card rendered above the message list while a long-
/// running report (Excel / PDF / Word) is being generated. Replaces the
/// generic typing row for these tools because the user is now waiting on
/// a fixed-throughput operation, not on the agent thinking.
///
/// Web parity for the `building-card` block in app.js (phase = building_report
/// or rendering_report).
class ChatRunProgressCard extends StatelessWidget {
  const ChatRunProgressCard({super.key, required this.progress});

  final ChatRunProgress progress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;

    final label = progress.phase == RunProgressPhase.fetching
        ? tr.phaseFetching(progress.current ?? 0, progress.total)
        : tr.phaseRendering(progress.rows);

    final pctChip = progress.isDeterminate
        ? Container(
            padding:
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s6,
                  vertical: AppSpacing.s1,
                ),
            decoration: BoxDecoration(
              color: s.brandCyan.withValues(alpha: 0.18),
              borderRadius: AppRadius.pillR,
              border: Border.all(color: s.brandCyan.withValues(alpha: 0.40)),
            ),
            child: Text(
              '${((progress.fraction ?? 0) * 100).round()}%',
              style: context.text.labelSmall?.copyWith(
                color: s.brandCyan,
                fontSize: AppFontSizes.chipLabel,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s6,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s12,
        AppSpacing.s14,
        AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.92),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.brandCyan.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(AppIcons.fileText, size: AppIconSizes.small, color: s.brandCyan),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: s.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (progress.fileName != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    progress.fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
              if (pctChip != null) ...[
                const SizedBox(width: AppSpacing.s8),
                pctChip,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          ClipRRect(
            borderRadius: AppRadius.pillR,
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 4,
              backgroundColor: s.brandCyan.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(s.brandCyan),
            ),
          ),
        ],
      ),
    );
  }
}
