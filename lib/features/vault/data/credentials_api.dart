import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'credential_models.dart';

/// Result of `POST /api/v1/credentials/test/`. Returned by
/// [CredentialsApi.testConnection]; the UI maps `success` to a green
/// badge and `error` (non-null) to the red one.
class CredentialTestResult {
  const CredentialTestResult.success() : success = true, error = null;
  const CredentialTestResult.failure(String this.error) : success = false;

  final bool success;
  final String? error;
}

/// Repository for the per-user credential vault (SAQQAR_MOBILE_API.md §7).
///
/// The Add Credential UI must render against [getSchemas] — never hard-code
/// per-kind field lists. Memorizing a credential goes through a two-step
/// approval handshake; see [save] / [saveWithApproval].
class CredentialsApi {
  CredentialsApi(this._dio);

  final Dio _dio;

  // ── Schemas (form descriptor) ───────────────────────────────────────

  /// `GET /api/v1/credentials/schemas/` — one [CredentialSchema] per
  /// supported [CredentialKind]. Cache this on cold start.
  Future<List<CredentialSchema>> getSchemas() async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.credentialSchemas,
    );
    return (res.data!['schemas'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CredentialSchema.fromJson)
        .toList();
  }

  // ── Bundle list (no payloads) ───────────────────────────────────────

  /// `GET /api/v1/credentials/` — every bundle for the calling user.
  /// `payload` is omitted in this response; call [get] for the full row.
  Future<List<Credential>> list() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.credentials);
    return (res.data!['credentials'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Credential.fromJson)
        .toList();
  }

  /// `GET /api/v1/credentials/<name>/` — full bundle with decrypted
  /// payload. Use for the edit screen, never the list.
  Future<Credential> get(String name) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.credentialDetail(name),
    );
    return Credential.fromJson(
      res.data!['credential'] as Map<String, dynamic>,
    );
  }

  // ── Test connection (read-only validation) ──────────────────────────

  /// `POST /api/v1/credentials/test/` — opens a real connection to the
  /// target service to validate [payload] without storing it. Backs the
  /// editor's "Test connection" button. 200 → success; 400/500/502 →
  /// failure with the server's `error` message surfaced to the user.
  ///
  /// Generic across credential kinds — the server inspects `kind` and
  /// routes to the matching connector. See SAQQAR_MOBILE_API_xmlrpc.md
  /// §2 for the wire shape.
  Future<CredentialTestResult> testConnection({
    required CredentialKind kind,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.credentialTest,
        data: {'kind': kind.wire, 'payload': payload},
      );
      final body = res.data ?? const <String, dynamic>{};
      if (body['ok'] == true) return const CredentialTestResult.success();
      final err = body['error']?.toString() ?? 'Connection failed';
      return CredentialTestResult.failure(err);
    } on DioException catch (e) {
      // 400 / 500 / 502 land here via the error interceptor. Pull the
      // server's `error` text out of the response body when present so
      // the user sees a real reason (e.g. "AccessDenied: invalid
      // password") instead of a generic "Connection failed".
      final data = e.response?.data;
      String? err;
      if (data is Map) {
        final v = data['error'];
        if (v is String && v.isNotEmpty) err = v;
      }
      return CredentialTestResult.failure(err ?? e.message ?? 'Connection failed');
    } catch (e) {
      return CredentialTestResult.failure(e.toString());
    }
  }

  // ── Save / update / delete ──────────────────────────────────────────

  /// `POST /api/v1/credentials/` — create or update (idempotent by name).
  ///
  /// Returns a [CredentialSaveResult]:
  ///   - [CredentialSaved]: the bundle was persisted in one shot (either
  ///     `remember=false` session-only, or `remember=true` with an
  ///     `approvalId` from a prior handshake).
  ///   - [CredentialApprovalRequired]: the server returned 202 because
  ///     the user requested memorize without an approval. The caller now
  ///     POSTs `/approvals/<id>/decision/` with `{approved: true}` and
  ///     calls [save] again with `approvalId` set.
  ///
  /// The server validates `payload` by attempting a live connection
  /// before storing — wrong credentials fail at save time with 400.
  Future<CredentialSaveResult> save({
    required String name,
    required CredentialKind kind,
    required Map<String, dynamic> payload,
    String? label,
    bool remember = false,
    String? approvalId,
    Map<String, dynamic>? metadata,
    String? conversationId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'kind': kind.wire,
      'payload': payload,
      if (label != null) 'label': label,
      'remember': remember,
      if (approvalId != null) 'approval_id': approvalId,
      if (metadata != null) 'metadata': metadata,
      if (conversationId != null) 'conversation_id': conversationId,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.credentials,
      data: body,
    );
    final data = res.data!;
    if (res.statusCode == 202 || data['status'] == 'approval_required') {
      return CredentialApprovalRequired(
        CredentialApprovalRequest(
          approvalId: data['approval_id'] as String,
          prompt: data['prompt'] as String? ?? '',
        ),
      );
    }
    return CredentialSaved(
      Credential.fromJson(data['credential'] as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/credentials/<name>/` — mutate label, payload, metadata,
  /// or the memorize flag. `name` and `kind` are immutable.
  Future<Credential> update({
    required String name,
    String? label,
    Map<String, dynamic>? payload,
    bool? isMemorized,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label,
      if (payload != null) 'payload': payload,
      if (isMemorized != null) 'is_memorized': isMemorized,
      if (metadata != null) 'metadata': metadata,
    };
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.credentialDetail(name),
      data: body,
    );
    return Credential.fromJson(
      res.data!['credential'] as Map<String, dynamic>,
    );
  }

  /// `DELETE /api/v1/credentials/<name>/` — hard delete. Server clears
  /// any `active_credential` pointers on conversations that referenced
  /// this bundle and returns those conversation IDs in `cleared_active_in`.
  Future<({String deleted, List<String> clearedActiveIn})> delete(
    String name,
  ) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      ApiEndpoints.credentialDetail(name),
    );
    return (
      deleted: res.data!['deleted'] as String? ?? name,
      clearedActiveIn: (res.data!['cleared_active_in'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

