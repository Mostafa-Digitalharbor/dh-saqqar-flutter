import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../data/credential_models.dart';
import '../data/project_models.dart';
import '../data/vault_repository.dart';
import 'vault_state.dart';

/// ViewModel for the Vault feature. Owns:
///
///   * The async lifecycle of the projects + schemas list ([VaultState.data]).
///   * Optimistic mutations for project / environment CRUD (the UI reads
///     the new state immediately; if the server call fails, we roll back
///     and emit a typed `VaultActionFailure` for the view's BlocListener
///     to surface as a localized toast).
///   * Lazy per-env credential fetches when the user opens a detail sheet.
///
/// **Error contract:** the cubit NEVER produces user-facing strings.
/// Every failure is classified via [ApiErrorMapper.toFailure] into one
/// of the [AppFailure] subtypes; the view layer localizes it at render
/// time. That keeps the cubit context-free AND guarantees the message
/// follows the user's current locale even if they switch language after
/// the cubit emitted.
class VaultCubit extends Cubit<VaultState> {
  VaultCubit({required VaultRepository repository})
      : _repo = repository,
        super(const VaultState());

  static const _tag = 'VaultCubit';

  final VaultRepository _repo;

  /// Drop any [emit] call that lands after [close]. Same guard pattern
  /// as [ChatCubit.emit] — load + every mutation here awaits the
  /// repository, and the cubit can be reset (close + new instance)
  /// by the auth gate during sign-out mid-fetch.
  @override
  void emit(VaultState state) {
    if (isClosed) return;
    super.emit(state);
  }

  // ── Loading ─────────────────────────────────────────────────────────

  /// Initial load — fetches projects + schemas in parallel and emits a
  /// single success state. Safe to call multiple times; subsequent calls
  /// refresh in place via [refresh].
  Future<void> load() async {
    if (state.data is DataLoading<VaultData>) return;
    emit(state.copyWith(
      data: DataLoading<VaultData>(previous: state.data.dataOrNull),
    ));
    try {
      final results = await Future.wait([
        _repo.listProjects(),
        _repo.getCredentialSchemas(),
      ]);
      final projects = results[0] as List<Project>;
      final schemas = results[1] as List<CredentialSchema>;
      emit(state.copyWith(
        data: DataSuccess(
          VaultData(
            projects: projects,
            schemas: schemas,
            credentialsByEnv:
                state.data.dataOrNull?.credentialsByEnv ?? const {},
          ),
        ),
      ));
    } catch (e, st) {
      AppLogger.error(_tag, 'load() failed', error: e, stackTrace: st);
      final failure = ApiErrorMapper.toFailure(e);
      emit(state.copyWith(
        data: DataFailure<VaultData>(
          error: failure,
          previous: state.data.dataOrNull,
        ),
        actionFailure: VaultActionFailure(
          action: VaultAction.load,
          failure: failure,
        ),
      ));
    }
  }

  /// Re-fetches the projects list without dropping the schema cache.
  /// Use for pull-to-refresh.
  Future<void> refresh() => load();

  /// Best-effort warm start from the offline cache. Called once on
  /// cubit creation (or before [load]) so the projects list paints
  /// instantly on cold start while the live fetch runs in parallel.
  ///
  /// No-op when the repository doesn't have a cache wired, or when no
  /// snapshot has been persisted yet. Never throws — failures only log
  /// inside [VaultCache.read].
  void hydrateFromCache() {
    // Race guard: don't paint stale cache OVER a fresh load that's
    // already in flight or has already resolved.
    if (state.data.isSuccess || state.data.isLoading) return;
    final snapshot = _repo.readCachedSnapshot();
    if (snapshot != null) {
      AppLogger.debug(
        _tag,
        'hydrateFromCache() · ${snapshot.projects.length} projects, '
        'saved ${snapshot.savedAt.toIso8601String()}',
      );
      emit(state.copyWith(
        data: DataSuccess(
          VaultData(
            projects: snapshot.projects,
            schemas: snapshot.schemas,
          ),
        ),
      ));
    }
    // CRITICAL: always fire a fresh fetch after hydrating the cache.
    // Without this, the cached snapshot masks any server-side changes
    // (e.g. a project created on the web won't appear here), AND
    // VaultScreen's `if (isIdle) load()` guard never fires because the
    // state is already DataSuccess from the hydrate. The cubit's
    // internal `if (state.data is DataLoading) return` makes load()
    // safe to call concurrently.
    unawaited(load());
  }

