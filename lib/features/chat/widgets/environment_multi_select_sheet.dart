import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../vault/data/project_models.dart';
import '../../vault/view_model/vault_cubit.dart';
import 'chat_sheet.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Multi-select environment picker — mirrors the web header's environment
/// dropdown that carries checkboxes so a single conversation can bind to
/// more than one environment at once (e.g. compare ALZOMMAN Staging and
/// Al Arabia Staging in the same chat).
///
/// Lists every project and its environments with a checkbox each. Returns
/// the full set of checked environment ids via [Navigator.pop] when the
/// user taps Apply, or `null` if they dismiss without applying (so the
/// caller can distinguish "cleared all" — an empty list — from "cancelled").
class EnvironmentMultiSelectSheet extends StatefulWidget {
  const EnvironmentMultiSelectSheet({
    super.key,
    required this.projectId,
    required this.selectedEnvironmentIds,
  });

  /// Project whose environments the sheet lists. Only this project's envs
  /// are shown — a conversation binds within one project, so surfacing every
  /// project's environments (as an earlier version did) was misleading.
  final String? projectId;

  /// Environment ids currently bound to the conversation. Pre-checks the
  /// matching rows so the sheet opens reflecting the live binding.
  final List<String> selectedEnvironmentIds;

  static Future<List<String>?> show(
    BuildContext context, {
    required String? projectId,
    required List<String> selectedEnvironmentIds,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EnvironmentMultiSelectSheet(
        projectId: projectId,
        selectedEnvironmentIds: selectedEnvironmentIds,
      ),
    );
  }

  @override
  State<EnvironmentMultiSelectSheet> createState() =>
      _EnvironmentMultiSelectSheetState();
}

class _EnvironmentMultiSelectSheetState
    extends State<EnvironmentMultiSelectSheet> {
  late final Set<String> _selected = {...widget.selectedEnvironmentIds};

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Only the currently-selected project's environments — a conversation
    // binds within one project, so listing every project's envs was wrong.
    final projects =
        context.watch<VaultCubit>().state.data.dataOrNull?.projects ??
            const <Project>[];
    Project? project;
    for (final p in projects) {
      if (p.id == widget.projectId) {
        project = p;
        break;
      }
    }
    final envs = project?.environments ?? const <Environment>[];

    return ChatSheet(
      title: context.tr.envMultiTitle,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppSpacing.s12,
            left: AppSpacing.s4,
            right: AppSpacing.s4,
          ),
          child: Text(
            context.tr.envMultiSubtitle,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: AppLineHeights.compact),
          ),
        ),
        if (project != null && envs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s8,
            ),
            child: Text(
              project.name.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: AppLetterSpacing.microCaps,
                fontSize: AppFontSizes.chipLabel,
              ),
            ),
          ),
        for (final env in envs)
          _EnvCheckRow(
            env: env,
            checked: _selected.contains(env.id),
            onTap: () => _toggle(env.id),
          ),
        const SizedBox(height: AppSpacing.s18),
        // Apply commits the whole set at once (a single PATCH), matching the
        // web's "select many then it saves" affordance rather than firing a
        // request per toggle.
        PrimaryButton(
          label: _selected.isEmpty
              ? context.tr.envMultiApply
              : '${context.tr.envMultiApply} · '
                  '${context.tr.envMultiSelectedCount(_selected.length)}',
          expand: true,
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
        ),
        const SizedBox(height: AppSpacing.s6),
      ],
    );
  }
}

/// One environment row with a leading checkbox. Uses the same badge
/// language (LIVE / READ-ONLY / AUTO) as the header environment dropdown
/// so the pickers read consistently.
class _EnvCheckRow extends StatelessWidget {
  const _EnvCheckRow({
    required this.env,
    required this.checked,
    required this.onTap,
  });

  final Environment env;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = env.isLive ? s.danger : s.brandCyan;

    return TappableSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s10,
        ),
        child: Row(
          children: [
            // Checkbox-styled leading box (filled + check when selected).
            Container(
              width: AppBoxSizes.selector,
              height: AppBoxSizes.selector,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? accent : Colors.transparent,
                borderRadius: AppRadius.checkboxR,
                border: Border.all(
                  color: checked ? accent : s.border,
                  width: AppBorderWidths.thick,
                ),
              ),
              child: checked
                  ? const Icon(AppIcons.check, size: AppIconSizes.inline, color: AppColors.onBrand)
                  : null,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(env.name, style: context.text.titleSmall),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s4,
                    runSpacing: AppSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (env.isLive)
                        MiniChip(context.tr.liveBadge, color: s.danger),
                      if (env.readOnly)
                        MiniChip(context.tr.readOnlyBadge, color: s.muted),
                      if (env.autoApprove)
                        MiniChip(context.tr.autoApproveBadge,
                            color: s.warning),
                      if (env.slug.isNotEmpty)
                        Text(
                          env.slug,
                          textDirection: TextDirection.ltr,
                          style: context.text.bodySmall
                              ?.copyWith(color: s.muted),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
