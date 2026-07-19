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
  static const deepThinkPreferenceKey = 'saqqar.deepThink';

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
}