  /// Drops the in-memory projects / schemas back to the idle state and
  /// wipes both the offline blob and the in-memory schema cache.
  /// Invoked by the auth boundary when the signed-in user changes so
  /// the next account's first paint doesn't show the previous user's
  /// data.
  Future<void> reset() async {
    _repo.clearCaches();
    await _repo.clearOfflineCache();
    if (state == const VaultState()) return;
    emit(const VaultState());
  }

  // ── Projects ────────────────────────────────────────────────────────

  Future<bool> createProject({required String name}) {
    return _runMutation(
      VaultAction.createProject,
      successToast: VaultToast.projectCreated,
      block: () async {
        final project = await _repo.createProject(name: name);
        final current = _requireData('createProject');
        emit(state.copyWith(
          data: DataSuccess(
            current.copyWith(projects: [...current.projects, project]),
          ),
        ));
      },
    );
  }

  Future<bool> renameProject({required String id, required String name}) {
    return _runOptimistic(
      VaultAction.renameProject,
      mutate: (data) {
        return data.copyWith(
          projects: [
            for (final p in data.projects)
              if (p.id == id)
                Project(
                  id: p.id,
                  name: name,
                  slug: p.slug,
                  environments: p.environments,
                )
              else
                p,
          ],
        );
      },
      commit: () => _repo.renameProject(id: id, name: name),
    );
  }

  Future<bool> deleteProject(String id) {
    return _runOptimistic(
      VaultAction.deleteProject,
      successToast: VaultToast.projectDeleted,
      mutate: (data) {
        final remaining = data.projects.where((p) => p.id != id).toList();
        final envIds =
            data.projectById(id)?.environments.map((e) => e.id).toSet() ??
                const <String>{};
        final cache = {
          for (final entry in data.credentialsByEnv.entries)
            if (!envIds.contains(entry.key)) entry.key: entry.value,
        };
        return data.copyWith(projects: remaining, credentialsByEnv: cache);
      },
      commit: () => _repo.deleteProject(id),
    );
  }

  // ── Environments ────────────────────────────────────────────────────

  Future<bool> createEnvironment({
    required String projectId,
    required String name,
    bool isLive = false,
    bool readOnly = false,
    bool autoApprove = false,
  }) {
    return _runMutation(
      VaultAction.createEnvironment,
      successToast: VaultToast.environmentCreated,
      block: () async {
        final env = await _repo.createEnvironment(
          projectId: projectId,
          name: name,
          isLive: isLive,
          readOnly: readOnly,
          autoApprove: autoApprove,
        );
        final current = _requireData('createEnvironment');
        emit(state.copyWith(
          data: DataSuccess(
            current.copyWith(
              projects: [
                for (final p in current.projects)
                  if (p.id == projectId)
                    Project(
                      id: p.id,
                      name: p.name,
                      slug: p.slug,
                      environments: [...p.environments, env],
                    )
                  else
                    p,
              ],
            ),
          ),
        ));
      },
    );
  }

  Future<bool> updateEnvironment({
    required String id,
    String? name,
    bool? isLive,
    bool? readOnly,
    bool? autoApprove,
  }) {
    Environment? owningEnv;
    String? owningProjectId;
    return _runOptimistic(
      VaultAction.updateEnvironment,
      mutate: (data) {
        for (final p in data.projects) {
          for (final e in p.environments) {
            if (e.id == id) {
              owningEnv = e;
              owningProjectId = p.id;
              break;
            }
          }
          if (owningEnv != null) break;
        }
        if (owningEnv == null) return data;
        return data.copyWith(
          projects: [
            for (final p in data.projects)
              if (p.id == owningProjectId)
                Project(
                  id: p.id,
                  name: p.name,
                  slug: p.slug,
                  environments: [
                    for (final e in p.environments)
                      if (e.id == id)
                        e.copyWith(
                          name: name,
                          isLive: isLive,
                          readOnly: readOnly,
                          autoApprove: autoApprove,
                        )
                      else
                        e,
                  ],
                )
              else
                p,
          ],
        );
      },
      commit: () => _repo.updateEnvironment(
        id: id,
        name: name,
        isLive: isLive,
        readOnly: readOnly,
        autoApprove: autoApprove,
      ),
    );
  }

