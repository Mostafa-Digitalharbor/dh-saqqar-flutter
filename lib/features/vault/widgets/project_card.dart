import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../data/project_models.dart';

/// Vault refactor (P0 from the web audit). Each card represents one
/// [Project]; its [Environment]s are listed underneath as tappable
/// rows. Tapping an env raises [onEnvTap]. Tapping the project header
/// (name/icon/env count) raises [onTap] so the parent can open the
/// project-detail sheet (rename / add env / delete project).
///
/// Mirrors the production data model: credentials nest under environments,
/// environments nest under projects.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.environments,
    required this.onEnvTap,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onLongPress,
  });

  final Project project;
  final List<Environment> environments;
  final ValueChanged<Environment> onEnvTap;

  /// Opens [ProjectDetailSheet] for this project. When null the project
  /// header is non-interactive (only env rows respond to taps).
  final VoidCallback? onTap;

  /// Inline pencil icon at the trailing edge of the project header — same
  /// destination as [onTap] in the web. Defaults to [onTap] when null.
  final VoidCallback? onEdit;

  /// Inline trash icon. When null the icon isn't rendered.
  final VoidCallback? onDelete;

  /// Long-press on the project header — opens a quick-action bottom sheet
  /// (Rename / Delete). The inline icons stay reachable for stylus + mouse;
  /// the long-press is the finger-friendly path.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              // Pulse the haptic the moment the long-press resolves so
              // the quick-actions sheet feels like it "lifts" out of the
              // card — without this, the sheet appearance is the only
              // confirmation and on slower phones it's a beat late.
              onLongPress: onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onLongPress!();
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.brandCyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: s.brandCyan.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        AppIcons.drive,
                        color: s.brandCyan,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${environments.length} ${context.tr.environment}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: s.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null || onTap != null)
                      IconButton(
                        icon: Icon(AppIcons.edit, size: 18, color: s.muted),
                        tooltip: context.tr.edit,
                        onPressed: onEdit ?? onTap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(AppIcons.trash, size: 18, color: s.muted),
                        tooltip: context.tr.delete,
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
          for (var i = 0; i < environments.length; i++) ...[
            Divider(color: s.border, height: 1),
            _EnvironmentRow(
              env: environments[i],
              onTap: () => onEnvTap(environments[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({required this.env, required this.onTap});

  final Environment env;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: env.isLive
                      ? s.danger.withValues(alpha: 0.12)
                      : s.brandCyan.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  AppIcons.server,
                  color: env.isLive ? s.danger : s.brandCyan,
                  size: 15,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        env.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (env.isLive) ...[
                      const SizedBox(width: 8),
                      MiniChip(context.tr.liveBadge, color: s.danger),
                    ],
                    if (env.readOnly) ...[
                      const SizedBox(width: 6),
                      MiniChip(context.tr.readOnlyBadge, color: s.muted),
                    ],
                    if (env.autoApprove) ...[
                      const SizedBox(width: 6),
                      MiniChip(
                        context.tr.autoApproveBadge,
                        color: s.warning,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18, color: s.muted),
            ],
          ),
        ),
      ),
    );
  }
}
