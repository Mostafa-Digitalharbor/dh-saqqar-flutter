import '../../../core/storage/versioned_prefs_cache.dart';
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
/// The envelope, the version gate and the self-healing read all live in
/// [VersionedPrefsCache]; only the model mapping is here.
class VaultCache extends VersionedPrefsCache<VaultCacheEntry> {
  const VaultCache(super.prefs);

  @override
  String get storageKey => 'saqqar.vault.cache.v1';

  @override
  String get logTag => 'VaultCache';

  @override
  int get version => 1;

  @override
  VaultCacheEntry fromBody(Map<String, dynamic> body, DateTime savedAt) {
    return VaultCacheEntry(
      projects: VersionedPrefsCache.objectList(
        body['projects'],
      ).map(Project.fromJson).toList(),
      schemas: VersionedPrefsCache.objectList(
        body['schemas'],
      ).map(CredentialSchema.fromJson).toList(),
      savedAt: savedAt,
    );
  }

  /// Overwrite the cached snapshot. Best-effort — see [VersionedPrefsCache].
  Future<void> write({
    required List<Project> projects,
    required List<CredentialSchema> schemas,
  }) {
    return writeBody({
      'projects': projects.map((p) => p.toJson()).toList(),
      'schemas': schemas.map((s) => s.toJson()).toList(),
    });
  }
}
