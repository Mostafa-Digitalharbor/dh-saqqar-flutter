/// Route paths and names. Keep them in one place so deep links and tests
/// can reference them by name instead of repeating string literals.
class RouteNames {
  RouteNames._();

  // Auth.
  static const signIn = 'sign_in';
  static const signInPath = '/sign-in';

  static const signUp = 'sign_up';
  static const signUpPath = '/sign-up';

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
  static String sharedTranscriptPath(String token) => '/share/$token';

  // Storybook (foundation-only, hidden behind a long-press in Account).
  static const storybook = 'storybook';
  static const storybookPath = '/_/storybook';
}
