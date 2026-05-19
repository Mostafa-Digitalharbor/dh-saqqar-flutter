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

  // Sign up
  String get signUpTitle => _t('sign_up_title');
  String get signUpSubtitle => _t('sign_up_subtitle');
  String get confirmPassword => _t('confirm_password');
  String get confirmPasswordHint => _t('confirm_password_hint');
  String get emailOptional => _t('email_optional');
  String get emailHint => _t('email_hint');
  String get createAccountButton => _t('create_account_button');
  String get alreadyHaveAccount => _t('already_have_account');
  String get backToSignIn => _t('back_to_sign_in');
  String get passwordTooShort => _t('password_too_short');
  String get passwordsDoNotMatch => _t('passwords_do_not_match');
  String get usernameRequired => _t('username_required');
  String get accountCreatedToast => _t('account_created_toast');

  // Change password
  String get changePassword => _t('change_password');
  String get currentPassword => _t('current_password');
  String get newPassword => _t('new_password');
  String get changePasswordHint => _t('change_password_hint');
  String get changePasswordKeepSignedIn => _t('change_password_keep_signed_in');
  String get currentPasswordWrong => _t('current_password_wrong');
  String get passwordUpdatedToast => _t('password_updated_toast');
  String get updatePassword => _t('update_password');

  // Inline credential request (chat §6.7)
  String get inlineCredentialRequestTitle => _t('inline_credential_request_title');
  String get inlineCredentialRequestBody => _t('inline_credential_request_body');
  String get provideCredential => _t('provide_credential');
  String get useExistingCredential => _t('use_existing_credential');
  String get inlineCredentialProvided => _t('inline_credential_provided');
  // Memorize toggle inside the inline credential request — mirrors the
  // web's `remember_preference: "memorize" | "session_only"` switch. Used
  // by the chat to pick which toast fires after submission.
  String get inlineCredentialMemorized => _t('inline_credential_memorized');
  String get inlineCredentialSession => _t('inline_credential_session');

  // Project / Environment (matches web saqqaar.com data model)
  String get pickEnvironment => _t('pick_environment');
  String get pickEnvironmentSubtitle => _t('pick_environment_subtitle');
  String get noEnvironmentPicked => _t('no_environment_picked');
  String get pickEnvironmentToStart => _t('pick_environment_to_start');
  String get environmentSetForChat => _t('environment_set_for_chat');
  String get liveBadge => _t('live_badge');
  String get readOnlyBadge => _t('read_only_badge');
  String get autoApproveBadge => _t('auto_approve_badge');
  String get project => _t('project');
  String get environment => _t('environment');
  String get changeEnvironment => _t('change_environment');

  // Inline pending approvals banner (above composer)
  String get reviewApproval => _t('review_approval');
  String morePendingApprovals(int n) =>
      _isArabic ? '+ $n موافقات أخرى معلّقة' : '+ $n more pending approvals';

  // Chat header strip — 3 dropdowns matching the web's header
  String get headerProject => _t('header_project');
  String get headerEnvironment => _t('header_environment');
  String get pickProjectFirst => _t('pick_project_first');
  String get noProjectsYet => _t('no_projects_yet');
  String get noEnvironmentsForProject => _t('no_environments_for_project');
  String get createEnvironmentCta => _t('create_environment_cta');
  String get createEnvironmentConfirmTitle =>
      _t('create_environment_confirm_title');
  String get createEnvironmentConfirmBody =>
      _t('create_environment_confirm_body');
  String get headerNoneOption => _t('header_none_option');

  // Vault lifecycle — matches web saqqaar.com verbatim copy
  String get noStoredCredentialsTitle => _t('no_stored_credentials_title');
  String get noStoredCredentialsBody => _t('no_stored_credentials_body');
  String get projectName => _t('project_name');
  String get addProject => _t('add_project');
  String get projectsTitle => _t('projects_title');
  String get backToProjects => _t('back_to_projects');
  /// Numeric-first count rendering — always `N word` so the count
  /// reads cleanly at a glance, even when the same row repeats across
  /// dozens of projects. Drops the locale-specific pluralisation that
  /// made rows like "بيئة واحدة" / "بيئتان" inconsistent next to the
  /// numeric variants. Reserves the special "no environments" copy for
  /// the empty case only.
  String environmentCount(int n) {
    if (_isArabic) {
      return n == 0 ? 'لا توجد بيئات' : '$n بيئة';
    }
    return n == 0 ? 'no environments' : '$n environment${n == 1 ? '' : 's'}';
  }
  String get addProjectHint => _t('add_project_hint');
  String get manageProjects => _t('manage_projects');
  String get projectSavedToast => _t('project_saved_toast');
  String get projectDeletedToast => _t('project_deleted_toast');
  String get deleteProjectTitle => _t('delete_project_title');
  String deleteProjectBody(String name) => _isArabic
      ? 'حذف المشروع "$name"؟ ستُحذف البيئات وبيانات الدخول المرتبطة بها.'
      : 'Delete project "$name"? Environments and their credentials are deleted with it.';

  String get addEnvironment => _t('add_environment');
  String get addEnvironmentHint => _t('add_environment_hint');
  String get environmentSavedToast => _t('environment_saved_toast');
  String get environmentDeletedToast => _t('environment_deleted_toast');
  String get deleteEnvironmentTitle => _t('delete_environment_title');
  String deleteEnvironmentBody(String name) => _isArabic
      ? 'حذف البيئة "$name"؟ ستُحذف جميع بيانات الدخول داخلها.'
      : 'Delete environment "$name"? All credentials inside it are deleted.';

  String get saveCredentialButton => _t('save_credential_button');
  String get deleteCredentialButton => _t('delete_credential_button');
  String get credentialSavedToast => _t('credential_saved_toast');
  String get credentialDeletedToast => _t('credential_deleted_toast');
  String get deleteCredentialTitle => _t('delete_credential_title');
  String get deleteCredentialBody => _t('delete_credential_body');
  String get notSavedYet => _t('not_saved_yet');
  String lastVerifiedAt(String at) =>
      _isArabic ? 'آخر تحقق: $at' : 'Last verified $at';

  /// Relative-time label like "2 hours ago" / "just now" — used inline by
  /// the credential form's "Last verified" hint.
  String relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    final mins = diff.inMinutes;
    final hours = diff.inHours;
    final days = diff.inDays;
    if (_isArabic) {
      if (mins < 1) return 'الآن';
      if (mins < 60) return 'منذ $mins دقيقة';
      if (hours < 24) return 'منذ $hours ساعة';
      if (days < 7) return 'منذ $days يوم';
      if (days < 30) return 'منذ ${(days / 7).floor()} أسبوع';
      return 'منذ ${(days / 30).floor()} شهر';
    }
    if (mins < 1) return 'just now';
    if (mins < 60) return '$mins min ago';
    if (hours < 24) return '$hours hour${hours == 1 ? '' : 's'} ago';
    if (days < 7) return '$days day${days == 1 ? '' : 's'} ago';
    if (days < 30) {
      final w = (days / 7).floor();
      return '$w week${w == 1 ? '' : 's'} ago';
    }
    final m = (days / 30).floor();
    return '$m month${m == 1 ? '' : 's'} ago';
  }

  // Credential form: Test connection
  String get testConnection => _t('test_connection');
  String get testingConnection => _t('testing_connection');
  String get connectionVerified => _t('connection_verified');
  String get connectionFailed => _t('connection_failed');
  String get noFieldsForKind => _t('no_fields_for_kind');
  String get noEnvironments => _t('no_environments');
  String get openEnvironment => _t('open_environment');
  String get flagLive => _t('flag_live');
  String get flagReadOnly => _t('flag_read_only');
  String get flagAutoApprove => _t('flag_auto_approve');

  // Env card row enrichments — credential count badge, inline rename hint,
  // and the confirm-mark-live dialog. Surface only when relevant; the
  // badge is hidden when count == 0 so empty envs stay quiet.
  /// Same `N word` rendering as [environmentCount] — keep the two count
  /// helpers shaped identically so the vault rows scan as a single
  /// vertical column of `N · label` pairs.
  String credentialCount(int n) {
    if (_isArabic) return '$n بيانات وصول';
    return n == 1 ? '1 credential' : '$n credentials';
  }
  String get markEnvLiveTitle => _t('mark_env_live_title');
  String markEnvLiveBody(String envName) => _isArabic
      ? 'تفعيل "$envName" كبيئة مباشرة سيُشغّل تأكيد التحذير قبل أول رسالة في كل محادثة جديدة. هل تريد المتابعة؟'
      : 'Marking "$envName" as LIVE turns on the warning gate before the first send in every new conversation. Continue?';
  String get markAsLive => _t('mark_as_live');
  String get envSearchHint => _t('env_search_hint');

  // Artifacts (inline pill matches web's "Artifact ready" label)
  String get artifactReady => _t('artifact_ready');

  // 404 conversation fallback
  String get conversationNotFoundTitle => _t('conversation_not_found_title');
  String get conversationNotFoundBody => _t('conversation_not_found_body');
  String get backToChats => _t('back_to_chats');

  // Date-group headers for the conversations list (Today / Yesterday /
  // Previous 7 days / Previous 30 days / Older — web parity).
  String get dateGroupToday => _t('date_group_today');
  String get dateGroupYesterday => _t('date_group_yesterday');
  String get dateGroupPrevious7 => _t('date_group_previous_7');
  String get dateGroupPrevious30 => _t('date_group_previous_30');
  String get dateGroupOlder => _t('date_group_older');

  // Contextual activity status labels (web's "Checking Odoo data",
  // "Building Excel report", "Reading repository files", etc.). The chat
  // typing row uses `pendingStatusForTool()` (see chat/state/tool_status.dart)
  // to pick the right one per active tool — these mirror the per-tool
  // branches in the web's `pendingStatusForTool()` (app.js line 2421).
  String get activityCheckingOdoo => _t('activity_checking_odoo');
  String get activityRunningQuery => _t('activity_running_query');
  String get activityBuildingReport => _t('activity_building_report');
  String get activityReadingRepo => _t('activity_reading_repo');
  String get activityRunningCommand => _t('activity_running_command');
  String get activityFinishingResponse => _t('activity_finishing_response');
  String get activityReviewingAttachment =>
      _t('activity_reviewing_attachment');
  String get activityPreparingAccess => _t('activity_preparing_access');
  String get activityInspectingOdooModel =>
      _t('activity_inspecting_odoo_model');
  String get activityApplyingOdooChange =>
      _t('activity_applying_odoo_change');
  String get activityBuildingExcel => _t('activity_building_excel');
  String get activityBuildingPdf => _t('activity_building_pdf');
  String get activityBuildingWord => _t('activity_building_word');
  String get activityPreparingApproval =>
      _t('activity_preparing_approval');

  // Grouped approvals (web pre-approval shortcut)
  String similarRequestsCount(int count) => _isArabic
      ? '$count طلب مشابه'
      : '$count similar requests';
  String operationOnModel(String operation, String model) =>
      _isArabic ? '$operation على `$model`' : '$operation on `$model`';
  String approveAllN(int count) =>
      _isArabic ? 'وافق على الكل ($count)' : 'Approve all $count';
  String rejectAllN(int count) =>
      _isArabic ? 'ارفض الكل ($count)' : 'Reject all $count';
  String get preApprovalTip => _t('pre_approval_tip');
  String get showIndividualRecords => _t('show_individual_records');
  String get hideIndividualRecords => _t('hide_individual_records');
  String approvalGrantedWithPreapproval(int count) => _isArabic
      ? 'تمت الموافقة. $count طلب مماثل تمت الموافقة عليه مسبقاً.'
      : 'Approval granted. $count similar request(s) pre-approved.';

  // Live environment confirmation (web one-shot warning)
  String liveWarningTitle(String envName) =>
      _isArabic ? 'بيئة مباشرة: $envName' : 'Live environment: $envName';
  String liveWarningBody(String envName, String projectName) => _isArabic
      ? 'أنت على وشك التحدث مع "$envName" في مشروع "$projectName" — بيئة مباشرة. الإجراءات المؤذية لا تزال تحت الموافقة، لكن انتبه. هل تريد المتابعة؟'
      : "You're about to talk to \"$envName\" in project \"$projectName\" — a LIVE environment. Destructive actions are still approval-gated, but be careful. Continue?";
  String get sendToLive => _t('send_to_live');
  String get dontAskAgain => _t('dont_ask_again');

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
  String get switchLanguageToEnglish => _t('switch_language_to_english');
  String get switchLanguageToArabic => _t('switch_language_to_arabic');
  String get switchThemeToLight => _t('switch_theme_to_light');
  String get switchThemeToDark => _t('switch_theme_to_dark');
  String get english => _t('english');
  String get arabic => _t('arabic');
  String get system => _t('system');
  String get live => _t('live');
  String get latest => _t('latest');
  String get all => _t('all');
  String get archived => _t('archived');
  String get showArchivedAction => _t('show_archived_action');
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
  String get downloadingArtifact => _t('downloading_artifact');
  String get artifactNoViewer => _t('artifact_no_viewer');
  String get artifactOpenFailed => _t('artifact_open_failed');
  String get artifactDownloadFailed => _t('artifact_download_failed');
  String get more => _t('more');
  String get shareLink => _t('share_link');
  String get rename => _t('rename');
  String get archive => _t('archive');
  String get unarchive => _t('unarchive');
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
  String get confirmYes => _t('confirm_yes');
  String get confirmNo => _t('confirm_no');
  String get close => _t('close');
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
  // Deep think — global toggle in the chat header. Web parity (mirrors
  // `state.deepThink` in app.js).
  String get deepThink => _t('deep_think');
  String get deepThinkTitle => _t('deep_think_title');
  String get deepThinkOn => _t('deep_think_on');
  String get deepThinkOff => _t('deep_think_off');
  // Stop generation — composer button label + toast.
  String get stopGeneration => _t('stop_generation');
  String get generationStopped => _t('generation_stopped');
  String get stopping => _t('stopping');
  // Agent live-status copy — feeds the AppBar "Working" pill and the
  // typing row's italic meta line. Three states because the web has
  // distinct labels: pill (terse, "Working"), meta line (verbose,
  // "Working on your request"), composer busy hint.
  String get agentWorking => _t('agent_working');
  String get agentThinking => _t('agent_thinking');
  String get saqqarThinking => _t('saqqar_thinking');
  String get thinkingStepsLabel => _t('thinking_steps_label');
  String get composerBusy => _t('composer_busy');
  // Long-running report progress (run_progress.phase = building_report /
  // rendering_report). Shown on the typing row while Excel/PDF/Word
  // generation is in flight.
  String phaseFetching(int current, int? total) {
    if (total == null) {
      return _isArabic ? 'جلب $current' : 'Fetching $current';
    }
    final pct = ((current / total) * 100).round().clamp(0, 100);
    return _isArabic
        ? 'جلب $current / $total · $pct%'
        : 'Fetching $current / $total · $pct%';
  }
  String phaseRendering(int? rows) {
    if (rows == null) {
      return _isArabic ? 'كتابة الملف…' : 'Writing file…';
    }
    return _isArabic
        ? 'كتابة الملف… $rows صف'
        : 'Writing file… $rows rows';
  }
  // Credential form — extra submit action: save + the agent resumes
  // immediately without dismissing the sheet. Web parity for the
  // `saveAndContinue` button.
  String get saveAndContinue => _t('save_and_continue');
  String get credentialSavedContinuing => _t('credential_saved_continuing');
  // Activity sheet — shows server-shell command outputs (stdout / stderr /
  // exit). Mirrors the web's "Activity" tab in the Inbox drawer.
  String get serverActivity => _t('server_activity');
  String get serverActivityFailed => _t('server_activity_failed');
  String get noServerActivity => _t('no_server_activity');
  String get noServerActivityBody => _t('no_server_activity_body');
  String get copyCommand => _t('copy_command');
  String get copyStdout => _t('copy_stdout');
  String get copied => _t('copied');
  String exitCode(int code) => 'exit $code';
  // Placeholder for a fresh chat whose agent-generated title hasn't landed
  // yet. Web sends this in the conversation row + chat AppBar.
  String get untitledConversation => _t('untitled_conversation');
  // Placeholder-row chip ("Soon") — used on menu items whose wired action
  // hasn't shipped yet so the user knows the row is real but not live.
  String get comingSoonBadge => _t('coming_soon_badge');
  String get comingSoonToast => _t('coming_soon_toast');
  String get renameConversation => _t('rename_conversation');
  String get openConversations => _t('open_conversations');
  String get openApprovals => _t('open_approvals');
  String get sidebarTitle => _t('sidebar_title');
  String get inboxTitle => _t('inbox_title');
  String get youLabel => _t('you_label');
  String get brandEyebrow => _t('brand_eyebrow');
  String get today => _t('today_label');
  String get older => _t('older_label');
  String get noMatches => _t('no_matches');
  String get renameConversationHint => _t('rename_conversation_hint');
  String get conversationRenamedToast => _t('conversation_renamed_toast');
  String get conversationPinnedToast => _t('conversation_pinned_toast');
  String get conversationUnpinnedToast => _t('conversation_unpinned_toast');
  String get pinConversation => _t('pin_conversation');
  String get unpinConversation => _t('unpin_conversation');
  String get pinned => _t('pinned');
  String get deleteNeedsConfirmation => _t('delete_needs_confirmation');
  String get attachedFilesForReview => _t('attached_files_for_review');
  String get defaultApiError => _t('default_api_error');
  String get loading => _t('loading');

  // ── Typed error categories (used by ApiErrorMapper) ────────────────
  // One key per AppFailure subtype. Adding a new failure → add one EN +
  // one AR string here + one switch arm in ApiErrorMapper._baseMessage.
  String get errorNetwork => _t('error_network');
  String get errorTimeout => _t('error_timeout');
  String get errorCancelled => _t('error_cancelled');
  String get errorUnauthorized => _t('error_unauthorized');
  String get errorForbidden => _t('error_forbidden');
  String get errorNotFound => _t('error_not_found');
  String get errorValidation => _t('error_validation');
  String get errorConflict => _t('error_conflict');
  String get errorRateLimited => _t('error_rate_limited');
  String errorRateLimitedWithRetry(int seconds) =>
      _t('error_rate_limited_with_retry').replaceFirst('{seconds}', '$seconds');
  String get errorPayloadTooLarge => _t('error_payload_too_large');
  String get errorServer => _t('error_server');
  String get errorUnknown => _t('error_unknown');

  // ── Vault action labels (prefix for "<action> · <error>" messages) ──
  String get vaultActionLoadFailed => _t('vault_action_load_failed');
  String get vaultActionCreateProjectFailed =>
      _t('vault_action_create_project_failed');
  String get vaultActionRenameProjectFailed =>
      _t('vault_action_rename_project_failed');
  String get vaultActionDeleteProjectFailed =>
      _t('vault_action_delete_project_failed');
  String get vaultActionCreateEnvironmentFailed =>
      _t('vault_action_create_environment_failed');
  String get vaultActionUpdateEnvironmentFailed =>
      _t('vault_action_update_environment_failed');
  String get vaultActionDeleteEnvironmentFailed =>
      _t('vault_action_delete_environment_failed');
  String get vaultActionLoadCredentialsFailed =>
      _t('vault_action_load_credentials_failed');
  String get vaultActionSaveCredentialFailed =>
      _t('vault_action_save_credential_failed');
  String get vaultActionDeleteCredentialFailed =>
      _t('vault_action_delete_credential_failed');

  // ── Vault action toasts (one-shot success messages) ────────────────
  String get vaultToastProjectCreated => _t('vault_toast_project_created');
  String get vaultToastProjectDeleted => _t('vault_toast_project_deleted');
  String get vaultToastEnvironmentCreated =>
      _t('vault_toast_environment_created');
  String get vaultToastEnvironmentDeleted =>
      _t('vault_toast_environment_deleted');
  String get vaultToastCredentialSaved => _t('vault_toast_credential_saved');
  String get vaultToastCredentialDeleted =>
      _t('vault_toast_credential_deleted');

  // ── Conversations action labels + toasts (Phase 4) ──
  String get conversationsActionLoadFailed =>
      _t('conversations_action_load_failed');
  String get conversationsActionCreateFailed =>
      _t('conversations_action_create_failed');
  String get conversationsActionRenameFailed =>
      _t('conversations_action_rename_failed');
  String get conversationsActionArchiveFailed =>
      _t('conversations_action_archive_failed');
  String get conversationsActionUnarchiveFailed =>
      _t('conversations_action_unarchive_failed');
  String get conversationsActionDeleteFailed =>
      _t('conversations_action_delete_failed');
  String get conversationsActionStopFailed =>
      _t('conversations_action_stop_failed');

  String get conversationCreatedToast => _t('conversation_created_toast');
  String get conversationArchivedToast => _t('conversation_archived_toast');
  String get conversationUnarchivedToast =>
      _t('conversation_unarchived_toast');
  String get conversationDeletedToast => _t('conversation_deleted_toast');
  String get conversationStoppedToast => _t('conversation_stopped_toast');

  // Auth flow toasts + error mapping (mobile API §1, §14)
  String get signedInToast => _t('signed_in_toast');
  String get signedOutToast => _t('signed_out_toast');
  String get sessionEndedToast => _t('session_ended_toast');
  String get signOutConfirmTitle => _t('sign_out_confirm_title');
  String get signOutConfirmBody => _t('sign_out_confirm_body');
  String get signingOut => _t('signing_out');
  String get exitAppConfirmTitle => _t('exit_app_confirm_title');
  String get exitAppConfirmBody => _t('exit_app_confirm_body');
  String get authInvalidCredentials => _t('auth_invalid_credentials');
  String get authEmailTaken => _t('auth_email_taken');
  String get authNetworkError => _t('auth_network_error');
  String get authRateLimited => _t('auth_rate_limited');
  String get authBootingSession => _t('auth_booting_session');
  String get emailLabel => _t('email_label');
  String get emailRequired => _t('email_required');
  String get emailInvalid => _t('email_invalid');
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
  String get noArchivedConversations => _t('no_archived_conversations');
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
  String get suggestUserCount => _t('suggest_user_count');
  String get suggestExportUsers => _t('suggest_export_users');
  String get suggestTailLog => _t('suggest_tail_log');

  // Empty-chat suggestions surface (replaces the bare "Start a conversation"
  // headline on 2026-05-17 — 4 prefab prompts that fill the composer on tap).
  String get emptyChatTitle => _t('empty_chat_title');
  String get emptyChatBody => _t('empty_chat_body');
  String get suggestExploreTitle => _t('suggest_explore_title');
  String get suggestExploreSub => _t('suggest_explore_sub');
  String get suggestExplorePrompt => _t('suggest_explore_prompt');
  String get suggestSummarizeTitle => _t('suggest_summarize_title');
  String get suggestSummarizeSub => _t('suggest_summarize_sub');
  String get suggestSummarizePrompt => _t('suggest_summarize_prompt');
  String get suggestReportTitle => _t('suggest_report_title');
  String get suggestReportSub => _t('suggest_report_sub');
  String get suggestReportPrompt => _t('suggest_report_prompt');
  String get suggestServerLogsTitle => _t('suggest_server_logs_title');
  String get suggestServerLogsSub => _t('suggest_server_logs_sub');
  String get suggestServerLogsPrompt => _t('suggest_server_logs_prompt');
  String get removeAttachment => _t('remove_attachment');
  String get offlineTitle => _t('offline_title');
  String get offlineBody => _t('offline_body');
  String get askSaqqarAnything => _t('ask_saqqar_anything');
  String get linkCopied => _t('link_copied');
  String get dateToday => _t('date_today');
  String get dateYesterday => _t('date_yesterday');
  String get inboxRefreshed => _t('inbox_refreshed');
  String get roleYou => _t('role_you');
  String get roleAssistant => _t('role_assistant');
  String get roleTool => _t('role_tool');
  String get roleSystem => _t('role_system');

  // Account coverage
  String get standardUser => _t('standard_user');
  String get staffUser => _t('staff_user');
  String get adminUser => _t('admin_user');
  String get accountJoinedLabel => _t('account_joined_label');
  String get accountLastLoginLabel => _t('account_last_login_label');
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
  'username': 'Name',
  'username_hint': 'Your full name',
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
  'tab_vault': 'Projects',
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
  'switch_language_to_english': 'Switch language to English',
  'switch_language_to_arabic': 'التبديل إلى العربية',
  'switch_theme_to_light': 'Switch to light theme',
  'switch_theme_to_dark': 'Switch to dark theme',
  'english': 'English',
  'arabic': 'Arabic',
  'system': 'System',
  'live': 'Live',
  'latest': 'Latest',
  'all': 'All',
  'archived': 'Archived',
  'show_archived_action': 'Show',
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
  'downloading_artifact': 'Downloading…',
  'artifact_no_viewer': "Couldn't find an app to open this file.",
  'artifact_open_failed': "Couldn't open the file.",
  'artifact_download_failed': "Couldn't download the file. Try again.",
  'more': 'More',
  'share_link': 'Share link',
  'rename': 'Rename',
  'archive': 'Archive',
  'unarchive': 'Unarchive',
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
  'confirm_yes': 'Yes',
  'confirm_no': 'No',
  'close': 'Close',
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
  'deep_think': 'Deep think',
  'deep_think_title':
      'Give Saqqar more reasoning budget for harder questions.',
  'deep_think_on': 'Deep think on.',
  'deep_think_off': 'Deep think off.',
  'stop_generation': 'Stop generating',
  'generation_stopped': 'Stopped.',
  'stopping': 'Stopping…',
  'agent_working': 'Working',
  'agent_thinking': 'Working on your request.',
  'saqqar_thinking': 'Saqqar thinking',
  'thinking_steps_label': 'steps',
  'composer_busy': 'Saqqar is working — type your next task; send unlocks when done.',
  'save_and_continue': 'Save and continue',
  'credential_saved_continuing': 'Credential saved — Saqqar is resuming.',
  'server_activity': 'Server activity',
  'server_activity_failed': 'Server activity (failed)',
  'no_server_activity': 'No server commands yet.',
  'no_server_activity_body':
      'When Saqqar runs a shell command, the output will land here.',
  'copy_command': 'Copy command',
  'copy_stdout': 'Copy output',
  'copied': 'Copied.',
  'untitled_conversation': 'Untitled conversation',
  'coming_soon_badge': 'Soon',
  'coming_soon_toast': 'This action ships in the next build.',
  'rename_conversation': 'Rename conversation',
  'open_conversations': 'Open conversations',
  'open_approvals': 'Open approvals',
  'sidebar_title': 'Conversations',
  'inbox_title': 'Inbox',
  'you_label': 'You',
  'brand_eyebrow': 'Saqqar',
  'today_label': 'Today',
  'older_label': 'Older',
  'no_matches': 'No matches.',
  'rename_conversation_hint': 'Type a new title…',
  'conversation_renamed_toast': 'Conversation renamed.',
  'conversation_pinned_toast': 'Pinned to the top.',
  'conversation_unpinned_toast': 'Unpinned.',
  'pin_conversation': 'Pin to top',
  'unpin_conversation': 'Unpin',
  'pinned': 'Pinned',
  'delete_needs_confirmation': 'Delete needs confirmation in production.',
  'attached_files_for_review': 'Attached files for review.',
  'default_api_error': 'Something went wrong. Please try again.',
  'loading': 'Loading…',
  // ── Typed error categories ──
  'error_network': "Couldn't reach the server. Check your connection.",
  'error_timeout': 'The server took too long to respond. Please try again.',
  'error_cancelled': 'The action was cancelled.',
  'error_unauthorized': 'Your session ended. Please sign in again.',
  'error_forbidden': "You don't have permission to do this.",
  'error_not_found': "We couldn't find what you were looking for.",
  'error_validation': 'Some fields need your attention.',
  'error_conflict': 'That action conflicts with current data. Refresh and try again.',
  'error_rate_limited': 'Too many attempts. Please slow down.',
  'error_rate_limited_with_retry': 'Too many attempts. Try again in {seconds}s.',
  'error_payload_too_large': 'That file is too large. The limit is 25 MB.',
  'error_server': 'The server hit a problem. Please try again in a moment.',
  'error_unknown': 'Something went wrong. Please try again.',
  // ── Vault action labels (prefixes) ──
  'vault_action_load_failed': "Couldn't load your projects",
  'vault_action_create_project_failed': "Couldn't create the project",
  'vault_action_rename_project_failed': "Couldn't rename the project",
  'vault_action_delete_project_failed': "Couldn't delete the project",
  'vault_action_create_environment_failed': "Couldn't create the environment",
  'vault_action_update_environment_failed': "Couldn't update the environment",
  'vault_action_delete_environment_failed': "Couldn't delete the environment",
  'vault_action_load_credentials_failed': "Couldn't load credentials",
  'vault_action_save_credential_failed': "Couldn't save the credential",
  'vault_action_delete_credential_failed': "Couldn't delete the credential",
  // ── Vault success toasts ──
  'vault_toast_project_created': 'Project created.',
  'vault_toast_project_deleted': 'Project deleted.',
  'vault_toast_environment_created': 'Environment created.',
  'vault_toast_environment_deleted': 'Environment deleted.',
  'vault_toast_credential_saved': 'Credential saved.',
  'vault_toast_credential_deleted': 'Credential deleted.',
  // ── Conversations action labels + toasts (Phase 4) ──
  'conversations_action_load_failed': "Couldn't load your conversations",
  'conversations_action_create_failed': "Couldn't create the conversation",
  'conversations_action_rename_failed': "Couldn't rename the conversation",
  'conversations_action_archive_failed': "Couldn't archive the conversation",
  'conversations_action_unarchive_failed':
      "Couldn't restore the conversation",
  'conversations_action_delete_failed': "Couldn't delete the conversation",
  'conversations_action_stop_failed': "Couldn't stop the conversation",
  'conversation_created_toast': 'Conversation started.',
  'conversation_archived_toast': 'Conversation archived.',
  'conversation_unarchived_toast': 'Conversation restored.',
  'conversation_deleted_toast': 'Conversation deleted.',
  'conversation_stopped_toast': 'Generation stopped.',
  'signed_in_toast': 'Signed in.',
  'signed_out_toast': 'Signed out.',
  'session_ended_toast': 'Your session ended. Please sign in again.',
  'sign_out_confirm_title': 'Sign out',
  'sign_out_confirm_body':
      'You will need to sign in again to access your projects and chats.',
  'signing_out': 'Signing out…',
  'exit_app_confirm_title': 'Exit Saqqar',
  'exit_app_confirm_body': 'Are you sure you want to close the app?',
  'auth_invalid_credentials': 'Invalid email or password.',
  'auth_email_taken': 'That email is already in use.',
  'auth_network_error': "Couldn't reach the server. Check your connection.",
  'auth_rate_limited': 'Too many attempts. Try again in a moment.',
  'auth_booting_session': 'Restoring your session…',
  'email_label': 'Email',
  'email_required': 'Email is required.',
  'email_invalid': "That doesn't look like a valid email.",
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
  'no_archived_conversations': 'No archived conversations',
  'start_conversation': 'Start a conversation',
  'send': 'Send',
  'auto_approve': 'Auto-approve',
  'credential_vault': 'Projects',
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
  'suggest_user_count': 'Show me how many users are in Odoo right now.',
  'suggest_export_users': 'Export active internal users as Excel.',
  'suggest_tail_log': 'Tail the Odoo server log for the last 100 lines.',
  'empty_chat_title': 'What should we work on?',
  'empty_chat_body': 'Tap a suggestion or describe what you need.',
  'suggest_explore_title': 'Explore my data',
  'suggest_explore_sub': 'Browse models, fields, or records.',
  'suggest_explore_prompt':
      'List the top 10 customers by total invoiced this year and show their outstanding balance.',
  'suggest_summarize_title': 'Summarize a document',
  'suggest_summarize_sub': 'Upload a PDF / Word / Excel file.',
  'suggest_summarize_prompt':
      'Summarize the attached document in 5 bullet points and flag anything that looks like a risk or open question.',
  'suggest_report_title': 'Generate a report',
  'suggest_report_sub': 'Export Excel / PDF / Word.',
  'suggest_report_prompt':
      'Generate a sales report for last month grouped by salesperson, exported as Excel.',
  'suggest_server_logs_title': 'Check server logs',
  'suggest_server_logs_sub': 'Tail logs or run a server command.',
  'suggest_server_logs_prompt':
      'Tail the Odoo server log for the last 200 lines and highlight any errors or warnings.',
  'remove_attachment': 'Remove attachment',
  'offline_title': 'You\'re offline',
  'offline_body': 'Saqqar needs a live connection to act.',
  'ask_saqqar_anything': 'Ask Saqqar anything',
  'link_copied': 'Link copied to clipboard.',
  'date_today': 'Today',
  'date_yesterday': 'Yesterday',
  'inbox_refreshed': 'Inbox refreshed.',
  'role_you': 'You',
  'role_assistant': 'Saqqar',
  'role_tool': 'Tool',
  'role_system': 'System',
  'standard_user': 'Standard user',
  'staff_user': 'Staff',
  'admin_user': 'Administrator',
  'account_joined_label': 'Joined',
  'account_last_login_label': 'Last login',
  'open_storybook': 'Open storybook',
  'conversations_coverage_title': 'Conversations',
  'conversations_coverage_body':
      'Search, archive, rename, share, and open full work logs.',
  'vault_coverage_title': 'Projects',
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

  // Sign up
  'sign_up_title': 'Set up your private workspace',
  'sign_up_subtitle': 'Create an account to start using your operations copilot.',
  'confirm_password': 'Confirm password',
  'confirm_password_hint': 'Repeat your password',
  'email_optional': 'Email (optional)',
  'email_hint': 'you@example.com',
  'create_account_button': 'Create account',
  'already_have_account': 'Already have an account?',
  'back_to_sign_in': 'Back to sign in',
  'password_too_short': 'Password must be at least 8 characters.',
  'passwords_do_not_match': 'Passwords do not match.',
  'username_required': 'Name is required.',
  'account_created_toast': 'Account ready. Welcome to Saqqar.',

  // Change password
  'change_password': 'Change password',
  'current_password': 'Current password',
  'new_password': 'New password',
  'change_password_hint':
      'Use at least 8 characters. You\'ll stay signed in after the update.',
  'change_password_keep_signed_in':
      "You'll stay signed in after the update.",
  'current_password_wrong': 'Current password is incorrect.',
  'password_updated_toast': 'Password updated.',
  'update_password': 'Update password',

  // Inline credential request
  'inline_credential_request_title': 'Saqqar needs a credential',
  'inline_credential_request_body':
      'Pick a saved bundle or fill the form below. Saqqar uses the value for this turn only and stores it after approval.',
  'provide_credential': 'Provide credential',
  'use_existing_credential': 'Use a saved credential',
  'inline_credential_provided': 'Credential provided. Saqqar resumed.',
  'inline_credential_memorized':
      'Storage approval created. Approve it to memorize this credential.',
  'inline_credential_session':
      'Credential used for this conversation only.',

  // Inline pending approvals banner
  'review_approval': 'Review',

  // Chat header strip (web parity)
  'header_project': 'Project',
  'header_environment': 'Environment',
  'pick_project_first': 'Pick a project first',
  'no_projects_yet': '— No projects yet —',
  'no_environments_for_project': '— No environments —',
  'create_environment_cta': '+ Add environment',
  'create_environment_confirm_title': 'Create an environment?',
  'create_environment_confirm_body':
      "This project doesn't have any environments yet. Add one to start chatting in this project.",
  'header_none_option': '—',

  // Vault lifecycle (web saqqaar.com verbatim)
  'no_stored_credentials_title': 'No stored credentials.',
  'no_stored_credentials_body':
      'The agent will request the exact access it needs.',
  'project_name': 'Project name',
  'add_project': 'Add project',
  'add_project_hint': 'Add project…',
  'projects_title': 'Projects',
  'back_to_projects': 'All projects',
  'manage_projects': 'Manage projects',
  'project_saved_toast': 'Project saved.',
  'project_deleted_toast': 'Project deleted.',
  'delete_project_title': 'Delete project?',
  'add_environment': 'Add environment',
  'add_environment_hint': 'Add environment…',
  'environment_saved_toast': 'Environment saved.',
  'environment_deleted_toast': 'Environment deleted.',
  'delete_environment_title': 'Delete environment?',
  'save_credential_button': 'Save credential',
  'delete_credential_button': 'Delete credential',
  'credential_saved_toast': 'Credential saved.',
  'credential_deleted_toast': 'Credential deleted.',
  'delete_credential_title': 'Delete credential?',
  'delete_credential_body':
      'The agent will need to re-receive this credential the next time it asks.',
  'not_saved_yet': 'Not saved yet.',
  'test_connection': 'Test',
  'testing_connection': 'Testing connection…',
  'connection_verified': 'Connection verified.',
  'connection_failed': "Couldn't reach the target.",
  'no_fields_for_kind': 'No fields defined for this kind.',
  'no_environments': '— No environments —',
  'open_environment': 'Open',
  'flag_live': 'Live',
  'flag_read_only': 'Read-only',
  'flag_auto_approve': 'Auto-approve',
  'mark_env_live_title': 'Mark as LIVE environment?',
  'mark_as_live': 'Mark as LIVE',
  'env_search_hint': 'Search environments…',

  // Project / Environment
  'pick_environment': 'Pick an environment',
  'pick_environment_subtitle':
      'The credential the agent uses for this conversation.',
  'no_environment_picked': '— No environment —',
  'pick_environment_to_start': 'Pick an environment to start.',
  'environment_set_for_chat': 'Environment set for this chat.',
  'live_badge': 'LIVE',
  'read_only_badge': 'READ-ONLY',
  'auto_approve_badge': 'AUTO',
  'project': 'Project',
  'environment': 'Environment',
  'change_environment': 'Change environment',

  // Live environment confirmation
  'send_to_live': 'Send to live',
  'dont_ask_again': "Don't ask again for this environment",

  // Grouped approvals
  'pre_approval_tip':
      "Tip: clicking 'Approve all' also pre-approves every future write of the same shape in this conversation.",
  'show_individual_records': 'Show individual records',
  'hide_individual_records': 'Hide individual records',

  // Artifacts
  'artifact_ready': 'Artifact ready',

  // 404 conversation fallback
  'conversation_not_found_title': 'Conversation not found',
  'conversation_not_found_body':
      "This chat may have been deleted or you don't have access to it.",
  'back_to_chats': 'Back to chats',

  // Date-group headers
  'date_group_today': 'Today',
  'date_group_yesterday': 'Yesterday',
  'date_group_previous_7': 'Previous 7 days',
  'date_group_previous_30': 'Previous 30 days',
  'date_group_older': 'Older',

  // Activity status labels
  'activity_checking_odoo': 'Checking Odoo data',
  'activity_running_query': 'Running database query',
  'activity_building_report': 'Building Excel report',
  'activity_reading_repo': 'Reading repository files',
  'activity_running_command': 'Running server command',
  'activity_finishing_response': 'Finishing response',
  'activity_reviewing_attachment': 'Reviewing attachment',
  'activity_preparing_access': 'Preparing access',
  'activity_inspecting_odoo_model': 'Inspecting Odoo model',
  'activity_applying_odoo_change': 'Applying Odoo change',
  'activity_building_excel': 'Building Excel report',
  'activity_building_pdf': 'Building PDF document',
  'activity_building_word': 'Building Word document',
  'activity_preparing_approval': 'Preparing approval',
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
  'username': 'الاسم',
  'username_hint': 'اسمك بالكامل',
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
  'tab_vault': 'المشاريع',
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
  'switch_language_to_english': 'Switch language to English',
  'switch_language_to_arabic': 'التبديل إلى العربية',
  'switch_theme_to_light': 'التبديل للوضع الفاتح',
  'switch_theme_to_dark': 'التبديل للوضع الداكن',
  'english': 'English',
  'arabic': 'العربية',
  'system': 'النظام',
  'live': 'مباشر',
  'latest': 'الأحدث',
  'all': 'الكل',
  'archived': 'مؤرشف',
  'show_archived_action': 'عرض',
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
  'downloading_artifact': 'جاري التنزيل…',
  'artifact_no_viewer': 'مفيش تطبيق مثبت يقدر يفتح الملف ده.',
  'artifact_open_failed': 'تعذّر فتح الملف.',
  'artifact_download_failed': 'تعذّر تنزيل الملف. حاول مرة أخرى.',
  'more': 'المزيد',
  'share_link': 'رابط المشاركة',
  'rename': 'إعادة تسمية',
  'archive': 'أرشفة',
  'unarchive': 'إلغاء الأرشفة',
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
  'confirm_yes': 'نعم',
  'confirm_no': 'لا',
  'close': 'إغلاق',
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
  'deep_think': 'تفكير عميق',
  'deep_think_title': 'أعطِ صقاراً مساحة تفكير أوسع للأسئلة الأصعب.',
  'deep_think_on': 'تفكير عميق مفعَّل.',
  'deep_think_off': 'تفكير عميق متوقف.',
  'stop_generation': 'إيقاف الردّ',
  'generation_stopped': 'تم الإيقاف.',
  'stopping': 'جارِ الإيقاف…',
  'agent_working': 'يعمل',
  'agent_thinking': 'يعمل على طلبك.',
  'saqqar_thinking': 'صقّار يفكر',
  'thinking_steps_label': 'خطوات',
  'composer_busy': 'صقّار يعمل — اكتب مهمتك التالية، وسيُفعَّل الإرسال عند الانتهاء.',
  'save_and_continue': 'حفظ ومتابعة',
  'credential_saved_continuing': 'تم حفظ البيانات — صقّار يكمل العمل.',
  'server_activity': 'نشاط الخادم',
  'server_activity_failed': 'نشاط الخادم (فشل)',
  'no_server_activity': 'لا توجد أوامر خادم بعد.',
  'no_server_activity_body':
      'عندما يُنفّذ صقّار أمر شل، ستظهر المخرجات هنا.',
  'copy_command': 'نسخ الأمر',
  'copy_stdout': 'نسخ المخرجات',
  'copied': 'تم النسخ.',
  'untitled_conversation': 'محادثة بدون عنوان',
  'coming_soon_badge': 'قريباً',
  'coming_soon_toast': 'هذا الإجراء يصل في الإصدار القادم.',
  'rename_conversation': 'إعادة تسمية المحادثة',
  'open_conversations': 'فتح المحادثات',
  'open_approvals': 'فتح الموافقات',
  'sidebar_title': 'المحادثات',
  'inbox_title': 'صندوق الوارد',
  'you_label': 'أنت',
  'brand_eyebrow': 'صقّار',
  'today_label': 'اليوم',
  'older_label': 'الأقدم',
  'no_matches': 'لا توجد نتائج.',
  'rename_conversation_hint': 'اكتب عنوانًا جديدًا…',
  'conversation_renamed_toast': 'تم تغيير اسم المحادثة.',
  'conversation_pinned_toast': 'تم التثبيت في الأعلى.',
  'conversation_unpinned_toast': 'تم إلغاء التثبيت.',
  'pin_conversation': 'تثبيت في الأعلى',
  'unpin_conversation': 'إلغاء التثبيت',
  'pinned': 'مثبتة',
  'delete_needs_confirmation': 'الحذف يحتاج تأكيد في الإنتاج.',
  'attached_files_for_review': 'تم إرفاق الملفات للمراجعة.',
  'default_api_error': 'حدث خطأ. حاول مرة أخرى.',
  'loading': 'جارٍ التحميل…',
  // ── Typed error categories ──
  'error_network': 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.',
  'error_timeout': 'استغرق الخادم وقتاً طويلاً. حاول مرة أخرى.',
  'error_cancelled': 'تم إلغاء العملية.',
  'error_unauthorized': 'انتهت جلستك. سجّل الدخول من جديد.',
  'error_forbidden': 'ليس لديك صلاحية لتنفيذ هذه العملية.',
  'error_not_found': 'لم نتمكن من العثور على المطلوب.',
  'error_validation': 'بعض الحقول تحتاج للمراجعة.',
  'error_conflict': 'هذه العملية تتعارض مع البيانات الحالية. حدّث الصفحة ثم حاول مجدداً.',
  'error_rate_limited': 'محاولات كثيرة. تمهّل قليلاً.',
  'error_rate_limited_with_retry': 'محاولات كثيرة. حاول بعد {seconds} ثانية.',
  'error_payload_too_large': 'الملف كبير جداً. الحد الأقصى 25 ميجابايت.',
  'error_server': 'وقعت مشكلة في الخادم. حاول بعد قليل.',
  'error_unknown': 'حدث خطأ. حاول مرة أخرى.',
  // ── Vault action labels (prefixes) ──
  'vault_action_load_failed': 'تعذّر تحميل مشاريعك',
  'vault_action_create_project_failed': 'تعذّر إنشاء المشروع',
  'vault_action_rename_project_failed': 'تعذّر إعادة تسمية المشروع',
  'vault_action_delete_project_failed': 'تعذّر حذف المشروع',
  'vault_action_create_environment_failed': 'تعذّر إنشاء البيئة',
  'vault_action_update_environment_failed': 'تعذّر تحديث البيئة',
  'vault_action_delete_environment_failed': 'تعذّر حذف البيئة',
  'vault_action_load_credentials_failed': 'تعذّر تحميل بيانات الدخول',
  'vault_action_save_credential_failed': 'تعذّر حفظ بيانات الدخول',
  'vault_action_delete_credential_failed': 'تعذّر حذف بيانات الدخول',
  // ── Vault success toasts ──
  'vault_toast_project_created': 'تم إنشاء المشروع.',
  'vault_toast_project_deleted': 'تم حذف المشروع.',
  'vault_toast_environment_created': 'تم إنشاء البيئة.',
  'vault_toast_environment_deleted': 'تم حذف البيئة.',
  'vault_toast_credential_saved': 'تم حفظ بيانات الدخول.',
  'vault_toast_credential_deleted': 'تم حذف بيانات الدخول.',
  // ── Conversations action labels + toasts (Phase 4) ──
  'conversations_action_load_failed': 'تعذّر تحميل محادثاتك',
  'conversations_action_create_failed': 'تعذّر إنشاء المحادثة',
  'conversations_action_rename_failed': 'تعذّر إعادة تسمية المحادثة',
  'conversations_action_archive_failed': 'تعذّر أرشفة المحادثة',
  'conversations_action_unarchive_failed': 'تعذّر استعادة المحادثة',
  'conversations_action_delete_failed': 'تعذّر حذف المحادثة',
  'conversations_action_stop_failed': 'تعذّر إيقاف المحادثة',
  'conversation_created_toast': 'بدأت المحادثة.',
  'conversation_archived_toast': 'تمت أرشفة المحادثة.',
  'conversation_unarchived_toast': 'تمت استعادة المحادثة.',
  'conversation_deleted_toast': 'تم حذف المحادثة.',
  'conversation_stopped_toast': 'تم إيقاف الجيل.',
  'signed_in_toast': 'تم تسجيل الدخول.',
  'signed_out_toast': 'تم تسجيل الخروج.',
  'session_ended_toast': 'انتهت جلستك. سجّل الدخول من جديد.',
  'sign_out_confirm_title': 'تسجيل الخروج',
  'sign_out_confirm_body':
      'هتحتاج تسجّل الدخول من جديد عشان توصل لمشاريعك ومحادثاتك.',
  'signing_out': 'جاري تسجيل الخروج…',
  'exit_app_confirm_title': 'الخروج من صقّار',
  'exit_app_confirm_body': 'هل أنت متأكد من إغلاق التطبيق؟',
  'auth_invalid_credentials': 'البريد أو كلمة المرور غير صحيحة.',
  'auth_email_taken': 'هذا البريد مستخدم بالفعل.',
  'auth_network_error': 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.',
  'auth_rate_limited': 'محاولات كثيرة. جرّب بعد لحظات.',
  'auth_booting_session': 'جارٍ استعادة الجلسة…',
  'email_label': 'البريد الإلكتروني',
  'email_required': 'البريد الإلكتروني مطلوب.',
  'email_invalid': 'البريد الإلكتروني غير صحيح.',
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
  'no_archived_conversations': 'لا توجد محادثات مؤرشفة',
  'start_conversation': 'ابدأ محادثة',
  'send': 'إرسال',
  'auto_approve': 'موافقة تلقائية',
  'credential_vault': 'المشاريع',
  'no_credentials': 'لا توجد بيانات دخول',
  'no_credentials_hint': 'أضف واحدة ليستطيع صقّار العمل على أنظمتك.',
  'add_credential': 'إضافة بيانات دخول',
  'edit_credential': 'تعديل بيانات الدخول',
  'save_credential': 'حفظ البيانات',
  'update_credential': 'تحديث البيانات',
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
  'suggest_user_count': 'كم عدد المستخدمين في أودو الآن؟',
  'suggest_export_users': 'صدّر المستخدمين الداخليين النشطين كملف Excel.',
  'suggest_tail_log': 'اعرض آخر 100 سطر من سجل سيرفر أودو.',
  'empty_chat_title': 'ما الذي نعمل عليه؟',
  'empty_chat_body': 'اضغط على اقتراح أو اكتب ما تحتاجه.',
  'suggest_explore_title': 'استكشف بياناتي',
  'suggest_explore_sub': 'تصفّح النماذج والحقول والسجلات.',
  'suggest_explore_prompt':
      'اعرض أعلى 10 عملاء من حيث إجمالي الفواتير هذا العام مع رصيدهم المتبقي.',
  'suggest_summarize_title': 'لخّص مستندًا',
  'suggest_summarize_sub': 'ارفع ملف PDF أو Word أو Excel.',
  'suggest_summarize_prompt':
      'لخّص المستند المرفق في 5 نقاط وأشِر إلى أي مخاطر أو أسئلة مفتوحة.',
  'suggest_report_title': 'أنشئ تقريرًا',
  'suggest_report_sub': 'صدّر Excel أو PDF أو Word.',
  'suggest_report_prompt':
      'أنشئ تقرير مبيعات للشهر الماضي مجمّعًا حسب البائع، وصدّره كملف Excel.',
  'suggest_server_logs_title': 'افحص سجلات السيرفر',
  'suggest_server_logs_sub': 'اعرض السجلات أو نفّذ أمرًا على السيرفر.',
  'suggest_server_logs_prompt':
      'اعرض آخر 200 سطر من سجل سيرفر أودو وأبرز أي أخطاء أو تحذيرات.',
  'remove_attachment': 'إزالة المرفق',
  'offline_title': 'لا يوجد اتصال',
  'offline_body': 'صقّار يحتاج اتصال مباشر للعمل.',
  'ask_saqqar_anything': 'اسأل صقّار أي حاجة',
  'link_copied': 'تم نسخ الرابط.',
  'date_today': 'اليوم',
  'date_yesterday': 'أمس',
  'inbox_refreshed': 'تم تحديث الوارد.',
  'role_you': 'أنت',
  'role_assistant': 'صقّار',
  'role_tool': 'أداة',
  'role_system': 'النظام',
  'standard_user': 'مستخدم عادي',
  'staff_user': 'فريق العمل',
  'admin_user': 'مسؤول',
  'account_joined_label': 'تاريخ الانضمام',
  'account_last_login_label': 'آخر تسجيل دخول',
  'open_storybook': 'فتح Storybook',
  'conversations_coverage_title': 'المحادثات',
  'conversations_coverage_body':
      'بحث وأرشفة وإعادة تسمية ومشاركة وفتح سجلات العمل كاملة.',
  'vault_coverage_title': 'المشاريع',
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

  // Sign up
  'sign_up_title': 'جهز مساحتك الخاصة',
  'sign_up_subtitle': 'أنشئ حسابك لتبدأ استخدام مساعد العمليات.',
  'confirm_password': 'تأكيد كلمة المرور',
  'confirm_password_hint': 'كرّر كلمة المرور',
  'email_optional': 'البريد الإلكتروني (اختياري)',
  'email_hint': 'you@example.com',
  'create_account_button': 'إنشاء الحساب',
  'already_have_account': 'لديك حساب بالفعل؟',
  'back_to_sign_in': 'الرجوع لتسجيل الدخول',
  'password_too_short': 'كلمة المرور لازم تكون 8 أحرف على الأقل.',
  'passwords_do_not_match': 'كلمتا المرور غير متطابقتين.',
  'username_required': 'الاسم مطلوب.',
  'account_created_toast': 'تم إنشاء الحساب. أهلاً بك في صقّار.',

  // Change password
  'change_password': 'تغيير كلمة المرور',
  'current_password': 'كلمة المرور الحالية',
  'new_password': 'كلمة المرور الجديدة',
  'change_password_hint':
      'استخدم 8 أحرف على الأقل. ستبقى مسجلاً للدخول بعد التحديث.',
  'change_password_keep_signed_in': 'ستبقى مسجلاً للدخول بعد التحديث.',
  'current_password_wrong': 'كلمة المرور الحالية غير صحيحة.',
  'password_updated_toast': 'تم تحديث كلمة المرور.',
  'update_password': 'تحديث كلمة المرور',

  // Inline credential request
  'inline_credential_request_title': 'صقّار يحتاج بيانات دخول',
  'inline_credential_request_body':
      'اختر حزمة محفوظة أو املأ الحقول. يستخدمها صقّار لهذه الخطوة فقط ويحفظها بعد الموافقة.',
  'provide_credential': 'تقديم بيانات الدخول',
  'use_existing_credential': 'استخدم بيانات دخول محفوظة',
  'inline_credential_provided': 'تم تقديم البيانات. صقّار استأنف العمل.',
  'inline_credential_memorized':
      'تم إنشاء طلب موافقة على الحفظ. وافِق عليه لتثبيت هذه البيانات للمحادثات المستقبلية.',
  'inline_credential_session':
      'سيتم استخدام هذه البيانات لهذه المحادثة فقط.',

  // Inline pending approvals banner
  'review_approval': 'مراجعة',

  // Chat header strip
  'header_project': 'المشروع',
  'header_environment': 'البيئة',
  'pick_project_first': 'اختر مشروعًا أولاً',
  'no_projects_yet': '— لا توجد مشاريع بعد —',
  'no_environments_for_project': '— لا توجد بيئات —',
  'create_environment_cta': '+ أضف بيئة',
  'create_environment_confirm_title': 'هل تريد إنشاء بيئة؟',
  'create_environment_confirm_body':
      'هذا المشروع ليس لديه أي بيئات بعد. أضف بيئة لتبدأ المحادثة في هذا المشروع.',
  'header_none_option': '—',

  // Vault lifecycle
  'no_stored_credentials_title': 'لا توجد بيانات دخول مخزّنة.',
  'no_stored_credentials_body':
      'سيطلب الوكيل الصلاحيات التي يحتاجها عند اللزوم.',
  'project_name': 'اسم المشروع',
  'add_project': 'إضافة مشروع',
  'add_project_hint': 'أضف مشروعًا…',
  'projects_title': 'المشاريع',
  'back_to_projects': 'كل المشاريع',
  'manage_projects': 'إدارة المشاريع',
  'project_saved_toast': 'تم حفظ المشروع.',
  'project_deleted_toast': 'تم حذف المشروع.',
  'delete_project_title': 'حذف المشروع؟',
  'add_environment': 'إضافة بيئة',
  'add_environment_hint': 'أضف بيئة…',
  'environment_saved_toast': 'تم حفظ البيئة.',
  'environment_deleted_toast': 'تم حذف البيئة.',
  'delete_environment_title': 'حذف البيئة؟',
  'save_credential_button': 'حفظ البيانات',
  'delete_credential_button': 'حذف البيانات',
  'credential_saved_toast': 'تم حفظ البيانات.',
  'credential_deleted_toast': 'تم حذف البيانات.',
  'delete_credential_title': 'حذف البيانات؟',
  'delete_credential_body':
      'سيحتاج الوكيل لإعادة استلام بيانات الدخول هذه عند طلبها مرة أخرى.',
  'not_saved_yet': 'لم تُحفظ بعد.',
  'test_connection': 'اختبار',
  'testing_connection': 'جارٍ اختبار الاتصال…',
  'connection_verified': 'تم التحقق من الاتصال.',
  'connection_failed': 'تعذّر الوصول للهدف.',
  'no_fields_for_kind': 'لا توجد حقول معرّفة لهذا النوع.',
  'no_environments': '— لا توجد بيئات —',
  'open_environment': 'فتح',
  'flag_live': 'مباشر',
  'flag_read_only': 'قراءة فقط',
  'flag_auto_approve': 'موافقة تلقائية',
  'mark_env_live_title': 'تفعيل البيئة كمباشرة؟',
  'mark_as_live': 'تفعيل كمباشرة',
  'env_search_hint': 'ابحث في البيئات…',

  // Project / Environment
  'pick_environment': 'اختر بيئة',
  'pick_environment_subtitle': 'بيانات الدخول التي سيستخدمها الوكيل لهذه المحادثة.',
  'no_environment_picked': '— لا توجد بيئة —',
  'pick_environment_to_start': 'اختر بيئة للبدء.',
  'environment_set_for_chat': 'تم تعيين البيئة لهذه المحادثة.',
  'live_badge': 'مباشر',
  'read_only_badge': 'قراءة فقط',
  'auto_approve_badge': 'تلقائي',
  'project': 'المشروع',
  'environment': 'البيئة',
  'change_environment': 'تغيير البيئة',

  // Live environment confirmation
  'send_to_live': 'إرسال للمباشر',
  'dont_ask_again': 'لا تسألني مرة أخرى لهذه البيئة',

  // Grouped approvals
  'pre_approval_tip':
      'تنبيه: الضغط على "وافق على الكل" يوافق مسبقاً على أي كتابة لاحقة لها نفس الشكل في هذه المحادثة.',
  'show_individual_records': 'عرض السجلات الفردية',
  'hide_individual_records': 'إخفاء السجلات الفردية',

  // Artifacts
  'artifact_ready': 'الملف جاهز',

  // 404 conversation fallback
  'conversation_not_found_title': 'لم يتم العثور على المحادثة',
  'conversation_not_found_body':
      'قد تكون هذه المحادثة محذوفة أو ليس لديك صلاحية للوصول إليها.',
  'back_to_chats': 'العودة للمحادثات',

  // Date-group headers
  'date_group_today': 'اليوم',
  'date_group_yesterday': 'أمس',
  'date_group_previous_7': 'آخر 7 أيام',
  'date_group_previous_30': 'آخر 30 يومًا',
  'date_group_older': 'الأقدم',

  // Activity status labels
  'activity_checking_odoo': 'يفحص بيانات أودو',
  'activity_running_query': 'ينفّذ استعلام قاعدة البيانات',
  'activity_building_report': 'يُجهز تقرير Excel',
  'activity_reading_repo': 'يقرأ ملفات المستودع',
  'activity_running_command': 'ينفّذ أمر على السيرفر',
  'activity_finishing_response': 'يُنهي الرد',
  'activity_reviewing_attachment': 'يراجع المرفق',
  'activity_preparing_access': 'يُجهّز الوصول',
  'activity_inspecting_odoo_model': 'يفحص نموذج أودو',
  'activity_applying_odoo_change': 'يُطبّق تعديلاً على أودو',
  'activity_building_excel': 'يُجهز تقرير Excel',
  'activity_building_pdf': 'يُجهز مستند PDF',
  'activity_building_word': 'يُجهز مستند Word',
  'activity_preparing_approval': 'يُجهّز طلب موافقة',
};
