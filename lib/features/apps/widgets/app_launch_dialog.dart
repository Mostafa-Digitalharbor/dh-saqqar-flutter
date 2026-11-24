import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/dialog_actions.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../vault/data/project_models.dart';
import '../../vault/view_model/vault_cubit.dart';
import '../data/app_package_models.dart';
import '../../../shared/fig/fig.dart';

/// What the user chose in [AppLaunchDialog].
@immutable
class AppLaunchChoice {
  const AppLaunchChoice({this.environmentId});

  /// The environment to bind, or `null` for "decide later in chat" — which
  /// the launch API explicitly supports (the agent then asks).
  final String? environmentId;
}

/// Asked before a Saqqar App opens its conversation.
///
/// Tapping a package used to launch straight into a chat, which meant the
/// first thing the user saw was an agent asking which database to work on —
/// a question the app already had the answer to, and one that is far easier
/// to answer from a list than by typing a name into a chat.
///
/// Returns `null` when dismissed, so the caller can tell "cancelled" apart
/// from "chose to decide later" (an [AppLaunchChoice] with a null
/// environment). Those are different: one must not launch anything.
class AppLaunchDialog extends StatefulWidget {
  const AppLaunchDialog({super.key, required this.app});

  final SaqqarApp app;

  static Future<AppLaunchChoice?> show(
    BuildContext context, {
    required SaqqarApp app,
  }) {
    return showDialog<AppLaunchChoice>(
      context: context,
      barrierColor: AppColors.scrimBase.withValues(alpha: AppAlphas.a55),
      builder: (_) => AppLaunchDialog(app: app),
    );
  }

  @override
  State<AppLaunchDialog> createState() => _AppLaunchDialogState();
}

class _AppLaunchDialogState extends State<AppLaunchDialog> {
  String? _projectId;
  String? _environmentId;

  List<Project> _projects(BuildContext context) =>
      context.watch<VaultCubit>().state.data.dataOrNull?.projects ??
      const <Project>[];

  /// The selected project, or the only one when there is exactly one — with
  /// a single project there is no choice to make, so pre-selecting it turns
  /// a two-step dialog into a one-step one.
  Project? _selectedProject(List<Project> projects) {
    if (projects.isEmpty) return null;
    if (_projectId == null) {
      return projects.length == 1 ? projects.first : null;
    }
    for (final p in projects) {
      if (p.id == _projectId) return p;
    }
    return null;
  }

  void _pickProject(String id) {
    setState(() {
      _projectId = id;
      // The old environment belongs to the old project; keeping it would
      // launch against a database the user just navigated away from.
      _environmentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final projects = _projects(context);
    final project = _selectedProject(projects);
    final envs = project?.environments ?? const <Environment>[];

    return AppDialogShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s20,
          AppSpacing.s20,
          AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr.appLaunchTitle,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              // The app itself names the stakes: `env_required` is the
              // server's own word on whether this package needs a database.
              widget.app.envRequired
                  ? tr.appLaunchNeedsEnv
                  : tr.appLaunchOptionalEnv,
              style: context.text.bodySmall?.copyWith(
                color: s.muted,
                height: AppLineHeights.body,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            if (projects.isEmpty)
              _Note(text: tr.appLaunchNoProjects)
            else ...[
              // Only worth a section header when there is a choice to make.
              if (projects.length > 1) ...[
                _SectionLabel(tr.appLaunchProject),
                for (final p in projects)
                  _PickRow(
                    label: p.name,
                    selected: p.id == project?.id,
                    onTap: () => _pickProject(p.id),
                  ),
                const SizedBox(height: AppSpacing.s12),
              ],
              _SectionLabel(tr.appLaunchEnvironment),
              if (project == null)
                // An INSTRUCTION, not the section label. This slot used to
                // render `appLaunchProject` — the word "Project" — sitting
                // under the heading "Database", which told the user nothing
                // about why the list was empty or what to do next. Caught on
                // the emulator, not by a test: the dialog's own widget test
                // seeds a project, so this branch never ran.
                _Note(text: tr.appLaunchPickProjectFirst)
              else if (envs.isEmpty)
                _Note(text: tr.appLaunchNoEnvs)
              else
                for (final env in envs)
                  _PickRow(
                    label: env.name,
                    selected: env.id == _environmentId,
                    // LIVE is the one badge that changes what a tap means —
                    // the same warning the chat header carries.
                    trailing: env.isLive
                        ? MiniChip(tr.live, color: s.danger)
                        : null,
                    onTap: () => setState(() => _environmentId = env.id),
                  ),
            ],

            const SizedBox(height: AppSpacing.s20),
            DialogActions(
              // "Decide later" is a real, supported outcome — the launch API
              // takes no environment and the agent asks in-chat — so it is a
              // choice here, not a cancel.
              cancel: FigButton.compact(
                secondary: true,
                label: tr.appLaunchSkip,
                onPressed: () =>
                    Navigator.of(context).pop(const AppLaunchChoice()),
              ),
              confirm: FigButton.compact(
                label: tr.appLaunchStart,
                icon: AppIcons.check,
                // Disabled until there is a database to send: with nothing
                // selected this button and "decide later" would do exactly
                // the same thing, which makes the choice look fake.
                onPressed: _environmentId == null
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(AppLaunchChoice(environmentId: _environmentId)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Text(
        text,
        style: context.text.labelSmall?.copyWith(
          color: context.saqqar.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: AppLetterSpacing.caps,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Text(
        text,
        style: context.text.bodySmall?.copyWith(
          color: context.saqqar.muted,
          height: AppLineHeights.body,
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.buttonR,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s11,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? s.brandCyan.withValues(alpha: AppAlphas.a12)
                  : Colors.transparent,
              borderRadius: AppRadius.buttonR,
              border: Border.all(color: selected ? s.brandCyan : s.border),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? AppIcons.check : AppIcons.database,
                  size: AppIconSizes.small,
                  color: selected ? s.brandCyan : s.muted,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: s.text,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
