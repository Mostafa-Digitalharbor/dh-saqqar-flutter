import 'package:flutter/material.dart';

import '../../core/network/api_error_mapper.dart';
import '../../core/state/data_state.dart';
import 'app_error_state.dart';
import 'app_loading_state.dart';

/// One widget that uniformly renders the four [DataState] branches.
///
/// Cubits that hold API data emit `DataState<T>`; views read it via
/// `BlocBuilder` and hand the snapshot to `DataStateView` — keeping
/// loading / error / data branching out of the screen code:
///
/// ```dart
/// BlocBuilder<VaultCubit, VaultState>(
///   builder: (context, state) => DataStateView<VaultData>(
///     state: state.data,
///     onRetry: () => context.read<VaultCubit>().refresh(),
///     onData: (context, data) => ProjectsList(projects: data.projects),
///   ),
/// )
/// ```
///
/// Defaults match the brand:
///   * `idle` → empty (the view is mounted but no fetch was triggered).
///   * `loading` → centered [AppLoadingState] with [loadingLabel].
///   * `failure` → [AppErrorState] with the message + retry.
///   * `success` → [onData].
///
/// Override any branch with the matching `onXxx` callback. Pass
/// [keepPreviousOnLoading] = true to render the last successful data
/// even while a refresh is in flight (pull-to-refresh feel).
class DataStateView<T> extends StatelessWidget {
  const DataStateView({
    super.key,
    required this.state,
    required this.onData,
    this.onLoading,
    this.onError,
    this.onIdle,
    this.onRetry,
    this.onStaleFailure,
    this.loadingLabel,
    this.keepPreviousOnLoading = false,
  });

  /// The state emitted by the cubit.
  final DataState<T> state;

  /// Renders the success branch. Required — there's no sensible default
  /// for "your data is loaded, now what".
  final Widget Function(BuildContext context, T data) onData;

  /// Override for the loading branch. Defaults to [AppLoadingState] with
  /// [loadingLabel] if supplied.
  final Widget Function(BuildContext context, T? previous)? onLoading;

  /// Override for the failure branch. Defaults to [AppErrorState] showing
  /// the failure's [DataFailure.message] + a retry button (if [onRetry]
  /// is provided).
  final Widget Function(BuildContext context, DataFailure<T> failure)? onError;

  /// Override for the idle branch. Defaults to an empty [SizedBox].
  final WidgetBuilder? onIdle;

  /// Wires the retry button on the default error surface. When null no
  /// retry button is shown — use that for terminal errors (deleted
  /// resource, etc.) where retry won't help.
  final VoidCallback? onRetry;

  /// Called once when the state is [DataFailure] BUT we have stale
  /// previous data to keep on screen (so the user wouldn't otherwise
  /// see the error). Surface as a toast at the screen level so a
  /// failed pull-to-refresh isn't invisible. Fires inside a
  /// post-frame callback so it's safe to call `BuildContext`-bound
  /// helpers (toasts, navigation).
  final void Function(BuildContext context, DataFailure<T> failure)?
      onStaleFailure;

  /// Caption under the spinner. Optional.
  final String? loadingLabel;

  /// When true and the loading state carries a [DataLoading.previous]
  /// value, render the success view with that previous value instead of
  /// the spinner. Use for pull-to-refresh / pagination so the list
  /// doesn't flash empty during a reload.
  final bool keepPreviousOnLoading;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      DataIdle<T>() =>
        onIdle != null ? onIdle!(context) : const SizedBox.shrink(),
      DataLoading<T>(previous: final prev) => _buildLoading(context, prev),
      DataSuccess<T>(data: final d) => onData(context, d),
      DataFailure<T>(previous: final prev) when prev != null =>
        _buildStaleData(context, prev, state as DataFailure<T>),
      DataFailure<T>() => _buildError(context, state as DataFailure<T>),
    };
  }

  /// Renders the previous successful data + fires [onStaleFailure] once
  /// per failure transition so the screen can surface a toast (failed
  /// pull-to-refresh, background re-fetch error). Without this hook the
  /// failure would be silently masked — the data stays on screen but
  /// the user never learns the refresh didn't take.
  Widget _buildStaleData(
    BuildContext context,
    T previous,
    DataFailure<T> failure,
  ) {
    final notify = onStaleFailure;
    if (notify != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) notify(context, failure);
      });
    }
    return onData(context, previous);
  }

  Widget _buildLoading(BuildContext context, T? previous) {
    if (keepPreviousOnLoading && previous != null) {
      return onData(context, previous);
    }
    if (onLoading != null) return onLoading!(context, previous);
    return AppLoadingState(label: loadingLabel);
  }

  Widget _buildError(BuildContext context, DataFailure<T> failure) {
    if (onError != null) return onError!(context, failure);
    // Prefer the typed [error] so the message renders in the active locale.
    // Cubits set [message] as a non-localized English fallback for logging;
    // routing through [ApiErrorMapper] keeps an Arabic UI fully Arabic.
    final message = failure.error != null
        ? ApiErrorMapper.message(context, failure.error)
        : failure.message;
    return AppErrorState(
      message: message,
      onRetry: onRetry,
    );
  }
}
