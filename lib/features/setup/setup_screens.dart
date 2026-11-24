import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../shared/fig/fig.dart';
import '../auth/view/auth_flow_screen.dart' show AuthFrame;
import '../vault/data/credential_models.dart';
import '../vault/data/credentials_api.dart';
import '../vault/data/vault_repository.dart';
import '../vault/view_model/vault_cubit.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/network/api_error_mapper.dart';
import '../../shared/widgets/app_toast.dart';
import '../../core/constants/ui_strings.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/fig_metrics.dart';
import 'setup_widgets.dart';

export 'setup_widgets.dart';

/// Wizard step 1 — "What is the name of your company?".
class CompanyNameScreen extends StatefulWidget {
  const CompanyNameScreen({super.key});

  @override
  State<CompanyNameScreen> createState() => _CompanyNameScreenState();
}

class _CompanyNameScreenState extends State<CompanyNameScreen> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    final v = _name.text.trim();
    if (v.isEmpty) {
      setState(() => _error = context.tr.figMustEnterCompanyName);
      return;
    }
    context.push(RouteNames.setupEnvironmentPath, extra: v);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: AuthFrame(
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(RouteNames.homePath),
            progress: 0.1,
            titleGap: 52,
            subtitleGap: 12,
            bodyGap: 70,
            title: context.tr.figWhatIsTheNameOfYour,
            subtitle: context.tr.figLetSCreateYourWorkspaceYou,
            footer: context.tr.figSaqqarSecurelyConnectsToYourExisting,
            children: [
              FigField(
                label: context.tr.figCompanyName,
                hint: context.tr.figEGElNadaCompany,
                controller: _name,
                error: _error,
                height: 56,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _next(),
              ),
              SizedBox(height: _error != null ? 44 : 50),
              FigButton(
                label: context.tr.figNext,
                height: 54,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wizard step 2 — connect the first Odoo environment.
class ConnectEnvironmentScreen extends StatefulWidget {
  const ConnectEnvironmentScreen({super.key, required this.companyName});

  final String companyName;

  @override
  State<ConnectEnvironmentScreen> createState() =>
      _ConnectEnvironmentScreenState();
}

class _ConnectEnvironmentScreenState extends State<ConnectEnvironmentScreen> {
  final _label = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _secret = TextEditingController();
  final _db = TextEditingController();
  EnvMode _mode = EnvMode.live;
  bool _apiKey = false;
  bool _busy = false;

  /// Shown only after auto-detection failed: some servers block listing their
  /// databases, and guessing a name from the host would send the backend a
  /// database that does not exist.
  bool _askDb = false;
  String? _labelErr, _urlErr, _userErr, _secretErr;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _user.dispose();
    _secret.dispose();
    _db.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final label = _label.text.trim();
    final url = _url.text.trim();
    final user = _user.text.trim();
    final secret = _secret.text;
    final req = context.tr.figRequired;
    setState(() {
      _labelErr = label.isEmpty ? req : null;
      _urlErr = url.isEmpty ? req : null;
      _userErr = user.isEmpty ? req : null;
      _secretErr = secret.isEmpty ? req : null;
    });
    if (label.isEmpty || url.isEmpty || user.isEmpty || secret.isEmpty) return;
    final repo = context.read<VaultRepository>();
    final creds = context.read<CredentialsApi>();
    final vault = context.read<VaultCubit>();
    final nav = GoRouter.of(context);
    final tr = context.tr;
    setState(() => _busy = true);

    // Resolve the database before anything is written server-side: a typed
    // name wins, else ask the server, else hand the question to the user.
    var db = _db.text.trim();
    if (db.isEmpty) {
      try {
        final dbs = await creds.listDatabases(url);
        if (dbs.isNotEmpty) db = dbs.first;
      } catch (_) {}
    }
    if (!mounted) return;
    if (db.isEmpty) {
      // Pre-fill the sub-domain (`acme.odoo.com` → `acme`) — right for Odoo
      // Online, a starting point elsewhere.
      final host =
          Uri.tryParse(
            url.contains('://') ? url : '${UiStrings.httpsScheme}$url',
          )?.host ??
          '';
      setState(() {
        _busy = false;
        _askDb = true;
        _db.text = host.split('.').first;
      });
      AppToast.show(
        context,
        title: tr.figCouldNotDetectDatabase,
        message: tr.figEnterTheDatabaseNameBelow,
        variant: ToastVariant.error,
      );
      return;
    }

    showProcessingDialog(context, widget.companyName);
    String? createdProjectId;
    try {
      final project = await repo.createProject(name: widget.companyName);
      createdProjectId = project.id;
      final env = await repo.createEnvironment(
        projectId: project.id,
        name: label,
        isLive: _mode == EnvMode.live,
        readOnly: _mode == EnvMode.readOnly,
        autoApprove: _mode == EnvMode.autoApprove,
      );
      await repo.upsertEnvironmentCredential(
        environmentId: env.id,
        kind: CredentialKind.xmlrpc,
        payload: {
          'url': url,
          'db': db,
          'username': user,
          'secret': secret,
          'auth_type': _apiKey ? 'api_key' : 'password',
        },
      );
      await vault.load();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // processing dialog
      nav.go(RouteNames.homePath);
    } catch (e) {
      // Roll back the half-created workspace so a retry doesn't pile up
      // orphaned projects/environments on the server.
      final orphan = createdProjectId;
      if (orphan != null) {
        try {
          await repo.deleteProject(orphan);
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _busy = false);
      AppToast.show(
        context,
        title: context.tr.figCouldNotConnectCheckTheUrl,
        message: ApiErrorMapper.message(context, e),
        variant: ToastVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: AuthFrame(
            onBack: () => context.pop(),
            progress: 0.5,
            titleGap: 52,
            subtitleGap: 12,
            bodyGap: 28,
            title: context.tr.figConnectYourOdooEnvironment,
            subtitle: context.tr.figAddTheConnectionDetailsForYou(
              widget.companyName,
            ),
            children: [
              FigField(
                label: context.tr.figLabelEnvironmentName,
                hint: context.tr.figEGElNadaCompany,
                controller: _label,
                error: _labelErr,
                onChanged: (_) {
                  if (_labelErr != null) setState(() => _labelErr = null);
                },
                height: 54,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s18),
              Text(
                context.tr.figEnvironmentType,
                style: Fig.t(context, size: AppFontSizes.body, color: Fig.navyText),
              ),
              const SizedBox(height: AppSpacing.s8),
              EnvTypePicker(
                value: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: AppSpacing.s20),
              ConnectionTabs(
                apiKey: _apiKey,
                onChanged: (v) => setState(() => _apiKey = v),
              ),
              const SizedBox(height: AppSpacing.s14),
              FigField(
                label: context.tr.figLabelUrl,
                hint: context.tr.figHintOdooUrl,
                controller: _url,
                error: _urlErr,
                onChanged: (_) {
                  if (_urlErr != null) setState(() => _urlErr = null);
                },
                height: 54,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              if (_askDb) ...[
                const SizedBox(height: AppSpacing.s18),
                FigField(
                  label: context.tr.figLabelDatabase,
                  hint: context.tr.figHintDbName,
                  controller: _db,
                  height: 54,
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: AppSpacing.s18),
              FigField(
                label: context.tr.figUsername,
                hint: context.tr.figHintOdooUser,
                controller: _user,
                error: _userErr,
                onChanged: (_) {
                  if (_userErr != null) setState(() => _userErr = null);
                },
                height: 54,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s18),
              Text(
                context.tr.figAuthentication,
                style: Fig.t(context, size: AppFontSizes.body, color: Fig.navyText),
              ),
              const SizedBox(height: AppSpacing.s8),
              FigDropdown(
                value: _apiKey
                    ? context.tr.figLabelApiKey
                    : context.tr.figPassword2,
                options: [context.tr.figPassword2, context.tr.figLabelApiKey],
                onChanged: (v) =>
                    setState(() => _apiKey = v == context.tr.figLabelApiKey),
              ),
              const SizedBox(height: AppSpacing.s18),
              FigField(
                label: _apiKey
                    ? context.tr.figLabelApiKey
                    : context.tr.figPassword2,
                hint: _apiKey
                    ? context.tr.figEnterOdooApiKey
                    : context.tr.figEnterOdooPassword,
                controller: _secret,
                error: _secretErr,
                onChanged: (_) {
                  if (_secretErr != null) setState(() => _secretErr = null);
                },
                height: 54,
                obscure: true,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: AppSpacing.s28),
              FigButton(
                label: context.tr.figConnectInitialize,
                height: 54,
                loading: _busy,
                onPressed: _connect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Processing — your company has been processing" dialog.
void showProcessingDialog(BuildContext context, String company) {
  showFigSheet<void>(
    context,
    builder: (_) => PopScope(
      canPop: false,
      child: FigNotchSheet(
        onClose: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AssetPaths.processPlane,
                width: 150,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: AppSpacing.s14),
              Text(
                context.tr.figProcessing,
                style: Fig.t(context, size: FigMetrics.fontFig30, color: Fig.inkDeep),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text.rich(
                TextSpan(
                  style: Fig.t(context, size: AppFontSizes.caption, color: Fig.tileText),
                  children: [
                    TextSpan(text: context.tr.figYour2),
                    TextSpan(
                      text: company,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: context.tr.figHasBeenProcessing),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
