import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Translates `saqqar://...` URIs (spec §4.4) into app routes.
///
/// Supported schemes:
/// - `saqqar://conversation/<uuid>` → `/chats/<uuid>`
/// - `saqqar://approval/<uuid>?conversation=<convId>` →
///   `/chats/<convId>?approval=<uuid>` (the chat screen pops its own
///   approvals sheet — Inbox tab was retired). The conversation id MUST be
///   carried on the link because `resolve` is pure/synchronous and can't
///   look up an approval → conversation mapping; the backend push that
///   raises the link already knows both ids (SAQQAR_MOBILE_API.md §8).
/// - `saqqar://credential/add?kind=xmlrpc` → `/vault/add?kind=xmlrpc`
/// - `saqqar://share/<token>` → `/share/<token>`
///
/// Returns the in-app path the router should navigate to, or `null` when the
/// link can't be parsed (caller should show a "Couldn't open link" toast).
///
/// Platform plumbing (intent-filters, URL scheme, App Links) is the mobile
/// runner's job — see `android/app/src/main/AndroidManifest.xml` and
/// `ios/Runner/Info.plist`. The recommended Flutter package for receiving
/// the cold-launch URI is `app_links`; once added, call [DeepLinks.handle]
/// in `main.dart` after `runApp` and pass the parsed URI to GoRouter.
class DeepLinks {
  DeepLinks._();

  static const String scheme = 'saqqar';

  /// Returns the in-app route for [uri], or `null` if it's not recognized.
  static String? resolve(Uri uri) {
    if (uri.scheme != scheme) return null;
    final segments = uri.pathSegments;
    final host = uri.host;

    // Both `saqqar://conversation/<id>` (host=conversation) and
    // `saqqar:conversation/<id>` (no host, segments=[conversation,id]) work.
    final head = host.isNotEmpty ? host : (segments.isEmpty ? '' : segments.first);
    final tail = host.isNotEmpty
        ? segments
        : (segments.length > 1 ? segments.sublist(1) : const <String>[]);

    switch (head) {
      case 'conversation':
        if (tail.isEmpty) return null;
        return RouteNames.chatPath(tail.first);

      case 'approval':
        if (tail.isEmpty) return null;
        final approvalId = tail.first;
        // The conversation the approval belongs to rides on the link's
        // `?conversation=` query (the push knows it). We land the user
        // inside that chat with an `?approval=` flag so the chat screen can
        // pop its approvals sheet automatically. Without the conversation
        // id there's nothing to route to synchronously → unrecognized.
        final conversationId = uri.queryParameters['conversation'];
        if (conversationId == null || conversationId.isEmpty) return null;
        return RouteNames.approvalDetailPath(
          conversationId: conversationId,
          approvalId: approvalId,
        );

      case 'credential':
        if (tail.isEmpty || tail.first != 'add') return null;
        final kind = uri.queryParameters['kind'];
        if (kind == null || kind.isEmpty) return RouteNames.credentialAddPath;
        return '${RouteNames.credentialAddPath}?kind=$kind';

      case 'share':
        if (tail.isEmpty) return null;
        return RouteNames.sharedTranscriptPath(tail.first);
    }
    return null;
  }

  /// Convenience: resolve [uri] then push it onto [router]. Returns `true`
  /// when the link was recognized and dispatched. The caller should toast
  /// the user when this returns `false`.
  static bool handle(GoRouter router, Uri uri) {
    final path = resolve(uri);
    if (path == null) {
      if (kDebugMode) debugPrint('[DeepLinks] unrecognized: $uri');
      return false;
    }
    router.go(path);
    return true;
  }
}
