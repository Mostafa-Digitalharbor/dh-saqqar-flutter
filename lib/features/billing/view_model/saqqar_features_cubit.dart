import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/saqqar_features.dart';
import '../data/usage_api.dart';

/// Holds the `saqqar_features` flag set app-wide.
///
/// **Why this is not part of [PlanCubit].** `PlanCubit` is replaced wholesale
/// by every conversation snapshot on the 1.5 s poll, and the snapshot's `plan`
/// object does not carry `saqqar_features` — only `GET /api/v1/usage/` does.
/// Storing the flags there would light the tools rows up on an Account visit
/// and blink them out one poll after the user opened a chat. Separate holder,
/// separate lifetime.
///
/// State starts as [SaqqarFeatures.unknown] and only ever moves to a real
/// value; a failed fetch leaves the previous answer standing rather than
/// reverting to unknown, because a transient 500 should not restyle the tools
/// sheet.
class SaqqarFeaturesCubit extends Cubit<SaqqarFeatures> {
  SaqqarFeaturesCubit(this._api) : super(SaqqarFeatures.unknown);

  final UsageApi _api;

  bool _inFlight = false;

  /// Bumped by [clear]. A fetch captures it before awaiting and discards its
  /// own result if it changed while the request was out.
  ///
  /// Without this, signing out mid-fetch leaks the PREVIOUS account's flags
  /// into the next session: `clear()` emits unknown, then the in-flight
  /// response lands and emits user A's staff-only rows for user B. The cubit
  /// is app-scoped and never closed, so `isClosed` cannot catch it.
  int _generation = 0;

  /// Fetch once. Repeat calls are no-ops while a request is in flight, and
  /// after a successful load unless [force] is set.
  ///
  /// Safe to call from `initState` on any screen that gates on a flag — the
  /// guard is what makes "just ask on mount" cheap rather than one request
  /// per chat open.
  Future<void> ensureLoaded({bool force = false}) async {
    if (_inFlight) return;
    if (state.known && !force) return;
    _inFlight = true;
    final generation = _generation;
    try {
      final usage = await _api.fetch();
      if (isClosed || generation != _generation) return;
      emit(usage.saqqarFeatures);
    } catch (_) {
      // Deliberately swallowed. Gating is cosmetic — the server refuses a
      // disabled feature regardless — so a usage fetch that fails must not
      // surface an error on a screen the user opened to do something else.
    } finally {
      _inFlight = false;
    }
  }

  /// Feed flags that another call site already fetched, so the Account and
  /// Usage screens don't trigger a second `/usage/` round-trip.
  void update(SaqqarFeatures features) {
    if (!features.known || features == state) return;
    emit(features);
  }

  /// Clear on sign-out — the next account must not inherit these rows.
  void clear() {
    _generation++;
    emit(SaqqarFeatures.unknown);
  }
}
