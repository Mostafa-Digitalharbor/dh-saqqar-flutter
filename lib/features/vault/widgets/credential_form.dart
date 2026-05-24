import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/credential_models.dart';
import '../data/credentials_api.dart';
import '../view_model/vault_cubit.dart';

/// Schema-driven credential form rendered inside a tab of
/// [EnvironmentDetailSheet]. Mirrors the web's `env-credential-form`:
/// label input + per-schema fields + Test connection + "Last verified"
/// hint + Save / Delete.
///
/// Two recent additions (SAQQAR_MOBILE_API_xmlrpc.md):
///
///   * **Dependent fields** — when a field in the schema ships
///     `*_key_by_auth_type` maps, its label / placeholder / help are
///     resolved against the current value of the sibling `auth_type`
///     field. Toggling the select clears the dependent secret. The
///     widget treats this generically (no `kind == 'xmlrpc'`
///     special-case) so future kinds can ship the same pattern.
///   * **Test connection** — a button above Save calls
///     `POST /api/v1/credentials/test/` with the current form payload
///     and shows a green / red badge with the result. No state is
///     mutated server-side.
class CredentialForm extends StatefulWidget {
  const CredentialForm({
    super.key,
    required this.envId,
    required this.kind,
  });

  final String envId;
  final CredentialKind kind;

