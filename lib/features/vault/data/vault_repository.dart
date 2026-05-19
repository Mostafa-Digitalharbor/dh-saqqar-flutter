import '../../../core/logging/app_logger.dart';
import 'credential_models.dart';
import 'credentials_api.dart';
import 'project_models.dart';
import 'projects_api.dart';
import 'vault_cache.dart';

/// Aggregates [ProjectsApi] + [CredentialsApi] into a single Vault-facing
/// surface so the cubit doesn't have to thread two repositories.
///
/// Responsibilities beyond simple delegation:
///   * **Schema cache** — credential schemas are static for the user's
///     session, so we fetch them once and memoize. Pass `forceRefresh:
///     true` to bypass.
///   * **Operation-level logging** — every call logs an intent line at
///     [LogLevel.info] (separate from the raw HTTP log produced by
///     `LoggingInterceptor`). Failures log at [LogLevel.warn] with the
///     attached exception, so a single grep on the tag tells you what
///     the cubit *tried* to do, not just which URL it hit.
///
/// Wired in `main.dart` via `RepositoryProvider<VaultRepository>` so the
/// cubit reads it cheaply with `context.read<VaultRepository>()`.
class VaultRepository {
  VaultRepository({
    required ProjectsApi projectsApi,
    required CredentialsApi credentialsApi,
    VaultCache? cache,
  })  : _projects = projectsApi,
        _credentials = credentialsApi,
        _cache = cache;

  static const _tag = 'VaultRepository';

  final ProjectsApi _projects;
  final CredentialsApi _credentials;

  /// Optional offline cache. When supplied, [listProjects] +
  /// [getCredentialSchemas] write the fresh result through after every
  /// successful fetch, and [readCachedSnapshot] exposes the
  /// last-persisted blob so cubits can warm-start.
  final VaultCache? _cache;

  List<CredentialSchema>? _schemasCache;

  /// Returns the last-persisted snapshot (projects + schemas + savedAt)
  /// when an offline cache is wired AND has data. Null otherwise.
  ///
  /// Cubits call this on cold start to render the projects list
  /// instantly while a fresh fetch runs in the background.
  VaultCacheEntry? readCachedSnapshot() => _cache?.read();

  /// Wipes the cached blob — call from sign-out / account-switch so the
  /// next user doesn't see the previous user's data.
  Future<void> clearOfflineCache() async => _cache?.clear();

  // ── Projects ────────────────────────────────────────────────────────

  Future<List<Project>> listProjects() async {
    AppLogger.info(_tag, 'listProjects()');
    final projects = await _projects.list();
    _maybePersist(projects: projects);
    return projects;
  }

  Future<Project> createProject({required String name}) async {
    AppLogger.info(_tag, 'createProject(name=$name)');
    return _projects.create(name: name);
  }

  Future<Project> renameProject({
    required String id,
    required String name,
  }) async {
    AppLogger.info(_tag, 'renameProject(id=$id, name=$name)');
    return _projects.rename(id: id, name: name);
  }

  Future<void> deleteProject(String id) async {
    AppLogger.info(_tag, 'deleteProject(id=$id)');
    return _projects.delete(id);
  }

  // ── Environments ────────────────────────────────────────────────────

  Future<Environment> createEnvironment({
    required String projectId,
    required String name,
    bool isLive = false,
    bool readOnly = false,
    bool autoApprove = false,
  }) async {
    AppLogger.info(
      _tag,
      'createEnvironment(projectId=$projectId, name=$name, '
          'isLive=$isLive, readOnly=$readOnly, autoApprove=$autoApprove)',
    );
    return _projects.createEnvironment(
      projectId: projectId,
      name: name,
      isLive: isLive,
      readOnly: readOnly,
      autoApprove: autoApprove,
    );
  }

  Future<Environment> updateEnvironment({
    required String id,
    String? name,
    bool? isLive,
    bool? readOnly,
    bool? autoApprove,
  }) async {
    AppLogger.info(
      _tag,
      'updateEnvironment(id=$id, name=$name, isLive=$isLive, '
          'readOnly=$readOnly, autoApprove=$autoApprove)',
    );
    return _projects.updateEnvironment(
      id: id,
      name: name,
      isLive: isLive,
      readOnly: readOnly,
      autoApprove: autoApprove,
    );
  }

