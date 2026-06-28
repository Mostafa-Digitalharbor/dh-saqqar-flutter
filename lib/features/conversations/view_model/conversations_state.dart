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
    this.pendingByConv = const {},
    this.filesByConv = const {},
  });

  final List<ConversationSummary> conversations;

  /// In-memory set of pinned ids. Reset on app restart by design — if
  /// you want persistence wire a SharedPreferences read in
  /// [ConversationsCubit] on cold start.
  final Set<String> pinnedIds;

  /// Total count from the paginated response (when supplied). Use for
  /// the "M conversations" label without iterating the list.
  final int? total;

  /// REAL per-conversation pending-approval counts, grouped from the flat
  /// `/approvals/?status=pending` feed. Drives the row's "N to approve"
  /// pill, the "Needs approval" filter, and the filter badge. Missing key =
  /// no pending approvals for that conversation.
  final Map<String, int> pendingByConv;

  /// REAL per-conversation file counts, grouped from the flat `/artifacts/`
  /// feed. Drives the row's file count. Missing key = no files.
  final Map<String, int> filesByConv;

  /// Real pending-approval count for [id] (0 when none).
  int pendingApprovalsFor(String id) => pendingByConv[id] ?? 0;

  /// Real produced-file count for [id] (0 when none).
  int filesFor(String id) => filesByConv[id] ?? 0;

  /// Whether the conversation has at least one pending approval — the real
  /// signal behind the "Needs approval" filter.
  bool needsApproval(String id) => pendingApprovalsFor(id) > 0;

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
    Map<String, int>? pendingByConv,
    Map<String, int>? filesByConv,
  }) {
    return ConversationsData(
      conversations: conversations ?? this.conversations,
      pinnedIds: pinnedIds ?? this.pinnedIds,
      total: total ?? this.total,
      pendingByConv: pendingByConv ?? this.pendingByConv,
      filesByConv: filesByConv ?? this.filesByConv,
    );
  }

  @override
  List<Object?> get props =>
      [conversations, pinnedIds, total, pendingByConv, filesByConv];
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