  @override
  State<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<CredentialForm> {
  /// Name of the sibling field whose value drives `*_key_by_auth_type`
  /// lookups. Hard-coded to "auth_type" because that's the only
  /// dependency name the backend ships today; if a future schema adds
  /// a different driver field name we'd promote this to a per-field
  /// hint on the schema instead of a global constant.
  static const _authDriverField = 'auth_type';

  late final TextEditingController _label;
  final Map<String, TextEditingController> _fieldControllers = {};

  /// Mirrored copy of the driver field's value so the dependent fields
  /// rebuild on toggle without forcing the whole form into a
  /// controller-listening loop. Updated by [_onAuthTypeChanged].
  String? _activeAuthType;

  /// Test-connection state machine. `null` → idle (no badge); other
  /// states render the appropriate badge under the button.
  _TestStatus _testStatus = _TestStatus.idle;
  String? _testError;

  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController();
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(CredentialSchema schema, Credential? saved) {
    if (_initialised) return;
    _label.text = saved?.label ?? '';
    final payload = saved?.payload ?? const <String, dynamic>{};
    for (final field in schema.fields) {
      final raw = payload[field.name];
      final initial = raw?.toString() ??
          field.defaultValue ??
          // Fall back to the first option for select fields so the user
          // sees a valid choice immediately.
          (field.type == CredentialFieldType.select &&
                  (field.options?.isNotEmpty ?? false)
              ? field.options!.first
              : '');
      _fieldControllers[field.name] = TextEditingController(text: initial);
    }
    // Seed the auth-type mirror so dependent fields render with the
    // right initial label/help on the first frame.
    final driver = _fieldControllers[_authDriverField];
    if (driver != null && driver.text.isNotEmpty) {
      _activeAuthType = driver.text;
    }
    _initialised = true;
  }

  void _onAuthTypeChanged(CredentialSchema schema, String next) {
    if (_activeAuthType == next) return;
    setState(() {
      _activeAuthType = next;
      // Clear any sibling fields whose label/placeholder/help depends
      // on the auth type. A password and an API key occupy different
      // value spaces — preserving the old text would silently fail the
      // next test-connection. Web client does the same (app.js:
      // `wireXmlrpcAuthTypeDependencies`).
      for (final field in schema.fields) {
        if (field.labelKeyByAuthType == null &&
            field.placeholderKeyByAuthType == null &&
            field.helpKeyByAuthType == null) {
          continue;
        }
        _fieldControllers[field.name]?.clear();
      }
      // Any prior test result is stale now — drop the badge.
      _testStatus = _TestStatus.idle;
      _testError = null;
    });
  }

  Map<String, dynamic> _collectPayload() {
    final payload = <String, dynamic>{};
    for (final entry in _fieldControllers.entries) {
      payload[entry.key] = entry.value.text.trim();
    }
    return payload;
  }

  Future<void> _save() async {
    await context.read<VaultCubit>().saveEnvironmentCredential(
          envId: widget.envId,
          kind: widget.kind,
          payload: _collectPayload(),
          label: _label.text.trim().isEmpty ? null : _label.text.trim(),
        );
  }

  Future<void> _test() async {
    setState(() {
      _testStatus = _TestStatus.running;
      _testError = null;
    });
    final api = context.read<CredentialsApi>();
    final result = await api.testConnection(
      kind: widget.kind,
      payload: _collectPayload(),
    );
    if (!mounted) return;
    setState(() {
      if (result.success) {
        _testStatus = _TestStatus.ok;
        _testError = null;
      } else {
        _testStatus = _TestStatus.failed;
        _testError = result.error;
      }
    });
  }

  Future<void> _delete() async {
    final ok = await ConfirmDialog.show(
      context,
      title: context.tr.deleteCredentialTitle,
      body: context.tr.deleteCredentialBody,
      confirmLabel: context.tr.deleteCredentialButton,
      destructive: true,
      icon: AppIcons.trash,
    );
    if (!ok || !mounted) return;
    await context.read<VaultCubit>().deleteEnvironmentCredential(
          envId: widget.envId,
          kind: widget.kind,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final state = context.watch<VaultCubit>().state;
    final data = state.data.dataOrNull;
    final schema = data?.schemaFor(widget.kind);
    final saved = data?.credentialFor(widget.envId, widget.kind);

    if (schema == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.tr.noFieldsForKind,
          style: context.text.bodySmall?.copyWith(color: s.muted),
        ),
      );
    }

    _ensureControllers(schema, saved);

    final hasCredential = saved != null;
    String hint;
    if (!hasCredential || saved.lastVerifiedAt == null) {
      hint = context.tr.notSavedYet;
    } else {
      hint = context.tr.lastVerifiedAt(
        context.tr.relativeTime(saved.lastVerifiedAt!),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: context.tr.label,
            controller: _label,
            hint: schema.label,
          ),
          const SizedBox(height: 12),
          for (final field in schema.fields) ...[
            _SchemaField(
              field: field,
              controller: _fieldControllers[field.name]!,
              activeAuthType: _activeAuthType,
              onSelectChanged: field.name == _authDriverField
                  ? (next) => _onAuthTypeChanged(schema, next)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          if (schema.fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.tr.noFieldsForKind,
                style: context.text.bodySmall?.copyWith(color: s.muted),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
          const SizedBox(height: 12),
          // Test connection — opens a real connection to the target
          // service via POST /api/v1/credentials/test/. Lives ABOVE
          // Save so the user can sanity-check before committing.
          _TestConnectionRow(
            status: _testStatus,
            error: _testError,
            onPressed: (state.actionInFlight ||
                    _testStatus == _TestStatus.running)
                ? null
                : _test,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: context.tr.saveCredentialButton,
                  icon: AppIcons.save,
                  onPressed: state.actionInFlight ? null : _save,
                ),
              ),
              if (hasCredential) ...[
                const SizedBox(width: 8),
                GhostButton(
                  label: context.tr.deleteCredentialButton,
                  icon: AppIcons.trash,
                  tone: GhostButtonTone.danger,
                  onPressed: state.actionInFlight ? null : _delete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

enum _TestStatus { idle, running, ok, failed }

class _SchemaField extends StatelessWidget {
  const _SchemaField({
    required this.field,
    required this.controller,
    required this.activeAuthType,
    this.onSelectChanged,
  });

  final CredentialField field;
  final TextEditingController controller;

  /// Currently-active value of the schema's `auth_type` driver field.
  /// Drives label / placeholder / help lookups for any field that ships
  /// `*_key_by_auth_type` maps. `null` for schemas without an auth-type
  /// driver — falls back to [field.label] / [field.placeholder] /
  /// [field.help].
  final String? activeAuthType;

  /// Only set for the auth-type driver field itself. Fired when the
  /// user picks a new option so the form can clear dependent secrets.
  final ValueChanged<String>? onSelectChanged;

  String _resolveLabel(BuildContext context) {
    final tr = context.tr;
    if (field.labelKeyByAuthType != null && activeAuthType != null) {
      final key = field.labelKeyByAuthType![activeAuthType];
      if (key != null && key.isNotEmpty) {
        return tr.lookup(key, fallback: field.label);
      }
    }
    if (field.labelKey != null && field.labelKey!.isNotEmpty) {
      return tr.lookup(field.labelKey!, fallback: field.label);
    }
    return field.label;
  }

  String _resolvePlaceholder(BuildContext context) {
    final tr = context.tr;
    if (field.placeholderKeyByAuthType != null && activeAuthType != null) {
      final key = field.placeholderKeyByAuthType![activeAuthType];
      if (key != null && key.isNotEmpty) {
        return tr.lookup(key, fallback: field.placeholder);
      }
    }
    return field.placeholder;
  }

  String _resolveHelp(BuildContext context) {
    final tr = context.tr;
    if (field.helpKeyByAuthType != null && activeAuthType != null) {
      final key = field.helpKeyByAuthType![activeAuthType];
      // Empty-string value means "no help block for this branch".
      if (key != null && key.isNotEmpty) {
        return tr.lookup(key, fallback: field.help);
      }
      return '';
    }
    return field.help;
  }

  /// Localized option label for a select. Currently special-cases the
  /// two known auth-type values (`api_key`, `password`) because the
  /// server didn't ship per-option i18n keys for those — they share
  /// the keys with the secret field's dynamic label.
  String _resolveOption(BuildContext context, String option) {
    final tr = context.tr;
    if (option == 'api_key') return tr.lookup('authApiKey', fallback: option);
    if (option == 'password') {
      return tr.lookup('authPassword', fallback: option);
    }
    return option;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final input = _buildInput(context);
    final help = _resolveHelp(context);
    if (help.isEmpty) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        input,
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            help,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    final label = _resolveLabel(context);
    final placeholder = _resolvePlaceholder(context);
    switch (field.type) {
      case CredentialFieldType.select:
        final options = field.options ?? const <String>[];
        final current = controller.text.isNotEmpty
            ? controller.text
            : (options.isNotEmpty
                ? (field.defaultValue ?? options.first)
                : null);
        return DropdownButtonFormField<String>(
          initialValue: current,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(_resolveOption(context, option)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            controller.text = value;
            onSelectChanged?.call(value);
          },
        );
      case CredentialFieldType.password:
        return AppPasswordField(
          label: label,
          hint: placeholder.isEmpty ? null : placeholder,
          controller: controller,
        );
      case CredentialFieldType.textarea:
        return AppTextField(
          label: label,
          hint: placeholder.isEmpty ? null : placeholder,
          controller: controller,
          maxLines: 4,
        );
      case CredentialFieldType.number:
        return AppTextField(
          label: label,
          hint: placeholder.isEmpty ? null : placeholder,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
        );
      case CredentialFieldType.text:
        return AppTextField(
          label: label,
          hint: placeholder.isEmpty ? null : placeholder,
          controller: controller,
        );
    }
  }
}

/// "Test connection" affordance — a ghost button with an inline status
/// badge below. Status mirrors [_TestStatus]:
///   * `idle` → just the button, no badge
///   * `running` → button shows spinner, badge reads "Testing…"
///   * `ok` → button enabled, green "Connection OK" badge
///   * `failed` → button enabled, red `Connection failed: <reason>`
class _TestConnectionRow extends StatelessWidget {
  const _TestConnectionRow({
    required this.status,
    required this.error,
    required this.onPressed,
  });

  final _TestStatus status;
  final String? error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GhostButton(
          label: status == _TestStatus.running
              ? tr.testingConnection
              : tr.testConnection,
          icon: AppIcons.shieldCheck,
          onPressed: onPressed,
        ),
        if (status != _TestStatus.idle) ...[
          const SizedBox(height: 8),
          _TestBadge(
            status: status,
            // For `failed`, render "Connection failed: <server reason>".
            // Server-side `error` messages are English and developer-
            // facing — surfacing them verbatim is fine per spec §4.
            text: switch (status) {
              _TestStatus.running => tr.testingConnection,
              _TestStatus.ok => tr.testConnectionOk,
              _TestStatus.failed => error == null
                  ? tr.testConnectionFailed
                  : '${tr.testConnectionFailed}: $error',
              _TestStatus.idle => '',
            },
            color: switch (status) {
              _TestStatus.ok => s.success,
              _TestStatus.failed => s.danger,
              _ => s.muted,
            },
          ),
        ],
      ],
    );
  }
}

class _TestBadge extends StatelessWidget {
  const _TestBadge({
    required this.status,
    required this.text,
    required this.color,
  });

  final _TestStatus status;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (status == _TestStatus.running)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              status == _TestStatus.ok
                  ? Icons.check_circle
                  : Icons.error_outline,
              color: color,
              size: 16,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
