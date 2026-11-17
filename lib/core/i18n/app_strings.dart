import 'package:flutter/material.dart';

import '../constants/ui_strings.dart';

part 'app_strings_vault.dart';
part 'app_strings_composer.dart';
part 'app_strings_screens.dart';
part 'app_strings_pulse.dart';
part 'app_strings_misc.dart';
part 'app_strings_en.dart';
part 'app_strings_ar.dart';

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

  /// CLDR plural category for [n] in the active locale.
  ///
  /// English has two forms and Arabic has six, and treating Arabic as if it
  /// had English's two is not a nuance — the chat's thinking pill rendered a
  /// literal **"1 خطوات"** ("1 stepS") on a real device, because a count was
  /// pasted in front of a fixed plural noun. Arabic inflects the noun on the
  /// count: خطوة / خطوتان / ٣ خطوات / ١١ خطوة, and the numeral is often
  /// dropped entirely at one and two.
  ///
  /// The bands key off `n % 100` because Arabic's `few` and `many` repeat
  /// every hundred — 103 is `few` for exactly the reason 3 is. The `n == 2`
  /// test deliberately reads the whole number, not the remainder, so 102
  /// lands in `other` (CLDR) rather than borrowing the dual.
  String _category(int n) {
    if (!_isArabic) return n == 1 ? 'one' : 'other';
    if (n == 0) return 'zero';
    if (n == 1) return 'one';
    if (n == 2) return 'two';
    final mod = n % 100;
    if (mod >= 3 && mod <= 10) return 'few';
    if (mod >= 11 && mod <= 99) return 'many';
    return 'other';
  }

  /// [_f] against the plural form of [key] for [n].
  ///
  /// Resolves `<key>_<category>`. Every plural key defines **all six**
  /// categories in **both** tables, even where several share a wording, so
  /// there is no fallback chain to reason about and `i18n_parity_test` can
  /// check the set by equality. A missing Arabic `few` that quietly rendered
  /// the `other` form would be precisely the silent drift the parity guard
  /// exists to prevent.
  ///
  /// `{n}` is pre-bound to the count so the common case needs no [vars];
  /// [vars] is applied after and may override it, which is how the relative
  /// stamp passes an already locale-formatted numeral instead of a raw int.
  String _p(String key, int n, [Map<String, Object?> vars = const {}]) =>
      _f('${key}_${_category(n)}', {'n': n, ...vars});

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

  /// [lookup] with `{placeholder}` substitution — the public half of [_f].
  ///
  /// Exists for the app-pulse action rows (`pulse_actions.dart`), which
  /// carry ~40 title/body/prompt strings whose keys are data, not typed
  /// getters: one getter per string would be forty getters that only ever
  /// get called from one table-driven builder. `pulse_action_copy_test`
  /// pins that every key that builder can ask for resolves in both
  /// locales, which is the guarantee a getter would otherwise give.
  String format(String key, Map<String, Object?> vars, {String fallback = ''}) {
    var out = lookup(key, fallback: fallback);
    for (final entry in vars.entries) {
      out = out.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return out;
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
  String get inlineCredentialRequestTitle =>
      _t('inline_credential_request_title');
  String get inlineCredentialRequestBody =>
      _t('inline_credential_request_body');
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
  String envMultiSelectedCount(int n) => _p('env_multi_selected_count', n);
  String envMultiExtra(int n) => _f('env_multi_extra', {'n': n});

  // Inline pending approvals banner (above composer)
  String get reviewApproval => _t('review_approval');
  String morePendingApprovals(int n) => _f('more_pending_approvals', {'n': n});

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

  /// `ZATCA e-invoicing` → `zatca_e_invoicing`. Lowercased, every run of
  /// non-alphanumerics collapsed to one underscore, both ends trimmed.
  ///
  /// Shared by every taxonomy lookup (and by `SaqqarApp`'s per-package key)
  /// so `Finance`, `finance` and ` FINANCE ` all resolve the same entry.
  /// The trim is not cosmetic: without it a padded server value produced
  /// `_finance_`, which matches nothing and silently fell back to English.
  ///
  /// The [RegExp]s are `static final`, not rebuilt per call — this runs once
  /// per tile per frame on a scrolling grid, and compiling two patterns each
  /// time is work the grid does not need to repeat.
  static String taxonomyKey(String value) => value
      .toLowerCase()
      .replaceAll(_nonAlphanumeric, '_')
      .replaceAll(_edgeUnderscores, '');

  static final RegExp _nonAlphanumeric = RegExp(r'[^a-z0-9]+');
  static final RegExp _edgeUnderscores = RegExp(r'^_+|_+$');
}
