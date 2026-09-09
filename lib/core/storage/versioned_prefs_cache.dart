import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

/// One versioned JSON blob under one SharedPreferences key, with the
/// read/version-check/self-heal behaviour every offline cache in the app
/// needs and none of them should re-implement.
///
/// [ConversationsCache] and [VaultCache] were byte-for-byte the same forty
/// lines apart from which model they mapped: the same envelope keys, the same
/// version gate, the same "a bad blob wipes itself rather than failing every
/// launch forever" recovery. Two copies is how one of them gets a fix — a
/// tightened guard, a `savedAt` that stops being local time — and the other
/// doesn't.
///
/// Subclasses supply the key, the tag and the version, then map their models
/// in [readBody] / out of [writeBody]. Everything about *storage* lives here.
///
/// **Never put a secret in one of these.** SharedPreferences is plain text on
/// both platforms; credential payloads and tokens belong in
/// `SecureTokenStore`.
abstract class VersionedPrefsCache<T> {
  const VersionedPrefsCache(this.prefs);

  final SharedPreferences prefs;

  /// SharedPreferences key. Include a `.vN` suffix so a hard format break can
  /// simply move to a new key and leave the old blob to be garbage.
  String get storageKey;

  /// Log tag, for the version-mismatch and self-heal lines.
  String get logTag;

  /// Bump when the *body* shape changes. A blob written by any other version
  /// is dropped rather than parsed.
  int get version;

  /// Maps a decoded, version-checked body to the entry type.
  ///
  /// [savedAt] is the write timestamp, already converted to local time. May
  /// throw freely — [read] treats a throw as "this blob is unusable" and
  /// wipes it.
  T fromBody(Map<String, dynamic> body, DateTime savedAt);

  /// Reads the persisted entry.
  ///
  /// Returns null when nothing is cached, when the blob was written by a
  /// different [version], or when it is malformed — and in that last case
  /// deletes it, so one bad write cannot cost the user their cache on every
  /// launch from here on.
  T? read() {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      // A blob that decodes to a list or a scalar is not ours. Checked rather
      // than cast so the failure reads as "wrong shape" in the log instead of
      // as an unhandled TypeError.
      if (decoded is! Map<String, dynamic>) {
        AppLogger.debug(logTag, 'cache root is ${decoded.runtimeType} · dropping');
        unawaited(clear());
        return null;
      }
      final storedVersion = decoded['version'];
      if (storedVersion != version) {
        AppLogger.debug(
          logTag,
          'cache version mismatch (got $storedVersion, want $version) · dropping',
        );
        return null;
      }
      final savedAt = DateTime.tryParse(decoded['saved_at'] as String? ?? '');
      return fromBody(decoded, savedAt?.toLocal() ?? DateTime.now());
    } catch (e, st) {
      AppLogger.warn(logTag, 'read() failed — dropping cache',
          error: e, stackTrace: st);
      unawaited(clear());
      return null;
    }
  }

  /// Overwrites the cached blob with [body], stamped with [version] and the
  /// current UTC time.
  ///
  /// Best-effort: a SharedPreferences hiccup logs and returns rather than
  /// propagating. Nothing the user is looking at depends on the write
  /// landing — the live data is already on screen.
  Future<void> writeBody(Map<String, Object?> body) async {
    try {
      await prefs.setString(
        storageKey,
        jsonEncode({
          'version': version,
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          ...body,
        }),
      );
    } catch (e, st) {
      AppLogger.warn(logTag, 'write() failed', error: e, stackTrace: st);
    }
  }

  /// Wipes the cached blob. Call on sign-out and account deletion so the next
  /// user never sees the previous user's data.
  Future<void> clear() async {
    try {
      await prefs.remove(storageKey);
    } catch (e, st) {
      // Best-effort by design, but silence here once hid a keystore failure
      // that left one user's rows readable after sign-out on a shared device.
      AppLogger.warn(logTag, 'clear() failed', error: e, stackTrace: st);
    }
  }

  /// `{String: int}` from an arbitrary decoded value — the shape both count
  /// maps in the app use. Anything unparseable is dropped rather than
  /// defaulted, so a bad key cannot become a real-looking zero.
  static Map<String, int> intMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      if (n != null) out['$k'] = n;
    });
    return out;
  }

  /// `List<Map<String, dynamic>>` from an arbitrary decoded value, skipping
  /// any element that is not an object.
  ///
  /// `.cast<Map<String, dynamic>>()` throws lazily on the first bad element,
  /// which costs the whole cache; skipping costs one row.
  static List<Map<String, dynamic>> objectList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) item,
    ];
  }
}