  Future<void> deleteEnvironment(String id) async {
    AppLogger.info(_tag, 'deleteEnvironment(id=$id)');
    return _projects.deleteEnvironment(id);
  }

  // ── Env-scoped credentials ──────────────────────────────────────────

  Future<List<Credential>> listEnvironmentCredentials(
    String environmentId,
  ) async {
    AppLogger.info(_tag, 'listEnvironmentCredentials(env=$environmentId)');
    return _projects.listEnvironmentCredentials(environmentId);
  }

  Future<Credential> getEnvironmentCredential({
    required String environmentId,
    required CredentialKind kind,
  }) async {
    AppLogger.info(
      _tag,
      'getEnvironmentCredential(env=$environmentId, kind=${kind.wire})',
    );
    return _projects.getEnvironmentCredential(
      environmentId: environmentId,
      kind: kind,
    );
  }

  Future<Credential> upsertEnvironmentCredential({
    required String environmentId,
    required CredentialKind kind,
    required Map<String, dynamic> payload,
    String? label,
    Map<String, dynamic>? metadata,
  }) async {
    AppLogger.info(
      _tag,
      'upsertEnvironmentCredential(env=$environmentId, kind=${kind.wire})',
    );
    return _projects.upsertEnvironmentCredential(
      environmentId: environmentId,
      kind: kind,
      payload: payload,
      label: label,
      metadata: metadata,
    );
  }

  Future<void> deleteEnvironmentCredential({
    required String environmentId,
    required CredentialKind kind,
  }) async {
    AppLogger.info(
      _tag,
      'deleteEnvironmentCredential(env=$environmentId, kind=${kind.wire})',
    );
    return _projects.deleteEnvironmentCredential(
      environmentId: environmentId,
      kind: kind,
    );
  }

  // ── Credential schemas (cached) ─────────────────────────────────────

  /// Returns the form descriptor for every supported credential kind.
  /// Result is memoized — credential schemas are essentially static for
  /// the session. Pass [forceRefresh] = true after a server-side schema
  /// change (or in tests) to bypass the cache.
  Future<List<CredentialSchema>> getCredentialSchemas({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _schemasCache != null) {
      AppLogger.debug(_tag, 'getCredentialSchemas() · cache hit');
      return _schemasCache!;
    }
    AppLogger.info(_tag, 'getCredentialSchemas() · fetching');
    final schemas = await _credentials.getSchemas();
    _schemasCache = schemas;
    _maybePersist(schemas: schemas);
    return schemas;
  }

  /// Drops the in-memory schema cache — call from sign-out so the next
  /// user's session re-fetches.
  void clearCaches() {
    _schemasCache = null;
  }

  /// Public hook for the cubit to persist the current in-memory snapshot
  /// after a mutation — so the offline cache reflects the result of
  /// creates / renames / deletes (the API methods only persist on the
  /// LIST + SCHEMAS path; mutations operate on different endpoints).
  ///
  /// Best-effort; failures only log inside [VaultCache.write]. No-op
  /// when no cache is wired.
  void persistSnapshot({
    required List<Project> projects,
    required List<CredentialSchema> schemas,
  }) {
    if (_cache == null) return;
    _lastProjects = projects;
    _schemasCache = schemas;
    _maybePersist(projects: projects, schemas: schemas);
  }

  // ── Offline cache write-through ─────────────────────────────────────

  // The cache stores BOTH projects + schemas in one blob (one
  // `SharedPreferences.setString` per write). When either fetch resolves
  // fresh, we re-persist the pair using the latest known value of the
  // other side — so a successful `listProjects` after a stale schema
  // load still updates the cache without losing the schema half.
  List<Project>? _lastProjects;

  void _maybePersist({
    List<Project>? projects,
    List<CredentialSchema>? schemas,
  }) {
    final cache = _cache;
    if (cache == null) return;
    if (projects != null) _lastProjects = projects;
    final resolvedProjects = projects ?? _lastProjects;
    final resolvedSchemas = schemas ?? _schemasCache;
    if (resolvedProjects == null || resolvedSchemas == null) return;
    // Fire-and-forget; failures only log inside [VaultCache.write].
    cache.write(projects: resolvedProjects, schemas: resolvedSchemas);
  }
}
