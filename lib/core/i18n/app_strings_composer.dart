part of 'app_strings.dart';

/// Copy: composer, tools sheet, interactive cards, failures, notifications.
extension AppStringsComposer on AppStrings {
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

  // ── Task wording ──────────────────────────────────────────────────
  String get promptBankTitle => _t('prompt_bank_title');
  String get promptBankSubtext => _t('prompt_bank_subtext');
  String get promptBankAskLabel => _t('prompt_bank_ask_label');
  String get promptBankAskPlaceholder => _t('prompt_bank_ask_placeholder');
  String get promptBankAskButton => _t('prompt_bank_ask_button');
  String get promptBankDraftTitle => _t('prompt_bank_draft_title');
  String get promptCardIntro => _t('prompt_card_intro');
  String get promptCardNeedText => _t('prompt_card_need_text');
  String get promptCardAdded => _t('prompt_card_added');
  String get promptInserted => _t('prompt_inserted');
  String get promptUseDraft => _t('prompt_use_draft');
  String get promptRunNow => _t('prompt_run_now');
  String get promptNoOriginal => _t('prompt_no_original');
  String get promptPreparing => _t('prompt_preparing');
  String get promptHintLong => _t('prompt_hint_long');
  String get promptHintOpen => _t('prompt_hint_open');
  String get promptHintDismiss => _t('prompt_hint_dismiss');
  String get promptBankFailed => _t('prompt_bank_failed');
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
      _f('report_compose', {'type': type, 'period': period, 'format': format}),
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
  String thinkingSteps(int n) => _p('thinking_steps', n);
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
  String get errorServiceUnavailable => _t('error_service_unavailable');
  String errorServiceUnavailableWithRetry(int seconds) => _t(
    'error_service_unavailable_with_retry',
  ).replaceFirst('{seconds}', '$seconds');
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
  String get chatActionCredentialFailed => _t('chat_action_credential_failed');
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
  /// "2 للموافقة".
  String toApprove(int n) => _f('to_approve', {'n': n});
  String get slashRestartDesc => _t('slash_restart_desc');
  String get slashReportDesc => _t('slash_report_desc');
  String get slashSyncDesc => _t('slash_sync_desc');
  String get slashLogsDesc => _t('slash_logs_desc');
  String get slashBackupDesc => _t('slash_backup_desc');

  // Composer quick-suggestion chips
  String get suggestRestartWorker => _t('suggest_restart_worker');
  String get suggestReconciliationReport => _t('suggest_reconciliation_report');
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

  /// [n] is the count already rendered through the locale's numbering
  /// system; [count] is the same value as an int, which is what picks the
  /// plural form. They are separate because the Arabic dual drops the
  /// numeral altogether ("منذ يومين"), so the form has to be chosen from the
  /// number even when the number never reaches the screen.
  String relativeDaysAgo(String n, int count) =>
      _p('relative_days_ago', count, {'n': n});

  /// Company header stats line — "3 environments · 1 live · 2 credentials"
  /// (pluralized for EN, RTL-natural for AR). Segments after the count are
  /// dropped when zero.
  String projectStats(int envs, int live, int connected) {
    final b = StringBuffer(
      _f(envs == 1 ? 'project_stats_envs_single' : 'project_stats_envs_multi', {
        'n': envs,
      }),
    );
    if (live > 0) b.write(' · ${_f('project_stats_live', {'n': live})}');
    if (connected > 0) {
      b.write(
        ' · ${_f(connected == 1 ? 'project_stats_connected_single' : 'project_stats_connected_multi', {'n': connected})}',
      );
    }
    return b.toString();
  }

  String get conversationCreatedToast => _t('conversation_created_toast');
  String get conversationArchivedToast => _t('conversation_archived_toast');
  String get conversationUnarchivedToast => _t('conversation_unarchived_toast');
  String get conversationDeletedToast => _t('conversation_deleted_toast');
  String get conversationStoppedToast => _t('conversation_stopped_toast');
}
