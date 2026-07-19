import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/ui_strings.dart';
import 'app_strings.dart';

/// Resolves [AppStrings] for code that runs OUTSIDE the widget tree.
///
/// `context.tr` is the only way to read copy inside a widget, but three
/// surfaces render user-facing text with no [BuildContext] to hand:
///
///  * Android notification channel names/descriptions, which the OS shows
///    in system Settings (see `PushNotificationsService`),
///  * the Apple Watch bridge, which returns strings the watch draws itself,
///  * the FCM background isolate, which has no widget tree at all.
///
/// Each of those would otherwise hardcode English. This resolves the same
/// locale [LocaleCubit] would, so an Arabic user gets Arabic on those
/// surfaces too.
///
/// Read [strings] fresh at each use rather than caching the result — the
/// user can change locale at runtime, and a cached copy would pin the OS
/// notification channel to whatever language was active at boot.
class PlatformStrings {
  const PlatformStrings(this._prefs);

  final SharedPreferences _prefs;

  /// Copy for the locale that's active right now.
  AppStrings get strings => AppStrings(locale);

  /// The active locale: the user's stored preference wins; absent one (the
  /// "follow system" default), the system locale; and English when the
  /// system runs a language we don't ship.
  ///
  /// Mirrors `LocaleCubit`'s resolution, but validates the stored value
  /// too — this runs on OS-facing paths where an unshipped locale would
  /// surface raw i18n keys rather than merely fall back.
  Locale get locale {
    final candidates = [
      _prefs.getString(UiStrings.localePreferenceKey),
      PlatformDispatcher.instance.locale.languageCode,
    ];
    for (final code in candidates) {
      if (code == null || code.isEmpty) continue;
      if (AppStrings.supported.any((l) => l.languageCode == code)) {
        return Locale(code);
      }
    }
    return const Locale(UiStrings.localeEnglishCode);
  }

  /// For the FCM background isolate, which is spawned cold and therefore
  /// holds no reference to the [SharedPreferences] resolved at boot.
  static Future<PlatformStrings> resolve() async =>
      PlatformStrings(await SharedPreferences.getInstance());
}
