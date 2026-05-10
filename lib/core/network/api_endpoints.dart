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
  static String conversationShare(String id) => '/api/conversations/$id/share/';

  // Credentials.
  static const String credentials = '/api/credentials/';
  static const String credentialSchemas = '/api/credentials/schemas/';

  // Approvals.
  static String approvalDecision(String id) => '/api/approvals/$id/decision/';

  // i18n.
  static String i18n(String lang) => '/api/i18n/$lang.json';

  // Devices (push registration).
  static const String registerDevice = '/api/devices/register/';
  static const String unregisterDevice = '/api/devices/unregister/';
}
