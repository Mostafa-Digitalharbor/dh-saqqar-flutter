part of 'chat_context.dart';

/// "Add environment" (existing [project]) / "Add company environment" (new
/// company) dark sheet.
Future<void> showAddEnvironmentSheet(BuildContext context, {Project? project}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _AddEnvironment(project: project),
  );
}

class _AddEnvironment extends StatefulWidget {
  const _AddEnvironment({this.project});

  final Project? project;

  @override
  State<_AddEnvironment> createState() => _AddEnvironmentState();
}

class _AddEnvironmentState extends State<_AddEnvironment> {
  final _company = TextEditingController();
  final _label = TextEditingController(text: 'Production');
  final _url = TextEditingController();
  final _db = TextEditingController();
  final _user = TextEditingController();
  final _secret = TextEditingController();
  EnvMode _mode = EnvMode.live;
  bool _apiKey = false;
  bool _busy = false;
  bool _detecting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_company, _label, _url, _db, _user, _secret]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _detect() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() => _detecting = true);
    try {
      final dbs = await context.read<CredentialsApi>().listDatabases(url);
      if (!mounted) return;
      if (dbs.isNotEmpty) _db.text = dbs.first;
    } catch (_) {
      // Manual entry stays available.
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _save() async {
    final newCompany = widget.project == null;
    if ((newCompany && _company.text.trim().isEmpty) ||
        _label.text.trim().isEmpty ||
        _url.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _secret.text.isEmpty) {
      setState(() => _error = context.tr.figPleaseFillInEveryField);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<VaultRepository>();
    final vault = context.read<VaultCubit>();
    final nav = Navigator.of(context);
    try {
      final projectId =
          widget.project?.id ??
          (await repo.createProject(name: _company.text.trim())).id;
      final env = await repo.createEnvironment(
        projectId: projectId,
        name: _label.text.trim(),
        isLive: _mode == EnvMode.live,
        readOnly: _mode == EnvMode.readOnly,
        autoApprove: _mode == EnvMode.autoApprove,
      );
      await repo.upsertEnvironmentCredential(
        environmentId: env.id,
        kind: CredentialKind.xmlrpc,
        payload: {
          'url': _url.text.trim(),
          'db': _db.text.trim(),
          'username': _user.text.trim(),
          'secret': _secret.text,
          'auth_type': _apiKey ? 'api_key' : 'password',
        },
      );
      await vault.load();
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiErrorMapper.message(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final newCompany = widget.project == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        newCompany
                            ? context.tr.figAddCompanyEnvironment
                            : context.tr.figAddEnvironment,
                        style: Fig.t(
                          context,
                          size: 17,
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
                const SizedBox(height: AppSpacing.s4),
                Text(
                  newCompany
                      ? context.tr.figConnectANewCompanyWithoutLeaving
                      : context.tr.figAddAnotherOdooEnvironmentTo(
                          widget.project!.name,
                        ),
                  style: Fig.t(
                    context,
                    size: 9,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.s18),
                if (newCompany) ...[
                  FigField(
                    dark: true,
                    label: context.tr.figCompanyName,
                    hint: context.tr.figCompanyName,
                    controller: _company,
                    height: 52,
                  ),
                  const SizedBox(height: AppSpacing.s14),
                ],
                FigField(
                  dark: true,
                  label: context.tr.figLabelEnvironmentName,
                  hint: context.tr.figEnvNameHint,
                  controller: _label,
                  height: 52,
                ),
                const SizedBox(height: AppSpacing.s14),
                Text(
                  context.tr.figEnvironmentType,
                  style: Fig.t(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                EnvTypePicker(
                  dark: true,
                  value: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: AppSpacing.s16),
                ConnectionTabs(
                  dark: true,
                  apiKey: _apiKey,
                  onChanged: (v) => setState(() => _apiKey = v),
                ),
                const SizedBox(height: AppSpacing.s14),
                FigField(
                  dark: true,
                  label: context.tr.figLabelUrl,
                  hint: context.tr.figHintOdooUrl,
                  controller: _url,
                  height: 52,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: AppSpacing.s14),
                Text(
                  context.tr.figDatabase,
                  style: Fig.t(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    Expanded(
                      child: FigField(
                        dark: true,
                        label: '',
                        hint: context.tr.figHintDbName,
                        controller: _db,
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    GestureDetector(
                      onTap: _detecting ? null : _detect,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s14,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9DFEF),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: _detecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 13,
                                    color: Fig.tileText,
                                  ),
                                  const SizedBox(width: AppSpacing.s6),
                                  Flexible(
                                    child: Text(
                                      context.tr.figDetectDatabases,
                                      style: Fig.t(
                                        context,
                                        size: 10.5,
                                        color: Fig.tileText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s14),
                FigField(
                  dark: true,
                  label: context.tr.figUsername,
                  hint: context.tr.figHintOdooUser,
                  controller: _user,
                  height: 52,
                ),
                const SizedBox(height: AppSpacing.s14),
                Text(
                  context.tr.figAuthentication,
                  style: Fig.t(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                FigDropdown(
                  dark: true,
                  height: 52,
                  value: _apiKey
                      ? context.tr.figLabelApiKey
                      : context.tr.figPassword2,
                  options: [context.tr.figPassword2, context.tr.figLabelApiKey],
                  onChanged: (v) =>
                      setState(() => _apiKey = v == context.tr.figLabelApiKey),
                ),
                const SizedBox(height: AppSpacing.s14),
                FigField(
                  dark: true,
                  label: _apiKey
                      ? context.tr.figLabelApiKey
                      : context.tr.figPassword2,
                  hint: _apiKey
                      ? context.tr.figEnterOdooApiKey
                      : context.tr.figEnterOdooPassword,
                  controller: _secret,
                  height: 52,
                  obscure: true,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s10),
                    child: Text(
                      _error!,
                      style: Fig.t(
                        context,
                        size: 11,
                        color: const Color(0xFFFF8A78),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.s20),
                FigButton(
                  label: context.tr.figConnectInitialize,
                  height: 52,
                  loading: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
