part of 'app_strings.dart';

/// Copy: app-pulse cards, OTP flow, personal info, approvals models.
extension AppStringsPulse on AppStrings {
  // App-pulse cards (Task 1, MOBILE_TASKS_2026-09.md) — the seven read-only
  // guided-app dashboards rendered inside their own chat. Titles reuse the
  // `app_name_<slug>` keys Task 3 added; these are the card's own chrome and
  // per-metric tile labels.
  String get pulseUnavailable => _t('pulse_unavailable');
  String pulseAsOf(String date) => _f('pulse_as_of', {'date': date});
  String get pulseNotesTitle => _t('pulse_notes_title');
  String get pulsePrioritiesTitle => _t('pulse_priorities_title');
  String get pulseTopRisksTitle => _t('pulse_top_risks_title');
  // Factory
  String get pulseFactoryMoRunning => _t('pulse_factory_mo_running');
  String get pulseFactoryMoLate => _t('pulse_factory_mo_late');
  String get pulseFactoryMoDoneToday => _t('pulse_factory_mo_done_today');
  String get pulseFactoryPoLate => _t('pulse_factory_po_late');
  String get pulseFactoryOrdersAtRisk => _t('pulse_factory_orders_at_risk');
  String get pulseFactoryRiskMissingLines =>
      _t('pulse_factory_risk_missing_lines');
  String get pulseFactoryRiskLeadDays => _t('pulse_factory_risk_lead_days');
  // Inventory
  String get pulseInventorySalesDays => _t('pulse_inventory_sales_days');
  String get pulseInventoryProductCount => _t('pulse_inventory_product_count');
  String get pulseInventoryValue => _t('pulse_inventory_value');
  String get pulseInventoryLowStock => _t('pulse_inventory_low_stock');
  String get pulseInventoryDemandShortage =>
      _t('pulse_inventory_demand_shortage');
  String get pulseInventoryStagnantStock =>
      _t('pulse_inventory_stagnant_stock');
  String get pulseInventoryOverstock => _t('pulse_inventory_overstock');
  String get pulseInventoryFastReorder => _t('pulse_inventory_fast_reorder');
  String get pulseInventoryMissingData => _t('pulse_inventory_missing_data');
  String get pulseInventoryMissingDataReasons =>
      _t('pulse_inventory_missing_data_reasons');
  // Shared by the counter-driven cards (accountant, HR)
  String get pulseCountersTitle => _t('pulse_counters_title');
  // Finance
  String get pulseFinanceCashBalance => _t('pulse_finance_cash_balance');
  String get pulseFinanceReceivablesOverdue =>
      _t('pulse_finance_receivables_overdue');
  String get pulseFinanceReceivablesDueSoon =>
      _t('pulse_finance_receivables_due_soon');
  String get pulseFinancePayablesOverdue =>
      _t('pulse_finance_payables_overdue');
  String get pulseFinancePayablesDueSoon =>
      _t('pulse_finance_payables_due_soon');
  String get pulseFinanceDraftVendorBills =>
      _t('pulse_finance_draft_vendor_bills');
  String get pulseFinanceDraftCustomerInvoices =>
      _t('pulse_finance_draft_customer_invoices');
  String get pulseFinanceBankReconciliation =>
      _t('pulse_finance_bank_reconciliation');
  String get pulseFinanceLiquidityStatus =>
      _t('pulse_finance_liquidity_status');
  // Purchasing
  String get pulsePurchasingOpenRfqs => _t('pulse_purchasing_open_rfqs');
  String get pulsePurchasingAwaitingApproval =>
      _t('pulse_purchasing_awaiting_approval');
  String get pulsePurchasingLateOrders => _t('pulse_purchasing_late_orders');
  String get pulsePurchasingLateReceipts =>
      _t('pulse_purchasing_late_receipts');
  String get pulsePurchasingToBill => _t('pulse_purchasing_to_bill');
  String get pulsePurchasingVendorBills => _t('pulse_purchasing_vendor_bills');
  String get pulsePurchasingVendorDelays =>
      _t('pulse_purchasing_vendor_delays');
  // HR
  String get pulseHrActiveEmployees => _t('pulse_hr_active_employees');
  String get pulseHrMissingManagers => _t('pulse_hr_missing_managers');
  String get pulseHrMissingWorkEmail => _t('pulse_hr_missing_work_email');
  String get pulseHrOperationsTitle => _t('pulse_hr_operations_title');
  // Accountant
  String pulseAccountantMonth(String month) =>
      _f('pulse_accountant_month', {'month': month});
  // Quality Guard
  String get pulseQualityOutOfSpec => _t('pulse_quality_out_of_spec');
  String get pulseQualityFailedChecks => _t('pulse_quality_failed_checks');
  String get pulseQualityPendingChecks => _t('pulse_quality_pending_checks');
  String get pulseQualityAlerts => _t('pulse_quality_alerts');
  String get pulseQualityMissingSpecs => _t('pulse_quality_missing_specs');
  String get pulseQualityReviewCases => _t('pulse_quality_review_cases');
  String get pulseQualityInvoiceSwaps => _t('pulse_quality_invoice_swaps');
  String get pulseQualityDeliverySwaps => _t('pulse_quality_delivery_swaps');
  String get pulseQualityHighRiskCases => _t('pulse_quality_high_risk_cases');
  String get pulseQualityCostSaving => _t('pulse_quality_cost_saving');
  String get pulseQualityDeepDiscounts => _t('pulse_quality_deep_discounts');
  String get pulseQualityLowerCostSubstitutes =>
      _t('pulse_quality_lower_cost_substitutes');
  String get pulseQualityDocumentedSubstitutes =>
      _t('pulse_quality_documented_substitutes');
  String get pulseQualityUndocumentedSubstitutes =>
      _t('pulse_quality_undocumented_substitutes');
  String get pulseQualityDiscountValue => _t('pulse_quality_discount_value');
  String get pulseQualityStandardOdooOnly =>
      _t('pulse_quality_standard_odoo_only');
  // Finance aging bands
  String get pulseFinanceCollectionAging =>
      _t('pulse_finance_collection_aging');
  String get pulseFinancePaymentHorizon => _t('pulse_finance_payment_horizon');
  String pulseBandInvoices(int n) => _p('pulse_band_invoices', n);
  // HR sections the server sends as their own top-level keys
  String get pulseHrRecruitment => _t('pulse_hr_recruitment');
  String get pulseHrPayroll => _t('pulse_hr_payroll');
  String get pulseHrTimeOff => _t('pulse_hr_time_off');

