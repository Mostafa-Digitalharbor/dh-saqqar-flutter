import 'package:flutter/material.dart';

import '../constants/ui_strings.dart';

/// Single source for user-facing copy.
///
/// Keep technical constants in [UiStrings]. Any text shown in the UI should
/// live here so English and Arabic stay in sync.
class AppStrings {
  AppStrings(this.locale);
  final Locale locale;

  static const supported = [
    Locale(UiStrings.localeEnglishCode),
    Locale(UiStrings.localeArabicCode),
  ];

  bool get _isArabic => locale.languageCode == UiStrings.localeArabicCode;

  Map<String, String> get _table => _isArabic ? _ar : _en;

  String _t(String key) => _table[key] ?? _en[key] ?? key;

  // App
  String get appName => _t('app_name');
  String get productInitial => _t('product_initial');
  String get appTagline => _t('app_tagline');
  String get productionDomain => _t('production_domain');
  String get digitalHarbor => _t('digital_harbor');
  String get poweredByDigitalHarbor => _t('powered_by_digital_harbor');

  // Auth
  String get welcomeBack => _t('welcome_back');
  String get signInSubtitle => _t('sign_in_subtitle');
  String get username => _t('username');
  String get usernameHint => _t('username_hint');
  String get password => _t('password');
  String get authPasswordHint => _t('auth_password_hint');
  String get email => _t('email');
  String get signIn => _t('sign_in');
  String get signOut => _t('sign_out');
  String get newToSaqqar => _t('new_to_saqqar');
  String get createAccount => _t('create_account');
  String get createAccountUnavailable => _t('create_account_unavailable');
  String get authBrandTitle => _t('auth_brand_title');
  String get authBrandBody => _t('auth_brand_body');
  String get openWorkspace => _t('open_workspace');

  // Tabs
  String get tabChats => _t('tab_chats');
  String get tabVault => _t('tab_vault');
  String get tabInbox => _t('tab_inbox');
  String get tabFiles => _t('tab_files');
  String get tabAccount => _t('tab_account');

  // Shared labels
  String get workspace => _t('workspace');
  String get workspaceCoverage => _t('workspace_coverage');
  String get preferences => _t('preferences');
  String get theme => _t('theme');
  String get themeDark => _t('theme_dark');
  String get themeLight => _t('theme_light');
  String get themeSystem => _t('theme_system');
  String get language => _t('language');
  String get english => _t('english');
  String get arabic => _t('arabic');
  String get system => _t('system');
  String get live => _t('live');
  String get latest => _t('latest');
  String get all => _t('all');
  String get archived => _t('archived');
  String get memorized => _t('memorized');
  String get session => _t('session');
  String get notVerified => _t('not_verified');
  String get approvalPending => _t('approval_pending');
  String get manual => _t('manual');
  String get auto => _t('auto');
  String get failed => _t('failed');
  String get placeholder => _t('placeholder');
  String get now => _t('now');
  String get page => _t('page');
  String get of => _t('of');
  String get add => _t('add');
  String get attach => _t('attach');
  String get search => _t('search');
  String get refresh => _t('refresh');
  String get download => _t('download');
  String get more => _t('more');
  String get shareLink => _t('share_link');
  String get rename => _t('rename');
  String get archive => _t('archive');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get dismiss => _t('dismiss');
  String get open => _t('open');
  String get approve => _t('approve');
  String get reject => _t('reject');
  String get approved => _t('approved');
  String get rejected => _t('rejected');
  String get history => _t('history');
  String get pending => _t('pending');
  String get risk => _t('risk');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get share => _t('share');
  String get retry => _t('retry');
  String get label => _t('label');
  String get kind => _t('kind');
  String get credential => _t('credential');
  String get credentials => _t('credentials');
  String get conversations => _t('conversations');
  String get artifactsLower => _t('artifacts_lower');
  String get requests => _t('requests');
  String get downloadsLower => _t('downloads_lower');

  // Product badges
  String get smartDiagnosis => _t('smart_diagnosis');
  String get liveTools => _t('live_tools');
  String get approvalGated => _t('approval_gated');
  String get perUserVault => _t('per_user_vault');
  String get liveSystemsOnly => _t('live_systems_only');
  String get perUserEncryptedVault => _t('per_user_encrypted_vault');
  String get downloads => _t('downloads');
  String get reviewQueue => _t('review_queue');
  String get agentRequests => _t('agent_requests');
  String get review => _t('review');

