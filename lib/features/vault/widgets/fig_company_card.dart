import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/fig/fig.dart';
import '../data/project_models.dart';

/// One company of the Figma "Companies & environments" list: a dark rounded
/// card with the name, the environment count, round edit / delete buttons and
/// a chevron; opened, it lists the environments and an "Add environment" link.
///
/// Shared by the chat's company picker (where a row is a radio that switches the
/// chat's environment) and the Connections page (where a row opens the
/// environment's details), so both read as the same design.
class FigCompanyCard extends StatelessWidget {
  const FigCompanyCard({
    super.key,
    required this.project,
    required this.open,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onEnvTap,
    required this.onAddEnvironment,
    this.selectedEnvId,
    this.pickable = false,
  });

  final Project project;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<Environment> onEnvTap;
  final VoidCallback onAddEnvironment;

  /// The environment the chat is on; only drawn when [pickable].
  final String? selectedEnvId;

  /// Radio rows (chat picker) rather than plain rows that open details.
  final bool pickable;

  Widget _circleBtn(IconData i, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: FigMetrics.size32,
      height: FigMetrics.size32,
      margin: const EdgeInsetsDirectional.only(start: AppSpacing.s6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: AppAlphas.a50)),
      ),
      child: Icon(i, size: AppIconSizes.compact, color: c),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = project;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a04),
        borderRadius: BorderRadius.circular(AppRadius.heroPlate),
        // One colour on all four sides: a rounded box refuses a border whose
        // sides differ (it throws while painting and the whole card went
        // blank when opened), so the "open" accent is the border colour
        // itself rather than a heavier top edge.
        border: Border.all(
          color: open ? Fig.blueSoft : Colors.white12,
          width: open ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s14,
                AppSpacing.s12,
                AppSpacing.s14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.dense,
                            color: AppColors.figWhite,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          context.tr.environmentCount(p.environments.length),
                          style: Fig.t(
                            context,
                            size: FigMetrics.fontFig8U5,
                            color: AppColors.figWhite.withValues(
                              alpha: AppAlphas.a80,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _circleBtn(
                    LucideIcons.pencil,
                    AppColors.figCFF6C8CFF,
                    onRename,
                  ),
                  _circleBtn(LucideIcons.trash2, Fig.danger, onDelete),
                  const SizedBox(width: AppSpacing.s10),
                  Icon(
                    open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: AppIconSizes.regular,
                    color: AppColors.figWhite,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                AppSpacing.s14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in p.environments) _envRow(context, e),
                  const SizedBox(height: AppSpacing.s4),
                  GestureDetector(
                    onTap: onAddEnvironment,
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.plus,
                          size: AppIconSizes.compact,
                          color: Fig.accentBlue,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            context.tr.figAddEnvironment,
                            style: Fig.t(
                              context,
                              size: FigMetrics.fontFig9,
                              color: Fig.accentBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _envRow(BuildContext context, Environment e) {
    final selected = pickable && selectedEnvId == e.id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onEnvTap(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s9),
        child: Row(
          children: [
            if (pickable) ...[
              Container(
                width: FigMetrics.size18,
                height: FigMetrics.size18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Fig.accentBlue : Colors.white38,
                    width: AppBorderWidths.medium,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: FigMetrics.size9,
                          height: FigMetrics.size9,
                          decoration: const BoxDecoration(
                            color: Fig.accentBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: Fig.t(
                      context,
                      size: FigMetrics.fontFig10U5,
                      weight: FontWeight.w600,
                      color: AppColors.figWhite,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Container(
                        width: FigMetrics.size5,
                        height: FigMetrics.size5,
                        decoration: BoxDecoration(
                          color: e.hasXmlrpc ? Fig.success : Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s5),
                      Flexible(
                        child: Text(
                          '${e.hasXmlrpc ? context.tr.figOdooConnected : context.tr.figNotConnected} · ${e.readOnly ? context.tr.figReadOnly : (e.isLive ? context.tr.figLive : context.tr.figStaging)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fig.t(
                            context,
                            size: FigMetrics.fontFig8,
                            color: AppColors.figWhite.withValues(
                              alpha: AppAlphas.a50,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              Text(
                context.tr.figCurrent,
                style: Fig.t(
                  context,
                  size: FigMetrics.fontFig8U5,
                  color: Fig.success,
                ),
              )
            else if (!pickable)
              Icon(
                context.chevronForward,
                size: AppIconSizes.compact,
                color: AppColors.figWhite.withValues(alpha: AppAlphas.a50),
              ),
          ],
        ),
      ),
    );
  }
}


/// The outlined "+ Add company" pill closing the Figma companies list.
class FigAddCompanyButton extends StatelessWidget {
  const FigAddCompanyButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppControlSizes.rowMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FigMetrics.radFig24),
          border: Border.all(
            color: AppColors.figWhite.withValues(alpha: AppAlphas.a20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.plus,
              size: AppIconSizes.small,
              color: Fig.accentBlue,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              context.tr.figAddCompany,
              style: Fig.t(
                context,
                size: AppFontSizes.microCaps,
                color: Fig.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
