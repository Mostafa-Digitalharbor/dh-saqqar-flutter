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

  /// Public form of [_isArabic] for callers that need to pick a locale-keyed
  /// value off a model (e.g. an approval's `{en, ar}` model label).
  bool get isArabic => _isArabic;

  Map<String, String> get _table => _isArabic ? _ar : _en;

  String _t(String key) => _table[key] ?? _en[key] ?? key;

  /// [_t] plus `{placeholder}` substitution.
  ///
  /// Interpolated copy used to be written as an inline
  /// `_isArabic ? 'منذ $n د' : '$n m ago'` ternary. That works, but it puts
  /// the Arabic *outside* the `_ar` table, where `i18n_parity_test` cannot
  /// see it — so a missing or drifted translation in one of those getters
  /// was invisible to the guard that exists precisely to catch it. Routing
  /// them through a keyed template restores that coverage.
  ///
  /// Uses `replaceAll`, not `replaceFirst`, so a template may repeat a
  /// placeholder; unknown placeholders are left verbatim rather than
  /// blanked, which makes a typo visible in review instead of silently
  /// dropping the value.
  String _f(String key, Map<String, Object?> vars) {
    var out = _t(key);
    for (final entry in vars.entries) {
      out = out.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return out;
  }

  /// Public lookup by raw key. Used by schema-driven UIs (e.g. the
  /// credential form) where the field schema carries the i18n key
  /// directly instead of mapping through a typed getter. Returns
  /// [fallback] when neither the active locale nor the English table
  /// has an entry — never returns the raw key (which would leak the
  /// underscore_case identifier into the UI).
  String lookup(String key, {String fallback = ''}) {
    if (key.isEmpty) return fallback;
    return _table[key] ?? _en[key] ?? fallback;
  }

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

  // Company / Environment (matches web saqqaar.com data model)
  String get pickEnvironment => _t('pick_environment');
  String get pickEnvironmentSubtitle => _t('pick_environment_subtitle');
  String get noEnvironmentPicked => _t('no_environment_picked');
  String get pickEnvironmentToStart => _t('pick_environment_to_start');
  String get environmentSetForChat => _t('environment_set_for_chat');
  String get liveBadge => _t('live_badge');
  String get readOnlyBadge => _t('read_only_badge');
  String get autoApproveBadge => _t('auto_approve_badge');
  // Getter and key stay `project` — they are identifiers, not copy. Only the
  // English/Arabic VALUES were renamed to "Company"/"الشركة"; renaming the key
  // would break `_t` (no such entry) and renaming the getter would break every
  // call site. The wire model is still `projects` on the backend too.
  String get project => _t('project');
  String get environment => _t('environment');
  String get changeEnvironment => _t('change_environment');

  // Multi-environment selection (mirrors web's multi-select env dropdown)
  String get envMultiTitle => _t('env_multi_title');
  String get envMultiSubtitle => _t('env_multi_subtitle');
  String get envMultiApply => _t('env_multi_apply');
  String get envMultiUpdated => _t('env_multi_updated');
  String get envMultiNone => _t('env_multi_none');
  String envMultiSelectedCount(int n) =>
      _f('env_multi_selected_count', {'n': n});
  String envMultiExtra(int n) => _f('env_multi_extra', {'n': n});

  // Inline pending approvals banner (above composer)
  String get reviewApproval => _t('review_approval');
  String morePendingApprovals(int n) =>
      _f('more_pending_approvals', {'n': n});

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
  /// dozens of companies. Drops the locale-specific pluralisation that
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
      ? 'حذف الشركة "$name"؟ ستُحذف البيئات وبيانات الدخول المرتبطة بها.'
      : 'Delete company "$name"? Environments and their credentials are deleted with it.';

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
  String lastVerifiedAt(String at) => _f('last_verified_at', {'at': at});

  /// Relative-time label like "2 hours ago" / "just now" — used inline by
  /// the credential form's "Last verified" hint.
  // NOTE: relative-time formatting lives in `AppDateFormat.relative`, not
  // here. A second implementation used to sit at this spot and was the
  // app's only source of `منذ 5 دقيقة` — Western digits inside Arabic copy —
  // because it interpolated ints directly instead of going through
  // `NumberFormat`, and hardcoded its Arabic inline instead of `_t()`, so
  // the i18n parity test couldn't see it either. Its one caller (the vault's
  // "last verified" hint) now uses AppDateFormat like everything else.

  // Credential form: Test connection
  // (deprecated short labels — replaced by the camelCase keys below
  // that mirror the server bundle from SAQQAR_MOBILE_API_xmlrpc.md §7.
  // Kept the call-site name; just changed the lookup key.)
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
  String similarRequestsCount(int count) =>
      _f('similar_requests_count', {'count': count});
  String operationOnModel(String operation, String model) =>
      _f('operation_on_model', {'operation': operation, 'model': model});
  String approveAllN(int count) => _f('approve_all_n', {'count': count});
  String rejectAllN(int count) => _f('reject_all_n', {'count': count});
  String get preApprovalTip => _t('pre_approval_tip');
  String get approveAllSimilar => _t('approve_all_similar');
  String approvalBatchResolved(int count) =>
      _f('approval_batch_resolved', {'count': count});
  String get showIndividualRecords => _t('show_individual_records');
  String get hideIndividualRecords => _t('hide_individual_records');
  String approvalGrantedWithPreapproval(int count) =>
      _f('approval_granted_with_preapproval', {'count': count});

  // Live environment confirmation (web one-shot warning)
  String liveWarningTitle(String envName) =>
      _f('live_warning_title', {'envName': envName});
  String liveWarningBody(String envName, String projectName) => _f(
        'live_warning_body',
        {'envName': envName, 'projectName': projectName},
      );
  String get sendToLive => _t('send_to_live');
  String get dontAskAgain => _t('dont_ask_again');

  // Tabs
  String get tabChats => _t('tab_chats');
  String get tabVault => _t('tab_vault');
  String get tabInbox => _t('tab_inbox');
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
  String get defaultProjectLabel => _t('default_project_label');

  /// Stand-in for a conversation preview whose last message is a machine
  /// payload (tool result / approval request) rather than readable prose.
  String get conversationPreviewUnavailable =>
      _t('conversation_preview_unavailable');
  String get artifactDownloadFailed => _t('artifact_download_failed');
  String get artifactDownloadOffline => _t('artifact_download_offline');
  String get artifactDownloadGone => _t('artifact_download_gone');
  String get artifactDownloadForbidden => _t('artifact_download_forbidden');

  /// Status-specific copy for a failed artifact download so the user learns
  /// the actual cause: no status → offline, 403 → plan-gated, 404 → the link
  /// expired, anything else → the generic retry message.
  String artifactDownloadMessage(int? statusCode) => switch (statusCode) {
        null => artifactDownloadOffline,
        403 => artifactDownloadForbidden,
        404 => artifactDownloadGone,
        _ => artifactDownloadFailed,
      };
  String get more => _t('more');
  String get shareLink => _t('share_link');
  String get rename => _t('rename');
  String get archive => _t('archive');
  String get unarchive => _t('unarchive');
  String get delete => _t('delete');
  String get deleteConversationTitle => _t('delete_conversation_title');
  String get deleteConversationBody => _t('delete_conversation_body');
  String get edit => _t('edit');
  String get dismiss => _t('dismiss');
  String get open => _t('open');
  String get approve => _t('approve');
  String get reject => _t('reject');
  String get showDetails => _t('show_details');
  String get hideDetails => _t('hide_details');
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
  String get sharedConversationTitle => _t('shared_conversation_title');
  String get sharedConversationEmpty => _t('shared_conversation_empty');

  /// Caption under the shared-transcript header. [token] is the opaque
  /// share id from the `saqqar://share/<token>` deep link — it's an
  /// identifier, so it stays verbatim in both locales; only the label
  /// around it translates.
  String shareTokenLabel(String token) =>
      _f('share_token_label', {'token': token});
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
  String get clearSearch => _t('clear_search');
  String get previousPage => _t('previous_page');
  String get nextPage => _t('next_page');
  String get firstPage => _t('first_page');
  String get conversationActions => _t('conversation_actions');
  String get credentialActions => _t('credential_actions');
  String get attachFiles => _t('attach_files');
  String get attachSourceTitle => _t('attach_source_title');
  String get attachSourcePhotos => _t('attach_source_photos');
  String get attachSourcePhotosHint => _t('attach_source_photos_hint');
  String get attachSourceCamera => _t('attach_source_camera');
  String get attachSourceCameraHint => _t('attach_source_camera_hint');
  String get attachSourceFiles => _t('attach_source_files');
  String get attachSourceFilesHint => _t('attach_source_files_hint');
  String get attachCameraDenied => _t('attach_camera_denied');
  String get viewerOpenExternally => _t('viewer_open_externally');
  String get viewerUnsupportedTitle => _t('viewer_unsupported_title');
  String get viewerUnsupportedBody => _t('viewer_unsupported_body');
  String get viewerLoadFailed => _t('viewer_load_failed');
  String get viewerTruncated => _t('viewer_truncated');
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
  // Email-approval preview — labels for the recipient rows.
  String get emailPreviewTo => _t('email_preview_to');
  String get emailPreviewCc => _t('email_preview_cc');
  String get emailPreviewBcc => _t('email_preview_bcc');
  String get emailPreviewReply => _t('email_preview_reply');
  // Destructive-delete type-to-confirm (web parity — `renderDeleteApproval`).
  // The phrase itself is the localized Delete verb + the record count, e.g.
  // "Delete 6" / "حذف 6"; `delete_confirmation.dart` folds Arabic-Indic
  // digits so ٦ matches 6 when the user types on an Arabic keyboard.
  String get deleteConfirmTitle => _t('delete_confirm_title');
  String deleteConfirmBody(int count, String phrase) =>
      _f('delete_confirm_body', {'count': count, 'phrase': phrase});
  String deleteConfirmHint(String phrase) =>
      _f('delete_confirm_hint', {'phrase': phrase});
  String deleteConfirmMismatch(String phrase) =>
      _f('delete_confirm_mismatch', {'phrase': phrase});

  /// The exact phrase the user must type to confirm deleting [count] records.
  String deleteConfirmPhrase(int count) => '${_t('approval_op_delete')} $count';

  // Task prep — global composer toggle. Web parity for `#taskPrepToggle`;
  // replaced Deep think, which the web removed (the backend escalates hard
  // tasks to the stronger model with no manual switch).
  String get taskPrep => _t('task_prep');
  String get taskPrepTitle => _t('task_prep_title');
  String get taskPrepOn => _t('task_prep_on');
  String get taskPrepOff => _t('task_prep_off');
  // Saqqar tools sheet — the composer's `+` menu (web `renderShadowMenu`).
  String get toolsTitle => _t('tools_title');
  String get toolsUploadFile => _t('tools_upload_file');
  String get toolsModesSection => _t('tools_modes_section');
  String get toolsOdooSection => _t('tools_odoo_section');
  String get toolsConnectSection => _t('tools_connect_section');
  String get toolsReadonlyNote => _t('tools_readonly_note');
  String get toolsNeedsConversation => _t('tools_needs_conversation');

  // §8 — voice support workspace
  String get voiceSupportTitle => _t('voice_support_title');
  String get voiceSupportIntro => _t('voice_support_intro');
  String get voiceSupportHint => _t('voice_support_hint');
  String get voiceSupportSubmit => _t('voice_support_submit');
  String get voiceSupportSummary => _t('voice_support_summary');
  String get voiceSupportDiagnosis => _t('voice_support_diagnosis');
  String get voiceSupportReply => _t('voice_support_reply');
  String get voiceSupportSteps => _t('voice_support_steps');
  String get voiceSupportQuestions => _t('voice_support_questions');
  String get voiceSupportFileTicket => _t('voice_support_file_ticket');
  String get voiceSupportTicketConfirmTitle =>
      _t('voice_support_ticket_confirm_title');
  String get voiceSupportTicketConfirmBody =>
      _t('voice_support_ticket_confirm_body');
  String get voiceSupportTicketCreated => _t('voice_support_ticket_created');
  String get voiceSupportTaskCreated => _t('voice_support_task_created');
  String get voiceSupportTicketNotCreated =>
      _t('voice_support_ticket_not_created');
  String get voiceSupportEmpty => _t('voice_support_empty');
  String get toolsPromptBank => _t('tools_prompt_bank');
  String get toolsHealthRadar => _t('tools_health_radar');
  String get toolsWhatIf => _t('tools_what_if');
  String get toolsBusinessPulse => _t('tools_business_pulse');
  String get toolsMyDatabase => _t('tools_my_database');
  String get toolsVoiceSupport => _t('tools_voice_support');
  // The request each §6 row sends. Authored here, not by the server — see the
  // note on the values. One string each to correct when the web team replies.
  // Interactive in-chat cards — dispatched on `message.tool_payload.kind`.
  String get clarifyTitle => _t('clarify_title');
  String get clarifySomethingElse => _t('clarify_something_else');
  String get clarifyBuildSend => _t('clarify_build_send');
  String get clarifyPrepareReview => _t('clarify_prepare_review');
  String get clarifyNeedsAnswer => _t('clarify_needs_answer');
  String get clarifyAnswersHeader => _t('clarify_answers_header');
  String get clarifyReadyToReview => _t('clarify_ready_to_review');
  String get suggestionTitle => _t('suggestion_title');
  String get suggestionApprove => _t('suggestion_approve');
  String get suggestionKeepMine => _t('suggestion_keep_mine');
  String get reportTitle => _t('report_title');
  String get reportType => _t('report_type');
  String get reportPeriod => _t('report_period');
  String get reportLens => _t('report_lens');
  String get reportFormat => _t('report_format');
  String get reportRecords => _t('report_records');
  String get reportPickRecords => _t('report_pick_records');
  String get reportSearchRecords => _t('report_search_records');
  String get reportNoRecords => _t('report_no_records');
  String get reportBuild => _t('report_build');
  String get reportNeedsType => _t('report_needs_type');
  String reportRecordsTruncated(int count) =>
      _f('report_records_truncated', {'count': count});
  String reportSelectedCount(int count) =>
      _f('report_selected_count', {'count': count});

  /// The report request the card composes and sends as a normal message.
  /// Optional parts (lens, ticked records) are appended only when present so
  /// the message never carries an empty "View: " line.
  String reportCompose({
    required String type,
    required String period,
    required String format,
    String? lens,
    String? records,
  }) {
    final buffer = StringBuffer(
      _f('report_compose', {
        'type': type,
        'period': period,
        'format': format,
      }),
    );
    if (lens != null && lens.isNotEmpty) {
      buffer.write(_f('report_compose_lens', {'lens': lens}));
    }
    if (records != null && records.isNotEmpty) {
      buffer.write(_f('report_compose_records', {'names': records}));
    }
    return buffer.toString();
  }
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
  String get saqqarWorkingNow => _t('saqqar_working_now');
  String get thinkingStepsLabel => _t('thinking_steps_label');
  String get composerBusy => _t('composer_busy');
  // Long-running report progress (run_progress.phase = building_report /
  // rendering_report). Shown on the typing row while Excel/PDF/Word
  // generation is in flight.
  String phaseFetching(int current, int? total) {
    if (total == null) return _f('phase_fetching', {'current': current});
    final pct = ((current / total) * 100).round().clamp(0, 100);
    return _f('phase_fetching_of_total', {
      'current': current,
      'total': total,
      'pct': pct,
    });
  }

  String phaseRendering(int? rows) => rows == null
      ? _t('phase_rendering')
      : _f('phase_rendering_rows', {'rows': rows});
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

  /// Shown when the server answered but the body didn't match our models.
  /// Names "update the app" because retrying replays the same mismatch.
  String get errorUnexpectedResponse => _t('error_unexpected_response');
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
  String get errorQuotaExceeded => _t('error_quota_exceeded');
  String get errorUnsupportedMedia => _t('error_unsupported_media');
  String get errorServer => _t('error_server');
  String get errorSocialNotConfigured => _t('error_social_not_configured');
  String get errorSocialNoToken => _t('error_social_no_token');
  String get errorSocialRejected => _t('error_social_rejected');
  String get errorUnknown => _t('error_unknown');

  /// Copy for the last-resort crash screen ([AppErrorScreen], wired to
  /// `ErrorWidget.builder`). That screen can mount before the app's
  /// Localizations are in scope, so it resolves these defensively and
  /// falls back to the English text inline — keep the English here and
  /// the fallback there in sync.
  String get crashScreenTitle => _t('crash_screen_title');
  String get crashScreenBody => _t('crash_screen_body');

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
  String get conversationsActionShareFailed =>
      _t('conversations_action_share_failed');

  // Chat action-failure labels — the "what failed" line a failed chat
  // mutation surfaces (paired with the mapped "why" from ApiErrorMapper).
  String get chatActionSendFailed => _t('chat_action_send_failed');
  String get chatActionUploadFailed => _t('chat_action_upload_failed');
  String get chatActionStopFailed => _t('chat_action_stop_failed');
  String get chatActionShareFailed => _t('chat_action_share_failed');
  String get chatActionRevokeShareFailed =>
      _t('chat_action_revoke_share_failed');
  String get chatActionCredentialFailed =>
      _t('chat_action_credential_failed');
  String get chatActionDismissFailed => _t('chat_action_dismiss_failed');

  // Chats list filter chips
  String get filterAll => _t('filter_all');
  String get filterNeedsApproval => _t('filter_needs_approval');

  // Notifications bell (page scaffold)
  String get notifications => _t('notifications');
  String get noNewNotifications => _t('no_new_notifications');
  String get notificationsClear => _t('notifications_clear');
  String get notificationsEmptyTitle => _t('notifications_empty_title');
  String get notificationsEmptyBody => _t('notifications_empty_body');
  String get notifFilterAll => _t('notif_filter_all');
  String get notifFilterApprovals => _t('notif_filter_approvals');
  String get notifFilterTasks => _t('notif_filter_tasks');
  String get notifFilterReports => _t('notif_filter_reports');
  String get notifGroupToday => _t('notif_group_today');
  String get notifGroupYesterday => _t('notif_group_yesterday');
  String get notifGroupEarlier => _t('notif_group_earlier');
  String get notificationsSettingTitle => _t('notifications_setting_title');
  String get notificationsSettingSubtitle =>
      _t('notifications_setting_subtitle');

  // Android notification channels — rendered by the OS in system Settings,
  // not by us. Read via `PlatformStrings` (no BuildContext out there).
  String get pushChannelApprovalsName => _t('push_channel_approvals_name');
  String get pushChannelApprovalsDescription =>
      _t('push_channel_approvals_description');
  String get pushChannelUpdatesName => _t('push_channel_updates_name');
  String get pushChannelUpdatesDescription =>
      _t('push_channel_updates_description');

  // Apple Watch bridge — drawn on the watch face, which has no widget tree
  // of its own. Also read via `PlatformStrings`.
  String get watchErrorNoSpeech => _t('watch_error_no_speech');
  String get watchErrorUnreachable => _t('watch_error_unreachable');
  String get watchErrorProjectsLoad => _t('watch_error_projects_load');
  String get watchErrorProjectSetup => _t('watch_error_project_setup');
  String get accountUsage => _t('account_usage');
  String get accountSeePlans => _t('account_see_plans');
  String get usageTitle => _t('usage_title');
  String get devicesTitle => _t('devices_title');
  String get devicesManage => _t('devices_manage');
  String get devicesEmptyTitle => _t('devices_empty_title');
  String get devicesEmptyBody => _t('devices_empty_body');
  String get deviceRevoke => _t('device_revoke');
  String get deviceRevoked => _t('device_revoked');
  String get deviceRevokeFailed => _t('device_revoke_failed');
  String deviceLastSeen(String when) =>
      _t('device_last_seen').replaceFirst('{when}', when);

  // Slash-command sheet (composer "/" menu)
  String get commandsHeader => _t('commands_header');
  String get commands => _t('commands');
  String get noResults => _t('no_results');
  String get searchMessagesHint => _t('search_messages_hint');
  String get searchInConversation => _t('search_in_conversation');

  /// Pending-approval safety pill on a conversation row — "2 TO APPROVE" /
  /// "٢ للموافقة".
  String toApprove(int n) => _f('to_approve', {'n': n});
  String get slashRestartDesc => _t('slash_restart_desc');
  String get slashReportDesc => _t('slash_report_desc');
  String get slashSyncDesc => _t('slash_sync_desc');
  String get slashLogsDesc => _t('slash_logs_desc');
  String get slashBackupDesc => _t('slash_backup_desc');

  // Composer quick-suggestion chips
  String get suggestRestartWorker => _t('suggest_restart_worker');
  String get suggestReconciliationReport =>
      _t('suggest_reconciliation_report');
  String get suggestPendingInvoices => _t('suggest_pending_invoices');
  String get suggestSyncInventory => _t('suggest_sync_inventory');

  // Vault / company card
  String get idleBadge => _t('idle_badge');
  String get envNoCredentials => _t('env_no_credentials');

  // Relative-time phrasing (the numeric part is pre-formatted by the caller
  // through NumberFormat so AR sees Arabic-Indic digits). "at"/"في" joins a
  // full date + time.
  String get dateAtConnector => _t('date_at_connector');

  // Unit words. `humanBytes` / `compactCount` render the digits and join
  // these on — the digits stay Western in both locales, the word does not.
  /// Attachment category word. The format badges next to it ("PDF",
  /// "XLSX") are identifiers and live in `UiStrings` instead.
  String get fileKindImage => _t('file_kind_image');

  /// Placeholder *inside* the 6-digit OTP field — distinct from
  /// [authOtpHint], which is the explanatory line above it. Localized
  /// because these are illustrative sample digits, not a computed value,
  /// so Arabic can show its own numerals here without breaking the
  /// app-wide "Western digits for real numbers" convention.
  String get authOtpPlaceholder => _t('auth_otp_placeholder');

  String get unitBytes => _t('unit_bytes');
  String get unitKilobytes => _t('unit_kilobytes');
  String get unitMegabytes => _t('unit_megabytes');
  String get compactThousands => _t('compact_thousands');
  String get compactMillions => _t('compact_millions');
  String relativeMinutesAgo(String n) => _f('relative_minutes_ago', {'n': n});
  String relativeHoursAgo(String n) => _f('relative_hours_ago', {'n': n});
  String relativeDaysAgo(String n) => _f('relative_days_ago', {'n': n});

  /// Company header stats line — "3 environments · 1 live · 2 credentials"
  /// (pluralized for EN, RTL-natural for AR). Segments after the count are
  /// dropped when zero.
  String projectStats(int envs, int live, int connected) {
    if (_isArabic) {
      final b = StringBuffer('$envs بيئة');
      if (live > 0) b.write(' · $live مباشرة');
      if (connected > 0) b.write(' · $connected بيانات اعتماد');
      return b.toString();
    }
    final b = StringBuffer('$envs ${envs == 1 ? 'environment' : 'environments'}');
    if (live > 0) b.write(' · $live live');
    if (connected > 0) {
      b.write(' · $connected ${connected == 1 ? 'credential' : 'credentials'}');
    }
    return b.toString();
  }

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
  // Account deletion (App/Play Store requirement)
  String get deleteAccount => _t('delete_account');
  String get deleteAccountConfirmTitle => _t('delete_account_confirm_title');
  String get deleteAccountConfirmBody => _t('delete_account_confirm_body');
  String get deletingAccount => _t('deleting_account');
  String get accountDeletedToast => _t('account_deleted_toast');
  String get deleteAccountFailed => _t('delete_account_failed');
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

  // Share intake (incoming Android ACTION_SEND / SEND_MULTIPLE).
  String get shareSheetTitle => _t('share_sheet_title');
  String get shareSheetSubtitle => _t('share_sheet_subtitle');
  String get shareNewChat => _t('share_new_chat');
  String get shareExistingChats => _t('share_existing_chats');
  String get shareCountFile => _t('share_count_file');
  String get shareCountFiles => _t('share_count_files');
  String get shareNoConversations => _t('share_no_conversations');
  String get shareCancel => _t('share_cancel');

  // Tester feedback batch (2026-05-23): sent-confirmation toast, voice
  // input, share-message, quick replies, swipe-archive hints.
  String get sentToastOneFile => _t('sent_toast_one_file');
  String get sentToastManyFiles => _t('sent_toast_many_files');
  String get shareMessage => _t('share_message');
  String get shareMessageSubject => _t('share_message_subject');
  String get voiceHoldToTalk => _t('voice_hold_to_talk');
  String get voiceListening => _t('voice_listening');
  String get voiceNotAvailable => _t('voice_not_available');
  String get voicePermissionDenied => _t('voice_permission_denied');
  String get voicePermissionOpenSettings =>
      _t('voice_permission_open_settings');
  String get openSettings => _t('open_settings');

  // Voice transcription (Whisper). Key names mirror the web client's
  // i18n table (SAQQAR_MOBILE_VOICE.md §5) so backend/web/mobile share
  // the same vocabulary when reporting issues.
  String get recordVoice => _t('record_voice');
  String get stopRecording => _t('stop_recording');
  String get transcribing => _t('transcribing');
  String get transcribeFailed => _t('transcribe_failed');
  String get transcribeEmpty => _t('transcribe_empty');
  String get micUnavailable => _t('mic_unavailable');
  String get voiceMaxLength => _t('voice_max_length');
  String get discardRecording => _t('discard_recording');
  String get shareCurrentChat => _t('share_current_chat');
  String get shareCurrentChatHint => _t('share_current_chat_hint');

  // Credential test connection + xmlrpc auth-type switcher
  // (SAQQAR_MOBILE_API_xmlrpc.md §7). Keys named to match the server
  // bundle (camelCase) so `AppStrings.lookup(field.labelKey!)` resolves
  // straight against schema responses.
  String get authType => _t('authType');
  String get authPassword => _t('authPassword');
  String get authApiKey => _t('authApiKey');
  String get apiKey => _t('apiKey');
  String get apiKeyHelp => _t('apiKeyHelp');
  String get apiKeyPlaceholder => _t('apiKeyPlaceholder');
  String get testConnection => _t('testConnection');
  String get testingConnection => _t('testingConnection');
  String get testConnectionOk => _t('testConnectionOk');
  String get testConnectionFailed => _t('testConnectionFailed');
  // Odoo database discovery (POST /credentials/databases/)
  String get detectDatabases => _t('detectDatabases');
  String get detectingDatabases => _t('detectingDatabases');
  String get detectDatabasesEmpty => _t('detectDatabasesEmpty');
  String get detectDatabasesNeedsUrl => _t('detectDatabasesNeedsUrl');
  String get detectDatabasesFailed => _t('detectDatabasesFailed');
  // Credential editor audience mode (web parity: "I'm a user" hides the
  // technical kinds and shows only the Odoo connection).
  String get credModeUser => _t('credModeUser');
  String get credModeDeveloper => _t('credModeDeveloper');
  // Chat history pagination — "Load earlier messages" button at the top of
  // the message list.
  String get chatLoadEarlier => _t('chatLoadEarlier');
  String get chatLoadingEarlier => _t('chatLoadingEarlier');
  // Biometric / device-credential app lock.
  String get security => _t('security');
  String get appLockTitle => _t('appLockTitle');
  String get appLockSubtitle => _t('appLockSubtitle');
  String get appLockUnlock => _t('appLockUnlock');
  String get appLockReason => _t('appLockReason');
  String get appLockConfirmSignOut => _t('appLockConfirmSignOut');
  String get appLockConfirmDelete => _t('appLockConfirmDelete');
  String get appLockSettingTitle => _t('appLockSettingTitle');
  String get appLockSettingSubtitle => _t('appLockSettingSubtitle');
  String get appLockUnavailable => _t('appLockUnavailable');
  String get appLockEnableFailed => _t('appLockEnableFailed');

  /// Matches [raw] against text a developer would never want a user to read:
  /// stack traces, driver exceptions, SQL constraint names, ORM internals.
  ///
  /// The backend's `error` field is developer-facing by design, so it carries
  /// whatever Django/psycopg/DRF raised — e.g. `IntegrityError: duplicate key
  /// value violates unique constraint "auth_user_email_key"`, or a 500 with a
  /// traceback inline. That text used to render verbatim into [AppErrorState],
  /// the very widget whose doc says "Don't put raw exception text here".
  ///
  /// Deliberately a denylist of technical SHAPES rather than a length cap
  /// alone: real copy is short prose, and the artifacts are recognizable.
  static final RegExp _technicalArtifact = RegExp(
    r'Traceback|Exception\b|\bError:|File "|line \d+, in |'
    r'<class |0x[0-9a-fA-F]{6,}|psycopg|sqlalchemy|django\.|'
    r'[a-z_]{2,}\.[a-z_]{2,}\(|violates \w+ constraint',
    caseSensitive: false,
  );

  /// Whether [raw] reads like a sentence written for a person.
  bool _looksLikeHumanCopy(String raw) =>
      raw.length <= 160 && // real copy is one sentence, not a dump
      !raw.contains('\n') && // multi-line means stack trace
      !_technicalArtifact.hasMatch(raw);

  /// The server's message, made safe to show — or `null` when it isn't.
  ///
  /// Returns localized copy for a recognized failure, the server's own text
  /// when it reads like human prose, and `null` when the text is a developer
  /// artifact. `null` means "substitute your own fallback": each caller knows
  /// which one fits (a conflict isn't a server crash), so this deliberately
  /// doesn't pick a generic one for them.
  String? presentableServerMessage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Applies in EVERY locale. An English user has no more use for a psycopg
    // traceback than an Arabic one does.
    if (!_looksLikeHumanCopy(raw)) return null;
    return localizeServerMessage(raw);
  }

  /// Localize a raw server-side error message. Backend `error` strings are
  /// developer-facing English; this matches the common cases to a clean
  /// localized line so an Arabic UI shows no English. Used by the credential
  /// test badge, and by [presentableServerMessage] for every API failure that
  /// carries a server message.
  ///
  /// Unrecognized messages fall back to [raw] — arbitrary server text can't
  /// be translated. Prefer [presentableServerMessage] on any path that
  /// renders to a user: it screens out the text that must never be shown at
  /// all, which this method (by itself) will happily pass through.
  String localizeServerMessage(String raw) {
    if (raw.isEmpty) return raw;
    // English locale (or any non-Arabic) keeps the server's own wording.
    if (!_isArabic) return raw;
    final lower = raw.toLowerCase();
    if (lower.contains('authentication failed') ||
        lower.contains('access denied') ||
        lower.contains('invalid password') ||
        lower.contains('wrong login') ||
        lower.contains('invalid credentials')) {
      return _t('testErrAuthFailed');
    }
    if ((lower.contains('provide') || lower.contains('required')) &&
        (lower.contains('url') ||
            lower.contains('username') ||
            lower.contains('api key') ||
            lower.contains('password'))) {
      return _t('testErrMissingFields');
    }
    if (lower.contains('incorrect code') ||
        lower.contains('invalid code') ||
        lower.contains('wrong code') ||
        lower.contains('code is incorrect') ||
        lower.contains('verification code')) {
      return _t('errInvalidCode');
    }
    if (lower.contains('expired') &&
        (lower.contains('code') || lower.contains('otp'))) {
      return _t('errExpiredCode');
    }
    if ((lower.contains('password') || lower.contains('new_password')) &&
        (lower.contains('at least') ||
            lower.contains('too short') ||
            lower.contains('8 characters'))) {
      return _t('password_too_short');
    }
    if (lower.contains('bad request') || lower.contains('http 400')) {
      return _t('testErrBadRequest');
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return _t('testErrTimeout');
    }
    if (lower.contains('failed to resolve') ||
        lower.contains('name or service not known') ||
        lower.contains('getaddrinfo') ||
        lower.contains('connection refused') ||
        lower.contains('no route to host') ||
        lower.contains('could not connect') ||
        lower.contains('unreachable')) {
      return _t('testErrUnreachable');
    }
    if (lower.contains('already exists') || lower.contains('duplicate')) {
      return _t('testErrDuplicate');
    }
    if (lower.contains('not found') || lower.contains('does not exist')) {
      return _t('testErrNotFound');
    }
    if (lower.contains('permission') ||
        lower.contains('not allowed') ||
        lower.contains('forbidden')) {
      return _t('testErrForbidden');
    }
    return raw;
  }

  /// Localizes a connection-test error for the credential editor badge.
  ///
  /// The server's `error` is developer-facing English and sometimes a raw
  /// driver/Python exception (e.g. `invalid literal for int()` when the port
  /// is blank). Map the common credential-test failures to a clear, actionable
  /// sentence in BOTH locales, then defer anything unrecognised to the shared
  /// [localizeServerMessage] (which still localizes auth/timeout/etc. for
  /// Arabic and keeps the server wording otherwise).
  String testConnectionError(String raw) {
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();

    // Empty / invalid Postgres `sslmode` (screen showed `invalid sslmode
    // value: ''`). Tell the user the accepted values.
    if (lower.contains('sslmode')) return _t('testErrInvalidSslmode');

    // Non-numeric / empty numeric field — almost always a blank Port that
    // hits Python's `int()` parse (`invalid literal for int() with base 10`).
    if (lower.contains('invalid literal for int') ||
        (lower.contains('invalid literal') && lower.contains('base 10'))) {
      return _t('testErrInvalidNumber');
    }

    // "GitHub token is required." and any other "<field> is required".
    if (lower.contains('token') &&
        (lower.contains('required') || lower.contains('missing'))) {
      return _t('testErrTokenRequired');
    }

    return localizeServerMessage(raw);
  }
  String get quickReplyMore => _t('quick_reply_more');
  String get quickReplySummarize => _t('quick_reply_summarize');
  String get quickReplyExport => _t('quick_reply_export');
  String get swipeArchive => _t('swipe_archive');
  String get swipeUnarchive => _t('swipe_unarchive');
  String get swipeDelete => _t('swipe_delete');
  String get longPressActionsTitle => _t('long_press_actions_title');
  String get copyAction => _t('copy_action');
  String get offlineTitle => _t('offline_title');
  String get offlineBody => _t('offline_body');
  String get backOnline => _t('back_online');
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

  // Plan / quota / usage (Gap A + B)
  String get planUsageTitle => _t('plan_usage_title');
  String get planWindowDay => _t('plan_window_day');
  String get planWindowWeek => _t('plan_window_week');
  String get planWindowMonth => _t('plan_window_month');
  String get planExemptLabel => _t('plan_exempt_label');
  String get planNearLimitTitle => _t('plan_near_limit_title');
  String get quotaExceededTitle => _t('quota_exceeded_title');
  String get quotaUpgradeCta => _t('quota_upgrade_cta');

  // Pricing screen (Gap L)
  String get pricingTitle => _t('pricing_title');
  String get pricingCurrent => _t('pricing_current');
  String get pricingFree => _t('pricing_free');
  String get pricingLoadError => _t('pricing_load_error');
  // `pricing_st_unit`, the two cap labels, `pricing_projects_label`,
  // `pricing_unlimited` and the four `feature_*` labels are gone with the
  // rows that used them. They described the API — token caps in an invented
  // "ST" unit and a capability tick/cross matrix — where the website
  // describes the product. See `plan_copy.dart`.

  /// The headline figure alone — "$20". Western digits in both locales to
  /// match the rest of the numeric UI.
  ///
  /// Quoted **per month** on both cycles, the way saqqaar.com quotes it: the
  /// annual plan's yearly total on its own would make the cheaper cycle look
  /// like the dearer one. [priceBothCycles] carries the yearly figures.
  String priceAmount(int cents) =>
      cents <= 0 ? pricingZero : '\$${_dollars(cents)}';

  /// The "+ VAT" rider next to [priceAmount]. Separate because it renders a
  /// size down beside the figure, the way the website sets it.
  String get pricePlusVat => _t('price_plus_vat');

  /// Both cycles on one line — "$10/mo billed annually ($120/yr) · $20/mo
  /// billed monthly ($240/yr)." Shown under the headline figure whichever
  /// cycle is selected, so the switch above it is never the only way to find
  /// out what the other one costs.
  String priceBothCycles({
    required int annualCentsPerMonth,
    required int monthlyCents,
  }) =>
      _f('price_both_cycles', {
        'annualMo': _dollars(annualCentsPerMonth),
        'annualYr': _dollars(annualCentsPerMonth * 12),
        'monthlyMo': _dollars(monthlyCents),
        'monthlyYr': _dollars(monthlyCents * 12),
      });

  String get pricingMostPopular => _t('pricing_most_popular');

  /// Cents → "20" or "2.50". Trailing `.00` reads as false precision on a
  /// price list where most tiers are whole dollars.
  String _dollars(int cents) => cents % 100 == 0
      ? '${cents ~/ 100}'
      : (cents / 100).toStringAsFixed(2);

  // Pricing — cycle switch + the web hand-off.
  String get pricingSubtitle => _t('pricing_subtitle');
  String get pricingCycleMonthly => _t('pricing_cycle_monthly');
  String get pricingCycleAnnual => _t('pricing_cycle_annual');
  String get pricingCycleAnnualSave => _t('pricing_cycle_annual_save');
  /// The tax footnote. [rate] comes from the `vat` object on `/plans/` — the
  /// rate used to be written into this string, which made it a number that
  /// could go stale without anyone noticing, on the one screen where being
  /// wrong costs money.
  String pricingVatNote(String rate) => _f('pricing_vat_note', {'rate': rate});
  String get pricingWebCta => _t('pricing_web_cta');

  /// The always-present footer action. Says "manage", not "subscribe": it is
  /// the only route to the web for someone on the top tier, who has nothing
  /// left to buy but still renews, cancels and downloads receipts there.
  String get pricingManageCta => _t('pricing_manage_cta');
  String get pricingWebNote => _t('pricing_web_note');
  String get pricingOpenFailed => _t('pricing_open_failed');
  String get pricingPlansTitle => _t('pricing_plans_title');
  String get pricingPlansSubtitle => _t('pricing_plans_subtitle');
  String get pricingPlansSubtitlePlain => _t('pricing_plans_subtitle_plain');
  String get pricingManagedOnWeb => _t('pricing_managed_on_web');
  String get pricingWebSignInNote => _t('pricing_web_signin_note');

  /// Localized label for a payment's wire status.
  ///
  /// The states are the ones `PAYMOB_WEB_CHECKOUT_BACKEND.md` commits to:
  /// `pending` / `paid` / `failed` / `expired` / `refunded` / `chargeback`.
  /// Anything else falls back to the raw value — a status we don't recognise
  /// is still better shown than swallowed, and it tells support what the
  /// server actually said.
  ///
  /// Without this, an Arabic user reads the Latin word "PENDING" in an
  /// otherwise Arabic screen; the i18n parity test can't catch it because the
  /// string never lived in our tables.
  String billingStatusLabel(String wire) => switch (wire.toLowerCase()) {
        'pending' => _t('billing_status_pending'),
        'paid' || 'succeeded' || 'success' => _t('billing_paid'),
        'failed' || 'declined' => _t('billing_failed'),
        'expired' => _t('billing_status_expired'),
        'refunded' => _t('billing_status_refunded'),
        'chargeback' => _t('billing_status_chargeback'),
        _ => wire,
      };

  /// Explains a payment that is neither paid nor failed. Shown under the row,
  /// because "PENDING" on its own leaves someone who has just paid with no
  /// idea whether their money arrived.
  ///
  /// Carries the short [ref] so a support message can start with the one fact
  /// that identifies the attempt, instead of "my payment didn't work".
  String billingPendingNote(String ref) =>
      _f('billing_pending_note', {'ref': ref});
  String get pricingZero => _t('pricing_zero');

  // Addon authoring hint (Gap M) — shown when a `.zip` addon is staged.
  String get addonHint => _t('addon_hint');

  // Feature-gating (Gap C) — shown when a locked tool 403s.
  String get voiceLockedPro => _t('voice_locked_pro');

  // Env-hint banner (Gap H) — one-click "Use My Database".
  String get useMyDatabaseTitle => _t('use_my_database_title');
  String get envHintTitle => _t('env_hint_title');
  String get envHintBody => _t('env_hint_body');
  String get envHintUseMyDatabase => _t('env_hint_use_my_database');
  String get envHintBound => _t('env_hint_bound');
  String get envHintNeedsCredentials => _t('env_hint_needs_credentials');
  String get envHintFailed => _t('env_hint_failed');

  // Email-OTP auth flow (Gap D)
  String get authSignUpEmailTitle => _t('auth_signup_email_title');
  String get authSignUpEmailSubtitle => _t('auth_signup_email_subtitle');
  String get authCheckEmailTitle => _t('auth_check_email_title');
  String get authCheckEmailSubtitle => _t('auth_check_email_subtitle');
  String get authProfileTitle => _t('auth_profile_title');
  String get authProfileSubtitle => _t('auth_profile_subtitle');
  String get authWelcomeBackTitle => _t('auth_welcome_back_title');
  String get authWelcomeBackSubtitle => _t('auth_welcome_back_subtitle');
  String get authPasswordTitle => _t('auth_password_title');
  String get authPasswordSubtitle => _t('auth_password_subtitle');
  String get authResetTitle => _t('auth_reset_title');
  String get authResetSubtitle => _t('auth_reset_subtitle');
  String get authNewPasswordTitle => _t('auth_new_password_title');
  String get authNewPasswordSubtitle => _t('auth_new_password_subtitle');

  String get authFirstName => _t('auth_first_name');
  String get authLastName => _t('auth_last_name');
  String get authNewPasswordLabel => _t('auth_new_password_label');
  String get authConfirmNewPasswordLabel => _t('auth_confirm_new_password');
  String get authOtpLabel => _t('auth_otp_label');
  String get authOtpHint => _t('auth_otp_hint');
  String get authEmailPlaceholder => _t('auth_email_placeholder');
  String get authPasswordPlaceholder => _t('auth_password_placeholder');
  String get authPasswordEnterPlaceholder =>
      _t('auth_password_enter_placeholder');
  String get authConfirmPlaceholder => _t('auth_confirm_placeholder');
  String get authConfirmNewPlaceholder => _t('auth_confirm_new_placeholder');

  String get authContinueWithEmail => _t('auth_continue_email');
  String get authContinueWithPassword => _t('auth_continue_password');
  String get authContinueWithEmailInstead => _t('auth_continue_email_instead');
  String get authContinueWithPasswordInstead =>
      _t('auth_continue_password_instead');
  String get authOrContinueWith => _t('auth_or_continue_with');
  String get authContinueWithGoogle => _t('auth_continue_google');
  String get authContinueWithApple => _t('auth_continue_apple');
  String get authVerifyCode => _t('auth_verify_code');
  String get authVerifyAndSignIn => _t('auth_verify_signin');
  String get authCreateAccountBtn => _t('auth_create_account_btn');
  String get authLoginBtn => _t('auth_login_btn');
  String get authForgotPassword => _t('auth_forgot_password');
  String get authSendResetCode => _t('auth_send_reset_code');
  String get authSetNewPasswordBtn => _t('auth_set_new_password_btn');
  String get authSignInInstead => _t('auth_signin_instead');
  String get authCreateAnAccount => _t('auth_create_an_account');
  String get authBackToSignIn => _t('auth_back_to_signin');
  String get authUseDifferentEmail => _t('auth_use_different_email');
  String get authDidntGetCode => _t('auth_didnt_get_code');
  String get authResendNow => _t('auth_resend_now');
  String get authRememberItNow => _t('auth_remember_it_now');
  String get authPasswordsMismatch => _t('auth_passwords_mismatch');
  String get authCodeRequired => _t('auth_code_required');
  String get authNameRequired => _t('auth_name_required');

  // Personal information card (Gap I)
  String get personalInfoTitle => _t('personal_info_title');
  String get personalInfoHint => _t('personal_info_hint');
  String get emailLoginLabel => _t('email_login_label');
  String get emailLoginHint => _t('email_login_hint');
  String get saveChanges => _t('save_changes');
  String get profileUpdatedToast => _t('profile_updated_toast');
  // Inline status shown next to a save button so the disabled state reads
  // as intentional ("nothing changed") rather than broken.
  String get statusSaved => _t('status_saved');
  String get statusNoChanges => _t('status_no_changes');

  /// "Resend in 53s" — countdown owned by the view.
  String authResendIn(int seconds) =>
      _f('auth_resend_in', {'seconds': seconds});

  // Approvals — friendly Odoo model names + operation verbs (Gap E)
  String approvalActionTitle(String wire) => switch (wire) {
        'credential_storage' => _t('approval_title_cred_storage'),
        'credential_usage' => _t('approval_title_cred_usage'),
        'server_command' => _t('approval_title_server_cmd'),
        'odoo_write' => _t('approval_title_odoo_write'),
        'report_export' => _t('approval_title_report_export'),
        _ => _t('approval_title_generic'),
      };

  String approvalOperationVerb(String? op) => switch (op) {
        'create' || 'create_many' => _t('approval_op_create'),
        'write' => _t('approval_op_write'),
        'delete' => _t('approval_op_delete'),
        'call' => _t('approval_op_call'),
        'load' => _t('approval_op_load'),
        _ => '',
      };

  /// Kind-aware "file too large" notice (Gap F). [capMb] is 500 for
  /// archives, 25 otherwise.
  String attachmentTooLarge(String name, int capMb) => _isArabic
      ? '«$name» يتجاوز حد $capMb ميجابايت.'
      : '"$name" is over the $capMb MB limit.';

  /// "Create 6 × Manufacturing Order" — verb + optional record count + model.
  String approvalModelTitle(String verb, int? count, String label) {
    final c = (count != null && count > 0) ? '$count× ' : '';
    final v = verb.isEmpty ? '' : '$verb ';
    return '$v$c$label';
  }

  /// Localized adjective for a usage window, keyed by its wire value
  /// (`day | week | month`). Used in banner / blocked-send copy.
  String planWindowWord(String wire) => switch (wire) {
        'day' => _t('plan_daily'),
        'week' => _t('plan_weekly'),
        'month' => _t('plan_monthly'),
        _ => '',
      };

  /// "12% used" — pct already computed server-side.
  String planPctUsed(int pct) => _f('plan_pct_used', {'pct': pct});

  // ── Subscription line (API_MOBILE_SUBSCRIPTION.md §1) ──────────────────

  /// `monthly` / `annual` → a display word. Falls back to the raw value so an
  /// unrecognised cycle is shown rather than dropped.
  String planCycleLabel(String wire) => switch (wire.toLowerCase()) {
        'monthly' => _t('pricing_cycle_monthly'),
        'annual' || 'yearly' => _t('pricing_cycle_annual'),
        _ => wire,
      };

  /// Subscription state. `active` is deliberately not surfaced by the card —
  /// only states the user needs to act on reach the screen.
  String planStatusLabel(String wire) => switch (wire.toLowerCase()) {
        'active' => _t('plan_status_active'),
        'trialing' => _t('plan_status_trialing'),
        'canceled' || 'cancelled' => _t('plan_status_canceled'),
        'past_due' => _t('plan_status_past_due'),
        _ => wire,
      };

  /// "Renews on 4 Mar 2027". Worded as a renewal, never a deadline: Saqqar
  /// billing is prepaid, so nothing stops working on this date.
  String planRenewsOn(String date) => _f('plan_renews_on', {'date': date});

  /// "12.3K / 125K" — compact used/cap pair (formatting done by caller).
  String planUsageLine(String used, String cap) => '$used / $cap';

  /// Near-limit banner body, e.g. "You've used 85% of your daily limit."
  String planNearLimitBody(String window, int pct) => _isArabic
      ? 'استخدمت $pct٪ من حدّك $window.'
      : "You've used $pct% of your $window limit.";

  /// Composer tooltip + quota card body when a window is exhausted.
  String quotaExceededBody(String window) => _isArabic
      ? 'لقد بلغت حدّ الاستخدام $window. ستُعاد التهيئة عند انتهاء الفترة، أو رقِّ خطتك.'
      : "You've reached your $window usage limit. It resets when the window rolls over, or upgrade your plan.";

  /// [quotaExceededBody] minus the upgrade nudge — used where paid-plan upsell
  /// is suppressed, which is currently everywhere: sales are web-only, so
  /// "upgrade your plan" would point at a door the app doesn't have. Callers
  /// pick via `showPaidUpsell`.
  String quotaExceededBodyPlain(String window) => _isArabic
      ? 'لقد بلغت حدّ الاستخدام $window. ستُعاد التهيئة عند انتهاء الفترة.'
      : "You've reached your $window usage limit. It resets when the window rolls over.";

  String sendBlockedTooltip(String window) => _isArabic
      ? 'تم بلوغ الحد $window'
      : '$window limit reached';

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

  // ── Account link groups ──────────────────────────────────────────────
  // Section headings + the one-line descriptions under each destination.
  // The descriptions are the point: a row reading only "Saqqar Apps" or
  // "Data explorer" tells a first-time user nothing about whether it is
  // worth tapping.
  String get accountGroupWorkspace => _t('account_group_workspace');
  String get accountGroupWorkspaceHint => _t('account_group_workspace_hint');
  String get accountGroupSecurity => _t('account_group_security');
  String get accountGroupBilling => _t('account_group_billing');
  String get accountGroupBillingHint => _t('account_group_billing_hint');
  String get appsSubtitle => _t('apps_subtitle');
  String get trialSubtitle => _t('trial_subtitle');
  String get dataExplorerSubtitle => _t('data_explorer_subtitle');
  String get devicesSubtitle => _t('devices_subtitle');
  String get checkoutSubtitle => _t('checkout_subtitle');
  String get billingHistorySubtitle => _t('billing_history_subtitle');

  // ── New endpoints (API_MOBILE_NEW_ENDPOINTS.md) ──────────────────────
  // Saqqar Apps (§1)
  String get appsTitle => _t('apps_title');
  String get appsEmptyTitle => _t('apps_empty_title');
  String get appsEmptyBody => _t('apps_empty_body');
  String get appsOpening => _t('apps_opening');
  String get appsNeedsEnv => _t('apps_needs_env');
  String get appLaunchTitle => _t('app_launch_title');
  String get appLaunchProject => _t('app_launch_project');
  String get appLaunchEnvironment => _t('app_launch_environment');
  String get appLaunchStart => _t('app_launch_start');
  String get appLaunchSkip => _t('app_launch_skip');
  String get appLaunchNeedsEnv => _t('app_launch_needs_env');
  String get appLaunchOptionalEnv => _t('app_launch_optional_env');
  String get appLaunchNoProjects => _t('app_launch_no_projects');
  String get appLaunchNoEnvs => _t('app_launch_no_envs');

  /// Placeholder under the Database section while no company is chosen.
  /// Distinct from [appLaunchProject], which is the section *label* — the
  /// dialog used to render the label here, so the empty slot read "Company"
  /// under the heading "Database" and instructed nobody.
  String get appLaunchPickProjectFirst =>
      _t('app_launch_pick_project_first');
  String get appGroupAll => _t('app_group_all');

  /// Group taxonomy label. Falls back to the server's own English value so a
  /// group the backend adds still reads as itself rather than as a key.
  String appGroup(String group) => lookup(
        'app_group_${group.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        fallback: group,
      );

  /// Toast title when launching a guided app fails. Names the action; the
  /// toast body carries the mapped reason from [ApiErrorMapper].
  String get appsLaunchFailed => _t('apps_launch_failed');

  // Billing history & receipts (§3)
  String get billingHistoryTitle => _t('billing_history_title');
  String get billingBalance => _t('billing_balance');
  String get billingTotalPurchased => _t('billing_total_purchased');
  String get billingEmptyTitle => _t('billing_empty_title');
  String get billingEmptyBody => _t('billing_empty_body');
  String get billingReceipt => _t('billing_receipt');
  String get billingReceiptFailed => _t('billing_receipt_failed');
  String get billingReceiptNoViewer => _t('billing_receipt_no_viewer');
  String get billingPaid => _t('billing_paid');
  String get billingFailed => _t('billing_failed');

  // Managed Odoo trial (§2)
  String get trialTitle => _t('trial_title');
  String get trialIntro => _t('trial_intro');
  String get trialCompanyName => _t('trial_company_name');
  String get trialCompanyRequired => _t('trial_company_required');
  String get trialWorkEmail => _t('trial_work_email');
  String get trialPhone => _t('trial_phone');
  String get trialRequestButton => _t('trial_request_button');
  String get trialPendingTitle => _t('trial_pending_title');
  String get trialProvisioningTitle => _t('trial_provisioning_title');
  String get trialProvisioningBody => _t('trial_provisioning_body');
  String get trialReadyTitle => _t('trial_ready_title');
  String get trialFailedTitle => _t('trial_failed_title');
  String get trialFailedBody => _t('trial_failed_body');
  String get trialUrl => _t('trial_url');
  String get trialDb => _t('trial_db');
  String get trialLogin => _t('trial_login');
  String get trialPassword => _t('trial_password');
  String get trialOpen => _t('trial_open');
  String get trialOpenFailed => _t('trial_open_failed');
  String get trialCopied => _t('trial_copied');
  String get trialCredentialsWarning => _t('trial_credentials_warning');

  // Shared
  String get copy => _t('copy');
  String get artifactDetailsTitle => _t('artifact_details_title');

  // Meetings (§4.1)
  String get meetingsTitle => _t('meetings_title');
  String get meetingsIntro => _t('meetings_intro');
  String get meetingsPreviewNote => _t('meetings_preview_note');
  String get meetingsUrlLabel => _t('meetings_url_label');
  String get meetingsUrlRequired => _t('meetings_url_required');
  String get meetingsStart => _t('meetings_start');
  String get meetingsStatus => _t('meetings_status');
  String get meetingsStop => _t('meetings_stop');
  String get meetingsSummarize => _t('meetings_summarize');
  String get meetingsTranscript => _t('meetings_transcript');
  String get meetingsTranscriptEmpty => _t('meetings_transcript_empty');
  String get meetingsSummary => _t('meetings_summary');
  String get meetingsAskLabel => _t('meetings_ask_label');
  String get meetingsAsk => _t('meetings_ask');
  String get meetingsReply => _t('meetings_reply');

  // Direct data explorer (§4.2)
  String get dataExplorerTitle => _t('data_explorer_title');
  String get dataExplorerPreviewNote => _t('data_explorer_preview_note');
  String get dataExplorerEnv => _t('data_explorer_env');
  String get dataExplorerNoEnvs => _t('data_explorer_no_envs');
  String get dataExplorerModel => _t('data_explorer_model');
  String get dataExplorerModelRequired => _t('data_explorer_model_required');
  String get dataExplorerDomain => _t('data_explorer_domain');
  String get dataExplorerCount => _t('data_explorer_count');
  String get dataExplorerSearch => _t('data_explorer_search');
  String get dataExplorerResult => _t('data_explorer_result');
  String get dataExplorerOperation => _t('data_explorer_operation');
  String get dataExplorerBody => _t('data_explorer_body');
  String get dataExplorerRun => _t('data_explorer_run');
  String get dataExplorerInvalidJson => _t('data_explorer_invalid_json');

  // Billing checkout (§4.3)
  String get checkoutTitle => _t('checkout_title');
  String get checkoutPreviewNote => _t('checkout_preview_note');
  String get checkoutBuy => _t('checkout_buy');
  String get checkoutWaiting => _t('checkout_waiting');
  String get checkoutPaid => _t('checkout_paid');
  String get checkoutFailed => _t('checkout_failed');
  String get checkoutOpenFailed => _t('checkout_open_failed');
  String get checkoutEmpty => _t('checkout_empty');

  // Formatters
  String routeNotFound(Uri uri) => '${_t('route_not_found')}: $uri';

  String itemCount(int visible, int total, String label) =>
      _f('item_count', {'visible': visible, 'total': total, 'label': label});

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
  'auth_brand_body':
      'Live Odoo agent that diagnoses, reports, and acts with private credentials and approval gating on every risky change.',
  'open_workspace': 'Open workspace',
  'tab_chats': 'Chats',
  'tab_vault': 'Companies',
  'tab_inbox': 'Inbox',
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
  'default_project_label': 'Default',
  'conversation_preview_unavailable': 'Waiting on an action in this chat.',
  'artifact_download_failed': "Couldn't download the file. Try again.",
  'artifact_download_offline':
      "You're offline. Check your connection and try again.",
  'artifact_download_gone': 'This file is no longer available.',
  'artifact_download_forbidden': "This file isn't available on your plan.",
  'more': 'More',
  'share_link': 'Share link',
  'rename': 'Rename',
  'archive': 'Archive',
  'unarchive': 'Unarchive',
  'delete': 'Delete',
  'delete_conversation_title': 'Delete conversation?',
  'delete_conversation_body':
      'This will permanently delete this conversation and its messages. This action cannot be undone.',
  'edit': 'Edit',
  'dismiss': 'Dismiss',
  'open': 'Open',
  'approve': 'Approve',
  'reject': 'Reject',
  'show_details': 'Show details',
  'hide_details': 'Hide details',
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
  'shared_conversation_title': 'Shared conversation',
  'shared_conversation_empty': 'This conversation has no messages to show.',
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
  'clear_search': 'Clear search',
  'previous_page': 'Previous page',
  'next_page': 'Next page',
  'first_page': 'First page',
  'conversation_actions': 'Conversation actions',
  'credential_actions': 'Credential actions',
  'attach_files': 'Attach screenshots, PDFs, or spreadsheets',
  'attach_source_title': 'Attach',
  'attach_source_photos': 'Photos',
  'attach_source_photos_hint': 'Pick from your photo library',
  'attach_source_camera': 'Camera',
  'attach_source_camera_hint': 'Take a photo now',
  'attach_source_files': 'Files',
  'attach_source_files_hint': 'PDF, Excel, Word, CSV, ZIP',
  'attach_camera_denied':
      'Camera access is off. Turn it on in Settings to take photos.',
  'viewer_open_externally': 'Open in another app',
  'viewer_unsupported_title': "Can't preview this file here",
  'viewer_unsupported_body':
      'Saqqar shows images, PDFs and text files in the app. This one needs '
          'another app to open it.',
  'viewer_load_failed': "This file couldn't be opened",
  'viewer_truncated': 'Showing the first part of this file only.',
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
  'email_preview_to': 'To:',
  'email_preview_cc': 'Cc:',
  'email_preview_bcc': 'Bcc:',
  'email_preview_reply': 'Reply',
  'delete_confirm_title': 'Confirm deletion',
  'delete_confirm_body':
      'This permanently deletes {count} record(s) in Odoo. Type {phrase} to '
          'confirm.',
  'delete_confirm_hint': 'Type {phrase}',
  'delete_confirm_mismatch': 'That doesn\'t match. Type {phrase} exactly.',
  'task_prep': 'Task prep',
  'task_prep_title':
      'Saqqar asks quick questions to refine a vague task before building',
  'task_prep_on':
      'Task prep on. Saqqar will ask a couple of questions to refine vague '
          'tasks.',
  'task_prep_off': 'Task prep off. Saqqar builds directly from what you write.',
  // Saqqar tools sheet (the composer's `+` menu).
  'tools_title': 'Saqqar tools',
  'tools_upload_file': 'Upload file',
  'tools_modes_section': 'Modes',
  'tools_odoo_section': 'Odoo tools',
  'tools_connect_section': 'Connections',
  'tools_readonly_note': 'Tools do not change Odoo without your approval.',
  'tools_needs_conversation':
      'Send a message first — scans run inside a conversation.',
  // Saqqar Apps — per-slug overrides for `GET /api/v1/apps/`, which serves
  // one language. Absent keys fall back to the server string, so an app the
  // backend adds tomorrow still renders. English side is kept in sync with
  // the server copy so the two tables stay comparable.
  // Keyed by slug where known, and by the normalized English name as a
  // second chance — the catalogue is server-owned and the slugs are not
  // published to mobile. Copy taken verbatim from the web's own two locales
  // so the same package reads identically on both clients.
  'app_name_zatca': 'ZATCA e-invoicing',
  'app_name_zatca_e_invoicing': 'ZATCA e-invoicing',
  'app_tagline_zatca':
      'Onboard Saudi Fatoora Phase-2 e-invoicing on your Odoo — CSR, OTP, '
          'and go-live.',
  'app_tagline_zatca_e_invoicing':
      'Onboard Saudi Fatoora Phase-2 e-invoicing on your Odoo — CSR, OTP, '
          'and go-live.',

  'app_name_whatsapp_integration': 'WhatsApp integration',
  'app_tagline_whatsapp_integration':
      'Connect WhatsApp Business (Cloud API) so Odoo can send and receive '
          'messages.',

  'app_name_chart_of_accounts_builder': 'Chart of Accounts builder',
  'app_tagline_chart_of_accounts_builder':
      'Build or import a clean, localized chart of accounts and wire up '
          'default postings.',

  'app_name_bank_reconciliation': 'Bank reconciliation',
  'app_tagline_bank_reconciliation':
      'Set up bank journals, statement import, and reconciliation rules that '
          'match automatically.',

  // Group taxonomy — a closed set, shown as the card chip and as the filter
  // pills. `app_group_all` is the client-side "no filter" pill.
  'app_group_all': 'All',
  'app_group_accounting': 'Accounting',
  'app_group_finance': 'Finance',
  'app_group_integrations': 'Integrations',
  // Launch picker — shown before the app opens a conversation.
  'app_launch_title': 'Where should this run?',
  'app_launch_project': 'Company',
  'app_launch_environment': 'Database',
  'app_launch_start': 'Start',
  'app_launch_skip': 'Decide later in chat',
  'app_launch_needs_env':
      'This setup works on a connected Odoo database. Pick one, or choose it '
          'later when Saqqar asks.',
  'app_launch_optional_env':
      'Optional — Saqqar will ask in the chat if it needs a database.',
  'app_launch_no_projects':
      'No companies yet. Saqqar will help you connect one in the chat.',
  'app_launch_no_envs': 'This company has no databases yet.',
  'app_launch_pick_project_first': 'Pick a company first.',
  // §8 — voice support. "Voice" is the web's name for the page, not a
  // promise of audio: nothing here dials or speaks.
  'voice_support_title': 'Support',
  'voice_support_intro':
      'Describe the problem and Saqqar will draft a diagnosis and a reply.',
  'voice_support_hint': 'What went wrong?',
  'voice_support_submit': 'Get help',
  'voice_support_summary': 'What we understood',
  'voice_support_diagnosis': 'Likely cause',
  'voice_support_reply': 'Suggested reply',
  'voice_support_steps': 'Steps to try',
  'voice_support_questions': 'Still needs answering',
  'voice_support_file_ticket': 'Save as a ticket',
  'voice_support_ticket_confirm_title': 'Create a ticket in Odoo?',
  'voice_support_ticket_confirm_body':
      'This creates a real helpdesk ticket in your connected database.',
  'voice_support_ticket_created': 'Ticket created',
  // Odoo Helpdesk isn't installed everywhere; the server falls back to
  // creating a project task. Naming which one was created stops the user
  // hunting for a ticket in an app their database doesn't have.
  'voice_support_task_created': 'Saved as a task in Odoo',
  // A 200 that carried no record id. Nothing was created, so the one thing
  // this must not say is "sent".
  'voice_support_ticket_not_created':
      "The server accepted the request but didn't return a ticket. Nothing was "
          'created — please try again.',
  'voice_support_empty': 'No draft came back. Try describing it differently.',
  'tools_prompt_bank': 'Prompt bank',
  'tools_health_radar': 'Health radar',
  'tools_what_if': 'What-if',
  'tools_business_pulse': 'Business pulse',
  'tools_my_database': 'My database',
  'tools_voice_support': 'Voice support',
  // §6 rows call `/radar/run/`, `/pulse/run/` and `/whatif/intro/` directly
  // (web team, 2026-08-06) — there is no prompt text to author any more.
  // The three `tools_*_prompt` strings that used to live here were locally
  // invented against a probe that missed the real routes; they are gone
  // rather than left unused, so nobody wires them back by accident.
  // Interactive chat cards (tool_payload.kind dispatch).
  'clarify_title': 'A couple of quick questions',
  'clarify_something_else': 'Something else…',
  'clarify_build_send': 'Build & send',
  'clarify_prepare_review': 'Prepare & review',
  'clarify_needs_answer': 'Pick at least one answer',
  'clarify_answers_header': 'Answers to your questions:',
  'clarify_ready_to_review': 'Answers ready in the composer — edit or send.',
  'suggestion_title': 'A clearer way to ask',
  'suggestion_approve': 'Approve & use',
  'suggestion_keep_mine': 'Keep mine',
  'report_title': 'Build a report',
  'report_type': 'Type',
  'report_period': 'Period',
  'report_lens': 'View',
  'report_format': 'Format',
  'report_records': 'Records',
  'report_pick_records': 'Pick records',
  'report_search_records': 'Search records',
  'report_records_truncated':
      'Showing the first {count} — search to narrow the list.',
  'report_no_records': 'No matching records.',
  'report_selected_count': '{count} selected',
  'report_build': 'Build report',
  'report_needs_type': 'Pick a report type first',
  'report_compose':
      'Build this report:\n- Type: {type}\n- Period: {period}\n'
          '- Format: {format}',
  'report_compose_lens': '\n- View: {lens}',
  'report_compose_records': '\n- Records: {names}',
  'stop_generation': 'Stop generating',
  'generation_stopped': 'Stopped.',
  'stopping': 'Stopping…',
  'agent_working': 'Working',
  'agent_thinking': 'Working on your request.',
  'saqqar_thinking': 'Saqqar thinking',
  'saqqar_working_now': 'is working now',
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
  'error_unexpected_response':
      "The server sent something this app didn't understand. Update to the "
          'latest version, and contact support if it keeps happening.',
  'loading': 'Loading…',
  // ── Typed error categories ──
  'error_network': "Couldn't reach the server. Check your connection.",
  'error_timeout': 'The server took too long to respond. Please try again.',
  'error_cancelled': 'The action was cancelled.',
  'error_unauthorized': 'Your session ended. Please sign in again.',
  // Every failure line names the cause AND the next step. These three used to
  // stop at the cause, which leaves the user staring at a sentence with
  // nothing to do about it — the two that matter most are the ones where the
  // fix is NOT "try again", because a retry button is the wrong instinct there.
  'error_forbidden':
      "You don't have permission to do this. Ask the owner of this Odoo "
          'database to grant it, or switch to a database you can write to.',
  'error_not_found':
      "We couldn't find that — it may have been deleted or moved. Pull down "
          'to refresh the list.',
  'error_validation':
      'Some fields need your attention. Check the highlighted ones and try '
          'again.',
  'error_conflict': 'That action conflicts with current data. Refresh and try again.',
  'error_rate_limited': 'Too many attempts. Please slow down.',
  'error_rate_limited_with_retry': 'Too many attempts. Try again in {seconds}s.',
  'error_payload_too_large':
      'That file is too large. The limit is 25 MB (500 MB for archives).',
  // Says "wait or upgrade" rather than "try again" — retrying a spent
  // quota just reproduces the same error.
  'error_quota_exceeded':
      'You\'ve used up your allowance for now. It resets at the start of '
          'your next window.',
  'error_unsupported_media':
      'That file type isn\'t supported. Try a document, spreadsheet, image '
          'or PDF.',
  'error_server': 'The server hit a problem. Please try again in a moment.',
  // Native Google / Apple sign-in, failing on the device before any request
  // reaches Saqqar. Each names the way out, because "try again" is advice
  // that cannot work for the first of the three.
  'error_social_not_configured':
      'This sign-in option isn\'t available in this version. You can sign in '
          'with your email address instead.',
  'error_social_no_token':
      'The sign-in didn\'t complete. Try again, or sign in with your email '
          'address.',
  'error_social_rejected':
      'Your device refused the sign-in. Check that you\'re signed in to that '
          'account in your phone settings, then try again.',
  'error_unknown': 'Something went wrong. Please try again.',
  'crash_screen_title': 'Something went wrong',
  'crash_screen_body': 'This screen ran into a problem. The error has been '
      'logged. Try going back, or restart the app if it keeps happening.',
  // ── Vault action labels (prefixes) ──
  'vault_action_load_failed': "Couldn't load your companies",
  'vault_action_create_project_failed': "Couldn't create the company",
  'vault_action_rename_project_failed': "Couldn't rename the company",
  'vault_action_delete_project_failed': "Couldn't delete the company",
  'vault_action_create_environment_failed': "Couldn't create the environment",
  'vault_action_update_environment_failed': "Couldn't update the environment",
  'vault_action_delete_environment_failed': "Couldn't delete the environment",
  'vault_action_load_credentials_failed': "Couldn't load credentials",
  'vault_action_save_credential_failed': "Couldn't save the credential",
  'vault_action_delete_credential_failed': "Couldn't delete the credential",
  // ── Vault success toasts ──
  'vault_toast_project_created': 'Company created.',
  'vault_toast_project_deleted': 'Company deleted.',
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
  'conversations_action_share_failed': "Couldn't create a share link",
  'chat_action_send_failed': "Couldn't send your message",
  'chat_action_upload_failed': "Couldn't upload the attachment",
  'chat_action_stop_failed': "Couldn't stop the agent",
  'chat_action_share_failed': "Couldn't share the conversation",
  // Names the consequence, not just the failure: the user needs to know
  // the link is still live so they can retry rather than assume it's dead.
  'chat_action_revoke_share_failed':
      "Couldn't revoke the link — it may still be public",
  'chat_action_credential_failed': "Couldn't update the credential",
  'chat_action_dismiss_failed': "Couldn't dismiss the request",
  'filter_all': 'All',
  'filter_needs_approval': 'Needs approval',
  'notifications': 'Notifications',
  'no_new_notifications': 'No new notifications',
  'notifications_clear': 'Clear all',
  'notif_filter_all': 'All',
  'notif_filter_approvals': 'Approvals',
  'notif_filter_tasks': 'Tasks',
  'notif_filter_reports': 'Reports',
  'notif_group_today': 'Today',
  'notif_group_yesterday': 'Yesterday',
  'notif_group_earlier': 'Earlier',
  'notifications_empty_title': 'No notifications yet',
  'notifications_empty_body':
      'Approvals, finished tasks, and ready reports will show up here.',
  'notifications_setting_title': 'Notifications',
  'notifications_setting_subtitle':
      'Get notified about approvals, finished tasks, and ready reports.',
  'push_channel_approvals_name': 'Approvals',
  'push_channel_approvals_description':
      'Actions that are waiting for your approval',
  'push_channel_updates_name': 'Updates',
  'push_channel_updates_description': 'Finished tasks and ready reports',
  'watch_error_no_speech': 'Didn\'t catch that — try again.',
  'watch_error_unreachable': 'Couldn\'t reach Saqqar. Try again.',
  'watch_error_projects_load': 'Couldn\'t load companies.',
  'watch_error_project_setup': 'Couldn\'t set up a database.',
  'account_usage': 'Usage',
  'account_see_plans': 'See plans',
  'usage_title': 'Usage',
  'devices_title': 'Devices',
  'devices_manage': 'Manage devices',
  'devices_empty_title': 'No registered devices',
  'devices_empty_body':
      'Devices that receive your notifications will appear here.',
  'device_revoke': 'Sign out device',
  'device_revoked': 'Device removed.',
  'device_revoke_failed': "Couldn't remove that device. Please try again.",
  'device_last_seen': 'Last active {when}',
  'commands_header': 'COMMANDS',
  'commands': 'Commands',
  'no_results': 'No results',
  'search_messages_hint': 'Type to search messages',
  'search_in_conversation': 'Search in conversation',
  'slash_restart_desc': 'Restart an Odoo worker',
  'slash_report_desc': 'Generate a report',
  'slash_sync_desc': 'Sync inventory or data',
  'slash_logs_desc': 'Fetch recent server logs',
  'slash_backup_desc': 'Snapshot the environment',
  'suggest_restart_worker': 'Restart Odoo worker',
  'suggest_reconciliation_report': 'Reconciliation report',
  'suggest_pending_invoices': 'Pending invoices',
  'suggest_sync_inventory': 'Sync inventory',
  'idle_badge': 'Idle',
  'env_no_credentials': 'No credentials',
  'date_at_connector': 'at',
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
      'You will need to sign in again to access your companies and chats.',
  'signing_out': 'Signing out…',
  'delete_account': 'Delete account',
  'delete_account_confirm_title': 'Delete account?',
  'delete_account_confirm_body':
      'This permanently deletes your account and all of its data — '
          'conversations, credentials, companies, and files. This cannot be '
          'undone.',
  'deleting_account': 'Deleting account…',
  'account_deleted_toast': 'Your account has been deleted.',
  'delete_account_failed':
      "Couldn't delete your account. Please try again.",
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
  'credential_vault': 'Companies',
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
  'share_sheet_title': 'Share with Saqqar',
  'share_sheet_subtitle': 'Pick a chat to attach to, or start a new one.',
  'share_new_chat': 'Start a new chat',
  'share_existing_chats': 'Recent chats',
  'share_count_file': '1 file from another app',
  'share_count_files': '{count} files from another app',
  'share_no_conversations': 'No chats yet — start a new one to attach.',
  'share_cancel': 'Cancel share',
  'sent_toast_one_file': 'Sent · 1 file attached',
  'sent_toast_many_files': 'Sent · {count} files attached',
  'share_message': 'Share',
  'share_message_subject': 'From Saqqar',
  'voice_hold_to_talk': 'Hold the mic to talk',
  'voice_listening': 'Listening… tap to stop',
  'voice_not_available': 'Voice input is not available on this device.',
  'voice_permission_denied':
      'Microphone access is needed to record a voice message.',
  'voice_permission_open_settings':
      'Microphone access is off. Turn it on in Settings to record voice messages.',
  'open_settings': 'Open Settings',
  'record_voice': 'Record voice',
  'stop_recording': 'Stop recording',
  'transcribing': 'Transcribing…',
  'transcribe_failed': 'Transcription failed. Try again.',
  'transcribe_empty': "Couldn't catch that. Try again.",
  'mic_unavailable': 'Microphone is unavailable on this device.',
  'voice_max_length': 'Recording reached the 2-minute limit.',
  'discard_recording': 'Discard recording',
  'share_current_chat': 'Send to current chat',
  'share_current_chat_hint':
      "You're already inside this chat — tap to attach the files here.",
  // Credentials — xmlrpc auth-type switcher + test connection.
  // camelCase keys mirror the server bundle exactly so schema fields
  // (label_key, *_key_by_auth_type) can `AppStrings.lookup()` straight
  // through.
  'authType': 'Authentication',
  'authPassword': 'Password',
  'authApiKey': 'API Key',
  'apiKey': 'API Key',
  'apiKeyHelp':
      'Generate in Odoo: My Profile → Account Security → New API Key (developer mode required).',
  'apiKeyPlaceholder': 'e.g. abc123def456…xyz',
  'testConnection': 'Test connection',
  'testingConnection': 'Testing…',
  'testConnectionOk': 'Connection OK',
  'testConnectionFailed': 'Connection failed',
  // Credential field labels — app-side fallback when the server schema
  // ships no `label_key`. Resolved by field.name in the credential form.
  'credUrl': 'URL',
  'credDb': 'Database',
  'detectDatabases': 'Detect databases',
  'detectingDatabases': 'Detecting…',
  'detectDatabasesEmpty':
      'This server doesn\'t expose its database list — enter the name '
          'manually.',
  'detectDatabasesNeedsUrl': 'Enter the server URL first.',
  'detectDatabasesFailed':
      'Couldn\'t reach that server to list its databases.',
  'credModeUser': 'I\'m a user',
  'credModeDeveloper': 'I\'m a developer',
  'chatLoadEarlier': 'Load earlier messages',
  'chatLoadingEarlier': 'Loading earlier messages…',
  'security': 'Security',
  'appLockTitle': 'Saqqar is locked',
  'appLockSubtitle': 'Authenticate to continue.',
  'appLockUnlock': 'Unlock',
  'appLockReason': 'Unlock Saqqar',
  // Shown in the system biometric dialog before an irreversible action, so
  // each one names what is about to happen rather than saying "Unlock".
  'appLockConfirmSignOut': 'Confirm it is you to sign out',
  'appLockConfirmDelete': 'Confirm it is you to delete your account',
  'appLockSettingTitle': 'App lock',
  'appLockSettingSubtitle':
      'Require Face ID / fingerprint to open Saqqar.',
  'appLockUnavailable': 'Not available on this device',
  'appLockEnableFailed': "Couldn't turn on the app lock. Please try again.",
  'credUsername': 'Username',
  'credSecret': 'Secret',
  'credHost': 'Host',
  'credPort': 'Port',
  'credToken': 'Token',
  // Credential kind / tab labels — proper nouns (PostgreSQL, GitHub,
  // XML-RPC) stay verbatim; only the descriptive part localizes.
  'credKindXmlrpc': 'Odoo Connection',
  'credKindPostgres': 'PostgreSQL',
  'credKindServerShell': 'Server Shell',
  'credKindGithub': 'GitHub',
  // Test-connection error mapping — common server messages localized so
  // the badge reads in the active locale. Unknown errors fall back to the
  // raw server text.
  'testErrAuthFailed':
      'Authentication failed. Check the URL, database, and credentials.',
  'testErrBadRequest':
      'Invalid request. Check the URL format (no “/odoo” at the end).',
  'testErrTimeout': 'Connection timed out. Make sure the server is reachable.',
  'testErrUnreachable': "Couldn't reach the server. Check the URL.",
  'testErrMissingFields':
      'Enter the URL, database, username, and a password or API key.',
  'testErrInvalidSslmode':
      'Invalid SSL mode. Use one of: disable, allow, prefer, require, '
          'verify-ca, or verify-full.',
  'testErrInvalidNumber':
      'A numeric field is empty or invalid — check the Port number.',
  'testErrTokenRequired': 'An access token is required. Enter it and retry.',
  'testErrDuplicate': 'This entry already exists.',
  'testErrNotFound': "The requested item wasn't found.",
  'testErrForbidden': "You don't have permission for this action.",
  'errInvalidCode': 'Incorrect code. Check it and try again.',
  'errExpiredCode': 'This code has expired. Request a new one.',
  // Plan / quota / usage (Gap A + B)
  'plan_usage_title': 'Plan & usage',
  'plan_window_day': 'Today',
  'plan_window_week': 'This week',
  'plan_window_month': 'This month',
  'plan_daily': 'daily',
  'plan_weekly': 'weekly',
  'plan_monthly': 'monthly',
  'plan_exempt_label': 'Unlimited',
  'plan_near_limit_title': 'Approaching your limit',
  'quota_exceeded_title': 'Usage limit reached',
  'quota_upgrade_cta': 'See plans',
  'pricing_title': 'Plans & pricing',
  'pricing_subtitle': 'Pick the plan that fits how you work with your Odoo.',
  'pricing_current': 'Current plan',
  'pricing_free': 'Free',
  'pricing_cycle_monthly': 'Monthly',
  'pricing_cycle_annual': 'Annual',
  'pricing_cycle_annual_save': 'save up to 50%',
  'pricing_vat_note': 'Prices exclude VAT. {rate}% VAT is added at checkout.',
  'pricing_web_cta': 'Subscribe on the web',
  'pricing_manage_cta': 'Manage subscription on saqqaar.com',
  // Says where the user is going and what happens when they come back. A CTA
  // that silently throws you into a browser reads as the app breaking.
  'pricing_web_note':
      'Payment is completed on saqqaar.com in your browser. Your plan updates '
          'here as soon as it goes through.',
  'pricing_open_failed': "Couldn't open saqqaar.com.",
  'pricing_plans_title': 'Plans & pricing',
  'pricing_plans_subtitle': 'Compare plans and subscribe on saqqaar.com.',
  // Used where the purchase surface is off: names no destination and makes no
  // offer, so it is a description of a screen rather than a route to a sale.
  'pricing_plans_subtitle_plain': 'See what each plan includes.',
  // Plain text, never a link or a button. Mirrors `create_account_unavailable`
  // ("Registration is available on saqqaar.com."), which is already shipped
  // and already through App Review.
  'pricing_managed_on_web': 'Plans are managed on saqqaar.com.',
  // Shown when the browser could not be opened already signed in. Says the
  // one thing the user needs to know before the page loads — otherwise a
  // signed-in user taps Subscribe, gets a login form, and concludes the app
  // logged them out.
  'pricing_web_signin_note': 'You may need to sign in on the web to continue.',
  'pricing_zero': '\$0',
  'pricing_load_error': "Couldn't load plans.",
  'pricing_most_popular': 'Most popular',
  'price_plus_vat': '+ VAT',
  // Both billing cycles on one line, exactly as saqqaar.com quotes them, so
  // the price above is never the only figure a buyer sees. Every number is
  // interpolated from `/plans/` — nothing here is written down.
  'price_both_cycles':
      '\${annualMo}/mo billed annually (\${annualYr}/yr) · '
          '\${monthlyMo}/mo billed monthly (\${monthlyYr}/yr).',
  // Plan copy. The ENGLISH entries below are not display strings — they are
  // lookup KEYS. `/plans/` sends this copy in English (the endpoint has no
  // Arabic; the web page translates in the browser), and `plan_copy.dart`
  // indexes these values to find the Arabic for whatever the server sent. So
  // each English value here must stay byte-identical to the server's, and the
  // Arabic beside it is what actually reaches the screen. `plan_copy_test`
  // pins both halves against a captured live payload.
  'plan_copy_free_name': 'Free',
  'plan_copy_free_tagline': 'Try Saqqar',
  'plan_copy_free_price_note': 'Free for everyone',
  'plan_copy_free_f1': 'Chat with Saqqar on web and mobile',
  'plan_copy_free_f2': 'Connect one Odoo database',
  'plan_copy_free_f3': 'Search, read and count records',
  'plan_copy_free_f4': 'Generate Excel, PDF and Word reports',
  'plan_copy_free_f5': 'Voice input (speech to text)',
  'plan_copy_free_f6': 'Read Odoo addons',
  'plan_copy_free_f7': 'Memory across conversations',
  'plan_copy_starter_name': 'Starter',
  'plan_copy_starter_tagline': 'Get started',
  'plan_copy_starter_inherits': 'Everything in Free, plus:',
  'plan_copy_starter_f1': 'A little more monthly usage',
  'plan_copy_starter_f2': 'Priority over the free tier at busy times',
  'plan_copy_solo_name': 'Solo',
  'plan_copy_solo_tagline': 'For individuals',
  'plan_copy_solo_inherits': 'Everything in Starter, plus:',
  'plan_copy_solo_f1': 'Much higher monthly usage',
  'plan_copy_solo_f2': 'Create and edit Odoo records (with approval)',
  'plan_copy_solo_f3': 'Multiple databases and environments',
  'plan_copy_solo_f4': 'Bulk imports (create-many / load)',
  'plan_copy_solo_f5': 'Priority access to the best models',
  'plan_copy_pro_name': 'Professional',
  'plan_copy_pro_tagline': 'For power users',
  'plan_copy_pro_inherits': 'Everything in Solo, plus:',
  'plan_copy_pro_f1': 'Build and edit Odoo addons, download as .zip',
  'plan_copy_pro_f2': 'Trigger server actions and install modules',
  'plan_copy_pro_f3': 'Higher usage limits',
  'plan_copy_pro_f4': 'Priority support',
  'plan_copy_business_name': 'Business',
  'plan_copy_business_tagline': 'For teams & heavy use',
  'plan_copy_business_inherits': 'Everything in Professional, plus:',
  'plan_copy_business_f1': 'Highest usage limits',
  'plan_copy_business_f2': 'Direct database and secure server access',
  'plan_copy_business_f3': 'Early access to new features',
  'plan_copy_business_f4': 'Priority support',
  'plan_copy_business_f5': 'Dedicated onboarding',
  'use_my_database_title': 'Set up your database?',
  'env_hint_title': 'No database connected',
  'env_hint_body':
      'Saqqar needs an Odoo environment to act on. Connect your database to start.',
  'env_hint_use_my_database': 'Use My Database',
  'env_hint_bound': 'Database connected.',
  'env_hint_needs_credentials':
      'Add your Odoo credentials to this environment to connect.',
  'env_hint_failed': 'Could not set up your database. Try again.',
  'addon_hint': 'Saqqar can read, edit, and rebuild this Odoo addon.',
  // Names no tier and sells nothing — the same copy ships on iOS, where
  // naming a paid plan would be an App Store 3.1.1 upsell.
  'voice_locked_pro': "Voice input isn't available on your account.",
  // Email-OTP auth flow (Gap D)
  'auth_signup_email_title': 'Create your account',
  'auth_signup_email_subtitle': 'Enter your email to get started.',
  'auth_check_email_title': 'Check your email',
  'auth_check_email_subtitle': 'Enter the 6-digit code we just sent.',
  'auth_profile_title': 'Finish your profile',
  'auth_profile_subtitle': 'Add your name and choose a password.',
  'auth_welcome_back_title': 'Welcome back',
  'auth_welcome_back_subtitle': 'Sign in to continue to your workspace.',
  'auth_password_title': 'Enter your password',
  'auth_password_subtitle': 'Sign in with your account password.',
  'auth_reset_title': 'Reset your password',
  'auth_reset_subtitle': "Enter your email — we'll send a verification code.",
  'auth_new_password_title': 'Set a new password',
  'auth_new_password_subtitle': 'Choose a strong password to finish resetting.',
  'auth_first_name': 'First name',
  'auth_last_name': 'Last name',
  'auth_new_password_label': 'New password',
  'auth_confirm_new_password': 'Confirm new password',
  'auth_otp_label': 'Verification code',
  'auth_otp_hint': 'We sent a 6-digit code to your email. It expires in 10 minutes.',
  'auth_email_placeholder': 'you@example.com',
  'auth_password_placeholder': 'At least 8 characters',
  'auth_password_enter_placeholder': 'Enter your password',
  'auth_confirm_placeholder': 'Repeat your password',
  'auth_confirm_new_placeholder': 'Repeat new password',
  'auth_continue_email': 'Continue with email',
  'auth_continue_password': 'Continue with password',
  'auth_continue_email_instead': 'Continue with email instead',
  'auth_continue_password_instead': 'Continue with password instead',
  'auth_or_continue_with': 'or continue with',
  'auth_continue_google': 'Continue with Google',
  'auth_continue_apple': 'Continue with Apple',
  'auth_verify_code': 'Verify code',
  'auth_verify_signin': 'Verify & sign in',
  'auth_create_account_btn': 'Create account',
  'auth_login_btn': 'Login',
  'auth_forgot_password': 'Forgot password?',
  'auth_send_reset_code': 'Send reset code',
  'auth_set_new_password_btn': 'Set new password & sign in',
  'auth_signin_instead': 'Sign in instead',
  'auth_create_an_account': 'Create an account',
  'auth_back_to_signin': 'Back to sign in',
  'auth_use_different_email': 'Use different email',
  'auth_didnt_get_code': "Didn't get the code?",
  'auth_resend_now': 'Resend',
  'auth_remember_it_now': 'Remember it now?',
  'auth_passwords_mismatch': "Passwords don't match.",
  'auth_code_required': 'Enter the 6-digit code.',
  'auth_name_required': 'Enter your first name.',
  'auth_password_set': 'Password set. Sign in with your new password.',
  'personal_info_title': 'Personal information',
  'personal_info_hint': 'The details you gave when you signed up.',
  'email_login_label': 'Email (login)',
  'email_login_hint': "Your email is your login and can't be changed here.",
  'save_changes': 'Save changes',
  'profile_updated_toast': 'Your profile was updated.',
  'status_saved': 'Saved',
  'status_no_changes': 'No changes',
  'approval_title_cred_storage': 'Credential storage',
  'approval_title_cred_usage': 'Credential usage',
  'approval_title_server_cmd': 'Server command',
  'approval_title_odoo_write': 'Odoo write',
  'approval_title_report_export': 'Report export',
  'approval_title_generic': 'Approval',
  'approval_op_create': 'Create',
  'approval_op_write': 'Update',
  'approval_op_delete': 'Delete',
  'approval_op_call': 'Run',
  'approval_op_load': 'Import',
  'auth_password': 'password',
  'quick_reply_more': 'Tell me more',
  'quick_reply_summarize': 'Summarize this',
  'quick_reply_export': 'Export as Excel',
  'swipe_archive': 'Archive',
  'swipe_unarchive': 'Unarchive',
  'swipe_delete': 'Delete',
  'long_press_actions_title': 'Conversation actions',
  'copy_action': 'Copy',
  'offline_title': 'You\'re offline',
  'offline_body': 'Saqqar needs a live connection to act.',
  'back_online': 'Back online',
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
  'vault_coverage_title': 'Companies',
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
  'header_project': 'Company',
  'header_environment': 'Environment',
  'pick_project_first': 'Pick a company first',
  'no_projects_yet': '— No companies yet —',
  'no_environments_for_project': '— No environments —',
  'create_environment_cta': '+ Add environment',
  'create_environment_confirm_title': 'Create an environment?',
  'create_environment_confirm_body':
      "This company doesn't have any environments yet. Add one to start chatting in this company.",
  'header_none_option': '—',

  // Vault lifecycle (web saqqaar.com verbatim)
  'no_stored_credentials_title': 'No stored credentials.',
  'no_stored_credentials_body':
      'The agent will request the exact access it needs.',
  'project_name': 'Company name',
  'add_project': 'Add company',
  'add_project_hint': 'Add company…',
  'projects_title': 'Companies',
  'back_to_projects': 'All companies',
  'manage_projects': 'Manage companies',
  'project_saved_toast': 'Company saved.',
  'project_deleted_toast': 'Company deleted.',
  'delete_project_title': 'Delete company?',
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
  // (old `test_connection` + `testing_connection` keys retired —
  // replaced by camelCase server bundle below.)
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

  // Company / Environment
  'pick_environment': 'Pick an environment',
  'pick_environment_subtitle':
      'The credential the agent uses for this conversation.',
  'no_environment_picked': '— No environment —',
  'pick_environment_to_start':
      'Choose a company and environment at the top of the screen to start.',
  'environment_set_for_chat': 'Environment set for this chat.',
  'live_badge': 'LIVE',
  'read_only_badge': 'READ-ONLY',
  'auto_approve_badge': 'AUTO',
  'project': 'Company',
  'environment': 'Environment',
  'change_environment': 'Change environment',
  'env_multi_title': 'Environments',
  'env_multi_subtitle':
      'Pick one or more environments the agent can use in this conversation.',
  'env_multi_apply': 'Apply',
  'env_multi_updated': 'Environments updated.',
  'env_multi_none': 'No environments selected',

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

  // Interpolated copy — `{placeholder}` slots are filled by `_f`. These
  // were inline `_isArabic ? … : …` ternaries until they were moved here
  // so `i18n_parity_test` can see both sides.
  'env_multi_selected_count': '{n} selected',
  'env_multi_extra': '+{n} more',
  'more_pending_approvals': '+ {n} more pending approvals',
  'last_verified_at': 'Last verified {at}',
  'similar_requests_count': '{count} similar requests',
  'operation_on_model': '{operation} on `{model}`',
  'approve_all_n': 'Approve all {count}',
  'reject_all_n': 'Reject all {count}',
  'approve_all_similar': 'Approve all similar requests',
  'approval_batch_resolved': 'Approved {count} requests',
  'approval_granted_with_preapproval':
      'Approval granted. {count} similar request(s) pre-approved.',
  'live_warning_title': 'Live environment: {envName}',
  'live_warning_body':
      'You\'re about to talk to "{envName}" in company "{projectName}" — a '
          'LIVE environment. Destructive actions are still approval-gated, '
          'but be careful. Continue?',
  'share_token_label': 'Token: {token}',
  'phase_fetching': 'Fetching {current}',
  'phase_fetching_of_total': 'Fetching {current} / {total} · {pct}%',
  'phase_rendering': 'Writing file…',
  'phase_rendering_rows': 'Writing file… {rows} rows',
  'to_approve': '{n} TO APPROVE',
  'relative_minutes_ago': '{n} m ago',
  'relative_hours_ago': '{n} h ago',
  'relative_days_ago': '{n} d ago',
  'auth_resend_in': 'Resend in {seconds} s',
  'plan_pct_used': '{pct}% used',
  'item_count': '{visible} of {total} {label}',

  // Units. Digits stay Western in both locales (see `AppDateFormat`), but
  // the unit *word* localizes — `2.4 MB` / `2.4 م.ب`.
  'unit_bytes': 'B',
  'unit_kilobytes': 'KB',
  'unit_megabytes': 'MB',
  'compact_thousands': 'K',
  'compact_millions': 'M',

  'file_kind_image': 'Image',
  'auth_otp_placeholder': '1 2 3 4 5 6',

  // Account link groups
  'account_group_workspace': 'Workspace',
  'account_group_workspace_hint': 'Tools that work on your Odoo directly.',
  'account_group_security': 'Security',
  'account_group_billing': 'Billing',
  'account_group_billing_hint': 'Your plan, payments and receipts.',
  'apps_subtitle': 'Guided setups you can run in one tap.',
  'trial_subtitle': 'Get a hosted Odoo to try things on.',
  'data_explorer_subtitle': 'Read your models and records directly.',
  'devices_subtitle': 'See where you\'re signed in, sign out a lost phone.',
  'checkout_subtitle': 'Top up the tokens Saqqar spends on your work.',
  'billing_history_subtitle': 'Past payments and receipts.',

  // New endpoints (API_MOBILE_NEW_ENDPOINTS.md)
  'apps_title': 'Saqqar Apps',
  'apps_empty_title': 'No apps yet',
  'apps_empty_body': 'Guided setups will appear here once they\'re available.',
  'apps_opening': 'Opening…',
  'apps_needs_env': 'Needs a connected environment',
  'apps_launch_failed': 'Couldn\'t open this app',
  'billing_history_title': 'Billing history',
  'billing_balance': 'Token balance',
  'billing_total_purchased': 'Total purchased',
  'billing_empty_title': 'No payments yet',
  'billing_empty_body': 'Your past payments and receipts will show up here.',
  'billing_receipt': 'Receipt',
  'billing_receipt_failed': 'Couldn\'t open the receipt. Try again.',
  'billing_receipt_no_viewer': 'No PDF viewer found on this device.',
  'billing_paid': 'Paid',
  'billing_failed': 'Failed',
  'plan_status_active': 'Active',
  'plan_status_trialing': 'Trial',
  'plan_status_canceled': 'Canceled',
  'plan_status_past_due': 'Payment overdue',
  'plan_renews_on': 'Renews on {date}',
  'billing_status_pending': 'Pending',
  'billing_status_expired': 'Expired',
  'billing_status_refunded': 'Refunded',
  'billing_status_chargeback': 'Chargeback',
  // Says what "pending" means and what to do. A payment that sits here is
  // either still being confirmed or never completed, and the user cannot tell
  // those apart — so give them the reference and a way to ask.
  'billing_pending_note':
      'Waiting for confirmation from the payment provider. If you completed '
          'this payment and it hasn\'t updated, contact support with reference '
          '{ref}.',
  'trial_title': 'Managed Odoo trial',
  'trial_intro':
      'Request a hosted Odoo trial and we\'ll set it up for you — no self-hosting needed.',
  'trial_company_name': 'Company name',
  'trial_company_required': 'Company name is required',
  'trial_work_email': 'Work email (optional)',
  'trial_phone': 'Phone (optional)',
  'trial_request_button': 'Request trial',
  'trial_pending_title': 'Queued…',
  'trial_provisioning_title': 'Building your trial…',
  'trial_provisioning_body':
      'This can take a few minutes. You can leave this screen and come back.',
  'trial_ready_title': 'Your trial is ready',
  'trial_failed_title': 'Provisioning failed',
  'trial_failed_body': 'Something went wrong while building your trial.',
  'trial_url': 'URL',
  'trial_db': 'Database',
  'trial_login': 'Login',
  'trial_password': 'Password',
  'trial_open': 'Open Odoo',
  'trial_open_failed': 'Couldn\'t open the link.',
  'trial_copied': 'Copied',
  'trial_credentials_warning':
      'These are live admin credentials — keep them private and don\'t share them.',
  'copy': 'Copy',
  'artifact_details_title': 'Artifact details',

  // §4 — Meetings
  'meetings_title': 'Meeting transcription',
  'meetings_intro':
      'Paste an online meeting link to start live transcription.',
  'meetings_preview_note':
      'Preview — the meetings API shapes aren\'t finalised in the spec; confirm with the backend.',
  'meetings_url_label': 'Meeting link',
  'meetings_url_required': 'A meeting link is required',
  'meetings_start': 'Start transcription',
  'meetings_status': 'Status',
  'meetings_stop': 'Stop',
  'meetings_summarize': 'Summarize',
  'meetings_transcript': 'Transcript',
  'meetings_transcript_empty': 'Waiting for the transcript…',
  'meetings_summary': 'Summary',
  'meetings_ask_label': 'Ask about this meeting',
  'meetings_ask': 'Ask',
  'meetings_reply': 'Answer',

  // §4 — Direct data explorer
  'data_explorer_title': 'Data explorer',
  'data_explorer_preview_note':
      'Read-only Odoo queries — no agent, no token cost, and nothing here can change your data. Edit the sample request to match the model and fields you need.',
  'data_explorer_env': 'Environment',
  'data_explorer_no_envs': 'No environments — set one up in Vault first.',
  'data_explorer_model': 'Model',
  'data_explorer_model_required': 'A model is required',
  'data_explorer_domain': 'Domain (optional JSON)',
  'data_explorer_count': 'Count',
  'data_explorer_search': 'Search',
  'data_explorer_result': 'Result',
  'data_explorer_operation': 'Operation',
  'data_explorer_body': 'Request body (JSON)',
  'data_explorer_run': 'Run',
  'data_explorer_invalid_json': 'The request body isn\'t valid JSON.',

  // §4 — Billing checkout
  'checkout_title': 'Buy tokens',
  'checkout_preview_note':
      'In-app purchase may conflict with App Store / Play billing rules — confirm before release. Hidden on iOS.',
  'checkout_buy': 'Buy',
  'checkout_waiting': 'Waiting for payment — complete it in your browser.',
  'checkout_paid': 'Payment complete. Thank you!',
  'checkout_failed': 'Payment failed or was cancelled.',
  'checkout_open_failed': 'Couldn\'t open the payment page.',
  'checkout_empty': 'No plans available right now.',
};

