import 'package:equatable/equatable.dart';

/// Generic four-branch state for any async data fetch.
///
/// Every Cubit that loads data from an API should emit `DataState<T>`
/// instead of a raw value — that way views always know whether to render
/// a spinner, the data, or an error retry, without each cubit reinventing
/// the wheel.
///
/// Pattern match in Dart 3:
/// ```dart
/// switch (state.projects) {
///   DataIdle()    => const SizedBox.shrink(),
///   DataLoading() => const AppLoadingState(),
///   DataSuccess(data: final p) => ProjectsList(projects: p),
///   DataFailure(message: final m) => AppErrorState(message: m, onRetry: ...),
/// }
/// ```
///
/// Or use [DataStateView] for the common "spinner / data / retry"
/// rendering with sensible defaults.
sealed class DataState<T> extends Equatable {
  const DataState();

  /// Convenience: the wrapped data when present, otherwise null. Useful
  /// when the view wants to keep stale data visible during a refresh.
  T? get dataOrNull => switch (this) {
        DataSuccess<T>(data: final d) => d,
        _ => null,
      };

  bool get isLoading => this is DataLoading<T>;
  bool get isSuccess => this is DataSuccess<T>;
  bool get isFailure => this is DataFailure<T>;
  bool get isIdle => this is DataIdle<T>;

  @override
  List<Object?> get props => const [];
}

/// Initial state — no fetch attempted yet. Used as the seed for cubits
/// that defer their first load until a view subscribes.
final class DataIdle<T> extends DataState<T> {
  const DataIdle();
}

/// Fetch in flight. Carries the previous successful data (if any) so the
/// view can show a "stale + refreshing" UI instead of flickering back to
/// a spinner — pull-to-refresh, pagination, optimistic updates all need
/// this.
final class DataLoading<T> extends DataState<T> {
  const DataLoading({this.previous});

  final T? previous;

  @override
  List<Object?> get props => [previous];
}

/// Fetch succeeded — render [data].
final class DataSuccess<T> extends DataState<T> {
  const DataSuccess(this.data);

  final T data;

  @override
  List<Object?> get props => [data];
}

/// Fetch failed. [message] is the user-facing, localized string ready to
/// render. [error] is the raw exception kept for logging / retry context.
final class DataFailure<T> extends DataState<T> {
  const DataFailure({
    required this.message,
    this.error,
    this.previous,
  });

  final String message;
  final Object? error;

  /// Previous successful data when the failure happened during a refresh
  /// (so the view can keep showing stale data with an error toast on top
  /// instead of replacing it with a full-screen error).
  final T? previous;

  @override
  List<Object?> get props => [message, error, previous];
}
