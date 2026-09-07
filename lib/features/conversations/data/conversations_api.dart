import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
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

  /// `GET /api/v1/conversations/?limit=&offset=&include_archived=`
  ///
  /// [offset] was sent before the endpoint documented it. The server used to
  /// cap the page at 100 whatever the client asked for, send no `total`, and
  /// ignore `offset` — an account with ~140 conversations got 100 rows and no
  /// way to ask for the rest, on a screen that looked complete.
  ///
  /// It became real on 2026-08-09: `limit` (default 30, capped at 200),
  /// `offset`, and a `total` that counts everything after filters.
  ///
  /// Sending `offset` remains safe either way — a server that supports it
  /// pages correctly, and one that ignores it returns the same first page,
  /// which the caller detects (no new ids) and stops on. See
  /// `ConversationsRepository.listAll`.
  ///
  /// **Advance `offset` by rows RECEIVED, never by rows requested.** The
  /// server clamps `limit` to 200, so stepping by a larger requested figure
  /// would skip everything in between.
  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    int offset = 0,
    bool includeArchived = false,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.conversations,
      queryParameters: {
        'limit': limit,
        if (offset > 0) 'offset': offset,
        'include_archived': includeArchived ? 1 : 0,
      },
    );
    // A bodiless 200 must not read as "you have no conversations" — that is
    // the same screen a brand-new account gets, and it offers no retry.
    // A body that IS present but lists nothing is a real empty account and
    // still flows through below.
    final data = res.requiredBody;
    return (
      // whereType skips a malformed row; the post-map filter drops any row
      // we couldn't identify (empty id) — one bad row never blanks the list.
      conversations: (data['conversations'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ConversationSummary.fromJson)
          .where((c) => c.id.isNotEmpty)
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
    final id = res.data?['conversation_id'];
    if (id is! String || id.isEmpty) {
      // Unexpected 200 body — fail loudly (and mappably) instead of
      // returning an empty id that would break every downstream route.
      throw const FormatException('create: response missing conversation_id');
    }
    return id;
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
    // Plain text, not decoded JSON — the body is handed to a background
    // isolate so parsing a long transcript never janks the chat. The
    // required-body rule still applies: `''` reaches
    // `getSnapshotOffIsolate`, which raises a FormatException for it, but
    // an outright missing body is worth failing on here rather than
    // travelling one layer further as an empty string.
    return res.requiredBody;
  }

  // ── Metadata ────────────────────────────────────────────────────────

  /// `PATCH /api/v1/conversations/<id>/` — any subset of title / archive
  /// flag / auto-approve / bound environment.
  ///
  /// To clear the environment binding, pass [environmentId] as the
  /// sentinel empty string `''` (Dio drops keys whose value is `null`,
  /// which would otherwise silently no-op).
  ///
  /// No `deep_think` key: the web removed the manual deep-think toggle and
  /// the backend routes hard tasks (artifact / code authoring) to the
  /// stronger model on its own, so a client-sent value would only fight it.
  /// [Conversation] still *parses* the field the server serializes.
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
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (isArchived != null) 'is_archived': isArchived,
      if (autoApprove != null) 'auto_approve': autoApprove,
      // Sent only when the caller has a value, like every key here — so a
      // build that never touches the toggle sends nothing new, and a server
      // that does not yet know the field is never handed one.
      if (taskPrep != null) 'task_prep': taskPrep,
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
    // Both flags default to false, so a missing body reported the run as
    // stopped and not running — the composer re-enables and the user is told
    // the cancel worked while the turn is very likely still going.
    final data = res.requiredBody;
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
    // Every field defaults to empty, so a missing body used to open the OS
    // share sheet on a blank link. Whatever the user then sent someone is
    // unrecoverable — better to fail here, where a retry still exists.
    final data = res.requiredBody;
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
    // Null means "no credential is active". Reading that off a body that
    // never arrived tells the chat the credential was cleared, and the
    // header drops the badge — the user believes the agent lost access to
    // a system it can still reach.
    return res.requiredBody['active_credential'] as String?;
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
    // An empty list means "nothing is disabled" — so a missing body used to
    // re-enable every credential in the UI while the server state was
    // untouched. The next turn then runs against a set the user thinks they
    // switched off.
    return (res.requiredBody['disabled_credentials'] as List? ?? [])
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

  /// `POST /api/v1/conversations/<id>/resume/` — restarts a run that stopped
  /// without finishing and without anything waiting on the user. Empty body;
  /// returns a full snapshot, same shape as [getSnapshot].
  Future<ConversationSnapshot> resume(String conversationId) async {
    final body = await _dio.postJson(
      ApiEndpoints.conversationResume(conversationId),
      data: const <String, dynamic>{},
    );
    return ConversationSnapshot.fromJson(body);
  }

  // ── Messages ────────────────────────────────────────────────────────

  /// `POST /api/v1/conversations/<id>/messages/` — sends the user's turn.
  /// Returns the snapshot the server has at the moment the message is
  /// persisted; the agent reply lands on a subsequent poll.
  ///
  /// 409 means the agent is mid-task (`is_running=true`) — either wait
  /// or call [stop].
  ///
  /// [taskPrep] rides along as `task_prep`. The server already honours the
  /// key (`payload.get("task_prep", True)`) and gates it itself, coercing to
  /// `false` when the caller's plan lacks the feature — so sending `true`
  /// from an ineligible account degrades to today's behaviour rather than
  /// erroring. On, Saqqar answers a vague task with a `prompt_clarify` card
  /// instead of guessing.
  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool taskPrep = true,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      if (model != null) 'model': model,
      'task_prep': taskPrep,
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

