import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

/// Tiny inline status chip shown beside a save/commit button so a disabled
/// button reads as intentional, not broken. Two tones:
///
///   * [SaveStatusTone.saved]   — success-green with a check ("Saved").
///   * [SaveStatusTone.neutral] — muted, icon-less ("No changes").
///
/// Deliberately lightweight (icon + label, no fill) so it sits quietly next
/// to the primary action instead of competing with it.
enum SaveStatusTone { saved, neutral }

class SaveStatusHint extends StatelessWidget {
  const SaveStatusHint({
    super.key,
    required this.label,
    this.tone = SaveStatusTone.neutral,
  });

  final String label;
  final SaveStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final saved = tone == SaveStatusTone.saved;
    final color = saved ? s.success : s.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saved) ...[
          Icon(AppIcons.success, size: AppIconSizes.dense, color: color),
          const SizedBox(width: AppSpacing.s4),
        ],
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
