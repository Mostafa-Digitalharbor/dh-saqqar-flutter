part of 'chat_context.dart';

/// "Companies & environments" sheet. [selectedEnvId] marks the current
/// environment; picking another calls [onSelect].
Future<void> showCompaniesSheet(
  BuildContext context, {
  required String? selectedEnvId,
  required Future<void> Function(Environment env) onSelect,
}) {
  return showFigSheet<void>(
    context,
    builder: (_) =>
        _CompaniesSheet(selectedEnvId: selectedEnvId, onSelect: onSelect),
  );
}

class _CompaniesSheet extends StatefulWidget {
  const _CompaniesSheet({required this.selectedEnvId, required this.onSelect});

  final String? selectedEnvId;
  final Future<void> Function(Environment env) onSelect;

  @override
  State<_CompaniesSheet> createState() => _CompaniesSheetState();
}

class _CompaniesSheetState extends State<_CompaniesSheet> {
  String? _open;
  late String? _selected = widget.selectedEnvId;

  @override
  void initState() {
    super.initState();
    final vault = context.read<VaultCubit>().state.data.dataOrNull;
    final p = vault?.projects.where(
      (p) => p.environments.any((e) => e.id == widget.selectedEnvId),
    );
    _open = (p != null && p.isNotEmpty) ? p.first.id : null;
  }

  Future<void> _rename(Project p) async {
    final name = await RenameConversationDialog.show(
      context,
      initial: p.name,
      title: context.tr.figRenameCompany,
      hint: context.tr.figCompanyName,
    );
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<VaultCubit>().renameProject(id: p.id, name: name);
  }

  Future<void> _delete(Project p) async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.figDelete(p.name),
      body: context.tr.figItsEnvironmentsAndCredentialsWillBe,
      confirmLabel: context.tr.figDelete2,
      cancelLabel: context.tr.figCancel,
      icon: AppIcons.trash,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteProject(p.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * AppFractions.companiesSheetMax,
      ),
      decoration: const BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(FigMetrics.radFig32)),
      ),
      child: SafeArea(
        top: false,
        child: BlocBuilder<VaultCubit, VaultState>(
          builder: (context, state) {
            final projects =
                state.data.dataOrNull?.projects ?? const <Project>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s22, AppSpacing.s18, AppSpacing.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr.figCompaniesEnvironments,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.avatarInitial,
                            weight: FontWeight.w500,
                            color: AppColors.figWhite,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          LucideIcons.x,
                          color: AppColors.figWhite,
                          size: AppIconSizes.tile,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s16),
                  child: Text(
                    context.tr.figSwitchContextOrManageYourOdoo,
                    style: Fig.t(
                      context,
                      size: FigMetrics.fontFig9,
                      color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s12),
                    children: [
                      for (final p in projects)
                        FigCompanyCard(
                          project: p,
                          open: _open == p.id,
                          pickable: true,
                          selectedEnvId: _selected,
                          onToggle: () => setState(
                            () => _open = _open == p.id ? null : p.id,
                          ),
                          onRename: () => _rename(p),
                          onDelete: () => _delete(p),
                          onEnvTap: (e) async {
                            setState(() => _selected = e.id);
                            await widget.onSelect(e);
                          },
                          onAddEnvironment: () =>
                              showAddEnvironmentSheet(context, project: p),
                        ),
                      const SizedBox(height: AppSpacing.s6),
                      FigAddCompanyButton(
                        onTap: () => showAddEnvironmentSheet(context),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
