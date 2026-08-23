import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../data/chat_view_models.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Spec / web parity widget for agent-generated outputs that appear inline
/// in an assistant bubble. The web's `renderMessageAttachments()` shows the
/// same kind/name/size pill plus an "Artifact ready" eyebrow when the
/// attachment came from the agent rather than from the user.
///
/// On tap, the caller wires the platform-appropriate open path (share sheet
/// on mobile, new tab on web). Today the chat screen just toasts because
/// `share_plus` isn't on the dependency list yet.
class ArtifactPill extends StatelessWidget {
  const ArtifactPill({
    super.key,
    required this.attachment,
    required this.onOpen,
  });

  final ChatAttachment attachment;
  final VoidCallback onOpen;

  IconData get _icon {
    final k = attachment.kind.toUpperCase();
    if (k == 'IMAGE' || attachment.isImage) return AppIcons.image;
    if (k == 'PDF') return AppIcons.fileText;
    if (k == 'SPREADSHEET' || k == 'EXCEL' || k == 'CSV') return AppIcons.table;
    if (k == 'LOG' || k == 'JSON' || k == 'MARKDOWN') return AppIcons.code;
    return AppIcons.file;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return TappableSurface(
      radius: AppRadius.cardR,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s10,
          AppSpacing.s10,
          AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: s.brandCyan.withValues(alpha: context.alpha(AppAlphaPairs.tintFaintest)),
          borderRadius: AppRadius.cardR,
          border: Border.all(color: s.brandCyan.withValues(alpha: AppAlphas.a32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(AppIcons.sparkles, size: AppIconSizes.meta, color: s.brandCyan),
                const SizedBox(width: AppSpacing.s6),
                Text(
                  context.tr.artifactReady.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w800,
                    fontSize: AppFontSizes.chipLabel,
                    letterSpacing: AppLetterSpacing.microCaps,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                ColoredIconBox(
                  icon: _icon,
                  color: s.brandCyan,
                  radius: AppRadius.small,
                  borderAlpha: 0.28,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: s.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        '${attachment.kind} · ${attachment.size}',
                        style: context.text.bodySmall?.copyWith(
                          color: s.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Icon(AppIcons.download, size: AppIconSizes.regular, color: s.brandCyan),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
