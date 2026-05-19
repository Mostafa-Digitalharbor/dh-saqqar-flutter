import 'package:flutter/foundation.dart';

/// The four credential kinds the backend currently supports. Mobile API §7.
enum CredentialKind {
  xmlrpc('xmlrpc'),
  postgres('postgres'),
  serverShell('server_shell'),
  github('github');

  const CredentialKind(this.wire);

  /// Wire value sent on the API (`POST /credentials/`). Differs from the
  /// Dart enum name for `serverShell` (snake_case on the wire).
  final String wire;

  static CredentialKind? fromWire(String? value) {
    if (value == null) return null;
    for (final k in CredentialKind.values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// The form-field types the credential schema can describe. Render against
/// these in [CredentialField] — never hard-code per-kind field lists.
enum CredentialFieldType {
  text,
  password,
  number,
  select,
  textarea;

  static CredentialFieldType fromWire(String? value) {
    return switch (value) {
      'password' => CredentialFieldType.password,
      'number' => CredentialFieldType.number,
      'select' => CredentialFieldType.select,
      'textarea' => CredentialFieldType.textarea,
      _ => CredentialFieldType.text,
    };
  }
}

/// A single field in a [CredentialSchema] — what label to show, what input
/// type to use, whether it's required, and (for selects) the allowed values.
@immutable
class CredentialField {
  const CredentialField({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    this.placeholder = '',
    this.help = '',
    this.options,
  });

  final String name;
  final String label;
  final CredentialFieldType type;
  final bool required;
  final String placeholder;
  final String help;

  /// Only set when [type] is [CredentialFieldType.select].
  final List<String>? options;

  factory CredentialField.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return CredentialField(
      name: json['name'] as String,
      label: json['label'] as String? ?? json['name'] as String,
      type: CredentialFieldType.fromWire(json['type'] as String?),
      required: json['required'] as bool? ?? false,
      placeholder: json['placeholder'] as String? ?? '',
      help: json['help'] as String? ?? '',
      options: opts is List ? opts.map((e) => e.toString()).toList() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type.name,
        'required': required,
        'placeholder': placeholder,
        'help': help,
        if (options != null) 'options': options,
      };
}

/// Form descriptor for one [CredentialKind] — the contract for what the
/// Add Credential UI must render. Comes from `GET /credentials/schemas/`.
@immutable
class CredentialSchema {
  const CredentialSchema({
    required this.kind,
    required this.label,
    required this.fields,
  });

  final CredentialKind kind;
  final String label;
  final List<CredentialField> fields;

  factory CredentialSchema.fromJson(Map<String, dynamic> json) {
    return CredentialSchema(
      kind: CredentialKind.fromWire(json['kind'] as String?) ??
          CredentialKind.xmlrpc,
      label: json['label'] as String? ?? '',
      fields: (json['fields'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(CredentialField.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.wire,
        'label': label,
        'fields': fields.map((f) => f.toJson()).toList(),
      };
}

/// A stored credential bundle. `payload` is only populated on the detail
/// GET (`/credentials/<name>/`) — list responses omit it for security.
@immutable
class Credential {
  const Credential({
    required this.name,
    required this.kind,
    required this.label,
    required this.isMemorized,
    this.metadata = const {},
    this.lastVerifiedAt,
    this.payload,
  });

  /// Per-user slug (`^[a-z0-9-_]+$`, unique). Used as the resource id on
  /// `/credentials/<name>/`.
  final String name;
  final CredentialKind kind;
  final String label;

  /// `true` = persisted across sessions (required approval handshake).
  /// `false` = session-only (still encrypted on disk).
  final bool isMemorized;

  final Map<String, dynamic> metadata;
  final DateTime? lastVerifiedAt;

  /// Decrypted credential payload. `null` for list responses — call
  /// `GET /credentials/<name>/` to populate.
  final Map<String, dynamic>? payload;

  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      name: json['name'] as String,
      kind: CredentialKind.fromWire(json['kind'] as String?) ??
          CredentialKind.xmlrpc,
      label: json['label'] as String? ?? '',
      isMemorized: json['is_memorized'] as bool? ?? false,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ??
          const {},
      lastVerifiedAt: _parseDate(json['last_verified_at']),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

/// Returned by `POST /credentials/` when the server requires the two-step
/// memorize approval handshake (§7). The caller then POSTs to
/// `/approvals/<approvalId>/decision/` and re-submits the original payload
/// with `approval_id` set.
@immutable
class CredentialApprovalRequest {
  const CredentialApprovalRequest({
    required this.approvalId,
    required this.prompt,
  });

  final String approvalId;
  final String prompt;
}

/// Wrapper for the response of `POST /credentials/` — either the saved
/// bundle (200) or an approval-required handshake (202). Repository
/// callers `.when(...)` against the two cases.
sealed class CredentialSaveResult {
  const CredentialSaveResult();
}

class CredentialSaved extends CredentialSaveResult {
  const CredentialSaved(this.credential);
  final Credential credential;
}

class CredentialApprovalRequired extends CredentialSaveResult {
  const CredentialApprovalRequired(this.request);
  final CredentialApprovalRequest request;
}
