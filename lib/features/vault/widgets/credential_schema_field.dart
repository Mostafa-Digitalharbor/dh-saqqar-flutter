part of 'credential_form.dart';

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
    if (option == 'oauth2') {
      return tr.lookup('credOptionOauth2', fallback: option);
    }
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
      final current =
          controller.text.isNotEmpty && dbs.contains(controller.text)
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
          onPressed: detectingDatabases
              ? null
              : () => onDetectDatabases?.call(),
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
