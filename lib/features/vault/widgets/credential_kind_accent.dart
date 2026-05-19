import 'package:flutter/widgets.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../data/credential_models.dart';

/// Returns the accent color associated with a given [CredentialKind].
///
/// Used by both the credential row icon plate and the "memorized" / kind
/// chips so each integration (XML-RPC / Postgres / Shell / GitHub) gets its
/// own consistent color signature throughout the app.
Color credentialKindAccent(BuildContext context, CredentialKind kind) {
  final s = context.saqqar;
  return switch (kind) {
    CredentialKind.xmlrpc => s.brandCyan,
    CredentialKind.postgres => s.brandPurple,
    CredentialKind.serverShell => s.warning,
    CredentialKind.github => s.success,
  };
}
