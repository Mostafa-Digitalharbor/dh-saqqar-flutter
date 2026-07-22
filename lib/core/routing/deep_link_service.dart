import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logging/app_logger.dart';
import 'app_router.dart';
import 'deep_links.dart';
import 'route_names.dart';

/// Receives Universal Links (iOS) / App Links (Android) and the `saqqar://`
/// custom scheme via the `app_links` plugin, and dispatches each URI to the
/// router (or the browser) using [DeepLinks.actionFor].
///
/// Wired once in `app.dart` after the router mounts. Two delivery paths:
///   * [start] reads the cold-start link (app launched by tapping a link) via
///     `getInitialLink()`, then subscribes to `uriLinkStream` for links that
///     arrive while the app is already running/backgrounded.
///
/// It navigates through the global [appRouter] because links can arrive
/// outside any `BuildContext` (e.g. a cold launch, or a background→foreground
/// resume) — there is no widget-tree `context.go` available at that point.
///
/// The engine's own deep-linking is disabled (AndroidManifest
/// `flutter_deeplinking_enabled=false`, Info.plist
/// `FlutterDeepLinkingEnabled=false`) so this service is the single handler
/// and go_router never double-handles the same URI.
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  static const _tag = 'DeepLinkService';

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Handle the cold-start link then listen for subsequent ones. Idempotent —
  /// safe to call more than once (later calls no-op). Never throws: a platform
  /// channel failure degrades to "no deep links" rather than blocking boot.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _dispatch(initial);
    } catch (e, st) {
      AppLogger.warn(_tag, 'getInitialLink failed', error: e, stackTrace: st);
    }

    _sub = _appLinks.uriLinkStream.listen(
      _dispatch,
      onError: (Object e, StackTrace st) =>
          AppLogger.warn(_tag, 'uriLinkStream error', error: e, stackTrace: st),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _dispatch(Uri uri) {
    AppLogger.info(_tag, 'deep link received: $uri');
    final action = DeepLinks.actionFor(uri);
    switch (action) {
      case DeepLinkNavigate(:final route):
        final router = appRouter;
        if (router == null) {
          AppLogger.debug(_tag, 'router not ready; dropping $route');
          return;
        }
        router.go(route);
      case DeepLinkOpenInBrowser(:final uri):
        unawaited(_openInBrowser(uri));
      case DeepLinkIgnore():
        AppLogger.debug(_tag, 'ignored: $uri');
    }
  }

  /// Opens an excluded `saqqaar.com` path (spec §4) outside the app. Uses an
  /// in-app browser view (Chrome Custom Tab / SFSafariViewController): unlike a
  /// plain external launch it does NOT re-trigger App Link verification, so a
  /// verified-domain URL can't bounce straight back into this handler and loop.
  Future<void> _openInBrowser(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (ok) return;
    } catch (e, st) {
      AppLogger.warn(_tag, 'browser launch failed', error: e, stackTrace: st);
    }
    // Fallback: if the browser can't be opened, don't strand the user — send
    // them to Home so a tap always lands somewhere in the app.
    appRouter?.go(DeepLinks.webRoute(uri) ?? RouteNames.chatsPath);
  }
}
