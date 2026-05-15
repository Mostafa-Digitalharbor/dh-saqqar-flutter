import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
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
import 'environment_detail_sheet.dart';

/// Project popup (web parity). Two modes:
/// - `existingProject: null` → create-project form (single field).
/// - `existingProject: project` → rename + nested env list with inline
///    flags, plus an "Add environment" form and a "Delete project" CTA.
///
/// Tapping an env's "Open" button closes this sheet and pushes the
/// [EnvironmentDetailSheet] so the user can manage that env's credentials.
class ProjectDetailSheet extends ConsumerStatefulWidget {
  const ProjectDetailSheet({super.key, this.existingProjectId});

  final String? existingProjectId;

  static Future<void> show(
    BuildContext context, {
    String? existingProjectId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ProjectDetailSheet(existingProjectId: existingProjectId),
    );
  }

  @override
  ConsumerState<ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends ConsumerState<ProjectDetailSheet> {
  late final TextEditingController _name;
  final TextEditingController _newEnv = TextEditingController();

  bool get _isNew => widget.existingProjectId == null;

  @override
  void initState() {
    super.initState();
    final initialName = _isNew
        ? ''
        : ref.read(vaultControllerProvider).projects.firstWhere(
              (p) => p.id == widget.existingProjectId,
              orElse: () => const DemoProject(id: 'missing', name: ''),
            ).name;
    _name = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    _newEnv.dispose();
    super.dispose();
  }

  void _toast(String message, {ToastVariant variant = ToastVariant.info}) {
    AppToast.show(context, message: message, variant: variant);
  }

  Future<void> _saveProject() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (_isNew) {
      ref.read(vaultControllerProvider.notifier).createProject(name: name);
    } else {
      ref.read(vaultControllerProvider.notifier).renameProject(
            projectId: widget.existingProjectId!,
            name: name,
          );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast(context.tr.projectSavedToast, variant: ToastVariant.success);
  }

  Future<void> _addEnv() async {
    final name = _newEnv.text.trim();
    if (name.isEmpty || widget.existingProjectId == null) return;
    ref.read(vaultControllerProvider.notifier).createEnvironment(
          projectId: widget.existingProjectId!,
          name: name,
        );
    _newEnv.clear();
    if (!mounted) return;
    _toast(context.tr.environmentSavedToast, variant: ToastVariant.success);
  }

  Future<void> _deleteProject() async {
    final state = ref.read(vaultControllerProvider);
    final project = state.projects.firstWhere(
      (p) => p.id == widget.existingProjectId,
      orElse: () => const DemoProject(id: 'missing', name: ''),
    );
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteProjectTitle,
      body: context.tr.deleteProjectBody(project.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    ref
        .read(vaultControllerProvider.notifier)
        .deleteProject(widget.existingProjectId!);
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast(context.tr.projectDeletedToast);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = ref.watch(vaultControllerProvider);
    final envs = _isNew
        ? <DemoEnvironment>[]
        : state.environmentsForProject(widget.existingProjectId!);

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 22 + viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.primaryCta,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isNew ? context.tr.addProject : context.tr.manageProjects,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: context.tr.projectName,
                        hint: context.tr.addProjectHint,
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveProject(),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: _isNew
                            ? context.tr.addProject
                            : context.tr.save,
                        icon: AppIcons.save,
                        expand: true,
                        onPressed: _saveProject,
                      ),
                      if (!_isNew) ...[
                        const SizedBox(height: 22),
                        Text(
                          context.tr.environment,
                          style: context.text.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (envs.isEmpty)
                          EmptyState(
                            icon: AppIcons.server,
                            title: context.tr.noEnvironments,
                          )
                        else
                          for (final env in envs)
                            _EnvRow(
                              env: env,
                              onOpen: () {
                                Navigator.of(context).pop();
                                EnvironmentDetailSheet.show(
                                  context,
                                  environmentId: env.id,
                                );
                              },
                            ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                hint: context.tr.addEnvironmentHint,
                                controller: _newEnv,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _addEnv(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            PrimaryButton(
                              label: context.tr.addEnvironment,
                              icon: AppIcons.plus,
                              onPressed: _addEnv,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: s.danger.withValues(alpha: 0.06),
                            borderRadius: AppRadius.cardR,
                            border: Border.all(
                              color: s.danger.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.warning,
                                  size: 18,
                                  color: s.danger,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr.deleteProjectBody(_name.text),
                                    style: context.text.bodySmall?.copyWith(
                                      color: s.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GhostButton(
                                  label: context.tr.delete,
                                  icon: AppIcons.trash,
                                  tone: GhostButtonTone.danger,
                                  onPressed: _deleteProject,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One env row inside the project popup. Tappable header opens the env
/// detail sheet; the row also exposes the 3 instant flag toggles
/// (`is_live`, `read_only`, `auto_approve`) so the user can flip them
/// without drilling into the env first — matches the web's project
/// popup row.
class _EnvRow extends ConsumerWidget {
  const _EnvRow({required this.env, required this.onOpen});

  final DemoEnvironment env;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    final notifier = ref.read(vaultControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardR,
        child: InkWell(
          borderRadius: AppRadius.cardR,
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
              borderRadius: AppRadius.cardR,
              border: Border.all(color: s.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.server,
                      color: env.isLive ? s.danger : s.brandCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        env.name,
                        style: context.text.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: onOpen,
                      icon: const Icon(AppIcons.chevronRight),
                      tooltip: context.tr.openEnvironment,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _FlagPill(
                      label: context.tr.flagLive,
                      value: env.isLive,
                      activeColor: s.danger,
                      onChanged: (v) =>
                          notifier.setEnvFlag(envId: env.id, isLive: v),
                    ),
                    _FlagPill(
                      label: context.tr.flagReadOnly,
                      value: env.readOnly,
                      activeColor: s.muted,
                      onChanged: (v) =>
                          notifier.setEnvFlag(envId: env.id, readOnly: v),
                    ),
                    _FlagPill(
                      label: context.tr.flagAutoApprove,
                      value: env.autoApprove,
                      activeColor: s.warning,
                      onChanged: (v) =>
                          notifier.setEnvFlag(envId: env.id, autoApprove: v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "label + tiny switch" pair used in the env row. Tapping the
/// label or the switch flips the flag instantly (no confirm), matching
/// the web's behaviour.
class _FlagPill extends StatelessWidget {
  const _FlagPill({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 18,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeThumbColor: activeColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: value ? activeColor : s.muted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

