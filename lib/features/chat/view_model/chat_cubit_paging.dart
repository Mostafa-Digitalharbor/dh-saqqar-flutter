import 'chat_cubit.dart';
import 'chat_scroll_coordinator.dart';

/// Adapts [ChatCubit] to the four members [ChatScrollCoordinator] needs.
///
/// Lives here rather than in the coordinator so that file imports no cubit,
/// no state and no repository — which is what makes its state machine
/// testable against a dozen-line fake instead of a live polling stack.
///
/// Constructed per call. The cubit is resolved out of the widget tree, and
/// holding that reference across the screen's life would outlive the lookup
/// that produced it.
class ChatCubitPaging implements ChatPagingSource {
  const ChatCubitPaging(this._cubit);

  final ChatCubit _cubit;

  @override
  bool get hasMoreOlder => _cubit.state.hasMoreOlder;

  /// The cubit reports a failed page by emitting rather than throwing, so a
  /// non-null `actionFailure` straight after an awaited [loadOlder] is the
  /// only signal that the rows never arrived.
  @override
  bool get lastLoadFailed => _cubit.state.actionFailure != null;

  @override
  Future<void> loadOlder({int? rows}) => _cubit.loadOlder(rows: rows);

  @override
  Future<void> prefetchOlder({int? rows}) => _cubit.prefetchOlder(rows: rows);
}