  Future<bool> deleteEnvironment(String id) {
    return _runOptimistic(
      VaultAction.deleteEnvironment,
      successToast: VaultToast.environmentDeleted,
      mutate: (data) {
        return data.copyWith(
          projects: [
            for (final p in data.projects)
              Project(
                id: p.id,
                name: p.name,
                slug: p.slug,
                environments: p.environments.where((e) => e.id != id).toList(),
              ),
          ],
          credentialsByEnv: {
            for (final entry in data.credentialsByEnv.entries)
              if (entry.key != id) entry.key: entry.value,
          },
        );
      },
      commit: () => _repo.deleteEnvironment(id),
    );
  }

  // ── Credentials (env-scoped) ────────────────────────────────────────

  /// Lazy-load credentials for one env. Safe to re-call — replaces the
  /// cached list. Failures surface as a typed [VaultActionFailure].
  Future<void> loadEnvironmentCredentials(String envId) async {
    final current = state.data.dataOrNull;
    if (current == null) return;
    try {
      final list = await _repo.listEnvironmentCredentials(envId);
      final cache = {...current.credentialsByEnv, envId: list};
      emit(state.copyWith(
        data: DataSuccess(current.copyWith(credentialsByEnv: cache)),
      ));
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'loadEnvironmentCredentials(env=$envId) failed',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(
        actionFailure: VaultActionFailure(
          action: VaultAction.loadCredentials,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
    }
  }

  /// Fetch the full credential bundle (with decrypted payload) for one
  /// env+kind and merge it into the cache, replacing the payload-less row
  /// that came from the list endpoint. The credential form calls this when
  /// it opens an existing credential so its fields show the saved values
  /// instead of rendering empty — the list response omits `payload` for
  /// security, so the cache alone can't fill the form.
  Future<void> loadEnvironmentCredentialDetail({
    required String envId,
    required CredentialKind kind,
  }) async {
    final current = state.data.dataOrNull;
    if (current == null) return;
    try {
      final full = await _repo.getEnvironmentCredential(
        environmentId: envId,
        kind: kind,
      );
      // The credential may have been deleted (or the env swapped out)
      // while the detail fetch was in flight — re-read the latest state.
      final latest = state.data.dataOrNull;
      if (latest == null) return;
      final existing = latest.credentialsByEnv[envId] ?? const <Credential>[];
      final next = [
        for (final c in existing)
          if (c.kind != kind) c,
        full,
      ];
      emit(state.copyWith(
        data: DataSuccess(latest.copyWith(
          credentialsByEnv: {...latest.credentialsByEnv, envId: next},
        )),
      ));
    } catch (e, st) {
      // Non-fatal: the form falls back to empty fields and the user can
      // still overwrite the credential. Surface a typed failure for the
      // view's listener, same as the list fetch.
      AppLogger.warn(
        _tag,
        'loadEnvironmentCredentialDetail(env=$envId, kind=${kind.wire}) failed',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(
        actionFailure: VaultActionFailure(
          action: VaultAction.loadCredentials,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
    }
  }

  Future<bool> saveEnvironmentCredential({
    required String envId,
    required CredentialKind kind,
    required Map<String, dynamic> payload,
    String? label,
  }) {
    return _runMutation(
      VaultAction.saveCredential,
      successToast: VaultToast.credentialSaved,
      block: () async {
        final saved = await _repo.upsertEnvironmentCredential(
          environmentId: envId,
          kind: kind,
          payload: payload,
          label: label,
        );
        final current = _requireData('saveEnvironmentCredential');
        final existing =
            current.credentialsByEnv[envId] ?? const <Credential>[];
        final next = [
          for (final c in existing)
            if (c.kind != kind) c,
          saved,
        ];
        emit(state.copyWith(
          data: DataSuccess(current.copyWith(
            credentialsByEnv: {...current.credentialsByEnv, envId: next},
          )),
        ));
      },
    );
  }

  Future<bool> deleteEnvironmentCredential({
    required String envId,
    required CredentialKind kind,
  }) {
    return _runMutation(
      VaultAction.deleteCredential,
      successToast: VaultToast.credentialDeleted,
      block: () async {
        await _repo.deleteEnvironmentCredential(
          environmentId: envId,
          kind: kind,
        );
        final current = _requireData('deleteEnvironmentCredential');
        final existing =
            current.credentialsByEnv[envId] ?? const <Credential>[];
        final next = existing.where((c) => c.kind != kind).toList();
        emit(state.copyWith(
          data: DataSuccess(current.copyWith(
            credentialsByEnv: {...current.credentialsByEnv, envId: next},
          )),
        ));
      },
    );
  }

  // ── One-shot message acknowledgement ────────────────────────────────

  /// Call from the screen's `BlocListener` after rendering the toast so
  /// it doesn't fire on subsequent state changes.
  void consumeActionFailure() {
    if (state.actionFailure == null) return;
    emit(state.copyWith(clearActionFailure: true));
  }

  void consumeActionToast() {
    if (state.actionToast == null) return;
    emit(state.copyWith(clearActionToast: true));
  }

  // ── Internals ───────────────────────────────────────────────────────

  /// Runs a mutation that needs the server response before we can update
  /// local state (creates — server assigns the id; credential save —
  /// server returns the canonical row). Sets [actionInFlight] for the
  /// duration. Returns true on success, false on failure (with
  /// [actionFailure] populated).
  Future<bool> _runMutation(
    VaultAction action, {
    required Future<void> Function() block,
    VaultToast? successToast,
  }) async {
    if (state.actionInFlight) {
      AppLogger.warn(_tag, '${action.name} skipped — another mutation in flight');
      return false;
    }
    emit(state.copyWith(actionInFlight: true, clearActionFailure: true));
    try {
      await block();
      emit(state.copyWith(
        actionInFlight: false,
        actionToast: successToast,
      ));
      // Snapshot the post-mutation state to the offline cache so the
      // next cold start sees the new project / env / credential even
      // before the live fetch returns.
      _persistCurrentSnapshot();
      return true;
    } catch (e, st) {
      AppLogger.warn(_tag, '${action.name} failed', error: e, stackTrace: st);
      emit(state.copyWith(
        actionInFlight: false,
        actionFailure: VaultActionFailure(
          action: action,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  /// Runs a mutation optimistically — applies [mutate] locally first,
  /// fires [commit] in the background, and rolls back to the
  /// pre-mutation data if the server rejects. Use for renames / deletes
  /// / flag toggles where the user expects instant feedback.
  /// Monotonic id stamped on each optimistic mutation. On rollback we only
  /// restore the captured pre-state if OURS is still the latest mutation —
  /// see [_runOptimistic].
  int _optimisticSeq = 0;

  Future<bool> _runOptimistic(
    VaultAction action, {
    required VaultData Function(VaultData) mutate,
    required Future<Object?> Function() commit,
    VaultToast? successToast,
  }) async {
    final current = state.data.dataOrNull;
    if (current == null) {
      AppLogger.warn(_tag, '${action.name} skipped — no data loaded');
      return false;
    }
    final optimistic = mutate(current);
    final seq = ++_optimisticSeq;
    emit(state.copyWith(
      data: DataSuccess(optimistic),
      actionInFlight: true,
      clearActionFailure: true,
    ));
    try {
      await commit();
      emit(state.copyWith(
        actionInFlight: false,
        actionToast: successToast,
      ));
      _persistCurrentSnapshot();
      return true;
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        '${action.name} failed — rolling back',
        error: e,
        stackTrace: st,
      );
      // Restore the pre-mutation data ONLY if no newer optimistic mutation
      // landed while our commit was in flight. Otherwise `current` is a stale
      // capture from before that newer change, and blindly restoring it would
      // silently discard the concurrent (already-applied, possibly-succeeded)
      // mutation — a lost update. In that case we keep the newer data intact
      // and only surface the failure; the newer mutation owns the rollback of
      // its own slice if IT fails too.
      final isLatest = seq == _optimisticSeq;
      emit(state.copyWith(
        data: isLatest ? DataSuccess(current) : state.data,
        actionInFlight: false,
        actionFailure: VaultActionFailure(
          action: action,
          failure: ApiErrorMapper.toFailure(e),
        ),
      ));
      return false;
    }
  }

  VaultData _requireData(String op) {
    final d = state.data.dataOrNull;
    if (d == null) {
      throw StateError('$op called before VaultCubit data loaded');
    }
    return d;
  }

  /// Persist the current in-memory snapshot to the offline cache so it
  /// survives an app restart. Called after every successful mutation;
  /// safe to call when no cache is wired (the repository no-ops).
  void _persistCurrentSnapshot() {
    final data = state.data.dataOrNull;
    if (data == null) return;
    _repo.persistSnapshot(
      projects: data.projects,
      schemas: data.schemas,
    );
  }
}
