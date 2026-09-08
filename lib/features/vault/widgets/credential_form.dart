import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/credential_field_visibility.dart';
import '../data/credential_models.dart';
import '../data/credentials_api.dart';
import '../view_model/vault_cubit.dart';
import '../../../core/theme/app_radius.dart';

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
  /// Name of the sibling select whose value the rest of the form depends on:
  /// which `*_key_by_auth_type` entry to read, and which fields apply at all.
  ///
  /// Resolved from the schema rather than hard-coded, because there are two
  /// spellings in play — Odoo and email ship `auth_type`, the SSH schema
  /// ships `auth` — and the SSH one was previously unhandled, so its form
  /// asked for a password AND a private key with nothing to say which the
  /// user should fill.
  String? _driverField;

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

  /// Odoo database discovery (POST /credentials/databases/). `null` means
  /// "not detected yet" → the db field stays a free-text input. A non-null
  /// list (even empty) means we've asked the server: a populated list turns
  /// the db field into a picker; an empty list means the host disables db
  /// listing (`list_db=False`) and the user types it manually.
  List<String>? _databases;
  bool _detectingDatabases = false;
  String? _detectError;

  /// True once the controllers have been filled from a known source — a
  /// new-credential default set, or an existing credential's payload.
  /// Guards [_seed] so a rebuild never clobbers the user's edits.
  bool _seeded = false;

  /// Guards the one-shot detail fetch for an existing credential whose
  /// cached row came from the list endpoint (payload omitted for security).
  bool _detailRequested = false;

  /// True while [loadEnvironmentCredentialDetail] is in flight. The form
  /// shows a spinner and withholds seeding until it resolves, so the saved
  /// values land in the fields instead of being briefly blank.
  bool _detailLoading = false;

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

  /// Create one controller per schema field exactly once so each input
  /// keeps a stable identity across rebuilds. Values are filled by [_seed].
  void _ensureControllers(CredentialSchema schema) {
    if (_fieldControllers.isNotEmpty) return;
    for (final field in schema.fields) {
      _fieldControllers[field.name] = TextEditingController();
    }
  }

  /// Fill the controllers from [saved] (or schema defaults when creating).
  /// Idempotent via [_seeded] — only the first call with usable data wins.
  void _seed(CredentialSchema schema, Credential? saved) {
    if (_seeded) return;
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
      _fieldControllers[field.name]!.text = initial;
    }
    // Seed the auth-type mirror so dependent fields render with the
    // right initial label/help on the first frame.
    _driverField = credentialAuthDriverFields
        .where(_fieldControllers.containsKey)
        .firstOrNull;
    final driver =
        _driverField == null ? null : _fieldControllers[_driverField!];
    if (driver != null && driver.text.isNotEmpty) {
      _activeAuthType = driver.text;
    }
    _seeded = true;
  }

  /// Pull the full bundle (with payload) for an existing credential so the
  /// form can show its saved values. Resolves whether the fetch succeeds or
  /// fails; on failure the form seeds empty and the user can re-enter.
  Future<void> _fetchDetail() async {
    await context.read<VaultCubit>().loadEnvironmentCredentialDetail(
          envId: widget.envId,
          kind: widget.kind,
        );
    if (!mounted) return;
    setState(() => _detailLoading = false);
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
        final dependsOnMode = field.labelKeyByAuthType != null ||
            field.placeholderKeyByAuthType != null ||
            field.helpKeyByAuthType != null;
        // A field the new mode does not use is cleared too, not just
        // hidden: an SSH form switched from password to key would otherwise
        // still be carrying the typed password in its payload.
        final nowHidden = !credentialFieldApplies(
          fieldName: field.name,
          driverField: _driverField,
          mode: next,
        );
        if (!dependsOnMode && !nowHidden) continue;
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

  /// Field names that hold the Odoo server URL / database, across the
  /// slight naming variants different schemas ship.
  static const _urlFieldNames = {'url', 'host'};
  static const _dbFieldNames = {'db', 'database'};

  /// The schema's database field, if any. Detection only applies when the
  /// schema also exposes a URL field to detect against.
  CredentialField? _databaseField(CredentialSchema schema) {
    CredentialField? db;
    var hasUrl = false;
    for (final f in schema.fields) {
      if (_dbFieldNames.contains(f.name)) db = f;
      if (_urlFieldNames.contains(f.name)) hasUrl = true;
    }
    return hasUrl ? db : null;
  }

  /// Whether the schema ships a URL/host field at all. When it does, Test
  /// connection stays disabled until that field has a value — testing
  /// against a blank endpoint can only fail.
  bool _hasUrlField(CredentialSchema schema) =>
      schema.fields.any((f) => _urlFieldNames.contains(f.name));

  /// The current URL value from whichever url-shaped field the schema ships.
  String _currentUrl() {
    for (final name in _urlFieldNames) {
      final c = _fieldControllers[name];
      if (c != null && c.text.trim().isNotEmpty) return c.text.trim();
    }
    return '';
  }

  /// Calls `POST /credentials/databases/` for the typed URL and turns the
  /// db field into a picker. Mirrors the web's "fetch databases" affordance
  /// so a typo in the db name stops silently failing the connection.
  Future<void> _detectDatabases() async {
    final url = _currentUrl();
    if (url.isEmpty) {
      setState(() {
        _detectError = context.tr.detectDatabasesNeedsUrl;
        _databases = null;
      });
      return;
    }
    setState(() {
      _detectingDatabases = true;
      _detectError = null;
    });
    try {
      final dbs = await context.read<CredentialsApi>().listDatabases(url);
      if (!mounted) return;
      setState(() {
        _databases = dbs;
        _detectingDatabases = false;
        // If the saved/typed db isn't in the discovered list, default to the
        // first one so the picker shows a valid selection immediately.
        final dbField = _fieldControllers.entries
            .where((e) => _dbFieldNames.contains(e.key))
            .map((e) => e.value)
            .firstOrNull;
        if (dbField != null &&
            dbs.isNotEmpty &&
            !dbs.contains(dbField.text.trim())) {
          dbField.text = dbs.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detectingDatabases = false;
        _detectError = context.tr.detectDatabasesFailed;
        _databases = null;
      });
    }
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

    if (schema == null || data == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Text(
          context.tr.noFieldsForKind,
          style: context.text.bodySmall?.copyWith(color: s.muted),
        ),
      );
    }

    _ensureControllers(schema);

    // Has this env's credential list loaded yet? Until it has, a null
    // `saved` is ambiguous ("no credential" vs "not fetched"), so we wait
    // rather than seed the form as a blank new-credential.
    final credsLoaded = data.credentialsByEnv.containsKey(widget.envId);
    // An existing credential whose payload the list endpoint omitted —
    // fetch the full row once so the saved values fill the fields.
    if (credsLoaded &&
        saved != null &&
        saved.payload == null &&
        !_detailRequested) {
      _detailRequested = true;
      _detailLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchDetail();
      });
    }

    final loading = !credsLoaded || _detailLoading;
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s56),
        child: Center(
          child: SizedBox(
            width: AppControlSizes.spinnerMedium,
            height: AppControlSizes.spinnerMedium,
            child: CircularProgressIndicator(strokeWidth: AppStrokeWidths.spinnerRegular, color: s.muted),
          ),
        ),
      );
    }

    _seed(schema, saved);

    final hasCredential = saved != null;
    String hint;
    if (!hasCredential || saved.lastVerifiedAt == null) {
      hint = context.tr.notSavedYet;
    } else {
      hint = context.tr.lastVerifiedAt(
        AppDateFormat.relative(context, saved.lastVerifiedAt!),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s12,
        horizontal: AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: context.tr.label,
            controller: _label,
            hint: schema.label,
          ),
          const SizedBox(height: AppSpacing.s12),
          // A field the current auth mode does not use is not dimmed or
          // disabled — it is absent. SSH offers a password and a private key
          // and wants exactly one; leaving both on screen asks the user to
          // decide something only the mode knows.
          for (final field in schema.fields)
            if (credentialFieldApplies(
              fieldName: field.name,
              driverField: _driverField,
              mode: _activeAuthType,
            )) ...[
            _SchemaField(
              field: field,
              controller: _fieldControllers[field.name]!,
              activeAuthType: _activeAuthType,
              onSelectChanged: field.name == _driverField
                  ? (next) => _onAuthTypeChanged(schema, next)
                  : null,
              // Wire DB detection onto the schema's database field (only
              // when the schema also exposes a URL to detect against). The
              // field stays schema-driven — this just augments the input
              // with a picker + "Detect databases" button.
              onDetectDatabases:
                  identical(field, _databaseField(schema)) ? _detectDatabases : null,
              detectedDatabases:
                  identical(field, _databaseField(schema)) ? _databases : null,
              detectingDatabases: _detectingDatabases,
              detectDatabasesError:
                  identical(field, _databaseField(schema)) ? _detectError : null,
            ),
            const SizedBox(height: AppSpacing.s10),
          ],
          if (schema.fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
              child: Text(
                context.tr.noFieldsForKind,
                style: context.text.bodySmall?.copyWith(color: s.muted),
              ),
            ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            hint,
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
          const SizedBox(height: AppSpacing.s12),
          // Test connection — opens a real connection to the target
          // service via POST /api/v1/credentials/test/. Lives ABOVE
          // Save so the user can sanity-check before committing.
          // Rebuild on field edits so Test flips enabled the moment a URL is
          // typed. Disabled while a write/test is in flight, or when the
          // schema has a URL field that's still blank.
          AnimatedBuilder(
            animation: Listenable.merge(_fieldControllers.values.toList()),
            builder: (context, _) {
              final canTest = !(state.actionInFlight ||
                      _testStatus == _TestStatus.running) &&
                  (!_hasUrlField(schema) || _currentUrl().isNotEmpty);
              return _TestConnectionRow(
                status: _testStatus,
                error: _testError,
                onPressed: canTest ? _test : null,
              );
            },
          ),
          const SizedBox(height: AppSpacing.s14),
          Row(
            children: [
              Expanded(
                // Save disabled until every required field is filled — a
                // submit missing a required value just bounces back a 400,
                // so we don't spend the round-trip. (We deliberately DON'T
                // diff against the saved payload: secret fields come back
                // masked, so a value-changed check would wrongly lock the
                // user out of re-entering a password.)
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                    _fieldControllers.values.toList(),
                  ),
                  builder: (context, _) {
                    final requiredFilled = schema.fields
                        .where((f) => f.required)
                        .every((f) =>
                            _fieldControllers[f.name]!.text.trim().isNotEmpty);
                    return PrimaryButton(
                      label: context.tr.saveCredentialButton,
                      icon: AppIcons.save,
                      onPressed: (state.actionInFlight || !requiredFilled)
                          ? null
                          : _save,
                    );
                  },
                ),
              ),
              if (hasCredential) ...[
                const SizedBox(width: AppSpacing.s8),
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
    this.onDetectDatabases,
    this.detectedDatabases,
    this.detectingDatabases = false,
    this.detectDatabasesError,
  });

  final CredentialField field;
  final TextEditingController controller;

  /// Non-null only on the schema's database field (when the schema also
  /// ships a URL field). Fires `POST /credentials/databases/` to discover
  /// the reachable Odoo databases and switch this input to a picker.
  final Future<void> Function()? onDetectDatabases;

  /// Discovered databases: `null` = not detected yet (free-text), empty =
  /// host disables listing (manual entry), non-empty = render a picker.
  final List<String>? detectedDatabases;

  /// True while [onDetectDatabases] is in flight — drives the button spinner.
  final bool detectingDatabases;

  /// Localized detection error (bad URL, transport failure), or null.
  final String? detectDatabasesError;

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
    // App-side fallback keyed by field name — covers schemas the server
    // ships without a `label_key`, so an Arabic UI shows a localized label
    // instead of the English `field.label`.
    final byName = _fallbackLabelKey();
    if (byName != null) {
      return tr.lookup(byName, fallback: field.label);
    }
    return field.label;
  }

  /// Best-effort i18n key for a well-known credential field name. `null`
  /// for unrecognized fields (the caller then keeps the server's label).
  String? _fallbackLabelKey() {
    switch (field.name) {
      case 'url':
        return 'credUrl';
      case 'db':
      case 'database':
        return 'credDb';
      case 'username':
      case 'user':
      case 'login':
        return 'credUsername';
      case 'secret':
        // The secret's meaning tracks the auth type when it's known.
        if (activeAuthType == 'api_key') return 'authApiKey';
        if (activeAuthType == 'password') return 'authPassword';
        return 'credSecret';
      case 'auth_type':
        return 'authType';
      case 'host':
        return 'credHost';
      case 'port':
        return 'credPort';
      case 'password':
        return 'authPassword';
      case 'token':
        return 'credToken';
      case 'imap_host':
        return 'credImapHost';
      case 'imap_port':
        return 'credImapPort';
      case 'smtp_host':
        return 'credSmtpHost';
      case 'smtp_port':
        return 'credSmtpPort';
      case 'smtp_security':
        return 'credSmtpSecurity';
      default:
        return null;
    }
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

  /// The explainer under the field, in the user's language.
  ///
  /// Three sources, in the web's order:
  ///
  ///   1. `help_key_by_auth_type` — the one field whose explainer changes
  ///      with a sibling ("API Key" vs "Password"). An empty-string value
  ///      means "no help block for this branch", which is not the same as
  ///      "fall through".
  ///   2. `help_key` — where the text lives for every OTHER field. This
  ///      branch was missing, and its absence is why the form had no help at
  ///      all: the server sends `help: ""` on 27 of its 28 fields, so the
  ///      fallback below had nothing to fall back to.
  ///   3. `help` — the schema's own literal, for a server that ships text
  ///      instead of a key.
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
    final key = field.helpKey;
    if (key != null && key.isNotEmpty) {
      return tr.lookup(key, fallback: field.help);
    }
    return field.help;
  }

  /// Localized option label for a select. Special-cases the known
  /// auth/security option values because the server doesn't ship
  /// per-option i18n keys for them — `api_key`/`password` share the
  /// keys with the secret field's dynamic label; the email kind's
  /// `oauth2`/`ssl`/`starttls` are protocol names kept as their
  /// standard technical spelling in both locales (same convention as
  /// keeping "PostgreSQL"/"GitHub" untranslated).
  String _resolveOption(BuildContext context, String option) {
    final tr = context.tr;
    if (option == 'api_key') return tr.lookup('authApiKey', fallback: option);
    if (option == 'password') {
      return tr.lookup('authPassword', fallback: option);
    }
    if (option == 'oauth2') return tr.lookup('credOptionOauth2', fallback: option);
    if (option == 'ssl') return tr.lookup('credOptionSsl', fallback: option);
    if (option == 'starttls') {
      return tr.lookup('credOptionStarttls', fallback: option);
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
        const SizedBox(height: AppSpacing.s4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.s4),
          child: Text(
            help,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontStyle: FontStyle.italic,
              height: AppLineHeights.label,
            ),
          ),
        ),
      ],
    );
  }

  /// The database field's input: a discovered-databases picker (or a
  /// free-text field before detection / when listing is disabled), with a
  /// "Detect databases" button and inline status below.
  Widget _buildDatabaseInput(
    BuildContext context,
    String label,
    String placeholder,
  ) {
    final tr = context.tr;
    final s = context.saqqar;
    final dbs = detectedDatabases;
    final hasList = dbs != null && dbs.isNotEmpty;

    final Widget field;
    if (hasList) {
      final current = controller.text.isNotEmpty && dbs.contains(controller.text)
          ? controller.text
          : null;
      field = DropdownButtonFormField<String>(
        initialValue: current,
        // Database names run long (`tenant-project-live-1234567`); without
        // this the closed field sizes to the text and overflows.
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final db in dbs)
            DropdownMenuItem(
              value: db,
              child: Text(db, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) controller.text = value;
        },
      );
    } else {
      field = AppTextField(
        label: label,
        hint: placeholder.isEmpty ? null : placeholder,
        controller: controller,
      );
    }

    // Status line under the button: error wins, else the "listing disabled,
    // type manually" hint when detection came back empty.
    String? status;
    Color statusColor = s.muted;
    if (detectDatabasesError != null) {
      status = detectDatabasesError;
      statusColor = s.danger;
    } else if (dbs != null && dbs.isEmpty) {
      status = tr.detectDatabasesEmpty;
      statusColor = s.muted;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        const SizedBox(height: AppSpacing.s8),
        GhostButton(
          label: detectingDatabases
              ? tr.detectingDatabases
              : tr.detectDatabases,
          icon: AppIcons.database,
          onPressed: detectingDatabases ? null : () => onDetectDatabases?.call(),
        ),
        if (status != null) ...[
          const SizedBox(height: AppSpacing.s6),
          Text(
            status,
            style: context.text.labelSmall?.copyWith(
              color: statusColor,
              height: AppLineHeights.label,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    final label = _resolveLabel(context);
    final placeholder = _resolvePlaceholder(context);
    // Database field with detection wired — render a picker (once detected)
    // plus a "Detect databases" button, instead of a plain text field.
    if (onDetectDatabases != null) {
      return _buildDatabaseInput(context, label, placeholder);
    }
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
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(
                  _resolveOption(context, option),
                  overflow: TextOverflow.ellipsis,
                ),
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
          const SizedBox(height: AppSpacing.s8),
          _TestBadge(
            status: status,
            // For `failed`, render "Connection failed: <reason>". The
            // server's `error` is developer-facing English; [testConnectionError]
            // maps the common cases to the active locale and falls back to
            // the raw text only for unknown errors.
            text: switch (status) {
              _TestStatus.running => tr.testingConnection,
              _TestStatus.ok => tr.testConnectionOk,
              _TestStatus.failed => error == null
                  ? tr.testConnectionFailed
                  : '${tr.testConnectionFailed}: ${tr.testConnectionError(error!)}',
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppAlphas.a10),
        borderRadius: AppRadius.tightR,
        border: Border.all(color: color.withValues(alpha: AppAlphas.a35)),
      ),
      child: Row(
        children: [
          if (status == _TestStatus.running)
            SizedBox(
              width: AppControlSizes.spinnerDense,
              height: AppControlSizes.spinnerDense,
              child: CircularProgressIndicator(strokeWidth: AppStrokeWidths.spinnerThin, color: color),
            )
          else
            Icon(
              status == _TestStatus.ok
                  ? AppIcons.success
                  : AppIcons.error,
              color: color,
              size: AppIconSizes.small,
            ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.footnote,
                height: AppLineHeights.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
