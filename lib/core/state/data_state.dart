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

  /// The wrapped data when this state is a *success*, otherwise null.
  ///
  /// Deliberately strict: this answers "is the data I'm holding current?".
  /// For "do I have anything at all to show the user?" — which is what a
  /// refresh path wants — use [dataOrPrevious].
  T? get dataOrNull => switch (this) {
    DataSuccess<T>(data: final d) => d,
    _ => null,
  };

  /// The freshest data available, *including* the stale copy that a loading
  /// or failed state carries forward.
  ///
  /// Both [DataLoading] and [DataFailure] have a `previous` field precisely so
  /// a transient error doesn't throw away what the user was already looking
  /// at — but [dataOrNull] can't see it, and a cubit that decides "should I
  /// show a skeleton?" with `dataOrNull == null` will answer *yes* the moment
  /// one refresh fails. That is how a flaky network turns a populated list
  /// into full-screen shimmers that never come back: the failure clears the
  /// data, the next poll sees nothing, paints a skeleton, fails again, and
  /// stores `previous: null`. Reach for this getter in that decision.
  T? get dataOrPrevious => switch (this) {
    DataSuccess<T>(data: final d) => d,
    DataLoading<T>(previous: final p) => p,
    DataFailure<T>(previous: final p) => p,
    DataIdle<T>() => null,
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
  const DataFailure({required this.error, this.previous});

  /// The thrown object, kept raw so the *view* decides the wording.
  ///
  /// This used to sit next to a `required String message` that every cubit
  /// had to invent ("Failed to load apps"). That message was English, and
  /// cubits have no `BuildContext` to localize with — so the field was a
  /// standing invitation to render English inside an Arabic screen. It
  /// survived only because every cubit also passed `error`, and
  /// `DataStateView` preferred `error` when it was non-null; the moment one
  /// new cubit passed just a message, an Arabic user would have seen it.
  ///
  /// Making [error] the required field removes the choice: the view always
  /// resolves copy through `ApiErrorMapper.message`, which is locale-aware
  /// and re-evaluates if the user switches language after the emit. `null`
  /// is still accepted (some failures have no exception object) and maps to
  /// the generic "something went wrong" line.
  final Object? error;

  /// Previous successful data when the failure happened during a refresh
  /// (so the view can keep showing stale data with an error toast on top
  /// instead of replacing it with a full-screen error).
  final T? previous;

  @override
  List<Object?> get props => [error, previous];
}
