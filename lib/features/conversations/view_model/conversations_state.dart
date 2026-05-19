import 'package:equatable/equatable.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/state/data_state.dart';
import '../data/conversation_models.dart';

/// Identifies which mutation a failure / success toast belongs to, so the
/// view can prefix the localized error message with a meaningful action
/// label. Same pattern as VaultAction — keeps strings out of the cubit.
enum ConversationsAction {
  load,
  create,
  rename,
  archive,
  unarchive,
  delete,
  stop,
}

enum ConversationsToast {
  conversationCreated,
  conversationRenamed,
  conversationArchived,
  conversationUnarchived,
  conversationDeleted,
  conversationStopped,
}

class ConversationsActionFailure extends Equatable {
  const ConversationsActionFailure({
    required this.action,
    required this.failure,
  });
  final ConversationsAction action;
  final AppFailure failure;
  @override
  List<Object?> get props => [action, failure];
}

/// Data block emitted by [ConversationsCubit].
///
/// The server returns a flat [ConversationSummary] list per
/// SAQQAR_MOBILE_API.md §2; pinning is a local-only client concept
/// (the server has no pin endpoint), so [pinnedIds] lives entirely
/// in-memory and merges into the sorted view via [ordered].
class ConversationsData extends Equatable {
  const ConversationsData({
    required this.conversations,
    this.pinnedIds = const {},
    this.total,
  });

  final List<ConversationSummary> conversations;

  /// In-memory set of pinned ids. Reset on app restart by design — if
  /// you want persistence wire a SharedPreferences read in
  /// [ConversationsCubit] on cold start.
  final Set<String> pinnedIds;

  /// Total count from the paginated response (when supplied). Use for
  /// the "M conversations" label without iterating the list.
  final int? total;

  /// Sorted view: pinned first (preserving original order), the rest
  /// in API order. The original [conversations] field stays unsorted
  /// so callers that need raw ordering can opt out.
  List<ConversationSummary> get ordered {
    if (pinnedIds.isEmpty) return conversations;
    final pinned = <ConversationSummary>[];
    final rest = <ConversationSummary>[];
    for (final c in conversations) {
      (pinnedIds.contains(c.id) ? pinned : rest).add(c);
    }
    return [...pinned, ...rest];
  }

  bool isPinned(String id) => pinnedIds.contains(id);

  /// Returns the matching conversation by id, or null when the user
  /// just deleted it (race between optimistic delete + a render pass).
  ConversationSummary? byId(String id) {
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Effective display title for a conversation — server title takes
  /// precedence; the old "rename overlay" pattern is gone because
  /// renames now hit PATCH and update [conversations] directly.
  String titleFor(ConversationSummary conv) => conv.title;

  ConversationsData copyWith({
    List<ConversationSummary>? conversations,
    Set<String>? pinnedIds,
    int? total,
  }) {
    return ConversationsData(
      conversations: conversations ?? this.conversations,
      pinnedIds: pinnedIds ?? this.pinnedIds,
      total: total ?? this.total,
    );
  }

  @override
  List<Object?> get props => [conversations, pinnedIds, total];
}

/// Top-level state. Same shape as VaultState — same `data` /
/// `actionInFlight` / `actionFailure` / `actionToast` quartet, ready to
/// be extracted into a `MutationMixin<TState, TAction, TToast>` when we
/// have three or more features following the pattern (see survey #2).
class ConversationsState extends Equatable {
  const ConversationsState({
    this.data = const DataIdle<ConversationsData>(),
    this.actionInFlight = false,
    this.actionFailure,
    this.actionToast,
  });

  final DataState<ConversationsData> data;
  final bool actionInFlight;
  final ConversationsActionFailure? actionFailure;
  final ConversationsToast? actionToast;

  ConversationsState copyWith({
    DataState<ConversationsData>? data,
    bool? actionInFlight,
    ConversationsActionFailure? actionFailure,
    ConversationsToast? actionToast,
    bool clearActionFailure = false,
    bool clearActionToast = false,
  }) {
    return ConversationsState(
      data: data ?? this.data,
      actionInFlight: actionInFlight ?? this.actionInFlight,
      actionFailure:
          clearActionFailure ? null : (actionFailure ?? this.actionFailure),
      actionToast:
          clearActionToast ? null : (actionToast ?? this.actionToast),
    );
  }

  @override
  List<Object?> get props => [data, actionInFlight, actionFailure, actionToast];
}