  // Actions, tooltips, toasts
  String get refreshConversations => _t('refresh_conversations');
  String get refreshCredentials => _t('refresh_credentials');
  String get searchConversations => _t('search_conversations');
  String get searchArtifacts => _t('search_artifacts');
  String get clearSearch => _t('clear_search');
  String get previousPage => _t('previous_page');
  String get nextPage => _t('next_page');
  String get conversationActions => _t('conversation_actions');
  String get credentialActions => _t('credential_actions');
  String get attachFiles => _t('attach_files');
  String get showPassword => _t('show_password');
  String get hidePassword => _t('hide_password');
  String get activeCredentialUpdated => _t('active_credential_updated');
  String get publicLinkCopied => _t('public_link_copied');
  String get conversationsRefreshed => _t('conversations_refreshed');
  String get credentialsRefreshed => _t('credentials_refreshed');
  String get credentialUpdated => _t('credential_updated');
  String get credentialSavedApproval => _t('credential_saved_approval');
  String get actionDismissed => _t('action_dismissed');
  String get archivedToast => _t('archived_toast');
  String get approvalRejected => _t('approval_rejected');
  String get approvalGrantedExecuting => _t('approval_granted_executing');
  String get autoApproveOn => _t('auto_approve_on');
  String get autoApproveOff => _t('auto_approve_off');
  String get renameConversation => _t('rename_conversation');
  String get deleteNeedsConfirmation => _t('delete_needs_confirmation');
  String get attachedFilesForReview => _t('attached_files_for_review');
  String get defaultApiError => _t('default_api_error');
  String get primaryTapped => _t('primary_tapped');
  String get ghostTapped => _t('ghost_tapped');
  String get dangerTapped => _t('danger_tapped');
  String get toggleTheme => _t('toggle_theme');
  String get toggleLanguage => _t('toggle_language');

  // Screen copy
  String get workspaceSummaryTitle => _t('workspace_summary_title');
  String get workspaceSummaryBody => _t('workspace_summary_body');
  String get vaultSummaryBody => _t('vault_summary_body');
  String get filesSummaryBody => _t('files_summary_body');
  String get actionCenterSummaryBody => _t('action_center_summary_body');
  String get liveAccessNote => _t('live_access_note');
  String get autoApproveSubtitle => _t('auto_approve_subtitle');
  String get composerHint => _t('composer_hint');
  String get composerAssist => _t('composer_assist');
  String get credentialSheetBody => _t('credential_sheet_body');
  String get noExportsTitle => _t('no_exports_title');
  String get noExportsBody => _t('no_exports_body');
  String get noAgentActionsTitle => _t('no_agent_actions_title');
  String get noAgentActionsBody => _t('no_agent_actions_body');
  String get noPendingApprovalsTitle => _t('no_pending_approvals_title');
  String get noPendingApprovalsBody => _t('no_pending_approvals_body');
  String get offlineBanner => _t('offline_banner');

  // Chat / vault / inbox
  String get newConversation => _t('new_conversation');
  String get noConversations => _t('no_conversations');
  String get noConversationsHint => _t('no_conversations_hint');
  String get startConversation => _t('start_conversation');
  String get send => _t('send');
  String get autoApprove => _t('auto_approve');
  String get credentialVault => _t('credential_vault');
  String get noCredentials => _t('no_credentials');
  String get noCredentialsHint => _t('no_credentials_hint');
  String get addCredential => _t('add_credential');
  String get editCredential => _t('edit_credential');
  String get saveCredential => _t('save_credential');
  String get updateCredential => _t('update_credential');
  String get bundleName => _t('bundle_name');
  String get memorizeCredential => _t('memorize_credential');
  String get actionCenter => _t('action_center');
  String get pendingApprovals => _t('pending_approvals');
  String get approvals => _t('approvals');
  String get artifacts => _t('artifacts');
  String get activeCredential => _t('active_credential');
  String get credentialNone => _t('credential_none');
  String get credentialNoneHint => _t('credential_none_hint');
  String get copiedToClipboard => _t('copied_to_clipboard');
  String get roleYou => _t('role_you');
  String get roleAssistant => _t('role_assistant');
  String get roleTool => _t('role_tool');
  String get roleSystem => _t('role_system');

