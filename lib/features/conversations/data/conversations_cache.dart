import '../../../core/storage/versioned_prefs_cache.dart';
import 'conversation_models.dart';

/// Persisted snapshot of the Chats list — the conversation rows plus the
/// per-conversation pending-approval and file counts — and when it was
/// taken. Lets the Chats tab paint instantly on cold start (and offline)
/// while the live list + meta fetch run in the background.
class ConversationsCacheEntry {
  const ConversationsCacheEntry({
    required this.conversations,
    required this.pendingByConv,
    required this.filesByConv,
    required this.savedAt,
  });

  final List<ConversationSummary> conversations;
  final Map<String, int> pendingByConv;
  final Map<String, int> filesByConv;
  final DateTime savedAt;
}

/// Read / write the Chats list cache to SharedPreferences. Stores only the
/// list rows + the two count maps — never message bodies (those live in the
/// per-conversation snapshot cache) and never credential payloads.
///
/// The envelope, the version gate and the self-healing read all live in
/// [VersionedPrefsCache]; only the model mapping is here.
class ConversationsCache extends VersionedPrefsCache<ConversationsCacheEntry> {
  const ConversationsCache(super.prefs);

  @override
  String get storageKey => 'saqqar.conversations.cache.v1';

  @override
  String get logTag => 'ConversationsCache';

  @override
  int get version => 1;

  @override
  ConversationsCacheEntry fromBody(Map<String, dynamic> body, DateTime savedAt) {
    return ConversationsCacheEntry(
      conversations: VersionedPrefsCache.objectList(body['conversations'])
          .map(ConversationSummary.fromJson)
          .toList(),
      pendingByConv: VersionedPrefsCache.intMap(body['pending_by_conv']),
      filesByConv: VersionedPrefsCache.intMap(body['files_by_conv']),
      savedAt: savedAt,
    );
  }

  /// Overwrite the cached list. Best-effort — see [VersionedPrefsCache].
  Future<void> write({
    required List<ConversationSummary> conversations,
    required Map<String, int> pendingByConv,
    required Map<String, int> filesByConv,
  }) {
    return writeBody({
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'pending_by_conv': pendingByConv,
      'files_by_conv': filesByConv,
    });
  }
}
