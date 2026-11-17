/// Route paths and names. Keep them in one place so deep links and tests
/// can reference them by name instead of repeating string literals.
class RouteNames {
  RouteNames._();

  // Auth.
  static const signIn = 'sign_in';
  static const signInPath = '/sign-in';

  static const signUp = 'sign_up';
  static const signUpPath = '/sign-up';

  // First-run welcome screen (shown once, before sign-in).
  static const welcome = 'welcome';
  static const welcomePath = '/welcome';

  // Redesigned tab roots.
  static const home = 'home';
  static const homePath = '/home';
  static const tasks = 'tasks';
  static const tasksPath = '/tasks';

  // First-run setup wizard (company name → connect Odoo environment).
  static const setupCompany = 'setup_company';
  static const setupCompanyPath = '/setup/company';
  static const setupEnvironment = 'setup_environment';
  static const setupEnvironmentPath = '/setup/environment';

  // Tab roots.
  static const chats = 'chats';
  static const chatsPath = '/chats';

  static const vault = 'vault';
  static const vaultPath = '/vault';

  static const account = 'account';
  static const accountPath = '/account';

  // Sub-routes.
  static const chat = 'chat';
  static String chatPath(String id) => '/chats/$id';

  static const credentialAdd = 'credential_add';
  static const credentialAddPath = '/vault/add';

  // Pricing / plans (Gap L). Opened from the quota-exceeded upgrade CTA.
  static const pricing = 'pricing';
  static const pricingPath = '/pricing';

  // Token usage detail — opened from the Account "Usage" button.
  static const usage = 'usage';
  static const usagePath = '/usage';

  // Support workspace (§8). Reachable ONLY from the chat tools sheet, and
  // only when `saqqar_features.voice_support` is on — there is deliberately
  // no entry point that ignores the flag.
  static const voiceSupport = 'voice-support';
  static const voiceSupportPath = '/voice-support';

  /// Optional `?env=<id>` on [voiceSupportPath] — which bound Odoo database a
  /// filed ticket is written to. Set by the chat that opened the screen;
  /// absent, the server falls back to the account's first environment.
  static const voiceSupportEnvQuery = 'env';

  // In-app notifications inbox — opened from the header bell.
  static const notifications = 'notifications';
  static const notificationsPath = '/notifications';

  // Registered push devices — opened from Account.
  static const devices = 'devices';
  static const devicesPath = '/devices';

  // Saqqar Apps gallery (API_MOBILE_NEW_ENDPOINTS.md §1) — opened from Account.
  static const apps = 'apps';
  static const appsPath = '/apps';
  static const workspaceApps = 'workspace_apps';
  static const workspaceAppsPath = '/workspace-apps';

  // Managed Odoo trial (§2) — opened from Account.
  static const trial = 'trial';
  static const trialPath = '/trial';

  // Billing history & receipts (§3) — opened from Account.
  static const billingHistory = 'billing_history';
  static const billingHistoryPath = '/billing/history';

  // Meetings transcription (§4.1) — opened from Account.
  static const meetings = 'meetings';
  static const meetingsPath = '/meetings';

  // Read-only Odoo data explorer (§4.2) — opened from Account.
  static const dataExplorer = 'data_explorer';
  static const dataExplorerPath = '/data-explorer';

  // Billing checkout (§4.3) — unreachable while sales are web-only; the route
  // is registered but redirects (gated behind showPaidUpsell).
  static const checkout = 'checkout';
  static const checkoutPath = '/billing/checkout';

  // Approval deep links now resolve into the chat that raised them, because
  // approvals live per-conversation (Inbox tab was retired). Format:
  //   /chats/<conversationId>?approval=<approvalId>
  // and the chat screen pops its own approvals sheet when the query is set.
  static const approvalDetail = 'approval_detail';
  static String approvalDetailPath({
    required String conversationId,
    required String approvalId,
  }) => '/chats/$conversationId?approval=$approvalId';

  // Public read-only transcript view (from saqqar://share/<token>).
  static const sharedTranscript = 'shared_transcript';

  /// Prefix shared by [sharedTranscriptPath] and the GoRoute pattern, and
  /// used by the auth gate to recognise the one unauthenticated route in
  /// the app. All three had their own `'/share/'` literal; a rename that
  /// missed the gate would have quietly required a login to open a link
  /// that is public by design.
  static const sharedTranscriptPrefix = '/share/';
  static const sharedTranscriptPattern = '$sharedTranscriptPrefix:token';
  static String sharedTranscriptPath(String token) =>
      '$sharedTranscriptPrefix$token';

  // Storybook (foundation-only, hidden behind a long-press in Account).
  static const storybook = 'storybook';
  static const storybookPath = '/_/storybook';
}
