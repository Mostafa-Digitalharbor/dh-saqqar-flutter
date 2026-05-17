import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../demo/saqqar_demo_data.dart';
import '../state/vault_controller.dart';
import 'credential_form.dart';

/// Environment popup — breadcrumb + rename + tab strip per credential
/// kind, with a [CredentialForm] inside each tab. Mirrors the web's
/// `environmentPopup` exactly.
///
/// Flag toggles (Live / Read-only / Auto-approve) and the Delete action
/// live one level up on the env row inside the project popup (see
/// [_EnvRow] in `project_detail_sheet.dart`). The env detail is purely a
/// credential editor.
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
                // Header — breadcrumb ("Project › Env") on the start side,
                // explicit X close on the end side. Matches the web layout
                // exactly. The bold env title sits below the breadcrumb.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.server,
                                  size: 13, color: s.muted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${project.name} › ${env.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      context.text.labelMedium?.copyWith(
                                    color: s.muted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            env.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr.close,
                      icon: const Icon(AppIcons.close),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Rename field — the env name displayed above is the
                // last-saved value; this lets the user update it without
                // backing out to the project popup. Submitting commits the
                // rename via the controller.
                AppTextField(
                  controller: _name,
                  hint: context.tr.environment,
                  prefixIcon: AppIcons.edit,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _commitRename,
                ),
                const SizedBox(height: 14),
                // Per-kind credential tabs — XML-RPC / PostgreSQL /
                // Server shell / GitHub. Each tab's form is schema-driven
                // from `demoCredentialSchemas`.
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// `_FlagsRow` + `_FlagToggle` were removed on 2026-05-16 — the three env
// flags (Live / Read-only / Auto-approve) now live exclusively on the env
// card row inside the project popup (see `project_detail_sheet.dart`),
// mirroring the web. Surfacing them in two places was redundant and made
// the env detail sheet feel busy.
