import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/ui_strings.dart';

const _kLocalePrefKey = UiStrings.localePreferenceKey;

/// Owns the user's locale preference. `null` means "follow system locale".
///
/// Persists to SharedPreferences so the choice survives app restarts.
/// Constructed once at app boot with the resolved [SharedPreferences].
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(this._prefs) : super(_initial(_prefs));

  final SharedPreferences _prefs;

  static Locale? _initial(SharedPreferences prefs) {
    final raw = prefs.getString(_kLocalePrefKey);
    if (raw == null || raw.isEmpty) return null;
    return Locale(raw);
  }

  Future<void> setLocale(Locale? locale) async {
    emit(locale);
    if (locale == null) {
      await _prefs.remove(_kLocalePrefKey);
    } else {
      await _prefs.setString(_kLocalePrefKey, locale.languageCode);
    }
  }

  Future<void> toggleEnglishArabic() async {
    final next = state?.languageCode == UiStrings.localeArabicCode
        ? const Locale(UiStrings.localeEnglishCode)
        : const Locale(UiStrings.localeArabicCode);
    await setLocale(next);
  }
}
