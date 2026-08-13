import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_exception.dart';
import '../../chat/data/chat_snapshot_disk_cache.dart';
import '../../inbox/data/approval_models.dart';
import '../../inbox/data/approvals_api.dart';
import '../../watch/data/watch_bridge.dart';
import 'attachment_models.dart';
import 'conversation_models.dart';
import 'conversations_api.dart';
import 'conversations_cache.dart';

/// Top-level so it can run inside a `compute` isolate — decodes a raw
/// snapshot JSON string into a map off the UI thread. Returns the map
/// (sendable) rather than the model, so the lightweight `fromJson` stays on
/// the caller's isolate while the heavy decode runs in the background.
Map<String, dynamic> decodeSnapshotJson(String body) =>
    jsonDecode(body) as Map<String, dynamic>;

/// Thin domain wrapper around [ConversationsApi]. Adds operation-level
/// logging (separate from raw HTTP) so a single grep on the tag tells
/// you what the cubit *tried* to do, not just which URL it hit.
///
/// Wired in `main.dart` via `RepositoryProvider<ConversationsRepository>`.
/// Holds no state — the polling lifecycle lives on [ChatCubit].
class ConversationsRepository {
  ConversationsRepository(
    this._api, {
    ApprovalsApi? approvalsApi,
    ConversationsCache? listCache,
    ChatSnapshotDiskCache? snapshotDiskCache,
    WatchBridge? watchBridge,
  })  : _approvalsApi = approvalsApi,
        _listCache = listCache,
        _diskCache = snapshotDiskCache,
        _watchBridge = watchBridge;

  static const _tag = 'ConversationsRepository';

  final ConversationsApi _api;

  /// Flat approvals feed, used to derive each row's pending-approval count —
  /// the one piece of per-row meta `GET /conversations/` still doesn't carry.
  /// Nullable so test/stub construction stays one-arg; when absent the count
  /// is simply omitted rather than guessed.
  ///
  /// The matching artifacts dependency was dropped when the list started
  /// carrying `files_count`; see [conversationMeta].
  final ApprovalsApi? _approvalsApi;

  /// Offline disk cache for the Chats list (stale-while-revalidate).
  /// Nullable so test/stub construction stays cache-free — when absent the
  /// list simply always loads from the network.
  final ConversationsCache? _listCache;

  /// On-disk cache of conversation snapshots (raw JSON), so opening a chat
  /// is instant even on a cold start, and the background prefetch can warm
  /// every conversation. Nullable for tests.
  final ChatSnapshotDiskCache? _diskCache;

  /// Pushes the pending-approvals feed to a paired Apple Watch after every
  /// list refresh. Nullable for tests / platforms without the bridge (it's
  /// a no-op off iOS anyway) — same optional-dependency shape as
  /// [_approvalsApi] above.
  final WatchBridge? _watchBridge;

  /// Guards the background prefetch so list reloads don't stack passes.
  bool _prefetching = false;

  /// Prefetch tuning — low concurrency + a breather between rounds so
  /// warming the whole list never competes with the foreground UI.
  static const _prefetchConcurrency = 2;
  static const _prefetchLimit = 40;
  static const _prefetchTtl = Duration(minutes: 10);
  static const _prefetchStartDelay = Duration(milliseconds: 800);
  static const _prefetchRoundGap = Duration(milliseconds: 120);

  // ── Offline list cache (disk, stale-while-revalidate) ───────────────

  /// The persisted Chats list from a previous session, or null when none /
  /// no cache wired. The cubit paints this on cold start, then revalidates.
  ConversationsCacheEntry? readCachedList() => _listCache?.read();

  /// Persist the current list + count maps for the next cold start.
  /// Best-effort; failures only log inside [ConversationsCache.write].
  Future<void> writeCachedList({
    required List<ConversationSummary> conversations,
    required Map<String, int> pendingByConv,
    required Map<String, int> filesByConv,
  }) async {
    final cache = _listCache;
    if (cache == null) return;
    await cache.write(
      conversations: conversations,
      pendingByConv: pendingByConv,
      filesByConv: filesByConv,
    );
  }

  /// Wipe the offline list cache. Call on sign-out / account deletion.
  Future<void> clearListCache() async => _listCache?.clear();

