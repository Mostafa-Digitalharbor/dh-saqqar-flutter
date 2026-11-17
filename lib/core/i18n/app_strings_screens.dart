part of 'app_strings.dart';

/// Copy: screens, credentials, plans and pricing.
extension AppStringsScreens on AppStrings {
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

  /// Tab title for the Odoo credential in the vault's user view.
  String get connectOdoo => _t('connect_odoo');

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
  String shareCountFiles(int n) => _p('share_count_files', n);
  String get shareNoConversations => _t('share_no_conversations');
  String get shareCancel => _t('share_cancel');

  // Tester feedback batch (2026-05-23): sent-confirmation toast, voice
  // input, share-message, quick replies, swipe-archive hints.
  String sentToastFiles(int n) => _p('sent_toast_files', n);
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
  String get quotaBalanceBody => _t('quota_balance_body');
  String get quotaBalanceBodyPlain => _t('quota_balance_body_plain');

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
  }) => _f('price_both_cycles', {
    'annualMo': _dollars(annualCentsPerMonth),
    'annualYr': _dollars(annualCentsPerMonth * 12),
    'monthlyMo': _dollars(monthlyCents),
    'monthlyYr': _dollars(monthlyCents * 12),
  });

  String get pricingMostPopular => _t('pricing_most_popular');

  /// Cents → "20" or "2.50". Trailing `.00` reads as false precision on a
  /// price list where most tiers are whole dollars.
  String _dollars(int cents) =>
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

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

  // Resume banner — a run stopped without finishing and with nothing else
  // waiting on the user (`conversation.needs_resume`). Copied verbatim from
  // the live web client (MOBILE_TASKS_2026-09.md Task 2).
  /// One-tap continue for a run that hit the agent's tool-round ceiling.
  /// Distinct from the resume banner above it: that one is for a run that
  /// stopped SILENTLY, this one for a run that stopped having said so and
  /// flagged `tool_payload.continue_available` on its last message.
  /// Per-message token cost, shown beside the timestamp (web parity).
  String tokensInput(String total, String fresh, String cached, int pct) => _f(
    'tokens_input',
    {'total': total, 'fresh': fresh, 'cached': cached, 'pct': pct},
  );
  String tokensOutput(String n) => _f('tokens_output', {'n': n});
  String tokensTotal(String n) => _f('tokens_total', {'n': n});
  String tokensChipLabel(String n) => _f('tokens_chip', {'n': n});
  String get continueRun => _t('continue_run');
  String get continueRunMessage => _t('continue_run_message');
  String get chatResumeBannerText => _t('chat_resume_banner_text');
  String get chatResumeButton => _t('chat_resume_button');
  String get chatResumeButtonWorking => _t('chat_resume_button_working');
}
