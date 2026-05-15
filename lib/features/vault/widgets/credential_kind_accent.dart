import 'package:flutter/widgets.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

/// Returns the accent color associated with a given [DemoCredentialKind].
///
/// Used by both the credential row icon plate and the "memorized" / kind
/// chips so each integration (XML-RPC / Postgres / Shell / GitHub) gets its
/// own consistent color signature throughout the app.
Color credentialKindAccent(BuildContext context, DemoCredentialKind kind) {
  final s = context.saqqar;
  return switch (kind) {
    DemoCredentialKind.xmlrpc => s.brandCyan,
    DemoCredentialKind.postgres => s.brandPurple,
    DemoCredentialKind.serverShell => s.warning,
    DemoCredentialKind.github => s.success,
  };
}
