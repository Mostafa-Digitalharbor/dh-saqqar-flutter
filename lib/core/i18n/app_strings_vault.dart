part of 'app_strings.dart';

/// Copy: vault, company/environment, chat chrome and approvals.
extension AppStringsVault on AppStrings {
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
    if (n == 0) return _t('environment_count_zero');
    return _f(n == 1 ? 'environment_count_single' : 'environment_count_multi', {
      'n': n,
    });
  }

  String get addProjectHint => _t('add_project_hint');
  String get manageProjects => _t('manage_projects');
  String get projectSavedToast => _t('project_saved_toast');
  String get projectDeletedToast => _t('project_deleted_toast');
  String get deleteProjectTitle => _t('delete_project_title');
  String deleteProjectBody(String name) =>
      _f('delete_project_body', {'name': name});

  String get addEnvironment => _t('add_environment');
  String get addEnvironmentHint => _t('add_environment_hint');
  String get environmentSavedToast => _t('environment_saved_toast');
  String get environmentDeletedToast => _t('environment_deleted_toast');
  String get deleteEnvironmentTitle => _t('delete_environment_title');
  String deleteEnvironmentBody(String name) =>
      _f('delete_environment_body', {'name': name});

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
  String credentialCount(int n) => _f(
    n == 1 ? 'credential_count_single' : 'credential_count_multi',
    {'n': n},
  );
  String get markEnvLiveTitle => _t('mark_env_live_title');
  String markEnvLiveBody(String envName) =>
      _f('mark_env_live_body', {'envName': envName});
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
  String get activityStepAwaitedApproval =>
      _t('activity_step_awaited_approval');
  String activityStepFailed(String step) =>
      _f('activity_step_failed', {'step': step});
  String get activityReviewingAttachment => _t('activity_reviewing_attachment');
  String get activityImportingFromFile => _t('activity_importing_from_file');
  String get activityRecallingHistory => _t('activity_recalling_history');
  String get activityPreparingQuestions => _t('activity_preparing_questions');
  String get activityPreparingAccess => _t('activity_preparing_access');
  String get activityInspectingOdooModel =>
      _t('activity_inspecting_odoo_model');
  String get activityApplyingOdooChange => _t('activity_applying_odoo_change');
  String get activityBuildingExcel => _t('activity_building_excel');
  String get activityBuildingPdf => _t('activity_building_pdf');
  String get activityBuildingWord => _t('activity_building_word');
  String get activityPreparingApproval => _t('activity_preparing_approval');

  // Grouped approvals (web pre-approval shortcut)
  String similarRequestsCount(int count) =>
      _f('similar_requests_count', {'count': count});
  String operationOnModel(String operation, String model) =>
      _f('operation_on_model', {'operation': operation, 'model': model});
  String approveAllN(int count) => _f('approve_all_n', {'count': count});
  String rejectAllN(int count) => _f('reject_all_n', {'count': count});
  String get preApprovalTip => _t('pre_approval_tip');
  String get approveAllSimilar => _t('approve_all_similar');
  String get showIndividual => _t('show_individual');
  String get hideIndividual => _t('hide_individual');
  String approvalBatchResolved(int count) =>
      _p('approval_batch_resolved', count);
  String approvalGrantedWithPreapproval(int count) =>
      _f('approval_granted_with_preapproval', {'count': count});

  // Live environment confirmation (web one-shot warning)
  String liveWarningTitle(String envName) =>
      _f('live_warning_title', {'envName': envName});
  String liveWarningBody(String envName, String projectName) =>
      _f('live_warning_body', {'envName': envName, 'projectName': projectName});
  String get sendToLive => _t('send_to_live');

  /// A gateway 5xx from a route that reads the user's own Odoo.
  String get errorOdooUnreachable => _t('error_odoo_unreachable');
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

  /// Accessible name for the floating chevron that returns the chat to its
  /// newest message. The control is an icon with no visible text, so without
  /// this a screen reader announces an unnamed button.
  String get scrollToLatest => _t('scroll_to_latest');
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

  /// Plural-correct "N conversations" for the chats-list header subtitle —
  /// unlike [conversations], which is only the bare noun and would render
  /// "1 محادثات" (grammatically wrong) if simply concatenated with a count.
  String conversationsCount(int n) => _p('conversations_count', n);
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
  // Task 4 (MOBILE_TASKS_2026-09.md) — subject/body may arrive empty.
  String get emailPreviewEmptySubject => _t('email_preview_empty_subject');
  String get emailPreviewEmptyBody => _t('email_preview_empty_body');
  // Destructive-delete type-to-confirm (web parity — `renderDeleteApproval`).
  /// The red button on a destructive-delete approval card — "Delete 12" /
  /// "حذف 12".
  ///
  /// The count is the informed consent. It used to live in a phrase the user
  /// had to type back; that gate was removed on 2026-08-17 because it was too
  /// hard for real users (it caused an outage) and because the value it
  /// collected was being dropped before the request anyway. Naming the number
  /// on the button keeps the user seeing how many rows die before they tap.
  String deleteApprovalAction(int count) =>
      _f('delete_approval_action', {'count': count});

  /// Header above the list of rows a delete would destroy.
  String deleteApprovalRecordsHeader(int count) =>
      _f('delete_approval_records_header', {'count': count});
}
