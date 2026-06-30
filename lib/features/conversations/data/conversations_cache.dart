import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
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
/// Single versioned JSON blob under one key. An unrecognized version wipes
/// the cache (the user sees a brief load on next open — safer than crashing
/// on a shape mismatch). Mirrors [VaultCache] so the two offline caches read
/// and invalidate the same way.
class ConversationsCache {
  ConversationsCache(this._prefs);

  static const _key = 'saqqar.conversations.cache.v1';
  static const _tag = 'ConversationsCache';
  static const _version = 1;

  final SharedPreferences _prefs;

  /// Reads the persisted list. Returns null when nothing's cached yet, or
  /// when the blob is malformed / a stale version.
  ConversationsCacheEntry? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final version = decoded['version'] as int? ?? 0;
      if (version != _version) {
        AppLogger.debug(
          _tag,
          'cache version mismatch (got $version, want $_version) · dropping',
        );
        return null;
      }
      final rows = (decoded['conversations'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ConversationSummary.fromJson)
          .toList();
      final savedAt = DateTime.tryParse(decoded['saved_at'] as String? ?? '');
      return ConversationsCacheEntry(
        conversations: rows,
        pendingByConv: _intMap(decoded['pending_by_conv']),
        filesByConv: _intMap(decoded['files_by_conv']),
        savedAt: savedAt?.toLocal() ?? DateTime.now(),
      );
    } catch (e, st) {
      AppLogger.warn(_tag, 'read() failed — dropping cache',
          error: e, stackTrace: st);
      unawaited(clear());
      return null;
    }
  }

  /// Overwrite the cached list. Best-effort — failures only log; a
  /// SharedPreferences hiccup must never break the live UI.
  Future<void> write({
    required List<ConversationSummary> conversations,
    required Map<String, int> pendingByConv,
    required Map<String, int> filesByConv,
  }) async {
    try {
      final payload = jsonEncode({
        'version': _version,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'conversations': conversations.map((c) => c.toJson()).toList(),
        'pending_by_conv': pendingByConv,
        'files_by_conv': filesByConv,
      });
      await _prefs.setString(_key, payload);
    } catch (e, st) {
      AppLogger.warn(_tag, 'write() failed', error: e, stackTrace: st);
    }
  }

  /// Wipe the cached list. Call on sign-out / account deletion so the next
  /// user never sees the previous user's conversations.
  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {
      // ignore
    }
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      if (n != null) out['$k'] = n;
    });
    return out;
  }
}
