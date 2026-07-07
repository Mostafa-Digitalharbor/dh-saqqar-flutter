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

  static const artifactExcel = 'Excel';
  static const artifactCsv = 'CSV';
  static const artifactLog = 'Log';
  static const artifactImage = 'Image';
  static const artifactJson = 'JSON';
  static const artifactMarkdown = 'Markdown';
}