  // ── Snapshot cache (stale-while-revalidate) ─────────────────────────
  //
  // Last full snapshot seen per conversation id, kept in memory so
  // re-opening a chat paints its messages on the FIRST frame instead of
  // blocking on a network round-trip (the "every tap spins a loader"
  // complaint). [ChatCubit.load] seeds from here, then revalidates.
  //
  // Repository-scoped (it's a singleton via RepositoryProvider) because
  // the cubit is rebuilt per-route and can't hold cross-navigation state.
  // Bounded so a long session doesn't pin every transcript in RAM —
  // oldest-inserted entry is evicted past [_cacheCap]. Wiped on sign-out
  // via [clearSnapshotCache] so the next user never sees stale messages.
  static const int _cacheCap = 12;
  final Map<String, ConversationSnapshot> _snapshotCache = {};

  /// The last full snapshot cached for [id], or null if none seen this
  /// session. Returned verbatim for instant paint — callers must treat it
  /// as stale and revalidate.
  ConversationSnapshot? cachedSnapshot(String id) => _snapshotCache[id];

  /// Store [snapshot] as the freshest known full state for [id]. The
  /// cubit calls this after every authoritative emit (initial load, poll
  /// merge, send) so the cache tracks appended messages, not just the
  /// first page.
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {
    if (!_snapshotCache.containsKey(id) && _snapshotCache.length >= _cacheCap) {
      _snapshotCache.remove(_snapshotCache.keys.first);
    }
    _snapshotCache[id] = snapshot;
  }

  /// Drop every in-memory cached transcript. Call on sign-out.
  void clearSnapshotCache() => _snapshotCache.clear();

  // ── Snapshot disk cache + background prefetch ───────────────────────

  /// Fetches a snapshot and decodes it **off the UI isolate** (`compute`).
  /// Use for the heavy "load the whole transcript" path (no `limit`) so
  /// parsing a long history never janks the chat — the body is pulled as
  /// plain text (no Dio decode) and decoded in the background. Also persists
  /// the body to the disk cache. Throws on an empty/missing body.
  Future<ConversationSnapshot> getSnapshotOffIsolate(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    AppLogger.debug(_tag, 'getSnapshotOffIsolate(id=$id, limit=$limit)');
    final body = await _api.fetchSnapshotBody(
      id,
      since: since,
      limit: limit,
      before: before,
    );
    if (body.isEmpty) {
      // FormatException, not StateError: `ApiErrorMapper` reads it as
      // `ParseFailure` → "unexpected response from the server", which is
      // what a 200 with no transcript in it actually is. A StateError fell
      // through to `UnknownFailure` — "something went wrong, please try
      // again" — which points the user at a retry that replays the same
      // empty body. Matches the rule `requiredBody` applies to every JSON
      // client; this path reads the body as plain text (to decode it off
      // the UI isolate) so it has to state the rule itself.
      throw const FormatException('empty conversation snapshot body');
    }
    final map = await compute(decodeSnapshotJson, body);
    // The failure envelope, checked here because nothing else can.
    //
    // `ErrorInterceptor` turns `200 {"ok": false, "error": "…"}` into an
    // ApiException for every JSON client in the app — but only when Dio has
    // decoded the body into a Map. This one call asks for `ResponseType.plain`
    // so the transcript can be decoded off the UI isolate, so the interceptor
    // sees a String, finds no `ok` key, and waves it through. The snapshot
    // parser then reads a body with no `messages` and produces a perfectly
    // valid EMPTY snapshot: the chat opens blank, the server's own
    // explanation is discarded, and nothing offers a retry — the false
    // success this envelope check exists to prevent, arriving through the one
    // door the central guard cannot watch.
    //
    // Raised as the same `ApiException` shape the interceptor would, so
    // `ApiErrorMapper` reaches the identical copy it would for any other
    // endpoint, including the server's `error` string when there is one.
    if (map['ok'] == false) {
      final error = map['error'];
      throw ApiException(
        kind: ApiExceptionKind.badResponse,
        message: error is String ? error : '',
        statusCode: 200,
      );
    }
    final snapshot = ConversationSnapshot.fromJson(map);
    // Persist only a page that represents the LATEST state of the chat.
    //
    // A `?before=` page is non-delta but is a window into old history, so
    // caching it would replace the cold-start transcript with a fragment
    // from the middle of the conversation — the user reopens the chat and
    // finds it starts and ends in the wrong place. `?since=` deltas are
    // excluded for the same reason: they carry only the newest rows.
    if (!snapshot.delta && before == null) {
      final cache = _diskCache;
      if (cache != null) unawaited(cache.writeBody(id, body));
    }
    return snapshot;
  }

