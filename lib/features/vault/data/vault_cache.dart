import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import 'credential_models.dart';
import 'project_models.dart';

/// Persisted snapshot of the user's Vault, plus the time it was taken.
/// Used to render the projects list instantly on cold start (and on a
/// surface where the user is offline) while the cubit fires a fresh
/// fetch in the background.
class VaultCacheEntry {
  const VaultCacheEntry({
    required this.projects,
    required this.schemas,
    required this.savedAt,
  });

  final List<Project> projects;
  final List<CredentialSchema> schemas;
  final DateTime savedAt;
}

/// Read / write the Vault cache to SharedPreferences. Persists only the
/// project list + credential schemas (NEVER credential payloads — those
/// stay server-side and never touch shared prefs).
///
/// Storage format: a single JSON blob under one key, with a version
/// field so we can ratchet the schema if the model shape evolves. An
/// unrecognized version simply wipes the cache (the user will see a
/// brief loading state on next open; safer than crashing on a mismatch).
class VaultCache {
  VaultCache(this._prefs);

  static const _key = 'saqqar.vault.cache.v1';
  static const _tag = 'VaultCache';
  static const _version = 1;

  final SharedPreferences _prefs;

  /// Reads the persisted snapshot. Returns null when nothing's cached
  /// yet, or when the cached blob is malformed / mismatched version.
  VaultCacheEntry? read() {
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
      final projectsJson = (decoded['projects'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final schemasJson = (decoded['schemas'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final savedAt = DateTime.tryParse(decoded['saved_at'] as String? ?? '');
      return VaultCacheEntry(
        projects: projectsJson.map(Project.fromJson).toList(),
        schemas: schemasJson.map(CredentialSchema.fromJson).toList(),
        savedAt: savedAt?.toLocal() ?? DateTime.now(),
      );
    } catch (e, st) {
      AppLogger.warn(_tag, 'read() failed — dropping cache',
          error: e, stackTrace: st);
      // Defensive: bad blob means we lose the cache on this start.
      // Better than failing every load forever.
      unawaited(clear());
      return null;
    }
  }

  /// Overwrite the cached snapshot. Best-effort — failures only log;
  /// we never want a SharedPreferences hiccup to break the live UI.
  Future<void> write({
    required List<Project> projects,
    required List<CredentialSchema> schemas,
  }) async {
    try {
      final payload = jsonEncode({
        'version': _version,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'projects': projects.map((p) => p.toJson()).toList(),
        'schemas': schemas.map((s) => s.toJson()).toList(),
      });
      await _prefs.setString(_key, payload);
    } catch (e, st) {
      AppLogger.warn(_tag, 'write() failed', error: e, stackTrace: st);
    }
  }

  /// Wipe the cached blob. Call on sign-out so the next user doesn't
  /// see the previous user's data.
  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {
      // ignore
    }
  }
}

