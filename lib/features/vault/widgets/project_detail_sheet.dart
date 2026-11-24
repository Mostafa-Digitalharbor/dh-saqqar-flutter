import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/compact_search_field.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/inline_add_form.dart';
import '../../../shared/widgets/app_card_dialog.dart';
import '../data/project_models.dart';
import '../view_model/vault_cubit.dart';
import 'environment_detail_sheet.dart';
import 'projects_list_sheet.dart';
import '../../../shared/fig/fig.dart';

part 'project_detail_env_row.dart';
part 'project_detail_parts.dart';

/// Project popup — web-parity centred dialog for managing one project's
/// environments. Mirrors the desktop site's `projectPopup`:
///
///   • Header: "PROJECT" eyebrow + bold project name + Close button +
///     hairline divider
///   • "← All projects" back link (full-width pill) that returns to the
///     projects list
///   • "PROJECT NAME" labelled TextField — renames the project on blur /
///     submit (no explicit Save button; matches the web's inline edit)
///   • Environment cards — each row carries its own flag checkboxes +
///     Open + Delete actions (see [_EnvRow])
///   • "Add environment…" inline form at the bottom — creates instantly
///
/// Project creation lives in [ProjectsListSheet] now; this sheet is
/// purely a per-project editor (the [existingProjectId] is required).
/// Delete-project lives in [ProjectsListSheet] too — surfacing it here
/// duplicated the surface and made the dialog feel busy.
class ProjectDetailSheet extends StatefulWidget {
  const ProjectDetailSheet({super.key, required this.existingProjectId});

  final String existingProjectId;

  static Future<void> show(
    BuildContext context, {
    required String existingProjectId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProjectDetailSheet(existingProjectId: existingProjectId),
    );
  }

  @override
  State<ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends State<ProjectDetailSheet> {
  late final TextEditingController _name;
  late final FocusNode _nameFocus;
  final TextEditingController _newEnv = TextEditingController();
  final TextEditingController _envSearch = TextEditingController();

  /// The env search field only appears when the project has enough
  /// environments that scanning visually starts to hurt. 6 is the
  /// threshold the web hits (Default project has 8 staging envs and
  /// became unreadable). Below this count the search field is hidden so
  /// small projects stay quiet.
  static const _envSearchThreshold = 6;

  @override
  void initState() {
    super.initState();
    final initialName =
        context
            .read<VaultCubit>()
            .state
            .data
            .dataOrNull
            ?.projectById(widget.existingProjectId)
            ?.name ??
        '';
    _name = TextEditingController(text: initialName);
    _nameFocus = FocusNode();
    // Auto-commit the rename on blur so the user never has to hunt for
    // a Save button — matches the web's inline edit (an explicit Save
    // CTA would feel redundant next to a single field).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _commitRename();
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _name.dispose();
    _newEnv.dispose();
    _envSearch.dispose();
    super.dispose();
  }

  void _commitRename() {
    final next = _name.text.trim();
    final cubit = context.read<VaultCubit>();
    final current =
        cubit.state.data.dataOrNull
            ?.projectById(widget.existingProjectId)
            ?.name ??
        '';
    if (next.isEmpty || next == current) {
      // Restore the previous value if the user blanked the field or
      // didn't actually change anything — saves a no-op write + keeps
      // the input from looking empty.
      _name.text = current;
      return;
    }
    cubit.renameProject(id: widget.existingProjectId, name: next);
  }

  void _backToProjectsList() {
    Navigator.of(context).pop();
    ProjectsListSheet.show(context);
  }

  /// Case-insensitive substring filter against the env name. When the
  /// search field is empty, returns the list unchanged so we don't pay
  /// for a filter pass on small projects.
  List<Environment> _filterEnvs(List<Environment> all) {
    final q = _envSearch.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _addEnv() async {
    final name = _newEnv.text.trim();
    if (name.isEmpty) return;
    final ok = await context.read<VaultCubit>().createEnvironment(
      projectId: widget.existingProjectId,
      name: name,
    );
    if (!mounted) return;
    if (ok) {
      _newEnv.clear();
      setState(() {});
    }
  }

  Future<void> _deleteEnv(Environment env) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteEnvironmentTitle,
      body: context.tr.deleteEnvironmentBody(env.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteEnvironment(env.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = context.watch<VaultCubit>().state;
    final data = state.data.dataOrNull;
    final project = data?.projectById(widget.existingProjectId);
    final envs =
        data?.environmentsForProject(widget.existingProjectId) ??
        const <Environment>[];

    // Centred dialog sized like the projects list popup — body grows with
    // content but never past ~70 % screen height; long env lists scroll
    // inside the body. Taller than the list dialog because this one carries
    // an edit field and its environments, not just rows.
    final projectName = project?.name ?? '—';

    return AppCardDialog(
      heightFactor: AppFractions.projectDetailSheet,
      minHeight: AppSheetHeights.projectDetailMin,
      maxHeight: AppSheetHeights.projectDetailMax,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s18,
          AppSpacing.s18,
          AppSpacing.s18,
          AppSpacing.s18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: eyebrow + project name + Close ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr.project.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(
                          color: s.brandCyan,
                          fontWeight: FontWeight.w900,
                          letterSpacing: AppLetterSpacing.microCapsWidest,
                          fontSize: AppFontSizes.chipLabel,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                FigButton.compact(
                  secondary: true,
                  label: context.tr.close,
                  height: AppControlSizes.rowMin,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s14),
            Divider(color: s.cardBorder, height: AppBorderWidths.hairline),
            const SizedBox(height: AppSpacing.s14),
            // ── "← All projects" back link (full-width pill) ────────
            _BackToProjectsPill(onTap: _backToProjectsList),
            const SizedBox(height: AppSpacing.s16),
            // ── Body: project name + env list + add-env row ────────
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr.projectName.toUpperCase(),
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: AppLetterSpacing.microCapsWide,
                        fontSize: AppFontSizes.chipLabel,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    AppTextField(
                      controller: _name,
                      focusNode: _nameFocus,
                      hint: context.tr.addProjectHint,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        _commitRename();
                        _nameFocus.unfocus();
                      },
                    ),
                    // Search field — only appears once the env list
                    // grows past the visual-scan threshold. Keeps
                    // small projects (1–5 envs) quiet.
                    if (envs.length >= _envSearchThreshold) ...[
                      const SizedBox(height: AppSpacing.s14),
                      CompactSearchField(
                        hintText: context.tr.envSearchHint,
                        textInputAction: TextInputAction.search,
                        controller: _envSearch,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    if (envs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s14),
                      _EnvList(
                        envs: _filterEnvs(envs),
                        onOpen: (env) {
                          Navigator.of(context).pop();
                          EnvironmentDetailSheet.show(
                            context,
                            environmentId: env.id,
                          );
                        },
                        onDelete: _deleteEnv,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s14),
                    // ── Add-environment inline form (always visible,
                    // even when no envs yet — matches screenshot 1)
                    // Disabled until an env name is typed (and no
                    // write in flight) — no empty-tap no-op.
                    InlineAddForm(
                      controller: _newEnv,
                      hint: context.tr.addEnvironmentHint,
                      buttonLabel: context.tr.addEnvironment,
                      enabled: !state.actionInFlight,
                      onSubmit: _addEnv,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
