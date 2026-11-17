import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'credential_models.dart';
import 'project_models.dart';

/// Repository for the Projects + Environments + Env-Credentials hierarchy
/// (SAQQAR_MOBILE_API.md §11).
///
/// Slugs are auto-derived from `name` on create; conflicts get `-2`, `-3`
/// suffixes. The caller passes only the human name.
class ProjectsApi {
  ProjectsApi(this._dio);

  final Dio _dio;

  // ── Projects ────────────────────────────────────────────────────────

  /// `GET /api/v1/projects/` — every project for the calling user, each
  /// with its nested environments.
  Future<List<Project>> list() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.projects);
    return (res.data!['projects'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Project.fromJson)
        .toList();
  }

  /// `POST /api/v1/projects/default/` (Gap H) — ensures the caller has a
  /// default project + production environment, then returns that environment.
  /// The env carries a `has_credential` flag (mapped onto
  /// [Environment.hasXmlrpc]) so the caller can prompt for credentials when
  /// the new env can't connect to Odoo yet. Idempotent — safe to call on
  /// every "Use My Database" tap.
  Future<Environment> defaultProject() async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.projectsDefault,
    );
    return Environment.fromJson(
      res.data!['environment'] as Map<String, dynamic>,
    );
  }

  /// `POST /api/v1/projects/` — creates a project. Slug derived server-side.
  Future<Project> create({required String name}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.projects,
      data: {'name': name},
    );
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  /// `GET /api/v1/projects/<id>/` — one project + its envs.
  Future<Project> get(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.projectDetail(id),
    );
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  /// `PATCH /api/v1/projects/<id>/` — rename only (slug is immutable).
  Future<Project> rename({required String id, required String name}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.projectDetail(id),
      data: {'name': name},
    );
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  /// `DELETE /api/v1/projects/<id>/` — cascades to envs + their credentials.
  Future<void> delete(String id) async {
    await _dio.delete<void>(ApiEndpoints.projectDetail(id));
  }

  // ── Environments ────────────────────────────────────────────────────

  /// `POST /api/v1/projects/<projectId>/environments/`
  Future<Environment> createEnvironment({
    required String projectId,
    required String name,
    bool isLive = false,
    bool readOnly = false,
    bool autoApprove = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.projectEnvironments(projectId),
      data: {
        'name': name,
        'is_live': isLive,
        'read_only': readOnly,
        'auto_approve': autoApprove,
      },
    );
    return Environment.fromJson(
      res.data!['environment'] as Map<String, dynamic>,
    );
  }

  /// `GET /api/v1/environments/<id>/`
  Future<Environment> getEnvironment(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.environmentDetail(id),
    );
    return Environment.fromJson(
      res.data!['environment'] as Map<String, dynamic>,
    );
  }

  /// `PATCH /api/v1/environments/<id>/` — any subset of name/flags.
  Future<Environment> updateEnvironment({
    required String id,
    String? name,
    bool? isLive,
    bool? readOnly,
    bool? autoApprove,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (isLive != null) 'is_live': isLive,
      if (readOnly != null) 'read_only': readOnly,
      if (autoApprove != null) 'auto_approve': autoApprove,
    };
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.environmentDetail(id),
      data: body,
    );
    return Environment.fromJson(
      res.data!['environment'] as Map<String, dynamic>,
    );
  }

  /// `DELETE /api/v1/environments/<id>/` — cascades to its credentials.
  Future<void> deleteEnvironment(String id) async {
    await _dio.delete<void>(ApiEndpoints.environmentDetail(id));
  }

  // ── Per-environment credentials (kind-keyed) ────────────────────────

  /// `GET /api/v1/environments/<id>/credentials/` — list, metadata only.
  Future<List<Credential>> listEnvironmentCredentials(
    String environmentId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.environmentCredentials(environmentId),
    );
    return (res.data!['credentials'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Credential.fromJson)
        .toList();
  }

  /// `GET /api/v1/environments/<id>/credentials/<kind>/` — includes the
  /// decrypted payload, for the edit screen.
  Future<Credential> getEnvironmentCredential({
    required String environmentId,
    required CredentialKind kind,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.environmentCredential(environmentId, kind.wire),
    );
    return Credential.fromJson(res.data!['credential'] as Map<String, dynamic>);
  }

  /// `PUT /api/v1/environments/<id>/credentials/<kind>/` — upsert. Server
  /// validates via a live connection before storing, so wrong creds fail
  /// at save time (not at first use).
  Future<Credential> upsertEnvironmentCredential({
    required String environmentId,
    required CredentialKind kind,
    required Map<String, dynamic> payload,
    String? label,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      'payload': payload,
      if (label != null) 'label': label,
      if (metadata != null) 'metadata': metadata,
    };
    final res = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.environmentCredential(environmentId, kind.wire),
      data: body,
    );
    return Credential.fromJson(res.data!['credential'] as Map<String, dynamic>);
  }

  /// `DELETE /api/v1/environments/<id>/credentials/<kind>/`
  Future<void> deleteEnvironmentCredential({
    required String environmentId,
    required CredentialKind kind,
  }) async {
    await _dio.delete<void>(
      ApiEndpoints.environmentCredential(environmentId, kind.wire),
    );
  }
}
