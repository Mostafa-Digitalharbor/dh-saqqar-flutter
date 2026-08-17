import 'package:flutter/material.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/format/file_kind.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/tappable_surface.dart';

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
  // The extension comes from the filename when it has one, and from the
  // server's `kind` token when it doesn't. Classification itself is
  // [FileKinds]' — this file used to carry its own copy of the table, one of
  // five that had drifted apart on which extensions count as images.
  final source = name.contains('.') ? name : kindRaw;
  final ext = FileKinds.extensionOf(source);
  // Archives (Gap M) get a distinct package icon: Odoo addon bundles come
  // back as a rebuilt `.zip` and should stand out in the artifacts list.
  //
  // The label is the badge for named formats and the raw extension for the
  // rest, which is what makes "PNG" and "TGZ" show their own name rather
  // than a category word.
  return switch (FileKinds.of(ext)) {
    FileKind.spreadsheet => const _ArtifactStyle(
        label: UiStrings.formatXlsx,
        icon: AppIcons.table,
        accent: AppColors.success,
      ),
    FileKind.pdf => const _ArtifactStyle(
        label: UiStrings.formatPdf,
        icon: AppIcons.fileText,
        accent: AppColors.danger,
      ),
    FileKind.document => const _ArtifactStyle(
        label: UiStrings.formatDocx,
        icon: AppIcons.fileText,
        accent: AppColors.brandCyan,
      ),
    FileKind.csv => const _ArtifactStyle(
        label: UiStrings.formatCsv,
        icon: AppIcons.table,
        accent: AppColors.warning,
      ),
    FileKind.json => const _ArtifactStyle(
        label: UiStrings.formatJson,
        icon: AppIcons.code,
        accent: AppColors.brandPurple,
      ),
    FileKind.image => _ArtifactStyle(
        label: ext.toUpperCase(),
        icon: AppIcons.image,
        accent: AppColors.brandPurple,
      ),
    FileKind.text => _ArtifactStyle(
        label: ext.toUpperCase(),
        icon: AppIcons.fileText,
        accent: AppColors.darkMuted,
      ),
    FileKind.archive => _ArtifactStyle(
        label: ext.toUpperCase(),
        icon: AppIcons.archive,
        accent: AppColors.brandPurple,
      ),
    // Unknown: the badge shows the first five characters of whatever the
    // extension was, so "PPTX" still reads as itself.
    FileKind.other => _ArtifactStyle(
        label: FileKinds.badge(ext),
        icon: AppIcons.file,
        accent: AppColors.brandCyan,
      ),
  };
}

/// One artifact row used inside the chat "Artifacts" sheet. Kind-coloured
/// leading plate + filename + meta line (kind · size · created) + bold
/// kind badge + download trailing button. Tappable across the whole row.
class ChatArtifactTile extends StatelessWidget {
  const ChatArtifactTile({
    super.key,
    required this.artifact,
    required this.onOpen,
    this.onLongPress,
  });

  final DemoArtifact artifact;
  final VoidCallback onOpen;

  /// Optional long-press (e.g. "show details"). Additive — the tap/download
  /// behaviour is unchanged when this is null.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final style = _styleFor(artifact.name, artifact.kind);
    return TappableSurface(
      radius: AppRadius.cardR,
      onTap: onOpen,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: s.surface2,
          borderRadius: AppRadius.cardR,
          border: Border.all(
            color: style.accent.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s12,
          AppSpacing.s10,
          AppSpacing.s12,
        ),
        child: Row(
          children: [
            // Kind-coloured icon plate. Bigger than the old 36-px square
            // (44 px) so the file kind reads from across the sheet.
            ColoredIconBox(
              icon: style.icon,
              color: style.accent,
              size: AppIconSizes.feature,
              radius: AppRadius.button,
              iconSize: AppIconSizes.boxGlyphTile,
              borderAlpha: 0.45,
            ),
            const SizedBox(width: AppSpacing.s12),
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
                      const SizedBox(width: AppSpacing.s6),
                      _KindBadge(style: style),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.18),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: style.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        style.label,
        style: context.text.labelSmall?.copyWith(
          color: style.accent,
          fontSize: AppFontSizes.microCaps,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
