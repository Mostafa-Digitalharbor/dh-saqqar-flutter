import 'package:flutter/material.dart';

import '../../core/state/data_state.dart';
import '../extensions/context_extensions.dart';
import 'data_state_view.dart';

/// [DataStateView] + a pull-to-refresh [RefreshIndicator] glued together.
///
/// Use whenever a screen-level cubit emits `DataState<T>` AND should
/// support manual refresh — the most common case. Hands off rendering
/// to [DataStateView] internally, so all four DataState branches are
/// handled uniformly with a single shared widget.
///
/// Behavior:
///   * The pull gesture only fires inside the data branch (otherwise
///     the spinner / error states are already conveying "we're working
///     on it"). [onRefresh] returns a Future that completes when the
///     RefreshIndicator should retract.
///   * `keepPreviousOnLoading` is forced on — the data list stays
///     visible during the refresh roundtrip rather than blanking to a
///     full-screen spinner (would defeat the point of pull-to-refresh).
///
/// ```dart
/// DataStateRefreshableView<VaultData>(
///   state: state.data,
///   onRefresh: () => context.read<VaultCubit>().refresh(),
///   onData: (context, data) => ProjectsList(projects: data.projects),
/// )
/// ```
class DataStateRefreshableView<T> extends StatelessWidget {
  const DataStateRefreshableView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onData,
    this.onLoading,
    this.onError,
    this.onIdle,
    this.loadingLabel,
    this.keepPreviousOnLoading = true,
  });

  final DataState<T> state;

  /// Triggered by the pull-down gesture. The returned future controls
  /// how long the indicator stays visible — usually
  /// `() => cubit.refresh()` (the cubit's refresh future).
  final Future<void> Function() onRefresh;

  final Widget Function(BuildContext context, T data) onData;
  final Widget Function(BuildContext context, T? previous)? onLoading;
  final Widget Function(BuildContext context, DataFailure<T> failure)? onError;
  final WidgetBuilder? onIdle;
  final String? loadingLabel;

  /// When `true` (default), the previous successful data stays visible
  /// during a refresh — pull-to-refresh feels gentle and the RefreshIndicator
  /// spinner is the only "we're working" signal.
  ///
  /// Set `false` for screens that want skeleton placeholders during
  /// refresh: the loading branch fires every time data is in flight,
  /// so the screen can paint card-shaped shimmers in place of the
  /// rows until the new data lands.
  final bool keepPreviousOnLoading;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return RefreshIndicator(
      color: s.brandCyan,
      backgroundColor: s.surface,
      onRefresh: onRefresh,
      // The indicator needs a scrollable child to anchor to. The data
      // branch supplies its own scrollable; the loading / error / idle
      // branches don't — wrap them in a single-child scroll view that
      // fills the viewport so the pull gesture still works.
      child: DataStateView<T>(
        state: state,
        loadingLabel: loadingLabel,
        keepPreviousOnLoading: keepPreviousOnLoading,
        onRetry: onRefresh,
        onIdle: (context) => _scrollFill(onIdle?.call(context) ?? const SizedBox.shrink()),
        onLoading: onLoading == null
            ? null
            : (context, prev) => _scrollFill(onLoading!(context, prev)),
        onError: onError == null
            ? null
            : (context, failure) => _scrollFill(onError!(context, failure)),
        onData: onData,
      ),
    );
  }

  /// Wraps a non-scrollable branch in a [SingleChildScrollView] so the
  /// surrounding [RefreshIndicator] still receives drag gestures even
  /// when the body is small.
  Widget _scrollFill(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // When the parent provides unbounded height (e.g. nested inside
        // a scrollable Column from PageScaffold), we can't enforce
        // minHeight=Infinity — it crashes with "RenderBox was not laid
        // out". In that case the parent is already scrollable, so just
        // render the child directly.
        if (!constraints.maxHeight.isFinite) {
          return child;
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}
