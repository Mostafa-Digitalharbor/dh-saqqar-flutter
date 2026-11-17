/// Technical constants only.
///
/// User-facing UI copy belongs in `core/i18n/app_strings.dart`.
class UiStrings {
  UiStrings._();

  static const routeNewConversation = 'new';
  static const newConversationId = 'new';
  static const none = 'none';
  static const monospaceFontFamily = 'monospace';

  static const localeEnglishCode = 'en';
  static const localeArabicCode = 'ar';
  static const localeSystemCode = 'system';

  /// Compact toggle glyphs for the language switch — these are language
  /// identifiers (not translatable copy), so they live here, not in
  /// `app_strings`. Shown as the target language: 'EN' when currently
  /// Arabic, 'ع' when currently English.
  static const localeEnglishLabel = 'EN';
  static const localeArabicLabel = 'ع';
  static const themePreferenceKey = 'saqqar.theme';
  static const localePreferenceKey = 'saqqar.locale';

  /// Global "Task prep" preference. Mirrors the web's composer toggle:
  /// when on, Saqqar asks a couple of clarifying questions (which arrive as
  /// a `prompt_clarify` card) before building a vague task.
  ///
  /// Replaced the old reasoning-budget preference, retired when the web
  /// removed its manual toggle — the backend routes hard tasks to the
  /// stronger model on its own now.
  static const taskPrepPreferenceKey = 'saqqar.taskPrep';

  /// Uppercase file-format badges shown on artifact tiles and attachment
  /// chips ("XLSX", "PDF", …).
  ///
  /// These are format identifiers, not prose — they read the same in
  /// Arabic, so they belong here rather than in `app_strings`. The
  /// *category* word next to them ("Image" / "صورة") does translate; see
  /// `AppStrings.fileKindImage`.
  ///
  /// This block previously held `artifactExcel = 'Excel'` and friends with
  /// zero references anywhere, while `chat_artifact_tile` and `chat_screen`
  /// each hardcoded their own copy — which had already drifted ('Excel' vs
  /// 'XLSX'). Named here so there is one spelling.
  static const formatXlsx = 'XLSX';
  static const formatPdf = 'PDF';
  static const formatDocx = 'DOCX';
  static const formatCsv = 'CSV';
  static const formatJson = 'JSON';
  static const formatZip = 'ZIP';

  /// Shown when a file has no extension and the server sent no kind.
  static const formatUnknown = 'FILE';

  /// Process stream names rendered as section labels on the server-activity
  /// card. Technical identifiers — untranslated in every locale.
  static const streamStdout = 'stdout';
  static const streamStderr = 'stderr';

  /// OS names shown as the title of a registered-device row. Proper nouns.
  static const platformIos = 'iOS';
  static const platformAndroid = 'Android';

  /// Brand wordmark. Rendered as the fallback lockup when the logo asset
  /// fails to decode — a trademark, so it is never translated.
  static const brandWordmark = 'SAQQAR';

  /// Placeholder shown in the meeting-link field (API_MOBILE_NEW_ENDPOINTS.md
  /// §4.1). A URL example — reads the same in every locale, so it lives here
  /// rather than in `app_strings`.
  /// Day-first long date used by the redesigned inbox section headers.
  static const dateLongDayFirst = 'd MMMM yyyy';

  /// Prefix assumed when the user types a bare Odoo host.
  static const httpsScheme = 'https://';

  static const meetingUrlExample = 'https://meet.google.com/…';

  /// Mask rendered in place of a secret while it is hidden (trial credential
  /// rows). Deliberately a fixed width rather than one bullet per character:
  /// matching the real length would leak how long the secret is, and the
  /// row's width would twitch as the value loads.
  static const secretMask = '••••••••••';
}
