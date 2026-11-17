import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Emits `true` whenever the device has at least one active network
/// interface (wifi / mobile / ethernet / vpn), `false` otherwise. UI
/// surfaces (e.g. [OfflineBanner], the chat composer) watch this to
/// disable network-dependent actions while offline.
///
/// Defaults to `true` so the UI doesn't flash an offline banner before
/// the first check returns.
///
/// Backed by the `connectivity_plus` package. We only check connectivity
/// *type* — confirming actual reachability is a separate concern (e.g.
/// ping-on-send) and is deferred until the real API is wired.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity(),
      super(true) {
    _sub = _connectivity.onConnectivityChanged.listen(_onChange);
    unawaited(_seed());
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _seed() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _onChange(results);
    } on Object {
      // Connectivity APIs throw on some unsupported platforms — treat as
      // online so we don't block the user with a false offline banner.
      if (!isClosed) emit(true);
    }
  }

  void _onChange(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!isClosed && online != state) emit(online);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
