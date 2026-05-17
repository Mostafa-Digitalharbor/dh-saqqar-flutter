import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';
import '../state/vault_controller.dart';
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
class ProjectsListSheet extends ConsumerStatefulWidget {
  const ProjectsListSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ProjectsListSheet(),
    );
  }

  @override
  ConsumerState<ProjectsListSheet> createState() => _ProjectsListSheetState();
}

class _ProjectsListSheetState extends ConsumerState<ProjectsListSheet> {
  final TextEditingController _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  void _toast(String message, {ToastVariant variant = ToastVariant.info}) {
    AppToast.show(context, message: message, variant: variant);
  }

  Future<void> _addProject() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    final newId =
        ref.read(vaultControllerProvider.notifier).createProject(name: name);
    if (!mounted) return;
    _toast(context.tr.projectSavedToast, variant: ToastVariant.success);
    // Push the new project's detail sheet (env management) so the user
    // can immediately add environments — staying on the projects list
    // after Create made the user tap the row again just to do the next
    // logical step. Close THIS dialog first so we don't stack sheets.
    Navigator.of(context).pop();
    await ProjectDetailSheet.show(context, existingProjectId: newId);
  }

  Future<void> _deleteProject(DemoProject project) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteProjectTitle,
      body: context.tr.deleteProjectBody(project.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    ref.read(vaultControllerProvider.notifier).deleteProject(project.id);
    if (!mounted) return;
    setState(() {});
    _toast(context.tr.projectDeletedToast);
  }

  Future<void> _openProject(DemoProject project) async {
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
    final state = ref.watch(vaultControllerProvider);
    final projects = state.projects;

    // Dialog body sits at ~60% of the screen height (slightly past
    // mid-screen so the user can comfortably scroll a handful of
    // projects). When the keyboard opens (adding a new project), the
    // `MediaQuery.viewInsets` shifts the dialog up — the inset Padding
    // below preserves a 16-dp gap above the keyboard.
    final screenH = MediaQuery.sizeOf(context).height;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = (screenH * 0.6).clamp(380.0, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: AnimatedPadding(
        // Lift above the keyboard with a smooth slide rather than the
        // default jank-jump Flutter dialogs do.
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                          'PROJECT',
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
                    onPressed: _addProject,
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
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: projects.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final project = projects[index];
                          final envCount = state
                              .environmentsForProject(project.id)
                              .length;
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

  final DemoProject project;
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
