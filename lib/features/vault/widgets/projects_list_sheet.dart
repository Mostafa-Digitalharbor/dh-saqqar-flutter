import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/project_models.dart';
import '../view_model/vault_cubit.dart';
import 'project_detail_sheet.dart';

/// Web-parity "Projects" popup. Replaces the old single-purpose new-project
/// form with the same shape the desktop site uses:
///
///   • Eyebrow "PROJECT" + bold "Projects" title + Close button
///   • Quick "Add project…" inline form (creates immediately on Add)
///   • One card per existing project — name, environment-count subtitle,
///     a Delete ghost button on the trailing edge, whole row tappable to
///     drill into the project detail sheet
///
/// Renders as a **centred half-screen dialog** (≈60% of the screen
/// height) so the user keeps context of the screen behind it — a full
/// bottom sheet felt too committal for what is essentially a quick
/// management surface. The internal project list scrolls when it
/// outgrows the dialog body; the header stays pinned.
class ProjectsListSheet extends StatefulWidget {
  const ProjectsListSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ProjectsListSheet(),
    );
  }

  @override
  State<ProjectsListSheet> createState() => _ProjectsListSheetState();
}

class _ProjectsListSheetState extends State<ProjectsListSheet> {
  final TextEditingController _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _addProject() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    final ok = await context.read<VaultCubit>().createProject(name: name);
    if (!ok || !mounted) return;
    // Find the project we just created so we can drill into its detail
    // sheet — the cubit appends new projects to the end of the list, and
    // names within a workspace are unique enough to disambiguate.
    final data = context.read<VaultCubit>().state.data.dataOrNull;
    final created = data?.projects.where((p) => p.name == name).lastOrNull;
    // Push the new project's detail sheet (env management) so the user
    // can immediately add environments — staying on the projects list
    // after Create made the user tap the row again just to do the next
    // logical step. Close THIS dialog first so we don't stack sheets.
    Navigator.of(context).pop();
    if (created != null) {
      await ProjectDetailSheet.show(context, existingProjectId: created.id);
    }
  }

  Future<void> _deleteProject(Project project) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteProjectTitle,
      body: context.tr.deleteProjectBody(project.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteProject(project.id);
  }

  Future<void> _openProject(Project project) async {
    // Close this sheet first so the user has a single-sheet context —
    // stacking sheets gets disorienting on phones. The project detail
    // sheet handles its own close → returns the user to the chat (since
    // they typically arrive here from the chat env picker).
    Navigator.of(context).pop();
    await ProjectDetailSheet.show(
      context,
      existingProjectId: project.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = context.watch<VaultCubit>().state;
    final data = state.data.dataOrNull;
    final projects = data?.projects ?? const <Project>[];

    // Dialog body sits at ~60% of the screen height (slightly past
    // mid-screen so the user can comfortably scroll a handful of
    // projects). The Flutter [Dialog] widget already adds
    // `MediaQuery.viewInsets` to its own padding when the keyboard
    // opens, so it floats the whole dialog above the keyboard
    // automatically — no inner AnimatedPadding needed (that was
    // doubling the offset and overflowing the column by a few px).
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenH * 0.6).clamp(380.0, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: ConstrainedBox(
        // Match the cap used by ProjectDetailSheet so the dialog
        // doesn't stretch the full width on foldables / landscape
        // phones — the project list becomes hard to scan past ~520 px.
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header — eyebrow + title + Close ──────────────────
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
                            letterSpacing: 1.4,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr.projectsTitle,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GhostButton(
                    label: context.tr.close,
                    minHeight: 36,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: s.cardBorder, height: 1),
              const SizedBox(height: 18),
              // ── Quick "Add project" inline form ─────────────────────
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      hint: context.tr.addProjectHint,
                      controller: _newName,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addProject(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PrimaryButton(
                    label: context.tr.addProject,
                    onPressed: state.actionInFlight ? null : _addProject,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // ── Project list ─────────────────────────────────────────
              Flexible(
                child: projects.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: AppIcons.projects,
                          title: context.tr.noStoredCredentialsTitle,
                          body: context.tr.noStoredCredentialsBody,
                        ),
                      )
                    : ListView.separated(
                        // No `shrinkWrap: true` — the parent `Flexible`
                        // already bounds the ListView's height to the
                        // sheet's remaining space, so leaving shrinkWrap
                        // on disables the lazy builder for nothing and
                        // forces every row into memory upfront (bad for
                        // workspaces with 30+ projects).
                        padding: EdgeInsets.zero,
                        // Pre-render rows that haven't scrolled into
                        // view yet so the sheet's scroll feels like
                        // everything was already there.
                        cacheExtent: 1500,
                        itemCount: projects.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final project = projects[index];
                          final envCount = project.environments.length;
                          return _ProjectRow(
                            project: project,
                            envCount: envCount,
                            onTap: () => _openProject(project),
                            onDelete: () => _deleteProject(project),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One project card inside the [ProjectsListSheet]. Whole surface is
/// tappable to open the project's detail sheet; trailing Delete button
/// fires its own confirm dialog without bubbling the tap.
class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.envCount,
    required this.onTap,
    required this.onDelete,
  });

  final Project project;
  final int envCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardR,
        child: Ink(
          decoration: BoxDecoration(
            color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
            borderRadius: AppRadius.cardR,
            border: Border.all(color: s.cardBorder),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr.environmentCount(envCount),
                      style: context.text.bodySmall?.copyWith(
                        color: s.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GhostButton(
                label: context.tr.delete,
                minHeight: 36,
                tone: GhostButtonTone.danger,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