  /// Reads the on-disk snapshot for [id] (persisted by a prior interactive
  /// fetch or the background prefetch) and decodes it **off the UI isolate**
  /// (`compute`). Returns null when nothing's cached or on a decode error.
  /// Lets a chat paint instantly on a cold start — before any network.
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async {
    final cache = _diskCache;
    if (cache == null) return null;
    final body = await cache.readBody(id);
    if (body == null || body.isEmpty) return null;
    try {
      final map = await compute(decodeSnapshotJson, body);
      return ConversationSnapshot.fromJson(map);
    } catch (e, st) {
      AppLogger.warn(_tag, 'diskCachedSnapshot($id) decode failed',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Warms the on-disk snapshot cache for [ids] in the background so that
  /// tapping any conversation opens instantly. Deliberately gentle:
  ///   * starts after a short delay so it never competes with first paint,
  ///   * fetches the body as **plain text** (no JSON parse on this isolate),
  ///   * runs ≤[_prefetchConcurrency] at a time with a breather between
  ///     rounds, and
  ///   * skips conversations already warm (in memory, or a fresh disk file).
  ///
  /// Fire-and-forget; a single pass at a time (guarded by [_prefetching]).
  Future<void> prefetchSnapshots(List<String> ids) async {
    final cache = _diskCache;
    if (cache == null || _prefetching || ids.isEmpty) return;
    _prefetching = true;
    try {
      await Future<void>.delayed(_prefetchStartDelay);
      for (var i = 0; i < ids.length; i += _prefetchConcurrency) {
        final chunk = ids.skip(i).take(_prefetchConcurrency);
        await Future.wait(chunk.map((id) async {
          if (_snapshotCache.containsKey(id)) return;
          if (await cache.isFresh(id, _prefetchTtl)) return;
          try {
            final body =
                await _api.fetchSnapshotBody(id, limit: _prefetchLimit);
            if (body.isNotEmpty) await cache.writeBody(id, body);
          } catch (_) {
            // Best-effort warming — one failed row never aborts the rest.
          }
        }));
        await Future<void>.delayed(_prefetchRoundGap);
      }
    } finally {
      _prefetching = false;
    }
  }

  /// Wipe the on-disk snapshot cache. Call on sign-out / account deletion.
  Future<void> clearDiskCache() async => _diskCache?.clear();

  // ── List + create ───────────────────────────────────────────────────

  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    int offset = 0,
    bool includeArchived = false,
  }) async {
    AppLogger.info(
      _tag,
      'list(limit=$limit, offset=$offset, includeArchived=$includeArchived)',
    );
    return _api.list(
      limit: limit,
      offset: offset,
      includeArchived: includeArchived,
    );
  }

  /// Every conversation, following the server's paging until the list is
  /// complete.
  ///
  /// **Why this exists.** The client asked for `limit=200`; the server
  /// answered with 100, silently — it capped the page at 100, ignored
  /// `offset`, and sent no `total` at all. The gap was found by counting the
  /// list on saqqaar.com (~140) against the app's 100, which is the worst
  /// kind of missing data: nothing on screen says anything is absent.
  ///
  /// The endpoint gained real `limit`/`offset` paging and a `total` on
  /// 2026-08-09 (cap 200, default 30). The three stop conditions below stay
  /// as they are: they were written to be safe against a server that ignores
  /// `offset`, and that is exactly the server anyone on an older deployment
  /// is still talking to.
  ///
  /// Three independent stop conditions, because this must not spin:
  ///
  ///   1. **No new ids.** A server that ignores `offset` returns page 1
  ///      again; zero new ids means paging does not work and we keep what we
  ///      have. This is the condition that makes sending `offset` safe.
  ///   2. **`total` reached** — the server told us how many exist.
  ///   3. **Page budget** — a hard ceiling so a pathological server cannot
  ///      loop us forever.
  ///
  /// Returns whatever was gathered plus the server's `total`, so the caller
  /// can still tell the user the list is short if paging is unsupported.
  Future<({List<ConversationSummary> conversations, int? total})> listAll({
    int pageSize = 200,
    int maxPages = 12,
    bool includeArchived = false,
  }) async {
    final out = <ConversationSummary>[];
    final seen = <String>{};
    int? total;
    // The server's OWN page size, learned from the first response — not the
    // `pageSize` we asked for. Comparing against the request would end the
    // loop on page one for exactly the servers this exists for: the cap is
    // below what we ask, so every page looks "short".
    int? serverPage;

    for (var page = 0; page < maxPages; page++) {
      final res = await list(
        limit: pageSize,
        offset: out.length,
        includeArchived: includeArchived,
      );
      total ??= res.total;

      final fresh = [
        for (final c in res.conversations)
          if (seen.add(c.id)) c,
      ];
      out.addAll(fresh);

      // (1) Paging made no progress — either we have everything, or the
      // server ignored `offset` and re-sent the same page.
      if (fresh.isEmpty) break;
      // (2) We have as many as the server says exist. This is what keeps a
      // small account at exactly one request.
      if (total != null && out.length >= total) break;
      // (3) A page shorter than the server's own page size is the last one.
      // Only meaningful once we know that size.
      if (serverPage != null && res.conversations.length < serverPage) break;
      serverPage ??= res.conversations.length;
    }

    AppLogger.info(
      _tag,
      'listAll() · ${out.length} of ${total ?? out.length}',
    );
    return (conversations: out, total: total);
  }

  /// Per-conversation meta for the Chats list that the list endpoint doesn't
  /// carry: the count of **pending** approvals, grouped from
  /// `GET /approvals/?status=pending`.
  ///
  /// The matching `/artifacts/` fetch was removed on 2026-07-25. The list row
  /// now carries `files_count` directly, and the flat feed was not merely
  /// redundant but *wrong*: capped at 100 artifacts account-wide, it
  /// disagreed with the server's own per-row count on 41 of 100 rows. Dropping
  /// it also takes the 20 s Chats poll from three requests to two.
  ///
  /// The approvals feed carries the same 100-row ceiling and so has the same
  /// flaw; it stays only because there is no `pending_approvals` on the row
  /// yet (docs/MOBILE_BACKEND_GAPS_CORE.md §1). Retire it the moment there is.
  ///
  /// Best-effort: a failure yields an empty map rather than failing the whole
  /// list load. Counts are honest — never fabricated.
  Future<({Map<String, int> pendingByConv, Map<String, int> filesByConv})>
      conversationMeta() async {
    final pending = await _pendingByConversation();
    return (pendingByConv: pending, filesByConv: const <String, int>{});
  }

  Future<Map<String, int>> _pendingByConversation() async {
    final api = _approvalsApi;
    if (api == null) return const {};
    try {
      final page = await api.list(status: ApprovalStatus.pending, limit: 100);
      final counts = <String, int>{};
      for (final a in page.approvals) {
        final id = a.conversation?.id;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
      unawaited(_watchBridge?.syncApprovals(
        page.approvals,
        pendingCount: page.pendingCount,
      ));
      return counts;
    } catch (e, st) {
      AppLogger.warn(_tag, 'pending-approvals meta failed', error: e, stackTrace: st);
      return const {};
    }
  }

  Future<String> create({String? title}) async {
    AppLogger.info(_tag, 'create(title=${title ?? '<auto>'})');
    return _api.create(title: title);
  }

  // ── Per-conversation ────────────────────────────────────────────────

  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    // Polling is high-frequency; log at debug so the console stays sane
    // for the 1.5 s tick. Errors still surface through the cubit.
    AppLogger.debug(
      _tag,
      'getSnapshot(id=$id, since=$since, limit=$limit, before=$before)',
    );
    final raw = await _api.getSnapshotRaw(
      id,
      since: since,
      limit: limit,
      before: before,
    );
    final snapshot = ConversationSnapshot.fromJson(raw);
    // Persist FULL snapshots (not `?since` deltas) to disk verbatim so the
    // next cold-start open paints instantly. Fire-and-forget.
    if (!snapshot.delta) {
      final cache = _diskCache;
      if (cache != null) unawaited(cache.writeMap(id, raw));
    }
    return snapshot;
  }

  Future<Conversation> patch({
    required String id,
    String? title,
    bool? isArchived,
    bool? autoApprove,
    bool? taskPrep,
    Map<String, dynamic>? context,
    String? environmentId,
    List<String>? environmentIds,
  }) async {
    AppLogger.info(
      _tag,
      'patch(id=$id, title=$title, isArchived=$isArchived, '
          'autoApprove=$autoApprove, taskPrep=$taskPrep, '
          'contextKeys=${context?.keys.toList()}, '
          'environmentId=$environmentId, environmentIds=$environmentIds)',
    );
    return _api.patch(
      id: id,
      title: title,
      isArchived: isArchived,
      autoApprove: autoApprove,
      taskPrep: taskPrep,
      context: context,
      environmentId: environmentId,
      environmentIds: environmentIds,
    );
  }

  Future<void> delete(String id) async {
    AppLogger.info(_tag, 'delete(id=$id)');
    return _api.delete(id);
  }

  // ── Run control + sharing ───────────────────────────────────────────

  Future<({bool isRunning, bool stopRequested})> stop(String id) async {
    AppLogger.info(_tag, 'stop(id=$id)');
    return _api.stop(id);
  }

  Future<({String token, String url, String path})> share(String id) async {
    AppLogger.info(_tag, 'share(id=$id)');
    return _api.share(id);
  }

  Future<void> revokeShare(String id) async {
    AppLogger.info(_tag, 'revokeShare(id=$id)');
    return _api.revokeShare(id);
  }

  // ── Per-conversation credentials ────────────────────────────────────

  Future<String?> setActiveCredential({
    required String id,
    required String? name,
  }) async {
    AppLogger.info(_tag, 'setActiveCredential(id=$id, name=$name)');
    return _api.setActiveCredential(id: id, name: name);
  }

  Future<List<String>> toggleCredential({
    required String id,
    required String name,
    required bool enabled,
  }) async {
    AppLogger.info(
      _tag,
      'toggleCredential(id=$id, name=$name, enabled=$enabled)',
    );
    return _api.toggleCredential(id: id, name: name, enabled: enabled);
  }

  Future<ConversationSnapshot> dismissPendingAction({
    required String conversationId,
    String? actionType,
    String? credentialName,
    String? credentialKind,
  }) async {
    AppLogger.info(
      _tag,
      'dismissPendingAction(conv=$conversationId, type=$actionType, '
          'name=$credentialName, kind=$credentialKind)',
    );
    return _api.dismissPendingAction(
      conversationId: conversationId,
      actionType: actionType,
      credentialName: credentialName,
      credentialKind: credentialKind,
    );
  }

  // ── Messages + attachments ──────────────────────────────────────────

  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool taskPrep = true,
  }) async {
    AppLogger.info(
      _tag,
      'sendMessage(conv=$conversationId, attachments=${attachmentIds.length}, '
          'taskPrep=$taskPrep, model=${model ?? '<default>'})',
    );
    return _api.sendMessage(
      conversationId: conversationId,
      content: content,
      attachmentIds: attachmentIds,
      model: model,
      taskPrep: taskPrep,
    );
  }

  Future<List<Attachment>> uploadAttachments({
    required String conversationId,
    required List<File> files,
  }) async {
    AppLogger.info(
      _tag,
      'uploadAttachments(conv=$conversationId, count=${files.length})',
    );
    return _api.uploadAttachments(
      conversationId: conversationId,
      files: files,
    );
  }

  Future<Attachment> getAttachmentStatus({
    required String conversationId,
    required String attachmentId,
  }) async {
    AppLogger.debug(
      _tag,
      'getAttachmentStatus(conv=$conversationId, att=$attachmentId)',
    );
    return _api.getAttachmentStatus(
      conversationId: conversationId,
      attachmentId: attachmentId,
    );
  }
}
