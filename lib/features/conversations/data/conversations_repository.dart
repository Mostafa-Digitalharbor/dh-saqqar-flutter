import 'dart:io';

import '../../../core/logging/app_logger.dart';
import '../../inbox/data/approval_models.dart';
import '../../inbox/data/approvals_api.dart';
import '../../inbox/data/artifacts_api.dart';
import 'attachment_models.dart';
import 'conversation_models.dart';
import 'conversations_api.dart';

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
  })  : _approvalsApi = approvalsApi,
        _artifactsApi = artifactsApi;

  static const _tag = 'ConversationsRepository';

  final ConversationsApi _api;

  /// Optional cross-conversation feeds used to enrich the list rows with
  /// REAL per-conversation pending-approval and file counts (§8 / §9).
  /// Nullable so test/stub construction stays one-arg — when absent the
  /// meta maps come back empty and the rows simply omit those counts.
  final ApprovalsApi? _approvalsApi;
  final ArtifactsApi? _artifactsApi;

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
  }) async {
    // Polling is high-frequency; log at debug so the console stays sane
    // for the 1.5 s tick. Errors still surface through the cubit.
    AppLogger.debug(_tag, 'getSnapshot(id=$id, since=$since)');
    return _api.getSnapshot(id, since: since);
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
