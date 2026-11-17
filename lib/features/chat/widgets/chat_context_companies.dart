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
    barrierColor: Colors.black.withValues(alpha: 0.55),
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
          style: Fig.t(ctx, color: Colors.white, size: 16),
        ),
        content: TextField(
          controller: c,
          style: Fig.t(ctx, color: Colors.white),
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
          style: Fig.t(ctx, color: Colors.white, size: 16),
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
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  padding: const EdgeInsets.fromLTRB(20, 22, 18, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr.figCompaniesEnvironments,
                          style: Fig.t(
                            context,
                            size: 18,
                            weight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          LucideIcons.x,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    context.tr.figSwitchContextOrManageYourOdoo,
                    style: Fig.t(
                      context,
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      for (final p in projects) _company(context, p),
                      const SizedBox(height: AppSpacing.s6),
                      GestureDetector(
                        onTap: () => showAddEnvironmentSheet(context),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.plus,
                                size: 16,
                                color: Fig.accentBlue,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                context.tr.figAddCompany,
                                style: Fig.t(
                                  context,
                                  size: 12,
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
      width: 32,
      height: 32,
      margin: const EdgeInsetsDirectional.only(start: AppSpacing.s6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Icon(i, size: 14, color: c),
    ),
  );

  Widget _company(BuildContext context, Project p) {
    final open = _open == p.id;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(26),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
                          style: Fig.t(context, size: 14, color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          context.tr.environmentCount(p.environments.length),
                          style: Fig.t(
                            context,
                            size: 8.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _circleBtn(
                    LucideIcons.pencil,
                    const Color(0xFF6C8CFF),
                    () => _rename(p),
                  ),
                  _circleBtn(LucideIcons.trash2, Fig.danger, () => _delete(p)),
                  const SizedBox(width: AppSpacing.s10),
                  Icon(
                    open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selected == e.id
                                      ? Fig.accentBlue
                                      : Colors.white38,
                                  width: 1.4,
                                ),
                              ),
                              child: _selected == e.id
                                  ? Center(
                                      child: Container(
                                        width: 9,
                                        height: 9,
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
                                      size: 10.5,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
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
                                          size: 8,
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
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
                                  size: 8.5,
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
                          size: 14,
                          color: Fig.accentBlue,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            context.tr.figAddEnvironment,
                            style: Fig.t(
                              context,
                              size: 9,
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