  /// One of the accountant's five documented checks, by wire key. Unknown
  /// keys fall back to the key itself rather than to a generic label: a new
  /// check the server adds should read as an untranslated name the user can
  /// report, not as a row that looks like every other row.
  String pulseAccountantCheck(String key) => switch (key) {
    'no_reference' => _t('pulse_accountant_no_reference'),
    'manual_on_control' => _t('pulse_accountant_manual_on_control'),
    'edited_after_post' => _t('pulse_accountant_edited_after_post'),
    'self_cancelling' => _t('pulse_accountant_self_cancelling'),
    'multi_company' => _t('pulse_accountant_multi_company'),
    _ => key,
  };

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
    'send_email' => _t('approval_title_send_email'),
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
  String attachmentTooLarge(String name, int capMb) =>
      _f('attachment_too_large', {'name': name, 'capMb': capMb});

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
  String planNearLimitBody(String window, int pct) =>
      _f('plan_near_limit_body', {'window': window, 'pct': pct});

  /// Composer tooltip + quota card body when a window is exhausted.
  String quotaExceededBody(String window) =>
      _f('quota_exceeded_body', {'window': window});

  /// [quotaExceededBody] minus the upgrade nudge — used where paid-plan upsell
  /// is suppressed, which is currently everywhere: sales are web-only, so
  /// "upgrade your plan" would point at a door the app doesn't have. Callers
  /// pick via `showPaidUpsell`.
  String quotaExceededBodyPlain(String window) =>
      _f('quota_exceeded_body_plain', {'window': window});
}
