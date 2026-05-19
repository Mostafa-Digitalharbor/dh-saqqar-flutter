import 'dart:io';

import '../../../core/logging/app_logger.dart';
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
  ConversationsRepository(this._api);

  static const _tag = 'ConversationsRepository';

  final ConversationsApi _api;

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