  // Account coverage
  String get standardUser => _t('standard_user');
  String get openStorybook => _t('open_storybook');
  String get conversationsCoverageTitle => _t('conversations_coverage_title');
  String get conversationsCoverageBody => _t('conversations_coverage_body');
  String get vaultCoverageTitle => _t('vault_coverage_title');
  String get vaultCoverageBody => _t('vault_coverage_body');
  String get approvalsCoverageTitle => _t('approvals_coverage_title');
  String get approvalsCoverageBody => _t('approvals_coverage_body');
  String get artifactsCoverageTitle => _t('artifacts_coverage_title');
  String get artifactsCoverageBody => _t('artifacts_coverage_body');

  // Storybook
  String get storybook => _t('storybook');
  String get storybookEyebrowMiniChip => _t('storybook_eyebrow_mini_chip');
  String get storybookEyebrowLabel => _t('storybook_eyebrow_label');
  String get storybookStatusPills => _t('storybook_status_pills');
  String get storybookButtons => _t('storybook_buttons');
  String get storybookInputs => _t('storybook_inputs');
  String get storybookSwitches => _t('storybook_switches');
  String get storybookAvatars => _t('storybook_avatars');
  String get storybookGlassCard => _t('storybook_glass_card');
  String get storybookEmptyState => _t('storybook_empty_state');
  String get sampleUsername => _t('sample_username');
  String get sampleUserSarah => _t('sample_user_sarah');
  String get sampleUserArabic => _t('sample_user_arabic');
  String get samplePasswordHint => _t('sample_password_hint');
  String get fieldRulesHint => _t('field_rules_hint');
  String get withError => _t('with_error');
  String get tryAgain => _t('try_again');
  String get invalidValue => _t('invalid_value');
  String get conversationTitle => _t('conversation_title');

  // Formatters
  String routeNotFound(Uri uri) => '${_t('route_not_found')}: $uri';

  String itemCount(int visible, int total, String label) =>
      _isArabic ? '$visible من $total $label' : '$visible of $total $label';

  String pageCount(int pageNumber, int totalPages) => _isArabic
      ? '${_t('page')} $pageNumber ${_t('of')} $totalPages'
      : '${_t('page')} $pageNumber ${_t('of')} $totalPages';

  String pendingCount(int count) => '$count ${_t('pending')}';
  String openCount(int count) => '$count ${_t('open_count_suffix')}';
  String requestsCount(int count) => '$count ${_t('requests')}';
  String downloadsCount(int count) => '$count ${_t('downloads_lower')}';
  String messageCount(int count) => '$count ${_t('messages')}';
  String keyValue(String key, Object? value) => '$key: $value';
  String riskValue(String value) => '${_t('risk')}: $value';
  String verified(String value) => '${_t('verified')} $value';
  String credentialSubtitle(String name, String kindLabel) =>
      '$name - $kindLabel';
  String opening(String title) => '${_t('opening')} $title.';
  String downloading(String title) => '${_t('downloading')} $title.';
  String actionOnConversation(String action, String title) => '$action: $title';
  String artifactMeta(String kind, String size, String createdLabel) =>
      '$kind - $size - $createdLabel';
  String assistantPlan(String credential) =>
      '${_t('assistant_plan_prefix')} $credential. ${_t('assistant_plan_suffix')}';
}

