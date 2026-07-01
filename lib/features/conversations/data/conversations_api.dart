import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'attachment_models.dart';
import 'conversation_models.dart';

/// Repository for the conversation-scoped surface (SAQQAR_MOBILE_API.md §§2-6).
///
/// Owns: listing/CRUD, the snapshot polling endpoint (delta via `?since`),
/// message send, attachment upload + status, pending-action dismiss,
/// per-conversation credential toggles, stop/share.
class ConversationsApi {
  ConversationsApi(this._dio);

  final Dio _dio;

  // ── Listing ─────────────────────────────────────────────────────────

  /// `GET /api/v1/conversations/?limit=&include_archived=`
  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    bool includeArchived = false,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.conversations,
      queryParameters: {
        'limit': limit,
        'include_archived': includeArchived ? 1 : 0,
      },
    );
    final data = res.data!;
    return (
      conversations: (data['conversations'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ConversationSummary.fromJson)
          .toList(),
      total: (data['total'] as num?)?.toInt(),
    );
  }

  /// `POST /api/v1/conversations/` — empty title is fine (server derives
  /// it from the first message).
  Future<String> create({String? title}) async {
    final body = <String, dynamic>{
      if (title != null && title.isNotEmpty) 'title': title,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversations,
      data: body,
    );
    return res.data!['conversation_id'] as String;
  }

  // ── Snapshot (poll) ─────────────────────────────────────────────────

  /// `GET /api/v1/conversations/<id>/?since=<iso>&before=<ts|id>&limit=<n>`
  /// — the chat-screen snapshot.
  ///
  /// Pass [since] to receive only messages newer than that cursor (other
  /// fields are always returned in full per §4.2). The `+` in the
  /// timezone offset must be URL-encoded; Dio handles that for us via
  /// `queryParameters`.
  ///
  /// Pass [limit] to bound the message page the server returns. The
  /// **initial** chat load uses this so we paint a recent window fast
  /// instead of deserialising the entire transcript on the UI isolate
  /// (the root cause of the "open chat → freeze while everything lands
  /// at once" lag). Older history is fetched lazily via [before].
  ///
  /// Pass [before] (a message id or ISO timestamp) to page **backwards** —
  /// the server returns the page of messages older than that anchor.
  /// Used by the chat's "load earlier" scroll-to-top path.
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    return ConversationSnapshot.fromJson(
      await getSnapshotRaw(id, since: since, limit: limit, before: before),
    );
  }

  /// Same request as [getSnapshot] but returns the **decoded raw map**
  /// instead of the parsed model. The repository uses this so it can both
  /// parse the model AND persist the verbatim JSON to the on-disk cache in
  /// one round-trip.
  Future<Map<String, dynamic>> getSnapshotRaw(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.conversationDetail(id),
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (before != null && before.isNotEmpty) 'before': before,
        if (limit != null) 'limit': limit,
      },
    );
    return res.data!;
  }

  /// Fetches the snapshot as the **raw JSON string** without Dio decoding
  /// it (`ResponseType.plain`). The background prefetch uses this to warm
  /// the on-disk cache for every conversation WITHOUT spending any JSON
  /// parse time on the UI isolate — decoding is deferred to chat-open, off
  /// the main isolate. Returns an empty string on a missing body.
  Future<String> fetchSnapshotBody(
    String id, {
    int? limit,
    DateTime? since,
    String? before,
  }) async {
    final res = await _dio.get<String>(
      ApiEndpoints.conversationDetail(id),
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (before != null && before.isNotEmpty) 'before': before,
        if (limit != null) 'limit': limit,
      },
      options: Options(responseType: ResponseType.plain),
    );
    return res.data ?? '';
  }

  // ── Metadata ────────────────────────────────────────────────────────

  /// `PATCH /api/v1/conversations/<id>/` — any subset of title / archive
  /// flag / auto-approve / deep-think / bound environment.
  ///
  /// To clear the environment binding, pass [environmentId] as the
  /// sentinel empty string `''` (Dio drops keys whose value is `null`,
  /// which would otherwise silently no-op).
  ///
  /// [deepThink] is forwarded as `deep_think` so the per-conversation
  /// toggle stays in sync with the web. Servers that don't yet support
  /// the field silently ignore the key — the snapshot's `deep_think`
  /// just stays at its previous value and the local UI doesn't break.
  Future<Conversation> patch({
    required String id,
    String? title,
    bool? isArchived,
    bool? autoApprove,
    bool? deepThink,
    Map<String, dynamic>? context,
    String? environmentId,
    List<String>? environmentIds,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (isArchived != null) 'is_archived': isArchived,
      if (autoApprove != null) 'auto_approve': autoApprove,
      if (deepThink != null) 'deep_think': deepThink,
      if (context != null) 'context': context,
      if (environmentId != null)
        'environment_id': environmentId.isEmpty ? null : environmentId,
      // Multi-env binding (web parity) — the full set of environments for
      // this conversation. Sent as `environment_ids:[uuid]` per the API
      // contract §3; an empty list clears all bindings.
      if (environmentIds != null) 'environment_ids': environmentIds,
    };
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.conversationDetail(id),
      data: body,
    );
    return Conversation.fromJson(
      res.data!['conversation'] as Map<String, dynamic>,
    );
  }

  /// `DELETE /api/v1/conversations/<id>/` — cascades to messages,
  /// attachments, artifacts, approvals.
  Future<void> delete(String id) async {
    await _dio.delete<void>(ApiEndpoints.conversationDetail(id));
  }

  // ── Run control ─────────────────────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/stop/` — cooperative cancel.
  /// Idempotent; safe to call even when no run is in flight (returns the
  /// current `is_running` / `stop_requested` flags).
  Future<({bool isRunning, bool stopRequested})> stop(String id) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationStop(id),
    );
    final data = res.data!;
    return (
      isRunning: data['is_running'] as bool? ?? false,
      stopRequested: data['stop_requested'] as bool? ?? false,
    );
  }

  // ── Sharing ─────────────────────────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/share/` — issues or reuses a public
  /// share token. The full URL is what the share sheet distributes.
  Future<({String token, String url, String path})> share(String id) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationShare(id),
    );
    final data = res.data!;
    return (
      token: data['share_token'] as String? ?? '',
      url: data['share_url'] as String? ?? '',
      path: data['share_path'] as String? ?? '',
    );
  }

  /// `DELETE /api/v1/conversations/<id>/share/` — revokes the token.
  Future<void> revokeShare(String id) async {
    await _dio.delete<void>(ApiEndpoints.conversationShare(id));
  }

  // ── Per-conversation credentials ────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/credentials/active/` — legacy
  /// single-credential pointer (new conversations prefer the env binding).
  /// Pass `name: null` to clear.
  Future<String?> setActiveCredential({
    required String id,
    required String? name,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationCredentialsActive(id),
      data: {'name': name},
    );
    return res.data!['active_credential'] as String?;
  }

  /// `POST /api/v1/conversations/<id>/credentials/toggle/` — per-conversation
  /// visibility toggle. Disabled bundles are invisible to the agent.
  Future<List<String>> toggleCredential({
    required String id,
    required String name,
    required bool enabled,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationCredentialsToggle(id),
      data: {'name': name, 'enabled': enabled},
    );
    return (res.data!['disabled_credentials'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
  }

  // ── Pending actions ─────────────────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/pending-actions/dismiss/` — removes
  /// matching entries from `pending_actions`. All filter params are
  /// AND-combined; omitting all of them removes every pending action.
  ///
  /// Returns the full conversation snapshot (server returns it for one-
  /// round-trip replacement).
  Future<ConversationSnapshot> dismissPendingAction({
    required String conversationId,
    String? actionType,
    String? credentialName,
    String? credentialKind,
  }) async {
    final body = <String, dynamic>{
      if (actionType != null) 'action_type': actionType,
      if (credentialName != null) 'credential_name': credentialName,
      if (credentialKind != null) 'credential_kind': credentialKind,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationDismiss(conversationId),
      data: body,
    );
    return ConversationSnapshot.fromJson(res.data!);
  }

  // ── Messages ────────────────────────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/messages/` — sends the user's turn.
  /// Returns the snapshot the server has at the moment the message is
  /// persisted; the agent reply lands on a subsequent poll.
  ///
  /// 409 means the agent is mid-task (`is_running=true`) — either wait
  /// or call [stop].
  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool deepThink = false,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      if (model != null) 'model': model,
      'deep_think': deepThink,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationMessages(conversationId),
      data: body,
    );
    return ConversationSnapshot.fromJson(res.data!);
  }

  // ── Attachments ─────────────────────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/attachments/` — multipart upload.
  /// Per-file cap is kind-aware: archives (.zip/.tar/.gz/.tgz) up to 500 MB
  /// for Odoo addon bundles, everything else 25 MB. Server returns 413 on
  /// overrun and 400 if `files` is empty. The chat picker pre-checks the
  /// cap so the user gets an instant local notice instead of a round-trip.
  Future<List<Attachment>> uploadAttachments({
    required String conversationId,
    required List<File> files,
  }) async {
    final form = FormData();
    for (final f in files) {
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(
            f.path,
            filename: f.uri.pathSegments.isNotEmpty
                ? f.uri.pathSegments.last
                : null,
          ),
        ),
      );
    }
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.conversationAttachments(conversationId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return (res.data!['attachments'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Attachment.fromJson)
        .toList();
  }

  /// `GET /api/v1/conversations/<id>/attachments/<aid>/status/` — poll
  /// every ~1 s while `status == pending`. Cap at ~30 s in the UI before
  /// surfacing a "taking longer than expected" hint.
  Future<Attachment> getAttachmentStatus({
    required String conversationId,
    required String attachmentId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.conversationAttachmentStatus(
        conversationId,
        attachmentId,
      ),
    );
    return Attachment.fromJson(res.data!);
  }
}

