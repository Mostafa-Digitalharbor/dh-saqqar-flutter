import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_logger.dart';

/// Marker interface for Cubits / Blocs that opt OUT of verbose state
/// logging. Implement on noisy cubits (snapshot pollers, ticker-driven
/// state) so they only log creation / errors / close — NOT every state
/// transition.
///
/// Usage:
/// ```dart
/// class ChatSnapshotCubit extends Cubit<ChatSnapshotState>
///     implements QuietBloc {
///   ...
/// }
/// ```
///
/// Creation / error / close events still log — the contract is "noisy
/// state changes only". Use sparingly; verbose logs are the default
/// because they're load-bearing during debugging.
abstract interface class QuietBloc {}

/// Global observer for every Cubit / Bloc in the app. Logs lifecycle
/// events to the dev console so state transitions are visible without
/// sprinkling `print` calls inside cubits.
///
/// Wire once at boot in `main.dart`:
/// ```dart
/// Bloc.observer = AppBlocObserver();
/// ```
///
/// Output (debug-only — release builds are no-op for state changes,
/// errors still flow through [AppLogger.error] for crash reporting):
/// ```
/// ◇ AuthCubit created
/// → AuthCubit · AuthState(initial) → AuthState(loading)
/// → AuthCubit · AuthState(loading) → AuthState(authenticated, user@x.com)
/// ✕ AuthCubit · login failed: ApiException(401)
/// ◇ AuthCubit closed
/// ```
///
/// State diffs use the state's `toString` — Equatable-based states
/// already format compactly. Long states are truncated to 160 chars so
/// the log column stays readable; for richer diffs in a debugger, set a
/// breakpoint inside the cubit instead.
class AppBlocObserver extends BlocObserver {
  AppBlocObserver({this.verboseStateChanges = true});

  /// Global default — set to false to silence verbose logs for every
  /// cubit. Per-cubit silencing is finer-grained: implement [QuietBloc]
  /// on the cubit itself.
  final bool verboseStateChanges;

  bool _verboseFor(BlocBase<dynamic> bloc) {
    if (!verboseStateChanges) return false;
    if (bloc is QuietBloc) return false;
    return true;
  }

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    if (!kDebugMode) return;
    AppLogger.debug('Bloc', '◇ ${_name(bloc)} created');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (!_verboseFor(bloc)) return;
    if (!kDebugMode) return;
    AppLogger.debug(
      'Bloc',
      '→ ${_name(bloc)} · ${_fmt(change.currentState)} → '
          '${_fmt(change.nextState)}',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    // Errors ALWAYS flow through AppLogger.error so the crash reporter
    // sink (when wired) catches them in release. The debug-console
    // formatting is handled inside AppLogger.
    AppLogger.error(
      'Bloc',
      '✕ ${_name(bloc)} threw',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    if (!kDebugMode) return;
    AppLogger.debug('Bloc', '◇ ${_name(bloc)} closed');
  }

  String _name(BlocBase<dynamic> bloc) => bloc.runtimeType.toString();

  /// Truncate long state dumps so the log column stays readable.
  String _fmt(Object? state) {
    final s = state.toString();
    return s.length <= 160 ? s : '${s.substring(0, 157)}…';
  }
}
