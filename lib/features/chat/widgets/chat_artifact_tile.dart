import 'package:flutter/material.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

/// Visual style for one artifact kind — drives the leading icon plate and
/// the uppercase kind badge so file types are recognisable at a glance.
/// Mirrors the web's `kind-xlsx` / `kind-pdf` / etc. CSS classes.
class _ArtifactStyle {
  const _ArtifactStyle({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}

/// Pick a colour + icon + uppercase label for an artifact based on its
/// extension first, falling back to its `kind` string. Mirrors the web's
/// `artifactKind()` switch.
_ArtifactStyle _styleFor(String name, String kindRaw) {
  final lower = name.toLowerCase();
  final ext = lower.contains('.')
      ? lower.substring(lower.lastIndexOf('.') + 1)
      : kindRaw.toLowerCase();
  if (['xlsx', 'xls', 'xlsm'].contains(ext)) {
    return const _ArtifactStyle(
      label: UiStrings.formatXlsx,
      icon: AppIcons.table,
      accent: AppColors.success,
    );
  }
  if (ext == 'pdf') {
    return const _ArtifactStyle(
      label: UiStrings.formatPdf,
      icon: AppIcons.fileText,
      accent: AppColors.danger,
    );
  }
  if (['docx', 'doc'].contains(ext)) {
    return const _ArtifactStyle(
      label: UiStrings.formatDocx,
      icon: AppIcons.fileText,
      accent: AppColors.brandCyan,
    );
  }
  if (['csv', 'tsv'].contains(ext)) {
    return const _ArtifactStyle(
      label: UiStrings.formatCsv,
      icon: AppIcons.table,
      accent: AppColors.warning,
    );
  }
  if (ext == 'json') {
    return const _ArtifactStyle(
      label: UiStrings.formatJson,
      icon: AppIcons.code,
      accent: AppColors.brandPurple,
    );
  }
  if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
    return _ArtifactStyle(
      label: ext.toUpperCase(),
      icon: AppIcons.image,
      accent: AppColors.brandPurple,
    );
  }
  if (['log', 'txt'].contains(ext)) {
    return _ArtifactStyle(
      label: ext.toUpperCase(),
      icon: AppIcons.fileText,
      accent: AppColors.darkMuted,
    );
  }
  // Archives (Gap M) — Odoo addon bundles come back as a rebuilt `.zip`.
  // Give them a distinct package icon so the produced addon stands out in
  // the artifacts list.
  if (['zip', 'tar', 'gz', 'tgz'].contains(ext)) {
    return _ArtifactStyle(
      label: ext.toUpperCase(),
      icon: AppIcons.archive,
      accent: AppColors.brandPurple,
    );
  }
  // Fallback — first 5 chars of the extension uppercased, neutral colour.
  final fallback = ext.isEmpty
      ? (kindRaw.isEmpty ? UiStrings.formatUnknown : kindRaw)
      : ext;
  return _ArtifactStyle(
    label: fallback.length > 5
        ? fallback.substring(0, 5).toUpperCase()
        : fallback.toUpperCase(),
    icon: AppIcons.file,
    accent: AppColors.brandCyan,
  );
}

/// One artifact row used inside the chat "Artifacts" sheet. Kind-coloured
/// leading plate + filename + meta line (kind · size · created) + bold
/// kind badge + download trailing button. Tappable across the whole row.
class ChatArtifactTile extends StatelessWidget {
  const ChatArtifactTile({
    super.key,
    required this.artifact,
    required this.onOpen,
  });

  final DemoArtifact artifact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final style = _styleFor(artifact.name, artifact.kind);
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardR,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.cardR,
        child: Container(
          decoration: BoxDecoration(
            color: s.surface2,
            borderRadius: AppRadius.cardR,
            border: Border.all(
              color: style.accent.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              // Kind-coloured icon plate. Bigger than the old 36-px square
              // (44 px) so the file kind reads from across the sheet.
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.buttonR,
                  border: Border.all(
                    color: style.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(style.icon, color: style.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            artifact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _KindBadge(style: style),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr.artifactMeta(
                        artifact.kind,
                        artifact.size,
                        artifact.createdLabel,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: s.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr.download,
                onPressed: onOpen,
                icon: Icon(AppIcons.download, color: style.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bold uppercase kind badge next to the filename — `XLSX` / `PDF` / etc.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.style});
  final _ArtifactStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.18),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: style.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        style.label,
        style: context.text.labelSmall?.copyWith(
          color: style.accent,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
