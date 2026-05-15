import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive provider that emits `true` whenever the device has at least one
/// active network interface (wifi / mobile / ethernet / vpn), and `false`
/// otherwise. UI surfaces (e.g. [OfflineBanner], the chat composer) watch
/// this to disable network-dependent actions while offline.
///
/// Backed by the `connectivity_plus` package. We only check connectivity
/// type — confirming actual reachability is a separate concern (e.g.,
/// ping-on-send) and is deferred until the real API is wired.
final connectivityControllerProvider =
    NotifierProvider<ConnectivityController, bool>(ConnectivityController.new);

class ConnectivityController extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  bool build() {
    final connectivity = Connectivity();
    // Seed the state from the current snapshot, then keep it in sync with
    // the stream. We default to `true` so the UI doesn't flash an offline
    // banner before the first check returns.
    unawaited(_seed(connectivity));
    _sub = connectivity.onConnectivityChanged.listen(_onChange);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return true;
  }

  Future<void> _seed(Connectivity connectivity) async {
    try {
      final results = await connectivity.checkConnectivity();
      _onChange(results);
    } on Object {
      // Connectivity APIs throw on some unsupported platforms — treat as
      // online so we don't block the user with a false offline banner.
      state = true;
    }
  }

  void _onChange(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != state) state = online;
  }
}
