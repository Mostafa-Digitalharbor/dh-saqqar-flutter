import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../data/conversation_models.dart';
import '../data/conversations_repository.dart';
import 'conversations_state.dart';

/// ViewModel for the Conversations tab (list view).
///
/// Owns:
///   * The async lifecycle of the conversation list ([state.data]).
///   * Optimistic mutations for rename / archive / delete (server PATCH
///     fires in the background; rollback on failure).
///   * In-memory pin overlay — server has no pin endpoint per
///     SAQQAR_MOBILE_API.md, so pinning lives here only.
///
/// Pattern mirrors [VaultCubit] — every mutation returns `Future<bool>`,
/// failures land on `state.actionFailure` as typed [AppFailure], the
/// view's BlocListener surfaces localized toasts via [ApiErrorMapper].
class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit({required ConversationsRepository repository})
      : _repo = repository,
        super(const ConversationsState());

  static const _tag = 'ConversationsCubit';

  final ConversationsRepository _repo;

  /// Drop any [emit] call that lands after [close]. Same guard pattern
  /// as [ChatCubit.emit] — every load / mutation here awaits the
  /// repository, and the cubit can be reset (and effectively closed)
  /// by the auth gate during sign-out mid-fetch.
  @override
  void emit(ConversationsState state) {
    if (isClosed) return;
    super.emit(state);
  }

  // ── Loading ─────────────────────────────────────────────────────────

  /// Initial load — fetches the conversation list. Default now
  /// includes archived rows so the "Archived" filter on the screen
  /// has something to show; the screen still filters locally to
  /// decide whether to display them. Pull-to-refresh hits the same
  /// path via [refresh].
  Future<void> load({bool includeArchived = true}) async {
    if (state.data is DataLoading<ConversationsData>) return;
    emit(state.copyWith(
      data: DataLoading<ConversationsData>(previous: state.data.dataOrNull),
    ));
    try {
      final res = await _repo.list(includeArchived: includeArchived);
      final pinned = state.data.dataOrNull?.pinnedIds ?? const <String>{};
      emit(state.copyWith(
        data: DataSuccess(
          ConversationsData(
            conversations: res.conversations,
            pinnedIds: pinned,
            total: res.total,
          ),
        ),
      ));
    } catch (e, st) {
      AppLogger.error(_tag, 'load() failed', error: e, stackTrace: st);
      final failure = ApiErrorMapper.toFailure(e);
      emit(state.copyWith(
        data: DataFailure<ConversationsData>(
          message: 'Failed to load conversations',
          error: failure,
          previous: state.data.dataOrNull,
        ),
        actionFailure: ConversationsActionFailure(
          action: ConversationsAction.load,
          failure: failure,
        ),
      ));
    }
  }

  Future<void> refresh() => load();

  /// Drops the in-memory conversation list back to the idle state.
  /// Called from the auth boundary when the signed-in user changes
  /// (sign-out OR sign-in as a different account) so the previous
  /// user's conversations don't bleed into the new session.
  void reset() {
    if (state == const ConversationsState()) return;
    emit(const ConversationsState());
  }

  // ── Mutations ───────────────────────────────────────────────────────

  /// Creates a new conversation. Returns the new conversation id on
  /// success (so the caller can route into the chat screen immediately),
  /// or null on failure (with [actionFailure] populated).
  Future<String?> createConversation({String? title}) async {
    if (state.actionInFlight) return null;
    emit(state.copyWith(actionInFlight: true, clearActionFailure: true));
    try {
      final id = await _repo.create(title: title);
      // Re-fetch the list so the new row appears (server fills out the
      // summary fields like message_count + preview that the bare POST
      // response doesn't include).
      await load();
      emit(state.copyWith(
        actionInFlight: false,
        actionToast: ConversationsToast.conversationCreated,
      ));
      return id;
    } catch (e, st) {
      AppLogger.warn(_tag, 'createConversation failed', error: e, stackTrace: st);
      emit(state.copyWith(
        actionInFlight: false,
        actionFailure: ConversationsActionFailure(
          action: ConversationsAction.create,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return null;
    }
  }

  Future<bool> renameConversation({
    required String id,
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(false);
    return _runOptimistic(
      ConversationsAction.rename,
      successToast: ConversationsToast.conversationRenamed,
      mutate: (data) {
        return data.copyWith(
          conversations: [
            for (final c in data.conversations)
              if (c.id == id) _renameSummary(c, trimmed) else c,
          ],
        );
      },
      commit: () => _repo.patch(id: id, title: trimmed),
    );
  }

  Future<bool> archiveConversation(String id) {
    return _runOptimistic(
      ConversationsAction.archive,
      successToast: ConversationsToast.conversationArchived,
      // Flip `isArchived = true` in place instead of dropping the row.
      // The screen splits the list into active vs. archived buckets
      // and the archived bucket only renders when there's at least
      // one archived conversation — if we remove the row entirely the
      // archived card stays hidden until a manual refresh, which is
      // exactly the bug the user reported.
      mutate: (data) => data.copyWith(
        conversations: [
          for (final c in data.conversations)
            if (c.id == id) _setArchived(c, true) else c,
        ],
      ),
      commit: () => _repo.patch(id: id, isArchived: true),
    );
  }

  Future<bool> unarchiveConversation(String id) {
    return _runOptimistic(
      ConversationsAction.unarchive,
      successToast: ConversationsToast.conversationUnarchived,
      // Optimistic flip: row appears back in the active list before the
      // server round-trip lands. No need for an extra `load()` call;
      // the in-memory mutation is the source of truth until the next
      // pull-to-refresh.
      mutate: (data) => data.copyWith(
        conversations: [
          for (final c in data.conversations)
            if (c.id == id) _setArchived(c, false) else c,
        ],
      ),
      commit: () => _repo.patch(id: id, isArchived: false),
    );
  }

  Future<bool> deleteConversation(String id) {
    return _runOptimistic(
      ConversationsAction.delete,
      successToast: ConversationsToast.conversationDeleted,
      mutate: (data) => data.copyWith(
        conversations: data.conversations.where((c) => c.id != id).toList(),
        pinnedIds: data.pinnedIds.where((p) => p != id).toSet(),
      ),
      commit: () => _repo.delete(id),
    );
  }

  // ── Pin (local-only) ────────────────────────────────────────────────

  /// Toggles the pin state. No server call — pinning is a client-only
  /// concept that lives in memory until app restart.
  void togglePin(String id) {
    final current = state.data.dataOrNull;
    if (current == null) return;
    final next = {...current.pinnedIds};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    emit(state.copyWith(
      data: DataSuccess(current.copyWith(pinnedIds: next)),
    ));
  }

  bool isPinned(String id) =>
      state.data.dataOrNull?.isPinned(id) ?? false;

  // ── One-shot message acknowledgement ────────────────────────────────

  void consumeActionFailure() {
    if (state.actionFailure == null) return;
    emit(state.copyWith(clearActionFailure: true));
  }

  void consumeActionToast() {
    if (state.actionToast == null) return;
    emit(state.copyWith(clearActionToast: true));
  }

  // ── Internals ───────────────────────────────────────────────────────

  Future<bool> _runOptimistic(
    ConversationsAction action, {
    required ConversationsData Function(ConversationsData) mutate,
    required Future<void> Function() commit,
    ConversationsToast? successToast,
  }) async {
    final current = state.data.dataOrNull;
    if (current == null) return false;
    final optimistic = mutate(current);
    emit(state.copyWith(
      data: DataSuccess(optimistic),
      actionInFlight: true,
      clearActionFailure: true,
    ));
    try {
      await commit();
      emit(state.copyWith(
        actionInFlight: false,
        actionToast: successToast,
      ));
      return true;
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        '${action.name} failed — rolling back',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(
        data: DataSuccess(current),
        actionInFlight: false,
        actionFailure: ConversationsActionFailure(
          action: action,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  /// `ConversationSummary` is immutable + `const` — manual rebuild
  /// instead of a `copyWith` (the model doesn't ship one because the
  /// canonical mutation path is "re-fetch from server").
  ConversationSummary _renameSummary(ConversationSummary c, String name) {
    return ConversationSummary(
      id: c.id,
      title: name,
      createdAt: c.createdAt,
      updatedAt: DateTime.now(),
      isArchived: c.isArchived,
      messageCount: c.messageCount,
      lastMessagePreview: c.lastMessagePreview,
    );
  }

  /// Same shape as [_renameSummary] but flips the archive flag. Lets
  /// the archive/unarchive optimistic mutations move a row between the
  /// active and archived buckets without a server round-trip.
  ConversationSummary _setArchived(ConversationSummary c, bool archived) {
    return ConversationSummary(
      id: c.id,
      title: c.title,
      createdAt: c.createdAt,
      updatedAt: DateTime.now(),
      isArchived: archived,
      messageCount: c.messageCount,
      lastMessagePreview: c.lastMessagePreview,
    );
  }
}
