import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../data/trial_models.dart';
import '../view_model/trial_cubit.dart';
import '../view_model/trial_state.dart';

/// Managed Odoo trial (API_MOBILE_NEW_ENDPOINTS.md §2) — request a hosted
/// trial, watch it provision, then read the credentials once it's ready.
///
/// Reached as a detail route from Account; the [TrialCubit] is provided
/// per-route so its poll timer is cancelled on pop.
class TrialScreen extends StatefulWidget {
  const TrialScreen({super.key});

  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> {
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _companyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<TrialCubit>().loadStatus());
  }

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final company = _company.text.trim();
    if (company.isEmpty) {
      setState(() => _companyError = context.tr.trialCompanyRequired);
      return;
    }
    setState(() => _companyError = null);
    FocusScope.of(context).unfocus();
    context.read<TrialCubit>().submit(
          TrialRequest(
            companyName: company,
            workEmail: _email.text,
            phone: _phone.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(title: Text(context.tr.trialTitle)),
      body: AmbientBackground(
        child: BlocConsumer<TrialCubit, TrialScreenState>(
          listenWhen: (prev, next) =>
              prev.submitError != next.submitError && next.submitError != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content:
                      Text(ApiErrorMapper.message(context, state.submitError)),
                ),
              );
          },
          builder: _buildBody,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TrialScreenState state) {
    final s = context.saqqar;
    final info = state.status.dataOrNull;

    // Nothing loaded yet.
    if (info == null) {
      if (state.status is DataFailure<TrialInfo>) {
        return ListView(
          padding: const EdgeInsets.only(top: 64),
          children: [
            AppErrorState(
              message: ApiErrorMapper.message(
                context,
                (state.status as DataFailure<TrialInfo>).error,
              ),
              onRetry: () => context.read<TrialCubit>().loadStatus(),
            ),
          ],
        );
      }
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2.4, color: s.muted),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        switch (info.state) {
          TrialState.ready => _ReadyCard(info: info),
          TrialState.pending ||
          TrialState.provisioning =>
            _ProvisioningCard(info: info),
          TrialState.failed => _FailedCard(
              info: info,
              onRetry: () => context.read<TrialCubit>().loadStatus(),
            ),
          TrialState.none ||
          TrialState.unknown =>
            _RequestForm(
              company: _company,
              email: _email,
              phone: _phone,
              companyError: _companyError,
              submitting: state.submitting,
              onSubmit: _submit,
            ),
        },
      ],
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.company,
    required this.email,
    required this.phone,
    required this.companyError,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController company;
  final TextEditingController email;
  final TextEditingController phone;
  final String? companyError;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr.trialIntro,
            style: context.text.bodyMedium?.copyWith(color: s.muted)),
        const SizedBox(height: 18),
        AppTextField(
          label: context.tr.trialCompanyName,
          controller: company,
          errorText: companyError,
          textInputAction: TextInputAction.next,
          autofocus: true,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: context.tr.trialWorkEmail,
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: context.tr.trialPhone,
          controller: phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 20),
        GhostButton(
          label: context.tr.trialRequestButton,
          icon: Icons.rocket_launch_outlined,
          expand: true,
          loading: submitting,
          onPressed: submitting ? null : onSubmit,
        ),
      ],
    );
  }
}

class _ProvisioningCard extends StatelessWidget {
  const _ProvisioningCard({required this.info});

  final TrialInfo info;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final title = info.state == TrialState.pending
        ? context.tr.trialPendingTitle
        : context.tr.trialProvisioningTitle;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: s.cardBg,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: s.brandCyan),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            context.tr.trialProvisioningBody,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.info, required this.onRetry});

  final TrialInfo info;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Server-supplied reason when present; otherwise a generic localized line.
    final reason = (info.error?.isNotEmpty ?? false)
        ? info.error!
        : context.tr.trialFailedBody;
    return AppErrorState(
      title: context.tr.trialFailedTitle,
      message: reason,
      icon: Icons.error_outline,
      onRetry: onRetry,
      retryLabel: context.tr.retry,
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.info});

  final TrialInfo info;

  Future<void> _open(BuildContext context) async {
    final raw = info.url;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.tr.trialOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: s.success, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr.trialReadyTitle,
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: s.cardBg,
            borderRadius: AppRadius.cardR,
            border: Border.all(color: s.cardBorder),
          ),
          child: Column(
            children: [
              if (info.url != null && info.url!.isNotEmpty)
                _CredentialRow(label: context.tr.trialUrl, value: info.url!),
              if (info.db != null && info.db!.isNotEmpty)
                _CredentialRow(label: context.tr.trialDb, value: info.db!),
              if (info.login != null && info.login!.isNotEmpty)
                _CredentialRow(label: context.tr.trialLogin, value: info.login!),
              if (info.password != null && info.password!.isNotEmpty)
                _CredentialRow(
                  label: context.tr.trialPassword,
                  value: info.password!,
                  secret: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Security note — these are LIVE admin credentials.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.warning, size: 15, color: s.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr.trialCredentialsWarning,
                style: context.text.labelSmall
                    ?.copyWith(color: s.warning, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GhostButton(
          label: context.tr.trialOpen,
          icon: Icons.open_in_new,
          expand: true,
          onPressed: () => _open(context),
        ),
      ],
    );
  }
}

/// One credential line: label + value + copy. When [secret], the value is
/// obscured behind an eye toggle (used for the admin password).
class _CredentialRow extends StatefulWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    this.secret = false,
  });

  final String label;
  final String value;
  final bool secret;

  @override
  State<_CredentialRow> createState() => _CredentialRowState();
}

class _CredentialRowState extends State<_CredentialRow> {
  late bool _hidden = widget.secret;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.tr.trialCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final shown = _hidden ? '••••••••••' : widget.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              widget.label,
              style: context.text.labelSmall?.copyWith(color: s.muted),
            ),
          ),
          Expanded(
            child: Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                fontFamily: AppTypography.fontMono,
                letterSpacing: _hidden ? 2 : 0,
              ),
            ),
          ),
          if (widget.secret)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(_hidden ? AppIcons.eye : AppIcons.eyeOff,
                  size: 17, color: s.muted),
              tooltip: _hidden ? context.tr.showPassword : context.tr.hidePassword,
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.copy_outlined, size: 16, color: s.muted),
            tooltip: context.tr.copy,
            onPressed: () => _copy(context),
          ),
        ],
      ),
    );
  }
}
