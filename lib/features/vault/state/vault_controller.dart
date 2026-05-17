import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/saqqar_demo_data.dart';

/// In-memory state for the Vault (projects → environments → credentials).
/// All mutations are local right now — the matching `/api/projects/`,
/// `/api/environments/`, and `/api/environments/{id}/credentials/{kind}/`
/// endpoints aren't live yet (see `BACKEND_REQUEST`). When they ship, swap
/// each `_update*` helper for a Dio call without touching call sites.
///
/// The state is seeded from the const `demoProjects` / `demoEnvironments` /
/// `demoCredentials` lists. Subsequent rebuilds use the cloned mutable
/// state inside the controller, so the const seed never gets mutated.
class VaultState {
  const VaultState({
    required this.projects,
    required this.environments,
    required this.credentialsByEnvKind,
  });

  /// All projects the user has access to, in display order.
  final List<DemoProject> projects;

  /// All environments — flat list, keyed back to their project via
  /// [DemoEnvironment.projectId].
  final List<DemoEnvironment> environments;

  /// `credentialsByEnvKind[envId][kind]` → the credential bound to that
  /// env-kind slot, or null if none is configured yet.
  final Map<String, Map<DemoCredentialKind, DemoCredential>>
      credentialsByEnvKind;

  List<DemoEnvironment> environmentsForProject(String projectId) {
    return environments.where((e) => e.projectId == projectId).toList();
  }

  DemoCredential? credentialFor(String envId, DemoCredentialKind kind) {
    return credentialsByEnvKind[envId]?[kind];
  }

  VaultState copyWith({
    List<DemoProject>? projects,
    List<DemoEnvironment>? environments,
    Map<String, Map<DemoCredentialKind, DemoCredential>>? credentialsByEnvKind,
  }) {
    return VaultState(
      projects: projects ?? this.projects,
      environments: environments ?? this.environments,
      credentialsByEnvKind:
          credentialsByEnvKind ?? this.credentialsByEnvKind,
    );
  }
}

class VaultController extends Notifier<VaultState> {
  @override
  VaultState build() {
    // Seed credentials-by-env-kind from the const env.credentialNames refs.
    final byEnvKind =
        <String, Map<DemoCredentialKind, DemoCredential>>{};
    for (final env in demoEnvironments) {
      final perKind = <DemoCredentialKind, DemoCredential>{};
      for (final name in env.credentialNames) {
        for (final c in demoCredentials) {
          if (c.name == name) {
            perKind[c.kind] = c;
            break;
          }
        }
      }
      byEnvKind[env.id] = perKind;
    }
    return VaultState(
      projects: List.of(demoProjects),
      environments: List.of(demoEnvironments),
      credentialsByEnvKind: byEnvKind,
    );
  }

  // ───── Projects ──────────────────────────────────────────────────────

  String createProject({required String name}) {
    final id = _generateId('proj');
    final project = DemoProject(id: id, name: name.trim());
    state = state.copyWith(projects: [...state.projects, project]);
    return id;
  }

  void renameProject({required String projectId, required String name}) {
    state = state.copyWith(
      projects: [
        for (final p in state.projects)
          if (p.id == projectId)
            DemoProject(id: p.id, name: name.trim())
          else
            p,
      ],
    );
  }

  void deleteProject(String projectId) {
    final envIds = state.environments
        .where((e) => e.projectId == projectId)
        .map((e) => e.id)
        .toSet();
    final remainingByEnvKind = {
      for (final entry in state.credentialsByEnvKind.entries)
        if (!envIds.contains(entry.key)) entry.key: entry.value,
    };
    state = state.copyWith(
      projects: state.projects.where((p) => p.id != projectId).toList(),
      environments:
          state.environments.where((e) => e.projectId != projectId).toList(),
      credentialsByEnvKind: remainingByEnvKind,
    );
  }

  // ───── Environments ──────────────────────────────────────────────────

  String createEnvironment({
    required String projectId,
    required String name,
  }) {
    final id = _generateId('env');
    final env = DemoEnvironment(
      id: id,
      projectId: projectId,
      name: name.trim(),
    );
    state = state.copyWith(
      environments: [...state.environments, env],
      credentialsByEnvKind: {
        ...state.credentialsByEnvKind,
        id: const {},
      },
    );
    return id;
  }

  void renameEnvironment({required String envId, required String name}) {
    state = state.copyWith(
      environments: [
        for (final e in state.environments)
          if (e.id == envId) _copyEnv(e, name: name.trim()) else e,
      ],
    );
  }

  void setEnvFlag({
    required String envId,
    bool? isLive,
    bool? readOnly,
    bool? autoApprove,
  }) {
    state = state.copyWith(
      environments: [
        for (final e in state.environments)
          if (e.id == envId)
            _copyEnv(
              e,
              isLive: isLive,
              readOnly: readOnly,
              autoApprove: autoApprove,
            )
          else
            e,
      ],
    );
  }

