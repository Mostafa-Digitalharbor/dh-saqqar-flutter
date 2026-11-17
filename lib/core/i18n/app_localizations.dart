import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';

// `AppStrings` keeps its copy getters in extensions (see `app_strings_*.dart`),
// and an extension only applies where it is imported. Anything that reaches
// strings through `context.tr` therefore gets them from here.
export 'app_strings.dart';

/// Tiny [LocalizationsDelegate] that exposes [AppStrings] for the active
/// locale. Use `context.tr` (defined below) to read strings.
class AppLocalizations {
  AppLocalizations(this.locale) : strings = AppStrings(locale);

  final Locale locale;
  final AppStrings strings;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(
      l != null,
      'AppLocalizations not found — did you wire its delegate?',
    );
    return l!;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.supported.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppStrings get tr => AppLocalizations.of(this).strings;
}
