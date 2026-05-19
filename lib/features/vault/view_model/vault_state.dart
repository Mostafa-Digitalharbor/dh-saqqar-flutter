import 'package:equatable/equatable.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/state/data_state.dart';
import '../data/credential_models.dart';
import '../data/project_models.dart';

/// The data the Vault screens render against. Lives inside a
/// `DataState<VaultData>` on [VaultState] so loading / error / success
/// branching is uniform with every other API-backed feature.
class VaultData extends Equatable {
  const VaultData({
    required this.projects,
    required this.schemas,
    this.credentialsByEnv = const {},
  });

  /// Every project the calling user has access to (server returns envs
  /// nested inside each project — no separate fetch needed).
  final List<Project> projects;

  /// Schema for every supported [CredentialKind]. Loaded once with the
  /// project list; passed straight to the credential form so it renders
  /// the right inputs per kind without hard-coding fields.
  final List<CredentialSchema> schemas;

  /// `envId → credentials` lazy cache populated when the user opens an
  /// environment detail sheet (the list-projects endpoint doesn't
  /// include credentials — they require a separate per-env fetch).
  ///
  /// Missing key = "not yet loaded"; empty list = "loaded, none configured".
  final Map<String, List<Credential>> credentialsByEnv;

  /// Flat env list across all projects — convenient for the legacy chat
  /// header that needs to resolve an env id without the project context.
  List<Environment> get allEnvironments => [
        for (final p in projects) ...p.environments,
      ];

  List<Environment> environmentsForProject(String projectId) {
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    return project?.environments ?? const [];
  }

  Project? projectById(String id) =>
      projects.where((p) => p.id == id).firstOrNull;

  Environment? environmentById(String id) {
    for (final p in projects) {
      for (final e in p.environments) {
        if (e.id == id) return e;
      }
    }
    return null;
  }

  Credential? credentialFor(String envId, CredentialKind kind) {
    final list = credentialsByEnv[envId];
    if (list == null) return null;
    return list.where((c) => c.kind == kind).firstOrNull;
  }

  CredentialSchema? schemaFor(CredentialKind kind) =>
      schemas.where((s) => s.kind == kind).firstOrNull;

  VaultData copyWith({
    List<Project>? projects,
    List<CredentialSchema>? schemas,
    Map<String, List<Credential>>? credentialsByEnv,
  }) {
    return VaultData(
      projects: projects ?? this.projects,
      schemas: schemas ?? this.schemas,
      credentialsByEnv: credentialsByEnv ?? this.credentialsByEnv,
    );
  }

  @override
  List<Object?> get props => [projects, schemas, credentialsByEnv];
}

/// Identifies which mutation a failure belongs to, so the view can
/// prefix the localized error message with a meaningful action label
/// ("Couldn't save the credential · Check your connection.").
enum VaultAction {
  load,
  createProject,
  renameProject,
  deleteProject,
  createEnvironment,
  updateEnvironment,
  deleteEnvironment,
  loadCredentials,
  saveCredential,
  deleteCredential,
}

/// One-shot success toast identifiers. Kept as an enum (not a raw string)
/// so the view picks the localized message at render time and the cubit
/// stays free of i18n imports.
enum VaultToast {
  projectCreated,
  projectDeleted,
  environmentCreated,
  environmentDeleted,
  credentialSaved,
  credentialDeleted,
}

/// Pairs a typed failure with the action that produced it. The view
/// renders the action label as a prefix to the error message.
class VaultActionFailure extends Equatable {
  const VaultActionFailure({required this.action, required this.failure});

  final VaultAction action;
  final AppFailure failure;

  @override
  List<Object?> get props => [action, failure];
}

/// Top-level state emitted by [VaultCubit].
///
/// [data]            — page-level data + async lifecycle (render with `DataStateView`).
/// [actionInFlight]  — disable submit buttons while a mutation is running.
/// [actionFailure]   — typed one-shot mutation failure; view's `BlocListener`
///                     renders a localized toast then calls
///                     [VaultCubit.consumeActionFailure] to clear it.
/// [actionToast]     — typed one-shot success toast; same consume contract.
class VaultState extends Equatable {
  const VaultState({
    this.data = const DataIdle<VaultData>(),
    this.actionInFlight = false,
    this.actionFailure,
    this.actionToast,
  });

  final DataState<VaultData> data;
  final bool actionInFlight;
  final VaultActionFailure? actionFailure;
  final VaultToast? actionToast;

  VaultState copyWith({
    DataState<VaultData>? data,
    bool? actionInFlight,
    VaultActionFailure? actionFailure,
    VaultToast? actionToast,
    bool clearActionFailure = false,
    bool clearActionToast = false,
  }) {
    return VaultState(
      data: data ?? this.data,
      actionInFlight: actionInFlight ?? this.actionInFlight,
      actionFailure:
          clearActionFailure ? null : (actionFailure ?? this.actionFailure),
      actionToast:
          clearActionToast ? null : (actionToast ?? this.actionToast),
    );
  }

  @override
  List<Object?> get props => [data, actionInFlight, actionFailure, actionToast];
}
