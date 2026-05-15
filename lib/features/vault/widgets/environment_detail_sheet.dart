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
import '../../../shared/widgets/ghost_button.dart';
import '../../demo/saqqar_demo_data.dart';
import '../state/vault_controller.dart';
import 'credential_form.dart';

/// Environment popup — rename + 3 flag switches + tab strip per credential
/// kind, with a [CredentialForm] inside each tab. Matches the web's
/// `environmentPopup`.
///
/// Pass the env id; the sheet pulls live state from [VaultController].
class EnvironmentDetailSheet extends ConsumerStatefulWidget {
  const EnvironmentDetailSheet({super.key, required this.environmentId});

  final String environmentId;

  static Future<void> show(
    BuildContext context, {
    required String environmentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EnvironmentDetailSheet(environmentId: environmentId),
    );
  }

  @override
  ConsumerState<EnvironmentDetailSheet> createState() =>
      _EnvironmentDetailSheetState();
}

class _EnvironmentDetailSheetState
    extends ConsumerState<EnvironmentDetailSheet> {
  late final TextEditingController _name;
  bool _initialised = false;

  static const _kinds = DemoCredentialKind.values;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ensureName(DemoEnvironment env) {
    if (_initialised) return;
    _name.text = env.name;
    _initialised = true;
  }

  Future<void> _deleteEnv(DemoEnvironment env) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteEnvironmentTitle,
      body: context.tr.deleteEnvironmentBody(env.name),
      confirmLabel: context.tr.delete,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    ref.read(vaultControllerProvider.notifier).deleteEnvironment(env.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppToast.show(context, message: context.tr.environmentDeletedToast);
  }

  void _commitRename(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    ref.read(vaultControllerProvider.notifier).renameEnvironment(
          envId: widget.environmentId,
          name: trimmed,
        );
    if (!mounted) return;
    AppToast.show(
      context,
      message: context.tr.environmentSavedToast,
      variant: ToastVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = ref.watch(vaultControllerProvider);
    final env = state.environments.firstWhere(
      (e) => e.id == widget.environmentId,
      orElse: () => const DemoEnvironment(
        id: 'missing',
        projectId: 'missing',
        name: '—',
      ),
    );
    _ensureName(env);
    final project = state.projects.firstWhere(
      (p) => p.id == env.projectId,
      orElse: () => const DemoProject(id: 'missing', name: '—'),
    );

    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return DefaultTabController(
      length: _kinds.length,
      child: SafeArea(
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
                const SizedBox(height: 14),
                Text(
                  // Breadcrumb: Project › Environment
                  '${project.name} › ${env.name}',
                  style: context.text.labelMedium?.copyWith(color: s.muted),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _name,
                  hint: context.tr.environment,
                  prefixIcon: AppIcons.server,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _commitRename,
                ),
                const SizedBox(height: 10),
                _FlagsRow(env: env),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: s.surface2.withValues(
                      alpha: context.isDark ? 0.5 : 0.85,
                    ),
                    borderRadius: AppRadius.cardR,
                    border: Border.all(color: s.cardBorder),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    labelColor: s.brandCyan,
                    unselectedLabelColor: s.muted,
                    indicatorColor: s.brandCyan,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (final k in _kinds) Tab(text: demoCredentialKindLabel(k)),
                    ],
                  ),
                ),
                Flexible(
                  child: TabBarView(
                    children: [
                      for (final k in _kinds)
                        CredentialForm(
                          key: ValueKey('${env.id}-${k.name}'),
                          envId: env.id,
                          kind: k,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GhostButton(
                  label: context.tr.delete,
                  icon: AppIcons.trash,
                  tone: GhostButtonTone.danger,
                  expand: true,
                  onPressed: () => _deleteEnv(env),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three switches that drive the env flags via [VaultController].
/// Toggles are instant (no confirm dialog) — matches the web behaviour.
class _FlagsRow extends ConsumerWidget {
  const _FlagsRow({required this.env});

  final DemoEnvironment env;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            _FlagToggle(
              label: context.tr.flagLive,
              value: env.isLive,
              color: s.danger,
              onChanged: (v) => ref
                  .read(vaultControllerProvider.notifier)
                  .setEnvFlag(envId: env.id, isLive: v),
            ),
            _FlagToggle(
              label: context.tr.flagReadOnly,
              value: env.readOnly,
              color: s.muted,
              onChanged: (v) => ref
                  .read(vaultControllerProvider.notifier)
                  .setEnvFlag(envId: env.id, readOnly: v),
            ),
            _FlagToggle(
              label: context.tr.flagAutoApprove,
              value: env.autoApprove,
              color: s.warning,
              onChanged: (v) => ref
                  .read(vaultControllerProvider.notifier)
                  .setEnvFlag(envId: env.id, autoApprove: v),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagToggle extends StatelessWidget {
  const _FlagToggle({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch(value: value, activeThumbColor: color, onChanged: onChanged),
      ],
    );
  }
}
