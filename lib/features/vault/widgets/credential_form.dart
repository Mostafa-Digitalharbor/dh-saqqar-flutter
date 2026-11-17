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
part 'credential_schema_field.dart';
part 'credential_test_row.dart';

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
  const CredentialForm({super.key, required this.envId, required this.kind});

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
      final initial =
          raw?.toString() ??
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
    final driver = _driverField == null
        ? null
        : _fieldControllers[_driverField!];
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
        final dependsOnMode =
            field.labelKeyByAuthType != null ||
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
            child: CircularProgressIndicator(
              strokeWidth: AppStrokeWidths.spinnerRegular,
              color: s.muted,
            ),
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
                onDetectDatabases: identical(field, _databaseField(schema))
                    ? _detectDatabases
                    : null,
                detectedDatabases: identical(field, _databaseField(schema))
                    ? _databases
                    : null,
                detectingDatabases: _detectingDatabases,
                detectDatabasesError: identical(field, _databaseField(schema))
                    ? _detectError
                    : null,
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
          Text(hint, style: context.text.labelSmall?.copyWith(color: s.muted)),
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
              final canTest =
                  !(state.actionInFlight ||
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
                        .every(
                          (f) =>
                              _fieldControllers[f.name]!.text.trim().isNotEmpty,
                        );
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