const Map<String, String> _en = {
  'app_name': 'Saqqar',
  'product_initial': 'S',
  'app_tagline': 'Odoo Operations Copilot',
  'production_domain': 'saqqaar.com',
  'digital_harbor': 'Digital Harbor',
  'powered_by_digital_harbor': 'Powered by Digital Harbor',
  'welcome_back': 'Welcome back',
  'sign_in_subtitle': 'Sign in to continue to your workspace.',
  'username': 'Username',
  'username_hint': 'username',
  'password': 'Password',
  'auth_password_hint': 'Enter your password',
  'email': 'Email',
  'sign_in': 'Sign in',
  'sign_out': 'Sign out',
  'new_to_saqqar': 'New to Saqqar?',
  'create_account': 'Create an account',
  'create_account_unavailable': 'Registration is available on saqqaar.com.',
  'auth_brand_title': 'Saqqar Operations\nCopilot',
  'auth_brand_body':
      'Live Odoo agent that diagnoses, reports, and acts with private credentials and approval gating on every risky change.',
  'open_workspace': 'Open workspace',
  'tab_chats': 'Chats',
  'tab_vault': 'Vault',
  'tab_inbox': 'Inbox',
  'tab_files': 'Files',
  'tab_account': 'Account',
  'workspace': 'Workspace',
  'workspace_coverage': 'Workspace coverage',
  'preferences': 'Preferences',
  'theme': 'Theme',
  'theme_dark': 'Dark',
  'theme_light': 'Light',
  'theme_system': 'System',
  'language': 'Language',
  'english': 'English',
  'arabic': 'Arabic',
  'system': 'System',
  'live': 'Live',
  'latest': 'Latest',
  'all': 'All',
  'archived': 'Archived',
  'memorized': 'memorized',
  'session': 'session',
  'not_verified': 'Not verified',
  'approval_pending': 'approval pending',
  'manual': 'Manual',
  'auto': 'Auto',
  'failed': 'Failed',
  'placeholder': 'Placeholder',
  'now': 'Now',
  'page': 'Page',
  'of': 'of',
  'add': 'Add',
  'attach': 'Attach',
  'search': 'Search',
  'refresh': 'Refresh',
  'download': 'Download',
  'more': 'More',
  'share_link': 'Share link',
  'rename': 'Rename',
  'archive': 'Archive',
  'delete': 'Delete',
  'edit': 'Edit',
  'dismiss': 'Dismiss',
  'open': 'Open',
  'approve': 'Approve',
  'reject': 'Reject',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'history': 'History',
  'pending': 'pending',
  'risk': 'Risk',
  'cancel': 'Cancel',
  'save': 'Save',
  'share': 'Share',
  'retry': 'Retry',
  'label': 'Label',
  'kind': 'Kind',
  'credential': 'Credential',
  'credentials': 'credentials',
  'conversations': 'conversations',
  'artifacts_lower': 'artifacts',
  'requests': 'requests',
  'downloads_lower': 'downloads',
  'smart_diagnosis': 'Smart diagnosis',
  'live_tools': 'Live tools',
  'approval_gated': 'Approval gated',
  'per_user_vault': 'Per-user vault',
  'live_systems_only': 'Live systems only',
  'per_user_encrypted_vault': 'Per-user encrypted vault',
  'downloads': 'Downloads',
  'review_queue': 'Review queue',
  'agent_requests': 'Agent requests',
  'review': 'Review',
  'refresh_conversations': 'Refresh conversations',
  'refresh_credentials': 'Refresh credentials',
  'search_conversations': 'Search conversations',
  'search_artifacts': 'Search artifacts',
  'clear_search': 'Clear search',
  'previous_page': 'Previous page',
  'next_page': 'Next page',
  'conversation_actions': 'Conversation actions',
  'credential_actions': 'Credential actions',
  'attach_files': 'Attach screenshots, PDFs, or spreadsheets',
  'show_password': 'Show password',
  'hide_password': 'Hide password',
  'active_credential_updated': 'Active credential updated.',
  'public_link_copied': 'Public link copied.',
  'conversations_refreshed': 'Conversations refreshed.',
  'credentials_refreshed': 'Credentials refreshed.',
  'credential_updated': 'Credential updated.',
  'credential_saved_approval':
      'Credential saved. Approval required before memorizing.',
  'action_dismissed': 'Action dismissed.',
  'archived_toast': 'Archived.',
  'approval_rejected': 'Approval rejected.',
  'approval_granted_executing': 'Approval granted. Executing approved action.',
  'auto_approve_on': 'Auto-approve on.',
  'auto_approve_off': 'Auto-approve off.',
  'rename_conversation': 'Rename conversation',
  'delete_needs_confirmation': 'Delete needs confirmation in production.',
  'attached_files_for_review': 'Attached files for review.',
  'default_api_error': 'Something went wrong. Please try again.',
  'primary_tapped': 'Primary tapped',
  'ghost_tapped': 'Ghost tapped',
  'danger_tapped': 'Danger tapped',
  'toggle_theme': 'Toggle theme',
  'toggle_language': 'Toggle language',
  'workspace_summary_title':
      'Ask Saqqar to inspect Odoo, query PostgreSQL, review files, and prepare reports.',
  'workspace_summary_body':
      'The web workspace keeps the same work log here: tool calls, approvals, credentials, and generated artifacts.',
  'vault_summary_body':
      'Store Odoo XML-RPC, PostgreSQL, server shell, and GitHub access. Saqqar can use session credentials once, or memorize them after approval.',
  'files_summary_body':
      'Excel exports, CSV audits, screenshots, logs, and generated outputs from every conversation.',
  'action_center_summary_body':
      'Credential requests, generated reports, and approval-gated actions land here before Saqqar proceeds.',
  'live_access_note':
      'Live access only. Saqqar requests credentials in-chat and uses them only when needed.',
  'auto_approve_subtitle':
      'Run agent requests automatically without stopping for approval.',
  'composer_hint': 'Message Saqqar...',
  'composer_assist': 'Ask about Odoo, reports, database, or server issues.',
  'credential_sheet_body':
      'Fill the fields below. Saqqar uses them for this task, or stores them only after approval.',
  'no_exports_title': 'No exports yet.',
  'no_exports_body':
      'Excel files and other generated outputs will appear here.',
  'no_agent_actions_title': 'No agent actions waiting.',
  'no_agent_actions_body':
      'Credential requests and next steps will appear here.',
  'no_pending_approvals_title': 'No pending approvals.',
  'no_pending_approvals_body':
      'When Saqqar needs consent for storage or commands, it will show up here.',
  'offline_banner': "You're offline. Saqqar needs a live connection to act.",
  'new_conversation': 'New conversation',
  'no_conversations': 'No conversations yet',
  'no_conversations_hint':
      'Start a new conversation to ask Saqqar to operate on your Odoo.',
  'start_conversation': 'Start a conversation',
  'send': 'Send',
  'auto_approve': 'Auto-approve',
  'credential_vault': 'Credential Vault',
  'no_credentials': 'No credentials yet',
  'no_credentials_hint': 'Add one to let Saqqar work against your systems.',
  'add_credential': 'Add credential',
  'edit_credential': 'Edit credential',
  'save_credential': 'Save credential',
  'update_credential': 'Update credential',
  'bundle_name': 'Bundle name',
  'memorize_credential':
      'Memorize this credential for future chats after approval.',
  'action_center': 'Action Center',
  'pending_approvals': 'Pending approvals',
  'approvals': 'Approvals',
  'artifacts': 'Artifacts',
  'active_credential': 'Active credential',
  'credential_none': '— None —',
  'credential_none_hint': 'Saqqar will ask for credentials when needed.',
  'copied_to_clipboard': 'Copied to clipboard.',
  'role_you': 'You',
  'role_assistant': 'Saqqar',
  'role_tool': 'Tool',
  'role_system': 'System',
  'standard_user': 'Standard user',
  'open_storybook': 'Open storybook',
  'conversations_coverage_title': 'Conversations',
  'conversations_coverage_body':
      'Search, archive, rename, share, and open full work logs.',
  'vault_coverage_title': 'Credential Vault',
  'vault_coverage_body':
      'Odoo XML-RPC, PostgreSQL, server shell, GitHub, and approval-backed memorization.',
  'approvals_coverage_title': 'Approvals',
  'approvals_coverage_body':
      'Approve or reject Odoo writes, credential storage, and server commands.',
  'artifacts_coverage_title': 'Artifacts',
  'artifacts_coverage_body':
      'Excel, CSV, logs, images, and generated downloads.',
  'storybook': 'Storybook',
  'storybook_eyebrow_mini_chip': 'Eyebrow & Mini Chip',
  'storybook_eyebrow_label': 'Eyebrow label',
  'storybook_status_pills': 'Status pills',
  'storybook_buttons': 'Buttons',
  'storybook_inputs': 'Inputs',
  'storybook_switches': 'Switches',
  'storybook_avatars': 'Avatars',
  'storybook_glass_card': 'Glass card',
  'storybook_empty_state': 'Empty state',
  'sample_username': 'mostafa',
  'sample_user_sarah': 'Sarah',
  'sample_user_arabic': 'Mohamed',
  'sample_password_hint': '********',
  'field_rules_hint': 'A-Z, 0-9, dot, dash',
  'with_error': 'With error',
  'try_again': 'try again',
  'invalid_value': 'Invalid value',
  'conversation_title': 'Conversation title',
  'route_not_found': 'Route not found',
  'open_count_suffix': 'open',
  'messages': 'messages',
  'verified': 'Verified',
  'opening': 'Opening',
  'downloading': 'Downloading',
  'assistant_plan_prefix': 'I can work on that with',
  'assistant_plan_suffix':
      'I will ask for approval before any write or server command.',
};

