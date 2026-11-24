part of 'app_strings.dart';

/// Copy: storybook, billing, meetings, formatters, update gate.
extension AppStringsMisc on AppStrings {
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
  String get appLaunchPickProjectFirst => _t('app_launch_pick_project_first');
  String get appGroupAll => _t('app_group_all');

  /// Group taxonomy label. Falls back to the server's own English value so a
  /// group the backend adds still reads as itself rather than as a key.
  String appGroup(String group) =>
      lookup('app_group_${AppStrings.taxonomyKey(group)}', fallback: group);

  /// Category chip label — the compound taxonomy string the catalogue sends
  /// on each package (`Compliance · KSA`, `Accounting · Setup`).
  ///
  /// Translated **token by token**, not as a whole string. The backend
  /// composes these labels from a small vocabulary, so the pairings are open
  /// ended while the words are not: keying the whole value would leave
  /// `Compliance · Egypt` English on the day someone adds it, even though
  /// both of its words are already translated. Each token falls back through
  /// `app_category_*` → `app_group_*` (the two taxonomies share `Finance`,
  /// `Accounting`, `Integrations` — no reason to spell them twice) → the
  /// server's own word, so an unknown token degrades to English rather than
  /// blanking the chip.
  ///
  /// The separator is normalized to `·`: the vocabulary is what carries
  /// meaning, and re-emitting a `/` or `,` the server happened to use would
  /// put three different separators on one grid.
  String appCategory(String category) {
    final raw = category.trim();
    if (raw.isEmpty) return raw;
    final parts = [
      for (final p in raw.split(_categorySeparator))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (parts.isEmpty) return raw;
    return parts
        .map((p) {
          final key = AppStrings.taxonomyKey(p);
          if (key.isEmpty) return p;
          return lookup(
            'app_category_$key',
            fallback: lookup('app_group_$key', fallback: p),
          );
        })
        .join(' · ');
  }

  /// Splits a compound taxonomy label on every separator the catalogue is
  /// known to use. `·` is the documented one; `/`, `,` and `|` are accepted
  /// because they cost nothing and a label written with one of them would
  /// otherwise translate as a single unmatched blob.
  static final RegExp _categorySeparator = RegExp(r'[·|/,]');

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

  String pageCount(int pageNumber, int totalPages) =>
      '${_t('page')} $pageNumber ${_t('of')} $totalPages';

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

  /// Joins only the parts the server actually sent. `size` is absent whenever
  /// the artifact carries no `size_kb` in its metadata, which is most of them
  /// in production — joining unconditionally rendered every row as
  /// "XLSX -  - ".
  String artifactMeta(String kind, String size, String createdLabel) =>
      [kind, size, createdLabel].where((p) => p.isNotEmpty).join(' - ');
  String assistantPlan(String credential) =>
      '${_t('assistant_plan_prefix')} $credential. ${_t('assistant_plan_suffix')}';

  // App update gate
  String get updateRequiredTitle => _t('update_required_title');
  String get updateRequiredBody => _t('update_required_body');
  String get updateOptionalTitle => _t('update_optional_title');
  String get updateOptionalBody => _t('update_optional_body');
  String get updateAction => _t('update_action');
  String get updateLater => _t('update_later');
  String get updateOpenStoreFailed => _t('update_open_store_failed');

  /// Routed through [_f] rather than written as an inline ternary so the
  /// Arabic stays inside `_ar` where `i18n_parity_test` can see it.
  String updateNewVersion(String version) =>
      _f('update_new_version', {'version': version});

  // ── Redesign (2026-11) screens ─────────────────────────────────────
  String get fig1Of1 => _t('fig_1_of_1');
  String get figAccounting => _t('fig_accounting');
  String get figActiveContext => _t('fig_active_context');
  String get figActivity => _t('fig_activity');
  String figAddAnotherOdooEnvironmentTo(Object? name) =>
      _f('fig_add_another_odoo_environment_to', {'name': name});
  String get figAddCompany => _t('fig_add_company');
  String get figAddCompanyEnvironment => _t('fig_add_company_environment');
  String get figAddEnvironment => _t('fig_add_environment');
  String get figAddMore => _t('fig_add_more');
  String figAddTheConnectionDetailsForYou(Object? companyName) => _f(
    'fig_add_the_connection_details_for_you',
    {'companyName': companyName},
  );
  String get figAiPromptTaskInstructions =>
      _t('fig_ai_prompt_task_instructions');
  String get figAll => _t('fig_all');
  String get figAppLock => _t('fig_app_lock');
  String get figAppLockIsnTAvailableOn => _t('fig_app_lock_isn_t_available_on');
  String get figApprovals => _t('fig_approvals');
  String get figApprove => _t('fig_approve');
  String get figApproved => _t('fig_approved');
  String get figApps => _t('fig_apps');
  String get figArabic => _t('fig_arabic');
  String get figArtifacts => _t('fig_artifacts');
  String get figAskMeAnything => _t('fig_ask_me_anything');
  String figAskSaqqarInChat(Object? value) =>
      _f('fig_ask_saqqar_in_chat', {'value': value});
  String get figAtLeast8Characters => _t('fig_at_least_8_characters');
  String get figAuthentication => _t('fig_authentication');
  String get figAutoApprove => _t('fig_auto_approve');
  String get figAutoApprove2 => _t('fig_auto_approve_2');
  String get figBack => _t('fig_back');
  String get figBilling => _t('fig_billing');
  String get figBillingHistory => _t('fig_billing_history');
  String get figCancel => _t('fig_cancel');
  String get figChangePassword => _t('fig_change_password');
  String get figChats => _t('fig_chats');
  String figChats2(Object? count) => _f('fig_chats_2', {'count': count});
  String get figChooseYourLanguage => _t('fig_choose_your_language');
  String get figClearAll => _t('fig_clear_all');
  String get figCommands => _t('fig_commands');
  String get figCommands2 => _t('fig_commands_2');
  String get figCompaniesEnvironments => _t('fig_companies_environments');
  String get figCompany => _t('fig_company');
  String get figCompanyName => _t('fig_company_name');
  String get figConfirmItSYouToEnable => _t('fig_confirm_it_s_you_to_enable');
  String get figConfirmNewPassword => _t('fig_confirm_new_password');
  String get figConfirmPassword => _t('fig_confirm_password');
  String get figConfirmPassword2 => _t('fig_confirm_password_2');
  String get figConnectANewCompanyWithoutLeaving =>
      _t('fig_connect_a_new_company_without_leaving');
  String get figConnectInitialize => _t('fig_connect_initialize');
  String get figConnectNaskGetNitDone => _t('fig_connect_nask_get_nit_done');
  String get figConnectWithYourOdooDataAutomate =>
      _t('fig_connect_with_your_odoo_data_automate');
  String get figConnectYourOdooEnvironment =>
      _t('fig_connect_your_odoo_environment');
  String get figConnections => _t('fig_connections');
  String get figConversations => _t('fig_conversations');
  String get figCouldNotConnectCheckTheDetails =>
      _t('fig_could_not_connect_check_the_details');
  String get figCouldNotConnectCheckTheUrl =>
      _t('fig_could_not_connect_check_the_url');
  String get figCouldNotUpdateCheckYourCurrent =>
      _t('fig_could_not_update_check_your_current');
  String get figCredentials => _t('fig_credentials');
  String get figCurrent => _t('fig_current');
  String get figCurrentPassword => _t('fig_current_password');
  String get figDataExplorer => _t('fig_data_explorer');
  String get figDatabase => _t('fig_database');
  String figDelete(Object? name) => _f('fig_delete', {'name': name});
  String get figDelete2 => _t('fig_delete_2');
  String get figDeleteAccount => _t('fig_delete_account');
  String get figDeleteYourAccount => _t('fig_delete_your_account');
  String get figDescribeWhatSaqqarShouldFetchAnalyze =>
      _t('fig_describe_what_saqqar_should_fetch_analyze');
  String get figDetectDatabases => _t('fig_detect_databases');
  String get figDocuments => _t('fig_documents');
  String get figDone => _t('fig_done');
  String get figDragToPanWhenZoomed => _t('fig_drag_to_pan_when_zoomed');
  String get figEGDailySalesReportSync => _t('fig_e_g_daily_sales_report_sync');
  String get figEGElNadaCompany => _t('fig_e_g_el_nada_company');
  String get figEmail => _t('fig_email');
  String get figEmailAddress => _t('fig_email_address');
  String get figEmailAddress2 => _t('fig_email_address_2');
  String get figEnterNewPasswordMustBeDifferent =>
      _t('fig_enter_new_password_must_be_different');
  String get figEnterOdooApiKey => _t('fig_enter_odoo_api_key');
  String get figEnterOdooPassword => _t('fig_enter_odoo_password');
  String get figEnterOtpCodeSentToYour => _t('fig_enter_otp_code_sent_to_your');
  String get figEnterYourEmail => _t('fig_enter_your_email');
  String get figEnterYourEmailWeLlSend => _t('fig_enter_your_email_we_ll_send');
  String get figEnterYourName => _t('fig_enter_your_name');
  String get figEnterYourPassword => _t('fig_enter_your_password');
  String get figEnvironmentType => _t('fig_environment_type');
  String figEnvironments(Object? count) =>
      _f('fig_environments', {'count': count});
  String get figExecutionTime => _t('fig_execution_time');
  String get figFeatures => _t('fig_features');
  String get figFetchRecentServerLogs => _t('fig_fetch_recent_server_logs');
  String get figFiles => _t('fig_files');
  String figFiles2(Object? count) => _f('fig_files_2', {'count': count});
  String get figForgotPassword => _t('fig_forgot_password');
  String get figFrequency => _t('fig_frequency');
  String get figFullName => _t('fig_full_name');
  String get figGenerateAReport => _t('fig_generate_a_report');
  String get figGetNotifiedAboutApprovalsFinishedTask =>
      _t('fig_get_notified_about_approvals_finished_task');
  String get figGetStarted => _t('fig_get_started');
  String get figGiveTheTaskATitle => _t('fig_give_the_task_a_title');
  String get figHasBeenChangedNsuccessfully =>
      _t('fig_has_been_changed_nsuccessfully');
  String get figHasBeenProcessing => _t('fig_has_been_processing');
  String get figHelloNhowCanIHelpNyou => _t('fig_hello_nhow_can_i_help_nyou');
  String figHelloNhowCanIHelpNyou2(Object? user) =>
      _f('fig_hello_nhow_can_i_help_nyou_2', {'user': user});
  String get figIAgreeToThe => _t('fig_i_agree_to_the');
  String get figImages => _t('fig_images');
  String get figInventory => _t('fig_inventory');
  String get figItsEnvironmentsAndCredentialsWillBe =>
      _t('fig_its_environments_and_credentials_will_be');
  String get figLabelEnvironmentName => _t('fig_label_environment_name');
  String get figLanguage => _t('fig_language');
  String get figLatestFirst => _t('fig_latest_first');
  String get figLetSCreateYourWorkspaceYou =>
      _t('fig_let_s_create_your_workspace_you');
  String get figLive => _t('fig_live');
  String get figManageConnectionsFromYourProfileWorks =>
      _t('fig_manage_connections_from_your_profile_works');
  String get figManageDevices => _t('fig_manage_devices');
  String get figManageYourAccountWorkspaceAndBilling =>
      _t('fig_manage_your_account_workspace_and_billing');
  String get figManagedOdooTrial => _t('fig_managed_odoo_trial');
  String get figMax0200 => _t('fig_max_02_00');
  String get figMeetYourAiPoweredCopilotTo =>
      _t('fig_meet_your_ai_powered_copilot_to');
  String get figModes => _t('fig_modes');
  String get figMore => _t('fig_more');
  String get figMustEnterCompanyName => _t('fig_must_enter_company_name');
  String get figName => _t('fig_name');
  String figNeedsYourReview(Object? needs) =>
      _f('fig_needs_your_review', {'needs': needs});
  String get figNewChat => _t('fig_new_chat');
  String get figNewChat2 => _t('fig_new_chat_2');
  String get figNewPassword => _t('fig_new_password');
  String get figNewPassword2 => _t('fig_new_password_2');
  String get figNewPassword3 => _t('fig_new_password_3');
  String get figNext => _t('fig_next');
  String get figNoChanges => _t('fig_no_changes');
  String get figNoNotificationsYet => _t('fig_no_notifications_yet');
  String get figNoNotificationsYetWeLlLet =>
      _t('fig_no_notifications_yet_we_ll_let');
  String get figNoScheduledTasksYet => _t('fig_no_scheduled_tasks_yet');
  String get figNotConnected => _t('fig_not_connected');
  String get figNotification => _t('fig_notification');
  String get figNotifications => _t('fig_notifications');
  String get figOdooConnected => _t('fig_odoo_connected');
  String get figOdooConnection => _t('fig_odoo_connection');
  String get figOdooContext => _t('fig_odoo_context');
  String get figOdooModule => _t('fig_odoo_module');
  String get figOdooTools => _t('fig_odoo_tools');
  String get figOr => _t('fig_or');
  String get figOtp => _t('fig_otp');
  String get figOtpNotCorrect => _t('fig_otp_not_correct');
  String get figOtpVerification => _t('fig_otp_verification');
  String get figPassword => _t('fig_password');
  String get figPassword2 => _t('fig_password_2');
  String get figPasswordChanged => _t('fig_password_changed');
  String get figPasswordsDonTMatch => _t('fig_passwords_don_t_match');
  String get figPdfs => _t('fig_pdfs');
  String get figPending => _t('fig_pending');
  String get figPerMonth => _t('fig_per_month');
  String get figPersonalInformation => _t('fig_personal_information');
  String get figPlansPricing => _t('fig_plans_pricing');
  String get figPleaseEnterAtLeast8Characters =>
      _t('fig_please_enter_at_least_8_characters');
  String get figPleaseFillInEveryField => _t('fig_please_fill_in_every_field');
  String get figPreferences => _t('fig_preferences');
  String get figProcessing => _t('fig_processing');
  String get figProfile => _t('fig_profile');
  String get figReEnterNewPassword => _t('fig_re_enter_new_password');
  String get figReadOnly => _t('fig_read_only');
  String get figReadWrite => _t('fig_read_write');
  String get figReadyMadeSaqqarAgentsForCommon =>
      _t('fig_ready_made_saqqar_agents_for_common');
  String get figRecentConversations => _t('fig_recent_conversations');
  String get figRecentlyChats => _t('fig_recently_chats');
  String get homeViewAllChats => _t('home_view_all_chats');
  String get figRecording => _t('fig_recording');
  String get figRecurringAgentWorkflowsThatKeepYour =>
      _t('fig_recurring_agent_workflows_that_keep_your');
  String get figReject => _t('fig_reject');
  String get figRejected => _t('fig_rejected');
  String get figRenameCompany => _t('fig_rename_company');
  String get figRequests => _t('fig_requests');
  String get figRequestsSharedInChats => _t('fig_requests_shared_in_chats');
  String figRequestsSharedInChats2(Object? company) =>
      _f('fig_requests_shared_in_chats_2', {'company': company});
  String get figRequireFaceIdFingerprint =>
      _t('fig_require_face_id_fingerprint');
  String get figRequireFaceIdFingerprintToOpen =>
      _t('fig_require_face_id_fingerprint_to_open');
  String get figRequired => _t('fig_required');
  String get figResendCode => _t('fig_resend_code');
  String get figReset => _t('fig_reset');
  String get figResetNewPassword => _t('fig_reset_new_password');
  String get figResetYourPassword => _t('fig_reset_your_password');
  String get figRestartAnOdooWorker => _t('fig_restart_an_odoo_worker');
  String get figReviewAClearPlanBeforeExecution =>
      _t('fig_review_a_clear_plan_before_execution');
  String get figRunTrustedActionsAutomatically =>
      _t('fig_run_trusted_actions_automatically');
  String get figCommandsSub => _t('fig_commands_sub');
  String get figConnectionsSub => _t('fig_connections_sub');
  String get figSales => _t('fig_sales');
  String get figSaqqarApps => _t('fig_saqqar_apps');
  String get figSaqqarAssistant => _t('fig_saqqar_assistant');
  String get figSaqqarMobile => _t('fig_saqqar_mobile');
  String get figSaqqarSecurelyConnectsToYourExisting =>
      _t('fig_saqqar_securely_connects_to_your_existing');
  String get figSaqqarTools => _t('fig_saqqar_tools');
  String get figSaqqarUnderstandsYourOdooBusinessData =>
      _t('fig_saqqar_understands_your_odoo_business_data');
  String get figSave => _t('fig_save');
  String get figScheduleASaqqarTask => _t('fig_schedule_a_saqqar_task');
  String get figScheduleATask => _t('fig_schedule_a_task');
  String get figScheduleTask => _t('fig_schedule_task');
  String get figScheduledTasks => _t('fig_scheduled_tasks');
  String get figSearch => _t('fig_search');
  String get figSearchContactsOrConversations =>
      _t('fig_search_contacts_or_conversations');
  String get figSearchSharedFiles => _t('fig_search_shared_files');
  String get figSeeWhereYouReSignedIn => _t('fig_see_where_you_re_signed_in');
  String figSelected(Object? count) => _f('fig_selected', {'count': count});
  String get figSend => _t('fig_send');
  String get figSessions => _t('fig_sessions');
  String get figSetUp => _t('fig_set_up');
  String get figSetUpARecurringAiWorkflow =>
      _t('fig_set_up_a_recurring_ai_workflow');
  String get figSharedFiles => _t('fig_shared_files');
  String get figSignIn => _t('fig_sign_in');
  String get figSignOut => _t('fig_sign_out');
  String get figSignOutOfSaqqar => _t('fig_sign_out_of_saqqar');
  String get figSignUp => _t('fig_sign_up');
  String get figSnapshotTheEnvironment => _t('fig_snapshot_the_environment');
  String get figSpreadsheets => _t('fig_spreadsheets');
  String get figStaging => _t('fig_staging');
  String get figStandardUser => _t('fig_standard_user');
  String get figStartSmarterWithSaqqarAi =>
      _t('fig_start_smarter_with_saqqar_ai');
  String get figStartYourFirstConversation =>
      _t('fig_start_your_first_conversation');
  String get figSwipeToBrowsePinchOrDouble =>
      _t('fig_swipe_to_browse_pinch_or_double');
  String get figSwitchContextOrManageYourOdoo =>
      _t('fig_switch_context_or_manage_your_odoo');
  String get figSyncInventoryOrData => _t('fig_sync_inventory_or_data');
  String get figSystem => _t('fig_system');
  String get figTaskPrep => _t('fig_task_prep');
  String get figTaskTitle => _t('fig_task_title');
  String get figTermsPrivacy => _t('fig_terms_privacy');
  String get figTheDetailsYouGaveWhenYou =>
      _t('fig_the_details_you_gave_when_you');
  String get figTheseAreTheSignUpDetails =>
      _t('fig_these_are_the_sign_up_details');
  String get figThisActionIsPermanentYourAccount =>
      _t('fig_this_action_is_permanent_your_account');
  String get figThisPhone => _t('fig_this_phone');
  String get figTimezone => _t('fig_timezone');
  String get figToolsThatWorkOnYourOdoo =>
      _t('fig_tools_that_work_on_your_odoo');
  String get figTrustedActions => _t('fig_trusted_actions');
  String figTypeToConfirm(Object? requireText) =>
      _f('fig_type_to_confirm', {'requireText': requireText});
  String get figUpdatePassword => _t('fig_update_password');
  String get figUseAtLeast8CharactersYou =>
      _t('fig_use_at_least_8_characters_you');
  String get figUsername => _t('fig_username');
  String get figVerify => _t('fig_verify');
  String get figViewDetails => _t('fig_view_details');
  String get figViewFile => _t('fig_view_file');
  String get figWhatIsTheNameOfYour => _t('fig_what_is_the_name_of_your');
  String get figWorkspace => _t('fig_workspace');
  String get figWorkspace2 => _t('fig_workspace_2');
  String get figWorkspaceActivity => _t('fig_workspace_activity');
  String get figYouLlNeedToSignIn => _t('fig_you_ll_need_to_sign_in');
  String get figYour => _t('fig_your');
  String get figYour2 => _t('fig_your_2');
  String get figYourBusinessOneAiConversation =>
      _t('fig_your_business_one_ai_conversation');
  String get figYourPlanPaymentsAndReceipts =>
      _t('fig_your_plan_payments_and_receipts');

  // ── Redesign (2026-11) screens ─────────────────────────────────────

  // ── Redesign (2026-11) screens ─────────────────────────────────────

  // ── Redesign (2026-11) screens ─────────────────────────────────────
  String get figApprovals2 => _t('fig_approvals_2');
  String get figApps2 => _t('fig_apps_2');
  String get figAutomation => _t('fig_automation');
  String get figChat => _t('fig_chat');
  String get figEarlierToday => _t('fig_earlier_today');
  String get figHome => _t('fig_home');
  String get figInventory2 => _t('fig_inventory_2');
  String get figReports => _t('fig_reports');
  String get figTasks => _t('fig_tasks');
  String get figToday => _t('fig_today');
  String get figUsage => _t('fig_usage');
  String get figLabelUrl => _t('fig_label_url');
  String get figHintOdooUrl => _t('fig_hint_odoo_url');
  String get figHintOdooUser => _t('fig_hint_odoo_user');
  String get figHintDbName => _t('fig_hint_db_name');
  String get figEnvNameHint => _t('fig_env_name_hint');
  String get figLabelApiKey => _t('fig_label_api_key');
  String get figUpdateThePasswordYouSignInWith =>
      _t('fig_update_the_password_you_sign_in_with');
  String get figLanguageAppLockAndNotifications =>
      _t('fig_language_app_lock_and_notifications');
  String get figLabelDatabase => _t('fig_label_database');
  String get figCouldNotDetectDatabase => _t('fig_could_not_detect_database');
  String get figEnterTheDatabaseNameBelow =>
      _t('fig_enter_the_database_name_below');
  String get taskFreqDaily => _t('task_freq_daily');
  String get taskFreqWeekly => _t('task_freq_weekly');
  String get taskFreqMonthly => _t('task_freq_monthly');
  String get taskModSales => _t('task_mod_sales');
  String get taskModAccounting => _t('task_mod_accounting');
  String get taskModInventory => _t('task_mod_inventory');
  String get taskModCrm => _t('task_mod_crm');
  String get taskModPurchase => _t('task_mod_purchase');
  String get taskModHr => _t('task_mod_hr');
  String get taskTzRiyadh => _t('task_tz_riyadh');
  String get taskTzCairo => _t('task_tz_cairo');
  String get taskTzDubai => _t('task_tz_dubai');
  String get taskTzLondon => _t('task_tz_london');
}
