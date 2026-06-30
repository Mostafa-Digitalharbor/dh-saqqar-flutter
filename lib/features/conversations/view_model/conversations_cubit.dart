import 'dart:async';

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

  /// Guards against overlapping project/environment enrichment passes when
  /// loads fire in quick succession (mount + pull-to-refresh).
  bool _enriching = false;

  /// Guards against overlapping [load] passes. Replaces the old
  /// `state.data is DataLoading` guard: once the offline cache is hydrated
  /// the state is `DataSuccess`, so a bare DataLoading check would let
  /// mount + refresh overlap. A plain in-flight flag is unambiguous.
  bool _loading = false;

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

  /// Paints the last-persisted Chats list instantly on cold start
  /// (stale-while-revalidate), before the live [load] lands. No-op when
  /// there's already data on state or nothing cached. Mirrors
  /// `VaultCubit.hydrateFromCache`; call once at construction in `main.dart`.
  void hydrateFromCache() {
    if (state.data.dataOrNull != null) return;
    final cached = _repo.readCachedList();
    if (cached == null || cached.conversations.isEmpty) return;
    emit(state.copyWith(
      data: DataSuccess(ConversationsData(
        conversations: cached.conversations,
        pinnedIds: const <String>{},
        total: cached.conversations.length,
        pendingByConv: cached.pendingByConv,
        filesByConv: cached.filesByConv,
      )),
    ));
  }

  /// Best-effort write of the current list + counts to the offline cache so
  /// the next cold start paints instantly. Fire-and-forget.
  void _persistCache() {
    final data = state.data.dataOrNull;
    if (data == null || data.conversations.isEmpty) return;
    unawaited(_repo.writeCachedList(
      conversations: data.conversations,
      pendingByConv: data.pendingByConv,
      filesByConv: data.filesByConv,
    ));
  }

  /// Initial load — fetches the conversation list. Default now
  /// includes archived rows so the "Archived" filter on the screen
  /// has something to show; the screen still filters locally to
  /// decide whether to display them. Pull-to-refresh hits the same
  /// path via [refresh].
  Future<void> load({bool includeArchived = true}) async {
    if (_loading) return;
    _loading = true;
    // Stale-while-revalidate: only show the loading skeleton on a truly
    // cold open (no cache, no prior data). When we already have rows — the
    // hydrated offline cache or a previous fetch — keep them on screen and
    // revalidate silently underneath, so opening Chats never blanks to
    // shimmers when we have something real to show.
    if (state.data.dataOrNull == null) {
      emit(state.copyWith(data: const DataLoading<ConversationsData>()));
    }
    try {
      // Kick off the list and the real per-conversation meta (pending
      // approvals + files) concurrently — the meta comes from the flat
      // cross-conversation feeds and is best-effort (never blocks/fails the
      // list; yields empty maps on error). No fabricated counts.
      final listFuture = _repo.list(includeArchived: includeArchived);
      final metaFuture = _repo.conversationMeta();
      final res = await listFuture;
      final meta = await metaFuture;
      final previous = state.data.dataOrNull;
      final pinned = previous?.pinnedIds ?? const <String>{};
      // Carry over any project/environment context already resolved for a
      // row so a refresh doesn't blank the tag out before the next
      // enrichment pass lands (the list endpoint never carries it).
      final prevById = <String, ConversationSummary>{
        for (final c in previous?.conversations ?? const <ConversationSummary>[])
          c.id: c,
      };
      final conversations = [
        for (final c in res.conversations)
          c.copyWith(
            projectName: prevById[c.id]?.projectName,
            environmentName: prevById[c.id]?.environmentName,
          ),
      ];
      emit(state.copyWith(
        data: DataSuccess(
          ConversationsData(
            conversations: conversations,
            pinnedIds: pinned,
            total: res.total,
            pendingByConv: meta.pendingByConv,
            filesByConv: meta.filesByConv,
          ),
        ),
      ));
      // Persist the fresh list for instant cold-start paint next time.
      _persistCache();
      // Warm every conversation's transcript on disk in the background so
      // tapping any row opens instantly (no request on open). Gentle by
      // design — see ConversationsRepository.prefetchSnapshots — so this
      // never makes the app feel heavy after launch.
      unawaited(_repo.prefetchSnapshots(
        [for (final c in conversations) c.id],
      ));
      // Fill in project · environment per row in the background — the list
      // is already on screen; the tags fade in as snapshots resolve.
      unawaited(_enrichContext());
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
    } finally {
      _loading = false;
    }
  }

  /// Pull-to-refresh / refresh-button — forces a fresh network fetch with
  /// VISIBLE feedback. Unlike the silent stale-while-revalidate [load] used
  /// on mount (which keeps the cached list on screen), this blanks to the
  /// loading skeleton first so the user actually sees the refresh happen,
  /// then repaints with the freshly fetched list. The cold-start / cache
  /// open behaviour is left exactly as-is.
  Future<void> refresh() async {
    // Drop the guard so an explicit refresh is never swallowed by an
    // in-flight background load, then blank to the skeleton.
    _loading = false;
    emit(state.copyWith(data: const DataLoading<ConversationsData>()));
    await load();
  }

  /// Resolves the real project · environment for each row from its snapshot
  /// (the list endpoint doesn't carry them) and folds the names back into the
  /// summaries. Runs in the background so it never delays the list, only
  /// fetches rows that don't already have context (so refreshes are cheap),
  /// and is best-effort — a row that fails or has no bound environment simply
  /// keeps its tag hidden rather than showing a fabricated value.
  /// Rows enriched per pass. Bounds the per-conversation snapshot N+1 to a
  /// screenful instead of firing one request for EVERY conversation on
  /// open — the rest enrich on demand as the user pages down ([enrichMore]).
  /// (The real fix is the backend embedding project/env in the list — see
  /// docs/backend-requests.md §6 — at which point this whole pass is retired.)
  static const _enrichBatch = 12;

  /// Enriches the next batch of rows that still lack project·env tags.
  /// Called by the screen's pagination handler so context is only fetched
  /// for rows the user actually scrolls to.
  Future<void> enrichMore() => _enrichContext();

  Future<void> _enrichContext() async {
    if (_enriching) return;
    final current = state.data.dataOrNull;
    if (current == null) return;
    final missing = [
      for (final c in current.conversations)
        if ((c.projectName == null || c.projectName!.isEmpty) &&
            (c.environmentName == null || c.environmentName!.isEmpty))
          c.id,
    ];
    if (missing.isEmpty) return;
    // Only this pass's batch — the next batch waits for the user to page on.
    final batch = missing.take(_enrichBatch).toList();
    _enriching = true;
    try {
      final ctx = await _repo.conversationContext(batch);
      if (ctx.projectByConv.isEmpty && ctx.envByConv.isEmpty) return;
      final cur = state.data.dataOrNull;
      if (cur == null) return;
      final enriched = [
        for (final c in cur.conversations)
          c.copyWith(
            projectName: ctx.projectByConv[c.id],
            environmentName: ctx.envByConv[c.id],
          ),
      ];
      emit(state.copyWith(
        data: DataSuccess(cur.copyWith(conversations: enriched)),
      ));
      // Re-persist so the cached rows carry the resolved project · env tags.
      _persistCache();
    } catch (e, st) {
      AppLogger.warn(_tag, 'context enrichment failed', error: e, stackTrace: st);
    } finally {
      _enriching = false;
    }
  }

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
      projectName: c.projectName,
      environmentName: c.environmentName,
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
      projectName: c.projectName,
      environmentName: c.environmentName,
    );
  }
}