const Map<String, String> _ar = {
  'app_name': 'صقّار',
  'product_initial': 'S',
  'app_tagline': 'مساعد عمليات أودو',
  'production_domain': 'saqqaar.com',
  'digital_harbor': 'Digital Harbor',
  'powered_by_digital_harbor': 'Powered by Digital Harbor',
  'welcome_back': 'أهلا بعودتك',
  'sign_in_subtitle': 'سجّل دخولك لمتابعة مساحة العمل.',
  'username': 'اسم المستخدم',
  'username_hint': 'اسم المستخدم',
  'password': 'كلمة المرور',
  'auth_password_hint': 'أدخل كلمة المرور',
  'email': 'البريد الإلكتروني',
  'sign_in': 'تسجيل الدخول',
  'sign_out': 'تسجيل الخروج',
  'new_to_saqqar': 'جديد على صقّار؟',
  'create_account': 'إنشاء حساب',
  'create_account_unavailable': 'التسجيل متاح على saqqaar.com.',
  'auth_brand_title': 'Saqqar Operations\nCopilot',
  'auth_brand_body':
      'وكيل أودو مباشر يشخّص ويجهز التقارير وينفذ عبر بيانات دخول خاصة وموافقات قبل أي تغيير حساس.',
  'open_workspace': 'فتح مساحة العمل',
  'tab_chats': 'المحادثات',
  'tab_vault': 'الخزنة',
  'tab_inbox': 'الوارد',
  'tab_files': 'الملفات',
  'tab_account': 'الحساب',
  'workspace': 'مساحة العمل',
  'workspace_coverage': 'تغطية مساحة العمل',
  'preferences': 'التفضيلات',
  'theme': 'المظهر',
  'theme_dark': 'داكن',
  'theme_light': 'فاتح',
  'theme_system': 'النظام',
  'language': 'اللغة',
  'english': 'English',
  'arabic': 'العربية',
  'system': 'النظام',
  'live': 'مباشر',
  'latest': 'الأحدث',
  'all': 'الكل',
  'archived': 'مؤرشف',
  'memorized': 'محفوظ',
  'session': 'جلسة',
  'not_verified': 'غير موثق',
  'approval_pending': 'بانتظار الموافقة',
  'manual': 'يدوي',
  'auto': 'تلقائي',
  'failed': 'فشل',
  'placeholder': 'مؤقت',
  'now': 'الآن',
  'page': 'صفحة',
  'of': 'من',
  'add': 'إضافة',
  'attach': 'إرفاق',
  'search': 'بحث',
  'refresh': 'تحديث',
  'download': 'تنزيل',
  'more': 'المزيد',
  'share_link': 'رابط المشاركة',
  'rename': 'إعادة تسمية',
  'archive': 'أرشفة',
  'delete': 'حذف',
  'edit': 'تعديل',
  'dismiss': 'إخفاء',
  'open': 'فتح',
  'approve': 'موافقة',
  'reject': 'رفض',
  'approved': 'تمت الموافقة',
  'rejected': 'مرفوض',
  'history': 'السجل',
  'pending': 'معلّق',
  'risk': 'المخاطرة',
  'cancel': 'إلغاء',
  'save': 'حفظ',
  'share': 'مشاركة',
  'retry': 'إعادة المحاولة',
  'label': 'العنوان',
  'kind': 'النوع',
  'credential': 'بيانات الدخول',
  'credentials': 'بيانات دخول',
  'conversations': 'محادثات',
  'artifacts_lower': 'ملفات',
  'requests': 'طلبات',
  'downloads_lower': 'تنزيلات',
  'smart_diagnosis': 'تشخيص ذكي',
  'live_tools': 'أدوات مباشرة',
  'approval_gated': 'بحاجة موافقة',
  'per_user_vault': 'خزنة لكل مستخدم',
  'live_systems_only': 'أنظمة مباشرة فقط',
  'per_user_encrypted_vault': 'خزنة مشفرة لكل مستخدم',
  'downloads': 'التنزيلات',
  'review_queue': 'قائمة المراجعة',
  'agent_requests': 'طلبات الوكيل',
  'review': 'مراجعة',
  'refresh_conversations': 'تحديث المحادثات',
  'refresh_credentials': 'تحديث بيانات الدخول',
  'search_conversations': 'بحث في المحادثات',
  'search_artifacts': 'بحث في الملفات',
  'clear_search': 'مسح البحث',
  'previous_page': 'الصفحة السابقة',
  'next_page': 'الصفحة التالية',
  'conversation_actions': 'إجراءات المحادثة',
  'credential_actions': 'إجراءات بيانات الدخول',
  'attach_files': 'إرفاق صور أو PDF أو جداول',
  'show_password': 'إظهار كلمة المرور',
  'hide_password': 'إخفاء كلمة المرور',
  'active_credential_updated': 'تم تحديث بيانات الدخول النشطة.',
  'public_link_copied': 'تم نسخ الرابط العام.',
  'conversations_refreshed': 'تم تحديث المحادثات.',
  'credentials_refreshed': 'تم تحديث بيانات الدخول.',
  'credential_updated': 'تم تحديث بيانات الدخول.',
  'credential_saved_approval':
      'تم حفظ بيانات الدخول. الموافقة مطلوبة قبل تذكرها.',
  'action_dismissed': 'تم إخفاء الإجراء.',
  'archived_toast': 'تمت الأرشفة.',
  'approval_rejected': 'تم رفض الموافقة.',
  'approval_granted_executing': 'تمت الموافقة. جار تنفيذ الإجراء.',
  'auto_approve_on': 'الموافقة التلقائية مفعلة.',
  'auto_approve_off': 'الموافقة التلقائية متوقفة.',
  'rename_conversation': 'إعادة تسمية المحادثة',
  'delete_needs_confirmation': 'الحذف يحتاج تأكيد في الإنتاج.',
  'attached_files_for_review': 'تم إرفاق الملفات للمراجعة.',
  'default_api_error': 'حدث خطأ. حاول مرة أخرى.',
  'primary_tapped': 'تم ضغط الزر الرئيسي',
  'ghost_tapped': 'تم ضغط الزر الثانوي',
  'danger_tapped': 'تم ضغط زر الخطر',
  'toggle_theme': 'تبديل المظهر',
  'toggle_language': 'تبديل اللغة',
  'workspace_summary_title':
      'اطلب من صقّار فحص أودو، الاستعلام من PostgreSQL، مراجعة الملفات، وتجهيز التقارير.',
  'workspace_summary_body':
      'مساحة العمل تحفظ نفس سجل العمل هنا: أدوات، موافقات، بيانات دخول، وملفات ناتجة.',
  'vault_summary_body':
      'احفظ وصول Odoo XML-RPC وPostgreSQL والسيرفر وGitHub. يستخدمها صقّار للجلسة أو يتذكرها بعد الموافقة.',
  'files_summary_body':
      'تظهر هنا صادرات Excel وCSV واللقطات والسجلات وكل المخرجات الناتجة من المحادثات.',
  'action_center_summary_body':
      'طلبات بيانات الدخول والتقارير والإجراءات التي تحتاج موافقة تظهر هنا قبل أن يكمل صقّار.',
  'live_access_note':
      'وصول مباشر فقط. صقّار يطلب بيانات الدخول داخل المحادثة ويستخدمها عند الحاجة فقط.',
  'auto_approve_subtitle': 'تشغيل طلبات الوكيل تلقائيا بدون التوقف للموافقة.',
  'composer_hint': 'اكتب لصقّار...',
  'composer_assist': 'اسأل عن أودو أو التقارير أو قاعدة البيانات أو السيرفر.',
  'credential_sheet_body':
      'املأ الحقول بالأسفل. يستخدمها صقّار لهذه المهمة أو يحفظها بعد الموافقة فقط.',
  'no_exports_title': 'لا توجد صادرات بعد.',
  'no_exports_body': 'ملفات Excel والمخرجات الناتجة ستظهر هنا.',
  'no_agent_actions_title': 'لا توجد إجراءات بانتظار الوكيل.',
  'no_agent_actions_body': 'طلبات بيانات الدخول والخطوات التالية ستظهر هنا.',
  'no_pending_approvals_title': 'لا توجد موافقات معلّقة.',
  'no_pending_approvals_body':
      'عندما يحتاج صقّار موافقة للتخزين أو الأوامر ستظهر هنا.',
  'offline_banner': 'أنت غير متصل. صقّار يحتاج اتصالا مباشرا للعمل.',
  'new_conversation': 'محادثة جديدة',
  'no_conversations': 'لا توجد محادثات بعد',
  'no_conversations_hint': 'ابدأ محادثة جديدة واطلب من صقّار العمل على أودو.',
  'start_conversation': 'ابدأ محادثة',
  'send': 'إرسال',
  'auto_approve': 'موافقة تلقائية',
  'credential_vault': 'خزنة بيانات الدخول',
  'no_credentials': 'لا توجد بيانات دخول',
  'no_credentials_hint': 'أضف واحدة ليستطيع صقّار العمل على أنظمتك.',
  'add_credential': 'إضافة بيانات دخول',
  'edit_credential': 'تعديل بيانات الدخول',
  'save_credential': 'حفظ بيانات الدخول',
  'update_credential': 'تحديث بيانات الدخول',
  'bundle_name': 'اسم الحزمة',
  'memorize_credential': 'تذكر بيانات الدخول للمحادثات القادمة بعد الموافقة.',
  'action_center': 'مركز الإجراءات',
  'pending_approvals': 'موافقات معلّقة',
  'approvals': 'الموافقات',
  'artifacts': 'الملفات',
  'active_credential': 'بيانات الدخول النشطة',
  'credential_none': '— بدون —',
  'credential_none_hint': 'صقّار يطلب بيانات الدخول عند الحاجة.',
  'copied_to_clipboard': 'تم النسخ.',
  'role_you': 'أنت',
  'role_assistant': 'صقّار',
  'role_tool': 'أداة',
  'role_system': 'النظام',
  'standard_user': 'مستخدم عادي',
  'open_storybook': 'فتح Storybook',
  'conversations_coverage_title': 'المحادثات',
  'conversations_coverage_body':
      'بحث وأرشفة وإعادة تسمية ومشاركة وفتح سجلات العمل كاملة.',
  'vault_coverage_title': 'خزنة بيانات الدخول',
  'vault_coverage_body':
      'Odoo XML-RPC وPostgreSQL والسيرفر وGitHub مع حفظ مدعوم بالموافقة.',
  'approvals_coverage_title': 'الموافقات',
  'approvals_coverage_body':
      'وافق أو ارفض تعديلات أودو وتخزين بيانات الدخول وأوامر السيرفر.',
  'artifacts_coverage_title': 'الملفات',
  'artifacts_coverage_body': 'Excel وCSV وسجلات وصور وتنزيلات مولدة.',
  'storybook': 'Storybook',
  'storybook_eyebrow_mini_chip': 'Eyebrow & Mini Chip',
  'storybook_eyebrow_label': 'Eyebrow label',
  'storybook_status_pills': 'Status pills',
  'storybook_buttons': 'Buttons',
  'storybook_inputs': 'Inputs',
  'storybook_switches': 'Switches',
  'storybook_avatars': 'Avatars',
  'storybook_glass_card': 'Glass card',
  'storybook_empty_state': 'Empty state',
  'sample_username': 'mostafa',
  'sample_user_sarah': 'Sarah',
  'sample_user_arabic': 'محمد',
  'sample_password_hint': '********',
  'field_rules_hint': 'A-Z, 0-9, dot, dash',
  'with_error': 'With error',
  'try_again': 'try again',
  'invalid_value': 'قيمة غير صحيحة',
  'conversation_title': 'عنوان المحادثة',
  'route_not_found': 'المسار غير موجود',
  'open_count_suffix': 'مفتوح',
  'messages': 'رسائل',
  'verified': 'موثق',
  'opening': 'فتح',
  'downloading': 'تنزيل',
  'assistant_plan_prefix': 'أقدر أشتغل على ذلك باستخدام',
  'assistant_plan_suffix': 'سأطلب الموافقة قبل أي كتابة أو أمر على السيرفر.',
};