const Map<String, String> _ar = {
  'app_name': 'صقّار',
  'product_initial': 'S',
  'app_tagline': 'مساعد عمليات أودو',
  'production_domain': 'saqqaar.com',
  'digital_harbor': 'Digital Harbor',
  // The company name stays Latin — it is a registered trademark and is not
  // transliterated — but the connector around it is prose and belongs in
  // the reader's language.
  'powered_by_digital_harbor': 'بدعم من Digital Harbor',
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
  'auth_brand_body':
      'وكيل أودو مباشر يشخّص ويجهز التقارير وينفذ عبر بيانات دخول خاصة وموافقات قبل أي تغيير حساس.',
  'open_workspace': 'فتح مساحة العمل',
  'tab_chats': 'المحادثات',
  'tab_vault': 'الشركات',
  'tab_inbox': 'الوارد',
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
  // Exonyms, matching the English table's own convention ('English' /
  // 'Arabic'). This entry used to read 'English', which left the language
  // picker in an Arabic UI showing 'العربية' next to a Latin 'English' —
  // half-translated, and the only such row on the Preferences card.
  'english': 'الإنجليزية',
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
  'default_project_label': 'الافتراضي',
  'conversation_preview_unavailable': 'في إجراء منتظر في هذه المحادثة.',
  'artifact_download_failed': 'تعذّر تنزيل الملف. حاول مرة أخرى.',
  'artifact_download_offline': 'لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مرة أخرى.',
  'artifact_download_gone': 'هذا الملف لم يعد متاحًا.',
  'artifact_download_forbidden': 'هذا الملف غير متاح ضمن خطتك الحالية.',
  'more': 'المزيد',
  'share_link': 'رابط المشاركة',
  'rename': 'إعادة تسمية',
  'archive': 'أرشفة',
  'unarchive': 'إلغاء الأرشفة',
  'delete': 'حذف',
  'delete_conversation_title': 'حذف المحادثة؟',
  'delete_conversation_body':
      'سيتم حذف هذه المحادثة وكل رسائلها نهائيًا. لا يمكن التراجع عن هذا الإجراء.',
  'edit': 'تعديل',
  'dismiss': 'إخفاء',
  'open': 'فتح',
  'approve': 'موافقة',
  'reject': 'رفض',
  'show_details': 'عرض التفاصيل',
  'hide_details': 'إخفاء التفاصيل',
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
  'shared_conversation_title': 'محادثة مُشارَكة',
  'shared_conversation_empty': 'لا توجد رسائل لعرضها في هذه المحادثة.',
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
  'clear_search': 'مسح البحث',
  'previous_page': 'الصفحة السابقة',
  'next_page': 'الصفحة التالية',
  'first_page': 'الصفحة الأولى',
  'conversation_actions': 'إجراءات المحادثة',
  'credential_actions': 'إجراءات بيانات الدخول',
  'attach_files': 'إرفاق صور أو PDF أو جداول',
  'attach_source_title': 'إرفاق',
  'attach_source_photos': 'الصور',
  'attach_source_photos_hint': 'اختر من مكتبة الصور',
  'attach_source_camera': 'الكاميرا',
  'attach_source_camera_hint': 'التقط صورة الآن',
  'attach_source_files': 'الملفات',
  'attach_source_files_hint': 'PDF وExcel وWord وCSV وZIP',
  'attach_camera_denied':
      'الوصول إلى الكاميرا مغلق. فعّله من الإعدادات لالتقاط الصور.',
  'viewer_open_externally': 'فتح في تطبيق آخر',
  'viewer_unsupported_title': 'لا يمكن عرض هذا الملف هنا',
  'viewer_unsupported_body':
      'يعرض صقار الصور وملفات PDF والملفات النصية داخل التطبيق. هذا الملف '
          'يحتاج تطبيقًا آخر لفتحه.',
  'viewer_load_failed': 'تعذّر فتح هذا الملف',
  'viewer_truncated': 'يتم عرض الجزء الأول من الملف فقط.',
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
  'email_preview_to': 'إلى:',
  'email_preview_cc': 'نسخة إلى:',
  'email_preview_bcc': 'نسخة مخفية إلى:',
  'email_preview_reply': 'رد',
  'delete_confirm_title': 'تأكيد الحذف',
  'delete_confirm_body':
      'سيحذف هذا {count} سجلاً من Odoo نهائياً. اكتب {phrase} للتأكيد.',
  'delete_confirm_hint': 'اكتب {phrase}',
  'delete_confirm_mismatch': 'النص غير مطابق. اكتب {phrase} كما هو.',
  'task_prep': 'تجهيز المهمة',
  'task_prep_title':
      'صقّار يطرح أسئلة توضيحية مختصرة قبل تنفيذ أي مهمة غير واضحة',
  'task_prep_on':
      'تجهيز المهمة مفعّل. صقّار سيطرح أسئلة قصيرة لتوضيح المهام غير المكتملة.',
  'task_prep_off': 'تجهيز المهمة متوقف. صقّار سيبدأ من النص المكتوب مباشرة.',
  'tools_title': 'أدوات صقار',
  'tools_upload_file': 'رفع ملف',
  'tools_modes_section': 'أوضاع التشغيل',
  'tools_odoo_section': 'أدوات Odoo',
  'tools_connect_section': 'الربط والتكاملات',
  'tools_readonly_note': 'الأدوات لا تغيّر أي شيء في Odoo بدون موافقتك.',
  'tools_needs_conversation':
      'أرسل رسالة أولاً — تعمل الفحوصات داخل محادثة قائمة.',
  'app_name_zatca': 'الفوترة الإلكترونية (زاتكا)',
  'app_name_zatca_e_invoicing': 'الفوترة الإلكترونية (زاتكا)',
  'app_tagline_zatca':
      'تفعيل فوترة المرحلة الثانية (فاتورة) على أودو – CSR ورمز التحقق '
          'والإطلاق.',
  'app_tagline_zatca_e_invoicing':
      'تفعيل فوترة المرحلة الثانية (فاتورة) على أودو – CSR ورمز التحقق '
          'والإطلاق.',

  'app_name_whatsapp_integration': 'تكامل واتساب',
  'app_tagline_whatsapp_integration':
      'اربط واتساب للأعمال (Cloud API) ليتمكّن أودو من إرسال الرسائل '
          'واستقبالها.',

  'app_name_chart_of_accounts_builder': 'مُنشئ شجرة الحسابات',
  'app_tagline_chart_of_accounts_builder':
      'أنشئ أو استورد شجرة حسابات نظيفة ومحلّية واضبط القيود الافتراضية.',

  'app_name_bank_reconciliation': 'التسوية البنكية',
  'app_tagline_bank_reconciliation':
      'إعداد اليوميات البنكية واستيراد الكشوف وقواعد التسوية التي تطابق '
          'تلقائيًا.',

  'app_group_all': 'الكل',
  'app_group_accounting': 'المحاسبة',
  'app_group_finance': 'المالية',
  'app_group_integrations': 'التكاملات',
  'app_launch_title': 'أين تريد تشغيل هذا؟',
  'app_launch_project': 'الشركة',
  'app_launch_environment': 'قاعدة البيانات',
  'app_launch_start': 'ابدأ',
  'app_launch_skip': 'أحدّدها لاحقًا في المحادثة',
  'app_launch_needs_env':
      'يعمل هذا الإعداد على قاعدة بيانات أودو متصلة. اختر واحدة، أو حدّدها '
          'لاحقًا حين يسألك صقّار.',
  'app_launch_optional_env':
      'اختياري — سيسألك صقّار داخل المحادثة إذا احتاج قاعدة بيانات.',
  'app_launch_no_projects':
      'لا توجد شركات بعد. سيساعدك صقّار على ربط واحدة داخل المحادثة.',
  'app_launch_no_envs': 'لا توجد قواعد بيانات في هذه الشركة بعد.',
  'app_launch_pick_project_first': 'اختر شركة أولًا.',
  'voice_support_title': 'الدعم',
  'voice_support_intro': 'اشرح المشكلة وسيقوم صقّار بصياغة تشخيص ورد مقترح.',
  'voice_support_hint': 'ما الذي حدث؟',
  'voice_support_submit': 'اطلب المساعدة',
  'voice_support_summary': 'اللي فهمناه',
  'voice_support_diagnosis': 'السبب المرجّح',
  'voice_support_reply': 'الرد المقترح',
  'voice_support_steps': 'خطوات للتجربة',
  'voice_support_questions': 'ما زال بحاجة إلى إجابة',
  'voice_support_file_ticket': 'احفظ كتذكرة',
  'voice_support_ticket_confirm_title': 'إنشاء تذكرة في Odoo؟',
  'voice_support_ticket_confirm_body':
      'سيؤدي هذا إلى إنشاء تذكرة دعم حقيقية في قاعدة بياناتك المتصلة.',
  'voice_support_ticket_created': 'تم إنشاء التذكرة',
  'voice_support_task_created': 'تم الحفظ كمهمة في Odoo',
  'voice_support_ticket_not_created':
      'قبل الخادم الطلب لكنه لم يُرجع تذكرة. لم يتم إنشاء أي شيء — من فضلك '
          'حاول مرة أخرى.',
  'voice_support_empty': 'لم يصل أي تشخيص. جرّب صياغة المشكلة بطريقة أخرى.',
  'tools_prompt_bank': 'بنك الصياغات',
  'tools_health_radar': 'رادار الصحة',
  'tools_what_if': 'ماذا لو',
  'tools_business_pulse': 'نبض الأعمال',
  'tools_my_database': 'قاعدة بياناتي',
  'tools_voice_support': 'الدعم الصوتي',
  'clarify_title': 'سؤالان سريعان',
  'clarify_something_else': 'شيء آخر…',
  'clarify_build_send': 'نفّذ وأرسل',
  'clarify_prepare_review': 'جهّز للمراجعة',
  'clarify_needs_answer': 'اختر إجابة واحدة على الأقل',
  'clarify_answers_header': 'إجابات أسئلتك:',
  'clarify_ready_to_review': 'الإجابات جاهزة في مربع الكتابة — عدّلها أو أرسلها.',
  'suggestion_title': 'صياغة أوضح للطلب',
  'suggestion_approve': 'اعتمد الصياغة',
  'suggestion_keep_mine': 'أبقِ صياغتي',
  'report_title': 'إنشاء تقرير',
  'report_type': 'النوع',
  'report_period': 'الفترة',
  'report_lens': 'العرض',
  'report_format': 'الصيغة',
  'report_records': 'السجلات',
  'report_pick_records': 'اختر السجلات',
  'report_search_records': 'ابحث في السجلات',
  'report_records_truncated': 'تظهر أول {count} — ابحث لتضييق القائمة.',
  'report_no_records': 'لا توجد سجلات مطابقة.',
  'report_selected_count': 'تم اختيار {count}',
  'report_build': 'أنشئ التقرير',
  'report_needs_type': 'اختر نوع التقرير أولاً',
  'report_compose':
      'أنشئ هذا التقرير:\n- النوع: {type}\n- الفترة: {period}\n'
          '- الصيغة: {format}',
  'report_compose_lens': '\n- العرض: {lens}',
  'report_compose_records': '\n- السجلات: {names}',
  'stop_generation': 'إيقاف الردّ',
  'generation_stopped': 'تم الإيقاف.',
  'stopping': 'جارِ الإيقاف…',
  'agent_working': 'يعمل',
  'agent_thinking': 'يعمل على طلبك.',
  'saqqar_thinking': 'صقّار يفكر',
  'saqqar_working_now': 'يعمل الآن',
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
  'error_unexpected_response':
      'وصل من الخادم رد لا يفهمه التطبيق. حدّث التطبيق إلى آخر إصدار، '
          'وتواصل مع الدعم إذا تكرر الأمر.',
  'loading': 'جارٍ التحميل…',
  // ── Typed error categories ──
  'error_network': 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.',
  'error_timeout': 'استغرق الخادم وقتاً طويلاً. حاول مرة أخرى.',
  'error_cancelled': 'تم إلغاء العملية.',
  'error_unauthorized': 'انتهت جلستك. سجّل الدخول من جديد.',
  'error_forbidden':
      'ليس لديك صلاحية لتنفيذ هذه العملية. اطلب الصلاحية من مالك قاعدة بيانات '
          'أودو، أو انتقل إلى قاعدة بيانات تملك صلاحية الكتابة عليها.',
  'error_not_found':
      'لم نعثر على المطلوب — قد يكون محذوفاً أو تم نقله. اسحب للأسفل لتحديث '
          'القائمة.',
  'error_validation':
      'بعض الحقول تحتاج للمراجعة. راجع الحقول المحدّدة ثم حاول مرة أخرى.',
  'error_conflict': 'هذه العملية تتعارض مع البيانات الحالية. حدّث الصفحة ثم حاول مجدداً.',
  'error_rate_limited': 'محاولات كثيرة. تمهّل قليلاً.',
  'error_rate_limited_with_retry': 'محاولات كثيرة. حاول بعد {seconds} ثانية.',
  'error_payload_too_large':
      'الملف كبير جداً. الحد الأقصى 25 ميجابايت (500 ميجابايت للأرشيف).',
  'error_quota_exceeded':
      'استهلكت حصتك الحالية. تُجدَّد مع بداية الفترة التالية.',
  'error_unsupported_media':
      'نوع الملف غير مدعوم. جرّب مستنداً أو جدولاً أو صورة أو PDF.',
  'error_server': 'وقعت مشكلة في الخادم. حاول بعد قليل.',
  'error_social_not_configured':
      'طريقة الدخول هذه غير متاحة في هذه النسخة. يمكنك الدخول ببريدك '
          'الإلكتروني بدلاً منها.',
  'error_social_no_token':
      'لم تكتمل عملية الدخول. حاول مرة أخرى، أو ادخل ببريدك الإلكتروني.',
  'error_social_rejected':
      'رفض جهازك عملية الدخول. تأكد من تسجيل دخولك لهذا الحساب في إعدادات '
          'الهاتف ثم حاول مرة أخرى.',
  'error_unknown': 'حدث خطأ. حاول مرة أخرى.',
  'crash_screen_title': 'حدث خطأ ما',
  'crash_screen_body': 'واجهت هذه الشاشة مشكلة، وتم تسجيل الخطأ. جرّب الرجوع '
      'للخلف، أو أعد تشغيل التطبيق إذا تكرر الأمر.',
  // ── Vault action labels (prefixes) ──
  'vault_action_load_failed': 'تعذّر تحميل شركاتك',
  'vault_action_create_project_failed': 'تعذّر إنشاء الشركة',
  'vault_action_rename_project_failed': 'تعذّر إعادة تسمية الشركة',
  'vault_action_delete_project_failed': 'تعذّر حذف الشركة',
  'vault_action_create_environment_failed': 'تعذّر إنشاء البيئة',
  'vault_action_update_environment_failed': 'تعذّر تحديث البيئة',
  'vault_action_delete_environment_failed': 'تعذّر حذف البيئة',
  'vault_action_load_credentials_failed': 'تعذّر تحميل بيانات الدخول',
  'vault_action_save_credential_failed': 'تعذّر حفظ بيانات الدخول',
  'vault_action_delete_credential_failed': 'تعذّر حذف بيانات الدخول',
  // ── Vault success toasts ──
  'vault_toast_project_created': 'تم إنشاء الشركة.',
  'vault_toast_project_deleted': 'تم حذف الشركة.',
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
  'conversations_action_share_failed': 'تعذّر إنشاء رابط المشاركة',
  'chat_action_send_failed': 'تعذّر إرسال رسالتك',
  'chat_action_upload_failed': 'تعذّر رفع المرفق',
  'chat_action_stop_failed': 'تعذّر إيقاف الوكيل',
  'chat_action_share_failed': 'تعذّر مشاركة المحادثة',
  'chat_action_revoke_share_failed':
      'تعذّر إلغاء الرابط — قد يكون ما زال عاماً',
  'chat_action_credential_failed': 'تعذّر تحديث بيانات الاعتماد',
  'chat_action_dismiss_failed': 'تعذّر تجاهل الطلب',
  'filter_all': 'الكل',
  'filter_needs_approval': 'بحاجة موافقة',
  'notifications': 'الإشعارات',
  'no_new_notifications': 'لا توجد إشعارات جديدة',
  'notifications_clear': 'مسح الكل',
  'notif_filter_all': 'الكل',
  'notif_filter_approvals': 'موافقات',
  'notif_filter_tasks': 'مهام',
  'notif_filter_reports': 'تقارير',
  'notif_group_today': 'اليوم',
  'notif_group_yesterday': 'أمس',
  'notif_group_earlier': 'أقدم',
  'notifications_empty_title': 'لا توجد إشعارات بعد',
  'notifications_empty_body':
      'الموافقات والمهام المكتملة والتقارير الجاهزة هتظهر هنا.',
  'notifications_setting_title': 'الإشعارات',
  'notifications_setting_subtitle':
      'استقبل تنبيهات الموافقات والمهام المكتملة والتقارير الجاهزة.',
  'push_channel_approvals_name': 'الموافقات',
  'push_channel_approvals_description': 'إجراءات في انتظار موافقتك',
  'push_channel_updates_name': 'التحديثات',
  'push_channel_updates_description': 'المهام المكتملة والتقارير الجاهزة',
  'watch_error_no_speech': 'لم يصلنا صوت واضح. حاول مرة أخرى.',
  'watch_error_unreachable': 'تعذّر الوصول إلى صقّار. حاول مرة أخرى.',
  'watch_error_projects_load': 'تعذّر تحميل الشركات.',
  'watch_error_project_setup': 'تعذّر إنشاء قاعدة بيانات.',
  'account_usage': 'الاستخدام',
  'account_see_plans': 'عرض الخطط',
  'usage_title': 'الاستخدام',
  'devices_title': 'الأجهزة',
  'devices_manage': 'إدارة الأجهزة',
  'devices_empty_title': 'لا توجد أجهزة مسجّلة',
  'devices_empty_body': 'الأجهزة اللي بتستقبل إشعاراتك هتظهر هنا.',
  'device_revoke': 'تسجيل خروج الجهاز',
  'device_revoked': 'تم حذف الجهاز.',
  'device_revoke_failed': 'تعذّر حذف الجهاز. حاول مرة أخرى.',
  'device_last_seen': 'آخر نشاط {when}',
  'commands_header': 'الأوامر',
  'commands': 'الأوامر',
  'no_results': 'لا نتائج',
  'search_messages_hint': 'اكتب للبحث في الرسائل',
  'search_in_conversation': 'بحث في المحادثة',
  'slash_restart_desc': 'إعادة تشغيل عامل Odoo',
  'slash_report_desc': 'توليد تقرير',
  'slash_sync_desc': 'مزامنة المخزون أو البيانات',
  'slash_logs_desc': 'جلب سجلّات الخادم الأخيرة',
  'slash_backup_desc': 'لقطة من البيئة',
  'suggest_restart_worker': 'إعادة تشغيل عامل Odoo',
  'suggest_reconciliation_report': 'تقرير التسويات',
  'suggest_pending_invoices': 'الفواتير المعلّقة',
  'suggest_sync_inventory': 'مزامنة المخزون',
  'idle_badge': 'خامل',
  'env_no_credentials': 'لا توجد بيانات اعتماد',
  'date_at_connector': 'في',
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
      'هتحتاج تسجّل الدخول من جديد عشان توصل لشركاتك ومحادثاتك.',
  'signing_out': 'جاري تسجيل الخروج…',
  'delete_account': 'حذف الحساب',
  'delete_account_confirm_title': 'حذف الحساب؟',
  'delete_account_confirm_body':
      'هيتم حذف حسابك وكل بياناته نهائيًا — المحادثات وبيانات الاعتماد '
          'والشركات والملفات. الإجراء ده مالوش رجعة.',
  'deleting_account': 'جاري حذف الحساب…',
  'account_deleted_toast': 'تم حذف حسابك.',
  'delete_account_failed': 'تعذّر حذف الحساب. حاول تاني.',
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
  'credential_vault': 'الشركات',
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
  'share_sheet_title': 'مشاركة مع صقّار',
  'share_sheet_subtitle': 'اختر محادثة لإرفاق الملفات بها، أو ابدأ محادثة جديدة.',
  'share_new_chat': 'محادثة جديدة',
  'share_existing_chats': 'المحادثات الأخيرة',
  'share_count_file': 'ملف واحد من تطبيق آخر',
  'share_count_files': '{count} ملفات من تطبيق آخر',
  'share_no_conversations': 'لا توجد محادثات — ابدأ واحدة جديدة لإرفاق الملفات.',
  'share_cancel': 'إلغاء المشاركة',
  'sent_toast_one_file': 'تم الإرسال · ملف واحد مرفق',
  'sent_toast_many_files': 'تم الإرسال · {count} ملفات مرفقة',
  'share_message': 'مشاركة',
  'share_message_subject': 'من صقّار',
  'voice_hold_to_talk': 'اضغط مطوّل على الميكروفون',
  'voice_listening': 'جارٍ الاستماع… اضغط للإيقاف',
  'voice_not_available': 'الإدخال الصوتي غير متاح على هذا الجهاز.',
  'voice_permission_denied':
      'محتاجين إذن الميكروفون عشان تسجّل رسالة صوتية.',
  'voice_permission_open_settings':
      'إذن الميكروفون مقفول. فعّله من الإعدادات عشان تسجّل رسائل صوتية.',
  'open_settings': 'افتح الإعدادات',
  'record_voice': 'تسجيل صوتي',
  'stop_recording': 'إيقاف التسجيل',
  'transcribing': 'جارٍ تحويل الصوت…',
  'transcribe_failed': 'تعذّر تحويل الصوت. حاول مرة أخرى.',
  'transcribe_empty': 'لم نتمكن من سماعك بوضوح، حاول مرة أخرى.',
  'mic_unavailable': 'الميكروفون غير متاح على هذا الجهاز.',
  'voice_max_length': 'وصل التسجيل إلى الحد الأقصى (دقيقتان).',
  'discard_recording': 'إلغاء التسجيل',
  'share_current_chat': 'إرسال للمحادثة الحالية',
  'share_current_chat_hint':
      'أنت بالفعل داخل هذه المحادثة — اضغط لإرفاق الملفات هنا.',
  // Credentials — xmlrpc auth-type switcher + test connection.
  'authType': 'نوع المصادقة',
  'authPassword': 'كلمة المرور',
  'authApiKey': 'مفتاح API',
  'apiKey': 'مفتاح API',
  'apiKeyHelp':
      'أنشئه في أودو: ملفي الشخصي ← الأمان ← مفتاح API جديد (يتطلب وضع المطوّر).',
  'apiKeyPlaceholder': 'مثلاً abc123def456…xyz',
  'testConnection': 'اختبر الاتصال',
  'testingConnection': 'جارٍ الاختبار…',
  'testConnectionOk': 'الاتصال ناجح',
  'testConnectionFailed': 'فشل الاتصال',
  // مسميات حقول بيانات الاعتماد — بديل من جهة التطبيق حين لا يرسل
  // السيرفر مفتاح ترجمة. تُحلّ حسب اسم الحقل في نموذج الاعتماد.
  'credUrl': 'الرابط',
  'credDb': 'قاعدة البيانات',
  'detectDatabases': 'اكتشاف قواعد البيانات',
  'detectingDatabases': 'جاري الاكتشاف…',
  'detectDatabasesEmpty':
      'السيرفر ده مش بيعرض قائمة قواعد البيانات — اكتب الاسم يدويًا.',
  'detectDatabasesNeedsUrl': 'اكتب رابط السيرفر الأول.',
  'detectDatabasesFailed': 'تعذّر الوصول للسيرفر لجلب قواعد البيانات.',
  'credModeUser': 'أنا مستخدم',
  'credModeDeveloper': 'أنا مطوّر',
  'chatLoadEarlier': 'تحميل الرسائل الأقدم',
  'chatLoadingEarlier': 'جاري تحميل الرسائل الأقدم…',
  'security': 'الأمان',
  'appLockTitle': 'صقّار مقفول',
  'appLockSubtitle': 'تحقّق من هويتك للمتابعة.',
  'appLockUnlock': 'فتح القفل',
  'appLockReason': 'افتح صقّار',
  'appLockConfirmSignOut': 'أكّد هويتك لتسجيل الخروج',
  'appLockConfirmDelete': 'أكّد هويتك لحذف حسابك',
  'appLockSettingTitle': 'قفل التطبيق',
  'appLockSettingSubtitle': 'اطلب البصمة أو بصمة الوجه لفتح صقّار.',
  'appLockUnavailable': 'غير متاح على هذا الجهاز',
  'appLockEnableFailed': 'تعذّر تفعيل قفل التطبيق. حاول مرة أخرى.',
  'credUsername': 'اسم المستخدم',
  'credSecret': 'كلمة السر',
  'credHost': 'المضيف',
  'credPort': 'المنفذ',
  'credToken': 'الرمز',
  // مسميات أنواع الاعتماد / التبويبات — الأسماء التقنية (PostgreSQL،
  // GitHub، XML-RPC) تبقى كما هي، ويُترجَم الجزء الوصفي فقط.
  'credKindXmlrpc': 'اتصال أودو',
  'credKindPostgres': 'PostgreSQL',
  'credKindServerShell': 'طرفية الخادم',
  'credKindGithub': 'GitHub',
  // ترجمة أخطاء اختبار الاتصال — رسائل السيرفر الشائعة تُترجَم لتظهر
  // بلغة الواجهة. الأخطاء غير المعروفة تعود لنص السيرفر الأصلي.
  'testErrAuthFailed':
      'فشلت المصادقة. تأكّد من الرابط وقاعدة البيانات وبيانات الدخول.',
  'testErrBadRequest':
      'طلب غير صالح. تأكّد من صيغة الرابط (بدون «‎/odoo‎» في آخره).',
  'testErrTimeout': 'انتهت مهلة الاتصال. تأكّد من أن الخادم متاح.',
  'testErrUnreachable': 'تعذّر الوصول إلى الخادم. تأكّد من الرابط.',
  'testErrInvalidSslmode':
      'وضع SSL غير صالح. استخدم أحد القيم: disable أو allow أو prefer أو '
          'require أو verify-ca أو verify-full.',
  'testErrInvalidNumber':
      'حقل رقمي فارغ أو غير صالح — تحقّق من رقم المنفذ (Port).',
  'testErrTokenRequired': 'يلزم إدخال رمز وصول (token). أدخله ثم أعد المحاولة.',
  'testErrMissingFields':
      'أدخل الرابط وقاعدة البيانات واسم المستخدم وكلمة المرور أو مفتاح API.',
  'testErrDuplicate': 'هذا العنصر موجود بالفعل.',
  'testErrNotFound': 'لم يتم العثور على العنصر المطلوب.',
  'testErrForbidden': 'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
  'errInvalidCode': 'الرمز غير صحيح. تأكّد منه وحاول مرة أخرى.',
  'errExpiredCode': 'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.',
  // الخطة / الحصة / الاستخدام (Gap A + B)
  'plan_usage_title': 'الخطة والاستخدام',
  'plan_window_day': 'اليوم',
  'plan_window_week': 'هذا الأسبوع',
  'plan_window_month': 'هذا الشهر',
  'plan_daily': 'اليومي',
  'plan_weekly': 'الأسبوعي',
  'plan_monthly': 'الشهري',
  'plan_exempt_label': 'غير محدود',
  'plan_near_limit_title': 'اقتربت من الحد',
  'quota_exceeded_title': 'تم بلوغ حد الاستخدام',
  'quota_upgrade_cta': 'عرض الباقات',
  'pricing_title': 'الباقات والأسعار',
  'pricing_subtitle': 'اختر الباقة التي تناسب طريقة عملك على أودو.',
  'pricing_current': 'باقتك الحالية',
  'pricing_free': 'مجاني',
  'pricing_cycle_monthly': 'شهري',
  'pricing_cycle_annual': 'سنوي',
  'pricing_cycle_annual_save': 'وفّر حتى 50%',
  'pricing_vat_note':
      'الأسعار لا تشمل ضريبة القيمة المضافة. تُضاف {rate}% عند الدفع.',
  'pricing_web_cta': 'الاشتراك عبر الموقع',
  'pricing_manage_cta': 'إدارة الاشتراك على saqqaar.com',
  'pricing_web_note':
      'يتم الدفع على saqqaar.com في المتصفح. تتحدّث باقتك هنا فور إتمام '
          'العملية.',
  'pricing_open_failed': 'تعذّر فتح saqqaar.com.',
  'pricing_plans_title': 'الباقات والأسعار',
  'pricing_plans_subtitle': 'قارن الباقات واشترك عبر saqqaar.com.',
  'pricing_plans_subtitle_plain': 'اطّلع على ما تتضمنه كل باقة.',
  'pricing_managed_on_web': 'تُدار الباقات على saqqaar.com.',
  'pricing_web_signin_note': 'قد تحتاج إلى تسجيل الدخول على الموقع للمتابعة.',
  'pricing_zero': '\$0',
  'pricing_load_error': 'تعذّر تحميل الباقات.',
  'pricing_most_popular': 'الأكثر شيوعًا',
  'price_plus_vat': '+ ض.ق.م',
  // saqqaar.com leaves this line in English on the Arabic page, where the
  // bidi algorithm reorders it into "billed monthly ($24/yr).$2/mo" — the
  // same content, unreadable. Translated here rather than mirrored.
  'price_both_cycles':
      '\${annualMo}/شهرياً عند الدفع السنوي (\${annualYr}/سنة) · '
          '\${monthlyMo}/شهرياً عند الدفع الشهري (\${monthlyYr}/سنة).',
  'plan_copy_free_name': 'مجاني',
  'plan_copy_free_tagline': 'تجربة صقّار',
  'plan_copy_free_price_note': 'مجاني للجميع',
  'plan_copy_free_f1': 'الدردشة مع صقّار على الويب والجوال',
  'plan_copy_free_f2': 'اربط قاعدة بيانات أودو واحدة',
  'plan_copy_free_f3': 'البحث والقراءة وعدّ السجلات',
  'plan_copy_free_f4': 'إنشاء تقارير Excel و PDF و Word',
  'plan_copy_free_f5': 'الإدخال الصوتي (تحويل الكلام إلى نص)',
  'plan_copy_free_f6': 'قراءة إضافات أودو',
  'plan_copy_free_f7': 'ذاكرة عبر المحادثات',
  'plan_copy_starter_name': 'المبتدئ',
  'plan_copy_starter_tagline': 'ابدأ الآن',
  'plan_copy_starter_inherits': 'كل ما في المجاني، بالإضافة إلى:',
  'plan_copy_starter_f1': 'استخدام شهري أكبر قليلاً',
  'plan_copy_starter_f2': 'أولوية على الباقة المجانية في أوقات الذروة',
  'plan_copy_solo_name': 'الفردي',
  'plan_copy_solo_tagline': 'للأفراد',
  'plan_copy_solo_inherits': 'كل ما في المبتدئ، بالإضافة إلى:',
  'plan_copy_solo_f1': 'استخدام شهري أعلى بكثير',
  'plan_copy_solo_f2': 'إنشاء وتعديل سجلات أودو (بموافقة)',
  'plan_copy_solo_f3': 'قواعد بيانات وبيئات متعددة',
  'plan_copy_solo_f4': 'استيراد جماعي (إنشاء متعدد / تحميل)',
  'plan_copy_solo_f5': 'وصول ذو أولوية لأفضل النماذج',
  'plan_copy_pro_name': 'الاحترافي',
  'plan_copy_pro_tagline': 'للمستخدمين المتقدمين',
  'plan_copy_pro_inherits': 'كل ما في الفردي، بالإضافة إلى:',
  // The LRM keeps ".zip" from being reordered to "zip." — the extension is a
  // Latin token inside an RTL sentence, and without the mark the neutral dot
  // inherits the paragraph direction and lands on the wrong side.
  'plan_copy_pro_f1': 'بناء وتعديل إضافات أودو وتنزيلها بصيغة ‎.zip',
  'plan_copy_pro_f2': 'تشغيل إجراءات الخادم وتثبيت الوحدات',
  'plan_copy_pro_f3': 'حدود استخدام أعلى',
  'plan_copy_pro_f4': 'دعم ذو أولوية',
  'plan_copy_business_name': 'الأعمال',
  'plan_copy_business_tagline': 'للفرق والاستخدام المكثّف',
  'plan_copy_business_inherits': 'كل ما في الاحترافي، بالإضافة إلى:',
  'plan_copy_business_f1': 'أعلى حدود استخدام',
  'plan_copy_business_f2': 'وصول مباشر لقاعدة البيانات وللخادم بشكل آمن',
  'plan_copy_business_f3': 'وصول مبكر للميزات الجديدة',
  'plan_copy_business_f4': 'دعم ذو أولوية',
  'plan_copy_business_f5': 'إعداد مخصص',
  'use_my_database_title': 'إعداد قاعدة بياناتك؟',
  'env_hint_title': 'لا توجد قاعدة بيانات متصلة',
  'env_hint_body':
      'يحتاج صقّار إلى بيئة Odoo للعمل عليها. اربط قاعدة بياناتك للبدء.',
  'env_hint_use_my_database': 'استخدم قاعدة بياناتي',
  'env_hint_bound': 'تم ربط قاعدة البيانات.',
  'env_hint_needs_credentials':
      'أضِف بيانات اعتماد Odoo لهذه البيئة للاتصال.',
  'env_hint_failed': 'تعذّر إعداد قاعدة بياناتك. حاول مرة أخرى.',
  'addon_hint': 'يستطيع صقّار قراءة وتعديل وإعادة بناء إضافة Odoo هذه.',
  'voice_locked_pro': 'الإدخال الصوتي غير متاح في حسابك.',
  // تدفّق التسجيل عبر رمز البريد (Gap D)
  'auth_signup_email_title': 'أنشئ حسابك',
  'auth_signup_email_subtitle': 'أدخل بريدك الإلكتروني للبدء.',
  'auth_check_email_title': 'تحقّق من بريدك',
  'auth_check_email_subtitle': 'أدخل الرمز المكوّن من ٦ أرقام الذي أرسلناه.',
  'auth_profile_title': 'أكمل ملفك الشخصي',
  'auth_profile_subtitle': 'أضف اسمك واختر كلمة مرور.',
  'auth_welcome_back_title': 'مرحبًا بعودتك',
  'auth_welcome_back_subtitle': 'سجّل الدخول للمتابعة إلى مساحة عملك.',
  'auth_password_title': 'أدخل كلمة المرور',
  'auth_password_subtitle': 'سجّل الدخول بكلمة مرور حسابك.',
  'auth_reset_title': 'إعادة تعيين كلمة المرور',
  'auth_reset_subtitle': 'أدخل بريدك — سنرسل لك رمز تحقق.',
  'auth_new_password_title': 'تعيين كلمة مرور جديدة',
  'auth_new_password_subtitle': 'اختر كلمة مرور قوية لإكمال إعادة التعيين.',
  'auth_first_name': 'الاسم الأول',
  'auth_last_name': 'الاسم الأخير',
  'auth_new_password_label': 'كلمة المرور الجديدة',
  'auth_confirm_new_password': 'تأكيد كلمة المرور الجديدة',
  'auth_otp_label': 'رمز التحقق',
  'auth_otp_hint': 'أرسلنا رمزًا من ٦ أرقام إلى بريدك. تنتهي صلاحيته خلال ١٠ دقائق.',
  'auth_email_placeholder': 'you@example.com',
  'auth_password_placeholder': '٨ أحرف على الأقل',
  'auth_password_enter_placeholder': 'أدخل كلمة المرور',
  'auth_confirm_placeholder': 'أعد إدخال كلمة المرور',
  'auth_confirm_new_placeholder': 'أعد إدخال كلمة المرور الجديدة',
  'auth_continue_email': 'المتابعة بالبريد',
  'auth_continue_password': 'المتابعة بكلمة المرور',
  'auth_continue_email_instead': 'المتابعة بالبريد بدلاً من ذلك',
  'auth_continue_password_instead': 'المتابعة بكلمة المرور بدلاً من ذلك',
  'auth_or_continue_with': 'أو تابع باستخدام',
  'auth_continue_google': 'المتابعة بحساب Google',
  'auth_continue_apple': 'المتابعة عبر Apple',
  'auth_verify_code': 'تأكيد الرمز',
  'auth_verify_signin': 'تأكيد وتسجيل الدخول',
  'auth_create_account_btn': 'إنشاء الحساب',
  'auth_login_btn': 'تسجيل الدخول',
  'auth_forgot_password': 'نسيت كلمة المرور؟',
  'auth_send_reset_code': 'إرسال رمز إعادة التعيين',
  'auth_set_new_password_btn': 'تعيين كلمة المرور وتسجيل الدخول',
  'auth_signin_instead': 'تسجيل الدخول بدلاً من ذلك',
  'auth_create_an_account': 'إنشاء حساب',
  'auth_back_to_signin': 'العودة لتسجيل الدخول',
  'auth_use_different_email': 'استخدام بريد آخر',
  'auth_didnt_get_code': 'لم يصلك الرمز؟',
  'auth_resend_now': 'إعادة الإرسال',
  'auth_remember_it_now': 'تذكّرتها الآن؟',
  'auth_passwords_mismatch': 'كلمتا المرور غير متطابقتين.',
  'auth_code_required': 'أدخل الرمز المكوّن من ٦ أرقام.',
  'auth_name_required': 'أدخل اسمك الأول.',
  'auth_password_set': 'تم تعيين كلمة المرور. سجّل الدخول بكلمتك الجديدة.',
  'personal_info_title': 'المعلومات الشخصية',
  'personal_info_hint': 'البيانات التي أدخلتها عند التسجيل.',
  'email_login_label': 'البريد الإلكتروني (تسجيل الدخول)',
  'email_login_hint': 'بريدك هو اسم الدخول ولا يمكن تغييره من هنا.',
  'save_changes': 'حفظ التغييرات',
  'profile_updated_toast': 'تم تحديث ملفك الشخصي.',
  'status_saved': 'تم الحفظ',
  'status_no_changes': 'لا توجد تغييرات',
  'approval_title_cred_storage': 'تخزين بيانات اعتماد',
  'approval_title_cred_usage': 'استخدام بيانات اعتماد',
  'approval_title_server_cmd': 'أمر خادم',
  'approval_title_odoo_write': 'كتابة في أودو',
  'approval_title_report_export': 'تصدير تقرير',
  'approval_title_generic': 'موافقة',
  'approval_op_create': 'إنشاء',
  'approval_op_write': 'تعديل',
  'approval_op_delete': 'حذف',
  'approval_op_call': 'تنفيذ',
  'approval_op_load': 'استيراد',
  'auth_password': 'كلمة المرور',
  'quick_reply_more': 'أعطني المزيد',
  'quick_reply_summarize': 'لخّص ده',
  'quick_reply_export': 'صدّر كـ Excel',
  'swipe_archive': 'أرشفة',
  'swipe_unarchive': 'إلغاء الأرشفة',
  'swipe_delete': 'حذف',
  'long_press_actions_title': 'إجراءات المحادثة',
  'copy_action': 'نسخ',
  'offline_title': 'لا يوجد اتصال',
  'offline_body': 'صقّار يحتاج اتصال مباشر للعمل.',
  'back_online': 'عاد الاتصال',
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
  'vault_coverage_title': 'الشركات',
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
  'header_project': 'الشركة',
  'header_environment': 'البيئة',
  'pick_project_first': 'اختر شركة أولاً',
  'no_projects_yet': '— لا توجد شركات بعد —',
  'no_environments_for_project': '— لا توجد بيئات —',
  'create_environment_cta': '+ أضف بيئة',
  'create_environment_confirm_title': 'هل تريد إنشاء بيئة؟',
  'create_environment_confirm_body':
      'هذه الشركة ليس لديها أي بيئات بعد. أضف بيئة لتبدأ المحادثة في هذه الشركة.',
  'header_none_option': '—',

  // Vault lifecycle
  'no_stored_credentials_title': 'لا توجد بيانات دخول مخزّنة.',
  'no_stored_credentials_body':
      'سيطلب الوكيل الصلاحيات التي يحتاجها عند اللزوم.',
  'project_name': 'اسم الشركة',
  'add_project': 'إضافة شركة',
  'add_project_hint': 'أضف شركة…',
  'projects_title': 'الشركات',
  'back_to_projects': 'كل الشركات',
  'manage_projects': 'إدارة الشركات',
  'project_saved_toast': 'تم حفظ الشركة.',
  'project_deleted_toast': 'تم حذف الشركة.',
  'delete_project_title': 'حذف الشركة؟',
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
  // (old `test_connection` + `testing_connection` keys retired)
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

  // Company / Environment
  'pick_environment': 'اختر بيئة',
  'pick_environment_subtitle': 'بيانات الدخول التي سيستخدمها الوكيل لهذه المحادثة.',
  'no_environment_picked': '— لا توجد بيئة —',
  'pick_environment_to_start': 'اختر الشركة والبيئة من أعلى الشاشة للبدء.',
  'environment_set_for_chat': 'تم تعيين البيئة لهذه المحادثة.',
  'live_badge': 'مباشر',
  'read_only_badge': 'قراءة فقط',
  'auto_approve_badge': 'تلقائي',
  'project': 'الشركة',
  'environment': 'البيئة',
  'change_environment': 'تغيير البيئة',
  'env_multi_title': 'البيئات',
  'env_multi_subtitle': 'اختر بيئة واحدة أو أكثر يمكن للوكيل استخدامها في هذه المحادثة.',
  'env_multi_apply': 'تطبيق',
  'env_multi_updated': 'تم تحديث البيئات.',
  'env_multi_none': 'لم يتم اختيار أي بيئة',

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

  // النصوص ذات المتغيّرات — خانات `{placeholder}` يملؤها `_f`.
  'env_multi_selected_count': '{n} بيئة مختارة',
  'env_multi_extra': '+{n} أخرى',
  'more_pending_approvals': '+ {n} موافقات أخرى معلّقة',
  'last_verified_at': 'آخر تحقق: {at}',
  'similar_requests_count': '{count} طلب مشابه',
  'operation_on_model': '{operation} على `{model}`',
  'approve_all_n': 'وافق على الكل ({count})',
  'reject_all_n': 'ارفض الكل ({count})',
  'approve_all_similar': 'وافق على كل الطلبات المشابهة',
  'approval_batch_resolved': 'تمت الموافقة على {count} طلب',
  'approval_granted_with_preapproval':
      'تمت الموافقة. {count} طلب مماثل تمت الموافقة عليه مسبقاً.',
  'live_warning_title': 'بيئة مباشرة: {envName}',
  'live_warning_body':
      'أنت على وشك التحدث مع "{envName}" في شركة "{projectName}" — بيئة '
          'مباشرة. الإجراءات المؤذية لا تزال تحت الموافقة، لكن انتبه. هل تريد '
          'المتابعة؟',
  'share_token_label': 'الرمز: {token}',
  'phase_fetching': 'جلب {current}',
  'phase_fetching_of_total': 'جلب {current} / {total} · {pct}%',
  'phase_rendering': 'كتابة الملف…',
  'phase_rendering_rows': 'كتابة الملف… {rows} صف',
  'to_approve': '{n} للموافقة',
  'relative_minutes_ago': 'منذ {n} د',
  'relative_hours_ago': 'منذ {n} س',
  'relative_days_ago': 'منذ {n} أيام',
  'auth_resend_in': 'إعادة الإرسال خلال {seconds} ث',
  'plan_pct_used': 'مُستخدَم {pct}٪',
  'item_count': '{visible} من {total} {label}',

  // الوحدات — الأرقام تبقى غربية في اللغتين، والكلمة وحدها تُترجم.
  'unit_bytes': 'بايت',
  'unit_kilobytes': 'ك.ب',
  'unit_megabytes': 'م.ب',
  'compact_thousands': 'ألف',
  'compact_millions': 'م',

  'file_kind_image': 'صورة',
  'auth_otp_placeholder': '١ ٢ ٣ ٤ ٥ ٦',

  // مجموعات روابط الحساب
  'account_group_workspace': 'مساحة العمل',
  'account_group_workspace_hint': 'أدوات تشتغل على أودو مباشرة.',
  'account_group_security': 'الأمان',
  'account_group_billing': 'الفوترة',
  'account_group_billing_hint': 'باقتك ومدفوعاتك وإيصالاتك.',
  'apps_subtitle': 'إعدادات موجّهة تشغّلها بضغطة واحدة.',
  'trial_subtitle': 'احصل على أودو مستضاف لتجربة ما تريد.',
  'data_explorer_subtitle': 'اقرأ نماذجك وسجلاتك مباشرة.',
  'devices_subtitle': 'اعرف أين سجّلت دخولك، وسجّل خروج جهاز مفقود.',
  'checkout_subtitle': 'اشحن التوكنز التي ينفقها صقّار على عملك.',
  'billing_history_subtitle': 'المدفوعات السابقة والإيصالات.',

  // نقاط النهاية الجديدة (API_MOBILE_NEW_ENDPOINTS.md)
  'apps_title': 'تطبيقات صقّار',
  'apps_empty_title': 'لا توجد تطبيقات بعد',
  'apps_empty_body': 'ستظهر الإعدادات الموجّهة هنا عند توفّرها.',
  'apps_opening': 'جارٍ الفتح…',
  'apps_needs_env': 'يحتاج بيئة متصلة',
  'apps_launch_failed': 'تعذّر فتح هذا التطبيق',
  'billing_history_title': 'سجل الفواتير',
  'billing_balance': 'رصيد التوكنز',
  'billing_total_purchased': 'إجمالي المشتراة',
  'billing_empty_title': 'لا مدفوعات بعد',
  'billing_empty_body': 'ستظهر مدفوعاتك السابقة وإيصالاتها هنا.',
  'billing_receipt': 'الإيصال',
  'billing_receipt_failed': 'تعذّر فتح الإيصال. حاول مرة أخرى.',
  'billing_receipt_no_viewer': 'لا يوجد عارض PDF على هذا الجهاز.',
  'billing_paid': 'مدفوع',
  'billing_failed': 'فشل',
  'plan_status_active': 'نشطة',
  'plan_status_trialing': 'تجريبية',
  'plan_status_canceled': 'ملغاة',
  'plan_status_past_due': 'دفعة متأخرة',
  'plan_renews_on': 'تتجدّد في {date}',
  'billing_status_pending': 'قيد الانتظار',
  'billing_status_expired': 'منتهية',
  'billing_status_refunded': 'مُستردّة',
  'billing_status_chargeback': 'ردّ مالي',
  'billing_pending_note':
      'في انتظار التأكيد من مزوّد الدفع. إذا كنت قد أتممت الدفع ولم تتحدّث '
          'الحالة، تواصل مع الدعم بالرقم المرجعي {ref}.',
  'trial_title': 'تجربة أودو المُدارة',
  'trial_intro':
      'اطلب تجربة أودو مستضافة وسنجهّزها لك — دون الحاجة للاستضافة الذاتية.',
  'trial_company_name': 'اسم الشركة',
  'trial_company_required': 'اسم الشركة مطلوب',
  'trial_work_email': 'البريد المهني (اختياري)',
  'trial_phone': 'الهاتف (اختياري)',
  'trial_request_button': 'اطلب التجربة',
  'trial_pending_title': 'في قائمة الانتظار…',
  'trial_provisioning_title': 'جارٍ تجهيز تجربتك…',
  'trial_provisioning_body':
      'قد يستغرق ذلك بضع دقائق. يمكنك مغادرة هذه الشاشة والعودة لاحقًا.',
  'trial_ready_title': 'تجربتك جاهزة',
  'trial_failed_title': 'فشل التجهيز',
  'trial_failed_body': 'حدث خطأ أثناء تجهيز تجربتك.',
  'trial_url': 'الرابط',
  'trial_db': 'قاعدة البيانات',
  'trial_login': 'المستخدم',
  'trial_password': 'كلمة المرور',
  'trial_open': 'افتح أودو',
  'trial_open_failed': 'تعذّر فتح الرابط.',
  'trial_copied': 'تم النسخ',
  'trial_credentials_warning':
      'هذه بيانات دخول مسؤول حيّة — احتفظ بها لنفسك ولا تشاركها.',
  'copy': 'نسخ',
  'artifact_details_title': 'تفاصيل الملف',

  // §4 — الاجتماعات
  'meetings_title': 'تفريغ الاجتماعات',
  'meetings_intro': 'الصق رابط اجتماع أونلاين لبدء التفريغ المباشر.',
  'meetings_preview_note':
      'معاينة — أشكال واجهة الاجتماعات غير نهائية في المواصفة؛ أكّدها مع الباك-إند.',
  'meetings_url_label': 'رابط الاجتماع',
  'meetings_url_required': 'رابط الاجتماع مطلوب',
  'meetings_start': 'ابدأ التفريغ',
  'meetings_status': 'الحالة',
  'meetings_stop': 'إيقاف',
  'meetings_summarize': 'تلخيص',
  'meetings_transcript': 'النص',
  'meetings_transcript_empty': 'في انتظار النص…',
  'meetings_summary': 'الملخّص',
  'meetings_ask_label': 'اسأل عن هذا الاجتماع',
  'meetings_ask': 'اسأل',
  'meetings_reply': 'الإجابة',

  // §4 — مستكشف البيانات
  'data_explorer_title': 'مستكشف البيانات',
  'data_explorer_preview_note':
      'استعلامات Odoo للقراءة فقط — بدون agent، بدون تكلفة توكنز، ولا شيء هنا يمكنه تعديل بياناتك. عدّل نموذج الطلب ليطابق الموديل والحقول التي تريدها.',
  'data_explorer_env': 'البيئة',
  'data_explorer_no_envs': 'لا توجد بيئات — جهّز واحدة في الخزنة أولاً.',
  'data_explorer_model': 'الموديل',
  'data_explorer_model_required': 'الموديل مطلوب',
  'data_explorer_domain': 'الـ Domain (JSON اختياري)',
  'data_explorer_count': 'عدّ',
  'data_explorer_search': 'بحث',
  'data_explorer_result': 'النتيجة',
  'data_explorer_operation': 'العملية',
  'data_explorer_body': 'جسم الطلب (JSON)',
  'data_explorer_run': 'تشغيل',
  'data_explorer_invalid_json': 'جسم الطلب مش JSON صالح.',

  // §4 — الدفع
  'checkout_title': 'شراء توكنز',
  'checkout_preview_note':
      'الشراء داخل التطبيق قد يتعارض مع سياسة متاجر Apple/Google — أكّد قبل الإصدار. مخفي على iOS.',
  'checkout_buy': 'شراء',
  'checkout_waiting': 'في انتظار الدفع — أكمِله في المتصفح.',
  'checkout_paid': 'تم الدفع. شكرًا لك!',
  'checkout_failed': 'فشل الدفع أو تم إلغاؤه.',
  'checkout_open_failed': 'تعذّر فتح صفحة الدفع.',
  'checkout_empty': 'لا توجد باقات متاحة حاليًا.',
};