  /// Reorders the environments belonging to [projectId] so the one at
  /// [oldIndex] (within the project's own env list) moves to [newIndex].
  /// Environments belonging to other projects keep their relative order
  /// untouched — we splice the project's slice back in at its original
  /// insertion points after sorting it. Demo-only; once the backend
  /// ships, swap for a single PATCH to the project that includes the new
  /// ordered env id list.
  void reorderEnvironment({
    required String projectId,
    required int oldIndex,
    required int newIndex,
  }) {
    // Flutter's ReorderableListView reports `newIndex` as the slot you
    // dropped INTO, which is +1 past the visual position when dragging
    // down. Normalise to a stable insertion index.
    final adjusted =
        newIndex > oldIndex ? newIndex - 1 : newIndex;

    final projectEnvs = <DemoEnvironment>[];
    final originalPositions = <int>[];
    for (var i = 0; i < state.environments.length; i++) {
      if (state.environments[i].projectId == projectId) {
        projectEnvs.add(state.environments[i]);
        originalPositions.add(i);
      }
    }
    if (oldIndex < 0 ||
        oldIndex >= projectEnvs.length ||
        adjusted < 0 ||
        adjusted >= projectEnvs.length ||
        oldIndex == adjusted) {
      return;
    }
    final moved = projectEnvs.removeAt(oldIndex);
    projectEnvs.insert(adjusted, moved);

    final next = [...state.environments];
    for (var i = 0; i < originalPositions.length; i++) {
      next[originalPositions[i]] = projectEnvs[i];
    }
    state = state.copyWith(environments: next);
  }

  void deleteEnvironment(String envId) {
    final remainingByEnvKind = {
      for (final entry in state.credentialsByEnvKind.entries)
        if (entry.key != envId) entry.key: entry.value,
    };
    state = state.copyWith(
      environments: state.environments.where((e) => e.id != envId).toList(),
      credentialsByEnvKind: remainingByEnvKind,
    );
  }

  // ───── Credentials (per env-kind slot) ───────────────────────────────

  void saveCredential({
    required String envId,
    required DemoCredentialKind kind,
    required String label,
    required Map<String, String> values,
  }) {
    final existing = state.credentialFor(envId, kind);
    final credential = DemoCredential(
      name: existing?.name ?? _generateId('cred'),
      label: label.trim().isEmpty
          ? demoCredentialKindLabel(kind)
          : label.trim(),
      kind: kind,
      source: 'env',
      lastVerified: _nowLabel(),
      isMemorized: true,
    );
    final next = {
      ...state.credentialsByEnvKind,
      envId: {
        ...?state.credentialsByEnvKind[envId],
        kind: credential,
      },
    };
    state = state.copyWith(credentialsByEnvKind: next);
  }

  /// Bumps the saved credential's `lastVerified` to "now". Demo-only —
  /// when the backend ships, swap for `POST /api/environments/{envId}/
  /// credentials/{kind}/verify` and persist the server-returned timestamp.
  void verifyCredential({
    required String envId,
    required DemoCredentialKind kind,
  }) {
    final existing = state.credentialFor(envId, kind);
    if (existing == null) return;
    final refreshed = DemoCredential(
      name: existing.name,
      label: existing.label,
      kind: existing.kind,
      source: existing.source,
      lastVerified: _nowLabel(),
      isMemorized: existing.isMemorized,
    );
    final next = {
      ...state.credentialsByEnvKind,
      envId: {
        ...?state.credentialsByEnvKind[envId],
        kind: refreshed,
      },
    };
    state = state.copyWith(credentialsByEnvKind: next);
  }

  void deleteCredential({
    required String envId,
    required DemoCredentialKind kind,
  }) {
    final perKind = {...?state.credentialsByEnvKind[envId]}..remove(kind);
    final next = {...state.credentialsByEnvKind, envId: perKind};
    state = state.copyWith(credentialsByEnvKind: next);
  }

  // ───── Helpers ───────────────────────────────────────────────────────

  static DemoEnvironment _copyEnv(
    DemoEnvironment e, {
    String? name,
    bool? isLive,
    bool? readOnly,
    bool? autoApprove,
  }) {
    return DemoEnvironment(
      id: e.id,
      projectId: e.projectId,
      name: name ?? e.name,
      isLive: isLive ?? e.isLive,
      readOnly: readOnly ?? e.readOnly,
      autoApprove: autoApprove ?? e.autoApprove,
      credentialNames: e.credentialNames,
    );
  }

  static String _generateId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$prefix-$ts';
  }

  /// ISO 8601 timestamp for the last successful verification — kept as a
  /// raw machine-readable string so the form can render it as relative
  /// time ("2 hours ago") via `AppStrings.relativeTime`.
  static String _nowLabel() => DateTime.now().toIso8601String();
}

final vaultControllerProvider =
    NotifierProvider<VaultController, VaultState>(VaultController.new);
