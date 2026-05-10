import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/ui_strings.dart';
import '../theme/theme_controller.dart';

const _kLocalePrefKey = UiStrings.localePreferenceKey;

/// `null` means "follow system locale".
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_kLocalePrefKey);
    if (raw == null || raw.isEmpty) return null;
    return Locale(raw);
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_kLocalePrefKey);
    } else {
      await prefs.setString(_kLocalePrefKey, locale.languageCode);
    }
  }

  Future<void> toggleEnglishArabic() async {
    final next = state?.languageCode == UiStrings.localeArabicCode
        ? const Locale(UiStrings.localeEnglishCode)
        : const Locale(UiStrings.localeArabicCode);
    await setLocale(next);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
