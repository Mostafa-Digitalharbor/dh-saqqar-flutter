import 'package:flutter/foundation.dart';

/// Identity row returned by `POST /api/v1/auth/{register,login}/` and
/// `GET /api/v1/auth/me/`. Schema per SAQQAR_MOBILE_API.md §1.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.isStaff,
    required this.isSuperuser,
    this.dateJoined,
    this.lastLogin,
  });

  final int id;
  final String email;
  final String username;
  final bool isStaff;
  final bool isSuperuser;
  final DateTime? dateJoined;
  final DateTime? lastLogin;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      isStaff: json['is_staff'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      dateJoined: _parseDate(json['date_joined']),
      lastLogin: _parseDate(json['last_login']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

/// Per-user counts returned alongside identity on `GET /auth/me/`.
@immutable
class AuthCounts {
  const AuthCounts({
    required this.conversations,
    required this.credentials,
    required this.approvals,
    required this.artifacts,
  });

  final int conversations;
  final int credentials;
  final int approvals;
  final int artifacts;

  factory AuthCounts.fromJson(Map<String, dynamic> json) {
    return AuthCounts(
      conversations: (json['conversations'] as num?)?.toInt() ?? 0,
      credentials: (json['credentials'] as num?)?.toInt() ?? 0,
      approvals: (json['approvals'] as num?)?.toInt() ?? 0,
      artifacts: (json['artifacts'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = AuthCounts(
    conversations: 0,
    credentials: 0,
    approvals: 0,
    artifacts: 0,
  );
}

/// Result of register / login / password-change — the freshly-minted bearer
/// token plus the user it belongs to.
@immutable
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}
