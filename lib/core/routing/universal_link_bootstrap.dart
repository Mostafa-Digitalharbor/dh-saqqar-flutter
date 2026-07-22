import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../logging/app_logger.dart';
import 'app_router.dart';
import 'deep_links.dart';

/// Wires `https://saqqaar.com/...` universal / app links and the legacy
/// `saqqar://...` custom scheme into [appRouter], for both the cold-start
/// case (app launched by tapping a link) and the running case (link tapped
/// while the app is already open).
///
/// Mounted inside `MaterialApp.router`'s `builder:` in `app.dart` — i.e.
/// AFTER [appRouter] is guaranteed non-null (the router is built earlier in
/// that same `build()` call via `routerConfig: _router`; see the doc on
/// `appRouter` in `app_router.dart`).
class UniversalLinkBootstrap extends StatefulWidget {
  const UniversalLinkBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<UniversalLinkBootstrap> createState() =>
      _UniversalLinkBootstrapState();
}

class _UniversalLinkBootstrapState extends State<UniversalLinkBootstrap> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _consumeInitialLink();
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.warn(
          'UniversalLinkBootstrap',
          'link stream error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> _consumeInitialLink() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (e, st) {
      AppLogger.warn(
        'UniversalLinkBootstrap',
        'getInitialLink failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _handleUri(Uri uri) {
    final router = appRouter;
    if (router == null) {
      // Shouldn't happen — this widget only mounts after the router is
      // built (see class doc) — but degrade to a no-op rather than crash if
      // the boot order ever changes.
      if (kDebugMode) {
        debugPrint('[UniversalLinkBootstrap] router not ready yet: $uri');
      }
      return;
    }
    DeepLinks.handle(router, uri);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
