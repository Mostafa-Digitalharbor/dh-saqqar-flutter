import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../constants/ui_strings.dart';
import 'route_names.dart';

/// Translates both the legacy `saqqar://...` custom-scheme URIs (spec §4.4,
/// still used by push notifications) and the `https://saqqaar.com/...`
/// universal / app links (iOS Associated Domains + Android verified App
/// Links) into in-app routes.
///
/// Supported `saqqar://` links:
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
/// Supported `https://saqqaar.com/...` links — see [_resolveWebLink].
///
/// Returns the in-app path the router should navigate to, or `null` when the
/// link can't be parsed, or is one of the browser-only paths the server-side
/// association files deliberately exclude (caller should leave navigation
/// alone / show a "Couldn't open link" toast for a truly unrecognized link).
///
/// Platform plumbing (intent-filters, URL scheme, Associated Domains) is the
/// mobile runner's job — see `android/app/src/main/AndroidManifest.xml` and
/// `ios/Runner/Runner.entitlements`. [UniversalLinkBootstrap] (in
/// `universal_link_bootstrap.dart`) wires the `app_links` package's cold-start
/// + streamed URIs into [DeepLinks.handle].
class DeepLinks {
  DeepLinks._();

  static const String scheme = 'saqqar';
  static const String webHost = 'saqqaar.com';

  /// `saqqaar.com` paths that intentionally stay in the browser (OAuth
  /// callbacks, legal pages, the Excel add-in, static/media assets). The
  /// server-side `apple-app-site-association` / `assetlinks.json` already
  /// exclude these from tap-to-open-app, so a normally tapped link never
  /// reaches [resolve] at all — this list is a defense-in-depth guard for
  /// anything that does (e.g. a manually constructed or `saqqar://`-relayed
  /// URI).
  static const _excludedPrefixes = <String>[
    '/auth/',
    '/excel-addin/',
    '/settings/',
    '/admin/',
    '/static/',
    '/media/',
  ];
  static const _excludedExact = <String>[
    '/privacy',
    '/terms',
    '/support',
    '/refund',
    '/cancellation',
  ];

  /// Returns the in-app route for [uri], or `null` if it's not recognized.
  static String? resolve(Uri uri) {
    if (uri.scheme == scheme) return _resolveCustomScheme(uri);
    if (uri.scheme == 'https' && uri.host == webHost) {
      return _resolveWebLink(uri);
    }
    return null;
  }

  static String? _resolveCustomScheme(Uri uri) {
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

  /// `https://saqqaar.com/<path>` → in-app route.
  ///
  /// - `/` → Home (Chats list)
  /// - `/new` → New conversation
  /// - `/chats/<id>` → that conversation (same target as the custom-scheme
  ///   `saqqar://conversation/<id>`)
  /// - `/share/<token>` → the public shared-transcript view (same target as
  ///   `saqqar://share/<token>`)
  /// - anything else → Home (safe default), UNLESS the path is one of the
  ///   browser-only paths in [_excludedPrefixes] / [_excludedExact], in which
  ///   case we return `null` and leave navigation alone entirely.
  static String? _resolveWebLink(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (_excludedExact.contains(path) ||
        _excludedPrefixes.any(path.startsWith)) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) return RouteNames.chatsPath;

    switch (segments.first) {
      case 'new':
        return RouteNames.chatPath(UiStrings.newConversationId);
      case 'chats':
        return segments.length > 1
            ? RouteNames.chatPath(segments[1])
            : RouteNames.chatsPath;
      case 'share':
        return segments.length > 1
            ? RouteNames.sharedTranscriptPath(segments[1])
            : RouteNames.chatsPath;
      default:
        return RouteNames.chatsPath;
    }
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
