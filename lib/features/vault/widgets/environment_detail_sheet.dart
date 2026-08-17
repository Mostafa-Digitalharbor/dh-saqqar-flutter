import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/credential_models.dart';
import '../data/project_models.dart';
import '../view_model/vault_cubit.dart';
import 'credential_form.dart';

/// Environment popup — breadcrumb + rename + tab strip per credential
/// kind, with a [CredentialForm] inside each tab. Mirrors the web's
/// `environmentPopup` exactly.
///
/// Flag toggles (Live / Read-only / Auto-approve) and the Delete action
/// live one level up on the env row inside the project popup (see
/// `_EnvRow` in `project_detail_sheet.dart`). The env detail is purely a
/// credential editor.
class EnvironmentDetailSheet extends StatefulWidget {
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
  State<EnvironmentDetailSheet> createState() => _EnvironmentDetailSheetState();
}

class _EnvironmentDetailSheetState extends State<EnvironmentDetailSheet> {
  late final TextEditingController _name;
  bool _initialised = false;

  /// Audience mode (web parity). Defaults to the simple "I'm a user" view,
  /// which exposes only the Odoo connection; "I'm a developer" reveals the
  /// technical kinds (PostgreSQL / Server shell / GitHub).
  bool _developerMode = false;

  static const _kinds = CredentialKind.values;
  static const _userKinds = [CredentialKind.xmlrpc];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    // Lazy-fetch the env's credentials — the projects-list endpoint
    // doesn't include them so the credential forms would otherwise
    // render against an empty cache. Safe to call multiple times.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<VaultCubit>()
          .loadEnvironmentCredentials(widget.environmentId);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ensureName(Environment env) {
    if (_initialised) return;
    _name.text = env.name;
    _initialised = true;
  }

  void _commitRename(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    // Skip the PATCH when the name didn't actually change (blur fires even
    // when the user just tapped in and out) — no point spending the request.
    final current = context
        .read<VaultCubit>()
        .state
        .data
        .dataOrNull
        ?.environmentById(widget.environmentId)
        ?.name;
    if (current != null && trimmed == current) return;
    context
        .read<VaultCubit>()
        .updateEnvironment(id: widget.environmentId, name: trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = context.watch<VaultCubit>().state;
    final data = state.data.dataOrNull;
    final env = data?.environmentById(widget.environmentId);
    final project = env != null ? data?.projectById(env.projectId) : null;

    final schemas = data?.schemas ?? const <CredentialSchema>[];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    if (env == null) {
      // Env may have been deleted while this sheet was open, or data is
      // still loading — render an empty surface so we don't crash on
      // missing lookups.
      return const SizedBox.shrink();
    }

    _ensureName(env);
    final projectName = project?.name ?? '—';

    // User mode shows only the Odoo connection; developer mode reveals all
    // kinds. Keyed below so the TabController remounts with the right length
    // when the mode flips (avoids an index-out-of-range on 4→1 tabs).
    final visibleKinds = _developerMode ? _kinds : _userKinds;

    return DefaultTabController(
      key: ValueKey(_developerMode),
      length: visibleKinds.length,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s18,
              AppSpacing.s4,
              AppSpacing.s18,
              AppSpacing.s22 + viewInsets,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetDragHandle(),
                const SizedBox(height: AppSpacing.s14),
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
                                  size: AppIconSizes.dense, color: s.muted),
                              const SizedBox(width: AppSpacing.s6),
                              Flexible(
                                child: Text(
                                  '$projectName › ${env.name}',
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
                          const SizedBox(height: AppSpacing.s4),
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
                const SizedBox(height: AppSpacing.s12),
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
                const SizedBox(height: AppSpacing.s14),
                // Audience toggle (web parity): "I'm a user" shows only the
                // Odoo connection; "I'm a developer" reveals every kind.
                _AudienceToggle(
                  developerMode: _developerMode,
                  onChanged: (dev) {
                    if (dev == _developerMode) return;
                    setState(() => _developerMode = dev);
                  },
                ),
                const SizedBox(height: AppSpacing.s14),
                // Per-kind credential tabs — XML-RPC / PostgreSQL /
                // Server shell / GitHub. Each tab's form is schema-driven
                // from the loaded credential schemas.
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
                      for (final k in visibleKinds)
                        Tab(text: _kindLabel(context, k, schemas)),
                    ],
                  ),
                ),
                Flexible(
                  child: TabBarView(
                    children: [
                      for (final k in visibleKinds)
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

  /// Resolve the human label for a kind. Prefers a localized app string so
  /// an Arabic UI doesn't show the server's English `schema.label`; falls
  /// back to the server label, then the enum name.
  String _kindLabel(
    BuildContext context,
    CredentialKind kind,
    List<CredentialSchema> schemas,
  ) {
    String serverLabel = kind.name;
    for (final s in schemas) {
      if (s.kind == kind) {
        serverLabel = s.label;
        break;
      }
    }
    final key = switch (kind) {
      CredentialKind.xmlrpc => 'credKindXmlrpc',
      CredentialKind.postgres => 'credKindPostgres',
      CredentialKind.serverShell => 'credKindServerShell',
      CredentialKind.github => 'credKindGithub',
    };
    return context.tr.lookup(key, fallback: serverLabel);
  }
}

/// Two-segment pill toggle: "I'm a user" / "I'm a developer". Mirrors the
/// web's audience switch above the credential tabs — user mode hides the
/// technical kinds, developer mode reveals them.
class _AudienceToggle extends StatelessWidget {
  const _AudienceToggle({
    required this.developerMode,
    required this.onChanged,
  });

  final bool developerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Row(
        children: [
          _segment(context, label: context.tr.credModeUser, selected: !developerMode, onTap: () => onChanged(false)),
          _segment(context, label: context.tr.credModeDeveloper, selected: developerMode, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final s = context.saqqar;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.control,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.primaryCta : null,
            borderRadius: AppRadius.pillR,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: selected ? Colors.white : s.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
