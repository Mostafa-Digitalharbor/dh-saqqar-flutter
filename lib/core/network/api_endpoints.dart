/// Static URLs / paths the mobile client talks to.
///
/// `baseUrl` is read from `--dart-define=SAQQAR_BASE_URL=...` at build time
/// (see `tool/run_dev.ps1` — defaults to production saqqaar.com if unset).
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'SAQQAR_BASE_URL',
    defaultValue: 'https://saqqaar.com',
  );

  // Auth (token endpoints — backend must add per BACKEND_REQUEST).
  static const String login = '/api/auth/login/';
  static const String register = '/api/auth/register/';
  static const String refresh = '/api/auth/refresh/';
  static const String logout = '/api/auth/logout/';
  static const String me = '/api/auth/me/';
  static const String changePassword = '/api/auth/password/change/';

  // Conversations.
  static const String conversations = '/api/conversations/';
  static String conversationDetail(String id) => '/api/conversations/$id/';
  static String conversationMessages(String id) =>
      '/api/conversations/$id/messages/';
  static String conversationAttachments(String id) =>
      '/api/conversations/$id/attachments/';
  static String conversationCredentialsToggle(String id) =>
      '/api/conversations/$id/credentials/toggle/';
  static String conversationDismiss(String id) =>
      '/api/conversations/$id/pending-actions/dismiss/';

  /// Cancels a running agent for the conversation. Body: empty.
  /// 204 on success, 409 {agent_not_running} if there's nothing to stop.
  static String conversationStop(String id) => '/api/conversations/$id/stop/';

  static String conversationShare(String id) => '/api/conversations/$id/share/';

  // Credentials.
  static const String credentials = '/api/credentials/';
  static const String credentialSchemas = '/api/credentials/schemas/';

  // Projects & Environments hierarchy (per credential vault deep-dive
  // against the production saqqaar.com JS). Backend needs to expose:
  static const String projects = '/api/projects/';
  static String projectDetail(String id) => '/api/projects/$id/';
  static String projectEnvironments(String projectId) =>
      '/api/projects/$projectId/environments/';
  static String environmentDetail(String id) => '/api/environments/$id/';

  /// Per-environment, per-kind credential — `kind` is one of
  /// `xmlrpc | postgres | server_shell | github`. PUT to save, DELETE to
  /// remove. Matches the web's:
  /// `PUT /api/environments/{id}/credentials/{kind}/`
  static String environmentCredential(String environmentId, String kind) =>
      '/api/environments/$environmentId/credentials/$kind/';

  /// Mutate / delete a saved credential bundle. `name` is the user-chosen
  /// slug (e.g. "icg-staging"), not a UUID.
  static String credentialDetail(String name) => '/api/credentials/$name/';

  // Approvals.
  /// Inbox feed. `?status=pending` is the primary call; response includes
  /// `pending_count` for the bottom-nav badge.
  static const String approvals = '/api/approvals/';
  static String approvalDecision(String id) => '/api/approvals/$id/decision/';

  // Artifacts (files).
  /// `?kind=<KIND>&conversation=<id>&limit=…&cursor=…` — all filters optional.
  static const String artifacts = '/api/artifacts/';
  static String artifactDownload(String id) =>
      '/api/artifacts/$id/download/';

  // i18n.
  static String i18n(String lang) => '/api/i18n/$lang.json';

  // Devices (push registration — reserved for v2).
  static const String registerDevice = '/api/devices/register/';
  static const String unregisterDevice = '/api/devices/unregister/';
}
