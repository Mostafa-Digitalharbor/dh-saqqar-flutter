part of 'chat_context.dart';

/// "Companies & environments" sheet. [selectedEnvId] marks the current
/// environment; picking another calls [onSelect].
Future<void> showCompaniesSheet(
  BuildContext context, {
  required String? selectedEnvId,
  required Future<void> Function(Environment env) onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.figBlack.withValues(alpha: AppAlphas.a55),
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
    final c = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dark,
        title: Text(
          context.tr.figRenameCompany,
          style: Fig.t(ctx, color: AppColors.figWhite, size: AppFontSizes.reading),
        ),
        content: TextField(
          controller: c,
          style: Fig.t(ctx, color: AppColors.figWhite),
          decoration: const InputDecoration(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr.figCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(context.tr.figSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<VaultCubit>().renameProject(id: p.id, name: name);
  }

  Future<void> _delete(Project p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dark,
        title: Text(
          context.tr.figDelete(p.name),
          style: Fig.t(ctx, color: AppColors.figWhite, size: AppFontSizes.reading),
        ),
        content: Text(
          context.tr.figItsEnvironmentsAndCredentialsWillBe,
          style: Fig.t(ctx, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr.figCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr.figDelete2,
              style: const TextStyle(color: Fig.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
                      for (final p in projects) _company(context, p),
                      const SizedBox(height: AppSpacing.s6),
                      GestureDetector(
                        onTap: () => showAddEnvironmentSheet(context),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(FigMetrics.radFig24),
                            border: Border.all(
                              color: AppColors.figWhite.withValues(alpha: AppAlphas.a20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.plus,
                                size: AppIconSizes.small,
                                color: Fig.accentBlue,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                context.tr.figAddCompany,
                                style: Fig.t(
                                  context,
                                  size: AppFontSizes.microCaps,
                                  color: Fig.accentBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _circleBtn(IconData i, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: FigMetrics.size32, height: FigMetrics.size32,
      margin: const EdgeInsetsDirectional.only(start: AppSpacing.s6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: AppAlphas.a50)),
      ),
      child: Icon(i, size: AppIconSizes.compact, color: c),
    ),
  );

  Widget _company(BuildContext context, Project p) {
    final open = _open == p.id;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a04),
        borderRadius: BorderRadius.circular(AppRadius.heroPlate),
        // One colour on all four sides: a rounded box refuses a border whose
        // sides differ (it throws while painting and the whole card went
        // blank when opened), so the "open" accent is the border colour
        // itself rather than a heavier top edge.
        border: Border.all(
          color: open ? Fig.blueSoft : Colors.white12,
          width: open ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = open ? null : p.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s12, AppSpacing.s14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fig.t(context, size: AppFontSizes.dense, color: AppColors.figWhite),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          context.tr.environmentCount(p.environments.length),
                          style: Fig.t(
                            context,
                            size: FigMetrics.fontFig8U5,
                            color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _circleBtn(
                    LucideIcons.pencil,
                    AppColors.figCFF6C8CFF,
                    () => _rename(p),
                  ),
                  _circleBtn(LucideIcons.trash2, Fig.danger, () => _delete(p)),
                  const SizedBox(width: AppSpacing.s10),
                  Icon(
                    open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: AppIconSizes.regular,
                    color: AppColors.figWhite,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in p.environments)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        setState(() => _selected = e.id);
                        await widget.onSelect(e);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s9,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: FigMetrics.size18, height: FigMetrics.size18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selected == e.id
                                      ? Fig.accentBlue
                                      : Colors.white38,
                                  width: AppBorderWidths.medium,
                                ),
                              ),
                              child: _selected == e.id
                                  ? Center(
                                      child: Container(
                                        width: FigMetrics.size9, height: FigMetrics.size9,
                                        decoration: const BoxDecoration(
                                          color: Fig.accentBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: Fig.t(
                                      context,
                                      size: FigMetrics.fontFig10U5,
                                      weight: FontWeight.w600,
                                      color: AppColors.figWhite,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s3),
                                  Row(
                                    children: [
                                      Container(
                                        width: FigMetrics.size5, height: FigMetrics.size5,
                                        decoration: BoxDecoration(
                                          color: e.hasXmlrpc
                                              ? Fig.success
                                              : Colors.white38,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s5),
                                      Text(
                                        '${e.hasXmlrpc ? context.tr.figOdooConnected : context.tr.figNotConnected} · ${e.readOnly ? context.tr.figReadOnly : (e.isLive ? context.tr.figLive : context.tr.figStaging)}',
                                        style: Fig.t(
                                          context,
                                          size: FigMetrics.fontFig8,
                                          color: AppColors.figWhite.withValues(
                                            alpha: AppAlphas.a50,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_selected == e.id)
                              Text(
                                context.tr.figCurrent,
                                style: Fig.t(
                                  context,
                                  size: FigMetrics.fontFig8U5,
                                  color: Fig.success,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s4),
                  GestureDetector(
                    onTap: () => showAddEnvironmentSheet(context, project: p),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.plus,
                          size: AppIconSizes.compact,
                          color: Fig.accentBlue,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            context.tr.figAddEnvironment,
                            style: Fig.t(
                              context,
                              size: FigMetrics.fontFig9,
                              color: Fig.accentBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
