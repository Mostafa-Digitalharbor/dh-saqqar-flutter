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

  static const inbox = 'inbox';
  static const inboxPath = '/inbox';

  static const files = 'files';
  static const filesPath = '/files';

  static const account = 'account';
  static const accountPath = '/account';

  // Sub-routes.
  static const chat = 'chat';
  static String chatPath(String id) => '/chats/$id';

  static const credentialAdd = 'credential_add';
  static const credentialAddPath = '/vault/add';

  // Storybook (foundation-only, hidden behind a long-press in Account).
  static const storybook = 'storybook';
  static const storybookPath = '/_/storybook';
}
