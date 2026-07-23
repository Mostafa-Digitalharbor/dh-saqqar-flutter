import 'package:flutter/foundation.dart';

/// Provisioning state of a managed trial (API_MOBILE_NEW_ENDPOINTS.md §2).
enum TrialState {
  /// No trial requested yet.
  none,

  /// Queued; provisioning not started.
  pending,

  /// Building the Odoo (can take several minutes).
  provisioning,

  /// Live; credentials are present on the info object.
  ready,

  /// Provisioning failed; [TrialInfo.error] explains why.
  failed,

  /// Unrecognized server status — treated as terminal (no polling) so an
  /// unexpected value can't spin the poller forever.
  unknown;

  static TrialState fromWire(String? raw) {
    switch (raw) {
      case 'none':
        return TrialState.none;
      case 'pending':
        return TrialState.pending;
      case 'provisioning':
        return TrialState.provisioning;
      case 'ready':
        return TrialState.ready;
      case 'failed':
        return TrialState.failed;
      default:
        return TrialState.unknown;
    }
  }

  /// Whether the client should keep polling `/trial/status/`.
  bool get isInProgress =>
      this == TrialState.pending || this == TrialState.provisioning;
}

/// A trial's current status. When [state] is [TrialState.ready], the
/// credential fields carry LIVE admin credentials — treat them as a secret:
/// never log them, and reveal the password only behind an explicit control.
@immutable
class TrialInfo {
  const TrialInfo({
    required this.state,
    required this.ready,
    this.url,
    this.db,
    this.login,
    this.password,
    this.error,
  });

  final TrialState state;
  final bool ready;

  final String? url;
  final String? db;
  final String? login;
  final String? password;

  /// Reason string when [state] is [TrialState.failed].
  final String? error;

  bool get hasCredentials =>
      (url?.isNotEmpty ?? false) && (login?.isNotEmpty ?? false);

  factory TrialInfo.fromJson(Map<String, dynamic> json) {
    return TrialInfo(
      state: TrialState.fromWire(json['status'] as String?),
      ready: json['ready'] as bool? ?? false,
      url: json['url'] as String?,
      db: json['db'] as String?,
      login: json['login'] as String?,
      password: json['password'] as String?,
      error: json['error'] as String?,
    );
  }

  static const none = TrialInfo(state: TrialState.none, ready: false);
}

/// Input for `POST /api/v1/trial/`. Only [companyName] is required; the rest
/// default server-side (name/email from the account) and are omitted from
/// the payload when blank.
@immutable
class TrialRequest {
  const TrialRequest({
    required this.companyName,
    this.fullName,
    this.workEmail,
    this.companySize,
    this.industry,
    this.country,
    this.phone,
  });

  final String companyName;
  final String? fullName;
  final String? workEmail;
  final String? companySize;
  final String? industry;
  final String? country;
  final String? phone;

  Map<String, dynamic> toJson() {
    void addIf(Map<String, dynamic> m, String key, String? value) {
      if (value != null && value.trim().isNotEmpty) m[key] = value.trim();
    }

    final body = <String, dynamic>{'company_name': companyName.trim()};
    addIf(body, 'full_name', fullName);
    addIf(body, 'work_email', workEmail);
    addIf(body, 'company_size', companySize);
    addIf(body, 'industry', industry);
    addIf(body, 'country', country);
    addIf(body, 'phone', phone);
    return body;
  }
}
