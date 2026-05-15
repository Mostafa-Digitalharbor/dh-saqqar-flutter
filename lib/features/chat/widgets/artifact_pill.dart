import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

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

  final DemoAttachment attachment;
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

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardR,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.cardR,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: context.isDark ? 0.10 : 0.06),
            borderRadius: AppRadius.cardR,
            border: Border.all(color: s.brandCyan.withValues(alpha: 0.32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(AppIcons.sparkles, size: 12, color: s.brandCyan),
                  const SizedBox(width: 6),
                  Text(
                    context.tr.artifactReady.toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: s.brandCyan,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.brandCyan.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: s.brandCyan.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(_icon, size: 18, color: s.brandCyan),
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 2),
                        Text(
                          '${attachment.kind} · ${attachment.size}',
                          style: context.text.bodySmall?.copyWith(
                            color: s.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(AppIcons.download, size: 18, color: s.brandCyan),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
