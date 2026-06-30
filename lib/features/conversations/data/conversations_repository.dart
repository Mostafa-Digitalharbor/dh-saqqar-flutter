import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../chat/data/chat_snapshot_disk_cache.dart';
import '../../inbox/data/approval_models.dart';
import '../../inbox/data/approvals_api.dart';
import '../../inbox/data/artifacts_api.dart';
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
    ArtifactsApi? artifactsApi,
    ConversationsCache? listCache,
    ChatSnapshotDiskCache? snapshotDiskCache,
  })  : _approvalsApi = approvalsApi,
        _artifactsApi = artifactsApi,
        _listCache = listCache,
        _diskCache = snapshotDiskCache;

  static const _tag = 'ConversationsRepository';

  final ConversationsApi _api;

  /// Optional cross-conversation feeds used to enrich the list rows with
  /// REAL per-conversation pending-approval and file counts (§8 / §9).
  /// Nullable so test/stub construction stays one-arg — when absent the
  /// meta maps come back empty and the rows simply omit those counts.
  final ApprovalsApi? _approvalsApi;
  final ArtifactsApi? _artifactsApi;

  /// Offline disk cache for the Chats list (stale-while-revalidate).
  /// Nullable so test/stub construction stays cache-free — when absent the
  /// list simply always loads from the network.
  final ConversationsCache? _listCache;

  /// On-disk cache of conversation snapshots (raw JSON), so opening a chat
  /// is instant even on a cold start, and the background prefetch can warm
  /// every conversation. Nullable for tests.
  final ChatSnapshotDiskCache? _diskCache;

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
      throw StateError('empty snapshot body for $id');
    }
    final map = await compute(decodeSnapshotJson, body);
    final snapshot = ConversationSnapshot.fromJson(map);
    if (!snapshot.delta) {
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
    bool includeArchived = false,
  }) async {
    AppLogger.info(
      _tag,
      'list(limit=$limit, includeArchived=$includeArchived)',
    );
    return _api.list(limit: limit, includeArchived: includeArchived);
  }

  /// Real per-conversation meta for the Chats list, fetched from the flat
  /// cross-conversation feeds and grouped by conversation id:
  ///   * `pendingByConv` — count of **pending** approvals
  ///     (`GET /approvals/?status=pending`). Drives the "N to approve" pill
  ///     and the "Needs approval" filter — there's no per-row approval API,
  ///     so this flat feed is the real signal.
  ///   * `filesByConv` — count of produced files
  ///     (`GET /artifacts/`). Drives the file count on each row.
  ///
  /// Best-effort: a failure on either feed yields an empty map rather than
  /// failing the whole list load. Counts are honest — never fabricated —
  /// though they reflect the first page (server-capped) of each feed.
  Future<({Map<String, int> pendingByConv, Map<String, int> filesByConv})>
      conversationMeta() async {
    final pending = await _pendingByConversation();
    final files = await _filesByConversation();
    return (pendingByConv: pending, filesByConv: files);
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
      return counts;
    } catch (e, st) {
      AppLogger.warn(_tag, 'pending-approvals meta failed', error: e, stackTrace: st);
      return const {};
    }
  }

  /// Best-effort per-conversation **project / environment** names, fetched
  /// from each conversation's snapshot — the flat list endpoint doesn't
  /// carry them. Bounded to [concurrency] in-flight requests so a long list
  /// doesn't fire a request storm; a per-row failure (or a conversation with
  /// no bound environment) simply skips that row. Never fabricated.
  ///
  /// [since] is forwarded as `?since=` so the server returns a delta snapshot
  /// (no message backlog) — we only need the `conversation` object's
  /// project / environment, not the transcript.
  Future<({Map<String, String> projectByConv, Map<String, String> envByConv})>
      conversationContext(
    List<String> ids, {
    int concurrency = 6,
  }) async {
    final projects = <String, String>{};
    final envs = <String, String>{};
    final now = DateTime.now();
    for (var i = 0; i < ids.length; i += concurrency) {
      final chunk = ids.skip(i).take(concurrency);
      await Future.wait(chunk.map((id) async {
        try {
          final snap = await _api.getSnapshot(id, since: now);
          final p = snap.conversation.project?.name.trim();
          final e = snap.conversation.environment?.name.trim();
          if (p != null && p.isNotEmpty) projects[id] = p;
          if (e != null && e.isNotEmpty) envs[id] = e;
        } catch (e) {
          // Best-effort — one row's failure must not block the rest, and we
          // never substitute a placeholder.
          AppLogger.debug(_tag, 'context fetch failed for $id: $e');
        }
      }));
    }
    return (projectByConv: projects, envByConv: envs);
  }

  Future<Map<String, int>> _filesByConversation() async {
    final api = _artifactsApi;
    if (api == null) return const {};
    try {
      final page = await api.list(limit: 100);
      final counts = <String, int>{};
      for (final a in page.artifacts) {
        final id = a.conversation?.id;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e, st) {
      AppLogger.warn(_tag, 'artifacts meta failed', error: e, stackTrace: st);
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
    bool? deepThink,
    Map<String, dynamic>? context,
    String? environmentId,
  }) async {
    AppLogger.info(
      _tag,
      'patch(id=$id, title=$title, isArchived=$isArchived, '
          'autoApprove=$autoApprove, deepThink=$deepThink, '
          'contextKeys=${context?.keys.toList()}, '
          'environmentId=$environmentId)',
    );
    return _api.patch(
      id: id,
      title: title,
      isArchived: isArchived,
      autoApprove: autoApprove,
      deepThink: deepThink,
      context: context,
      environmentId: environmentId,
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
    bool deepThink = false,
  }) async {
    AppLogger.info(
      _tag,
      'sendMessage(conv=$conversationId, attachments=${attachmentIds.length}, '
          'deepThink=$deepThink, model=${model ?? '<default>'})',
    );
    return _api.sendMessage(
      conversationId: conversationId,
      content: content,
      attachmentIds: attachmentIds,
      model: model,
      deepThink: deepThink,
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
