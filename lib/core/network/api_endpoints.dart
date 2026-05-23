/// Static URLs / paths the mobile client talks to.
///
/// `baseUrl` is read from `--dart-define=SAQQAR_BASE_URL=...` at build time
/// (see `tool/run_dev.ps1` — defaults to production saqqaar.com if unset).
///
/// All paths are pinned to `/api/v1/` per SAQQAR_MOBILE_API.md §0
/// (Versioning). `/api/` still works (back-compat) but `/api/v2/` will be
/// the first to break the v1 contract, so pinning protects us.
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'SAQQAR_BASE_URL',
    defaultValue: 'https://saqqaar.com',
  );

  // ── Auth (§1) ─────────────────────────────────────────────────────────
  static const String login = '/api/v1/auth/login/';
  static const String register = '/api/v1/auth/register/';
  static const String logout = '/api/v1/auth/logout/';
  static const String me = '/api/v1/auth/me/';

  /// Rotates the password and returns a fresh bearer token. Every other
  /// device's token is revoked server-side.
  static const String changePassword = '/api/v1/auth/password/';

  // ── Conversations (§2) ────────────────────────────────────────────────
  static const String conversations = '/api/v1/conversations/';
  static String conversationDetail(String id) =>
      '/api/v1/conversations/$id/';
  static String conversationMessages(String id) =>
      '/api/v1/conversations/$id/messages/';
  static String conversationAttachments(String id) =>
      '/api/v1/conversations/$id/attachments/';
  static String conversationAttachmentStatus(
    String conversationId,
    String attachmentId,
  ) =>
      '/api/v1/conversations/$conversationId/attachments/$attachmentId/status/';

  static String conversationCredentialsActive(String id) =>
      '/api/v1/conversations/$id/credentials/active/';
  static String conversationCredentialsToggle(String id) =>
      '/api/v1/conversations/$id/credentials/toggle/';
  static String conversationDismiss(String id) =>
      '/api/v1/conversations/$id/pending-actions/dismiss/';

  /// Cooperative cancel — sets `stop_requested=true`; the agent worker
  /// exits cleanly between tool rounds. Idempotent.
  static String conversationStop(String id) =>
      '/api/v1/conversations/$id/stop/';

  static String conversationShare(String id) =>
      '/api/v1/conversations/$id/share/';

  // ── Credentials (§7) ─────────────────────────────────────────────────
  static const String credentials = '/api/v1/credentials/';
  static const String credentialSchemas = '/api/v1/credentials/schemas/';
  static String credentialDetail(String name) =>
      '/api/v1/credentials/$name/';

  // ── Projects & Environments (§11) ────────────────────────────────────
  static const String projects = '/api/v1/projects/';
  static String projectDetail(String id) => '/api/v1/projects/$id/';
  static String projectEnvironments(String projectId) =>
      '/api/v1/projects/$projectId/environments/';
  static String environmentDetail(String id) =>
      '/api/v1/environments/$id/';
  static String environmentCredentials(String environmentId) =>
      '/api/v1/environments/$environmentId/credentials/';
  static String environmentCredential(String environmentId, String kind) =>
      '/api/v1/environments/$environmentId/credentials/$kind/';

  // ── Approvals (§8) ───────────────────────────────────────────────────
  /// Flat feed for the Inbox tab. `?status=pending` is the primary call;
  /// response includes `pending_count` for the bottom-nav badge.
  static const String approvals = '/api/v1/approvals/';
  static String approvalDecision(String id) =>
      '/api/v1/approvals/$id/decision/';

  // ── Artifacts (§9) ───────────────────────────────────────────────────
  static const String artifacts = '/api/v1/artifacts/';

  // ── Shares (§10) — public, no bearer ─────────────────────────────────
  static String shareTranscript(String token) => '/api/v1/shares/$token/';

  // ── i18n (§13) — public, no bearer ───────────────────────────────────
  static String i18n(String lang) => '/api/v1/i18n/$lang.json';

  // ── Voice transcription (SAQQAR_MOBILE_VOICE.md §2) ─────────────────
  // Multipart upload: field `audio` (m4a recommended, ≤25 MB, ≤120 s),
  // optional `language` ("ar"/"en"/""). Server proxies to OpenAI
  // Whisper and returns `{ ok: true, text: "..." }`.
  static const String transcribe = '/api/v1/transcribe/';

  // ── Devices / push (§12) ─────────────────────────────────────────────
  static const String devices = '/api/v1/devices/';
  static String deviceDetail(String id) => '/api/v1/devices/$id/';
}
