import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../constants/ui_strings.dart';
import 'route_names.dart';

/// What the app should do with an incoming deep link. A [DeepLinkService]
/// (driven by the `app_links` plugin) resolves each URI to one of these and
/// executes it, keeping the pure classification logic here fully unit-testable.
sealed class DeepLinkAction {
  const DeepLinkAction();
}

/// Navigate the router to [route] (an in-app path like `/chats/<id>`).
class DeepLinkNavigate extends DeepLinkAction {
  const DeepLinkNavigate(this.route);
  final String route;

  @override
  bool operator ==(Object other) =>
      other is DeepLinkNavigate && other.route == route;

  @override
  int get hashCode => route.hashCode;

  @override
  String toString() => 'DeepLinkNavigate($route)';
}

/// Open [uri] in an external browser instead of the app. Used for the
/// `saqqaar.com` paths the iOS association file excludes (spec §4) — on
/// Android the verified App Link routes every path to the app, so mirroring
/// that "stays in the browser" intent has to happen here.
class DeepLinkOpenInBrowser extends DeepLinkAction {
  const DeepLinkOpenInBrowser(this.uri);
  final Uri uri;

  @override
  bool operator ==(Object other) =>
      other is DeepLinkOpenInBrowser && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'DeepLinkOpenInBrowser($uri)';
}

/// The URI isn't one we handle (foreign scheme/host, or an unrecognized
/// `saqqar://` link) — do nothing.
class DeepLinkIgnore extends DeepLinkAction {
  const DeepLinkIgnore();

  @override
  bool operator ==(Object other) => other is DeepLinkIgnore;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'DeepLinkIgnore()';
}

/// Translates incoming deep links into router actions.
///
/// Two link families land here, both parsed scheme-independently:
///
/// 1. `saqqar://...` custom scheme (spec §4.4) — used by push/handoff:
///    - `saqqar://conversation/<uuid>` → `/chats/<uuid>`
///    - `saqqar://approval/<uuid>?conversation=<convId>` →
///      `/chats/<convId>?approval=<uuid>` (the chat screen pops its own
///      approvals sheet — Inbox tab was retired). The conversation id MUST
///      ride on the link because [resolve] is pure/synchronous and can't look
///      up an approval → conversation mapping; the push that raises the link
///      already knows both ids (SAQQAR_MOBILE_API.md §8).
///    - `saqqar://credential/add?kind=xmlrpc` → `/vault/add?kind=xmlrpc`
///    - `saqqar://share/<token>` → `/share/<token>`
///
/// 2. `https://saqqaar.com/...` Universal Links (iOS) / App Links (Android)
///    — see [webAction] and the `docs/SAQQAR_DEEP_LINKS_FLUTTER.md` mapping.
///
/// Platform plumbing (Associated Domains, the `assetlinks.json`-verified
/// intent-filter, and the URL scheme) lives in `ios/Runner/*.entitlements`
/// and `android/app/src/main/AndroidManifest.xml`. The URI itself is received
/// by the `app_links` plugin and dispatched via [DeepLinkService].
class DeepLinks {
  DeepLinks._();

  /// Custom scheme for push/handoff links.
  static const String scheme = 'saqqar';

  /// Web host the Universal / App Links are verified for. `www.` is accepted
  /// defensively even though only the apex is currently configured on the
  /// platforms, so a future association-file change needs no Dart edit.
  static const String webHost = 'saqqaar.com';

  /// Path prefixes under [webHost] that MUST stay in the browser (spec §4).
  /// `/auth/*` are OAuth callbacks — routing them into the app breaks web
  /// sign-in. The rest are web-only surfaces (add-in, admin, static assets).
  static const List<String> _browserOnlyPrefixes = <String>[
    '/auth',
    '/excel-addin',
    '/settings',
    '/admin',
    '/static',
    '/media',
  ];

  /// Exact paths under [webHost] that stay in the browser (spec §4). These are
  /// content pages with no in-app equivalent.
  static const Set<String> _browserOnlyExact = <String>{
    '/privacy',
    '/terms',
    '/support',
    '/refund',
    '/cancellation',
  };

  /// Classifies [uri] into the action the app should take. Pure — the caller
  /// ([DeepLinkService]) performs the navigation / browser launch.
  static DeepLinkAction actionFor(Uri uri) {
    if (uri.scheme == scheme) {
      final route = resolve(uri);
      return route == null ? const DeepLinkIgnore() : DeepLinkNavigate(route);
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') && _isWebHost(uri)) {
      return webAction(uri);
    }
    return const DeepLinkIgnore();
  }

  /// Classifies a `saqqaar.com` web link. Recognized app paths navigate;
  /// excluded paths (spec §4) open in the browser; anything else falls back
  /// to Home — the safe default the spec's mapping table specifies.
  static DeepLinkAction webAction(Uri uri) {
    if (_isBrowserOnly(uri)) return DeepLinkOpenInBrowser(uri);
    final route = webRoute(uri);
    return DeepLinkNavigate(route ?? RouteNames.chatsPath);
  }

  /// The in-app route for a recognized `saqqaar.com` path, or `null` when the
  /// path has no dedicated screen (caller falls back to Home). Mirrors the
  /// screens the `saqqar://` push links already use, so one set of
  /// destinations covers both link families.
  ///
  /// | Incoming path            | Route                         |
  /// |--------------------------|-------------------------------|
  /// | `/`                      | `/chats` (home)               |
  /// | `/new`                   | `/chats/new` (new chat)       |
  /// | `/chats/<id>`            | `/chats/<id>`                 |
  /// | `/share/<token>`         | `/share/<token>`              |
  static String? webRoute(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return RouteNames.chatsPath;
    switch (segments.first) {
      case 'new':
        return RouteNames.chatPath(UiStrings.newConversationId);
      case 'chats':
        if (segments.length > 1 && segments[1].isNotEmpty) {
          return RouteNames.chatPath(segments[1]);
        }
        return RouteNames.chatsPath;
      case 'share':
        if (segments.length > 1 && segments[1].isNotEmpty) {
          return RouteNames.sharedTranscriptPath(segments[1]);
        }
        return null;
    }
    return null;
  }

  static bool _isWebHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == webHost || host == 'www.$webHost';
  }

  static bool _isBrowserOnly(Uri uri) {
    // `uri.path` drops the query/fragment; normalize an empty path to '/'.
    final path = uri.path.isEmpty ? '/' : uri.path;
    for (final prefix in _browserOnlyPrefixes) {
      if (path == prefix || path.startsWith('$prefix/')) return true;
    }
    return _browserOnlyExact.contains(path);
  }

  /// Returns the in-app route for a `saqqar://` [uri], or `null` if it's not
  /// recognized. Kept for the custom scheme only; web links go through
  /// [webAction]. See the class doc for the supported forms.
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

  /// Convenience: resolve a `saqqar://` [uri] then push it onto [router].
  /// Returns `true` when the link was recognized and dispatched. Web links
  /// go through [DeepLinkService] / [actionFor] instead.
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
