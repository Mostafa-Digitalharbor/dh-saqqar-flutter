import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/ui_strings.dart';

const _kThemePrefKey = UiStrings.themePreferenceKey;

/// User-facing theme choice. `system` follows the OS dark/light setting.
enum AppThemeMode { light, dark, system }

extension AppThemeModeX on AppThemeMode {
  ThemeMode get materialMode => switch (this) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };

  String get storageValue => name;

  static AppThemeMode parse(String? raw) {
    return AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }
}

/// Owns the user's theme preference and persists it in SharedPreferences
/// so it survives app restarts.
///
/// Constructed once at app boot in `main.dart` with the resolved
/// [SharedPreferences] instance (no provider gymnastics — plain
/// constructor injection).
class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit(this._prefs)
      : super(AppThemeModeX.parse(_prefs.getString(_kThemePrefKey)));

  final SharedPreferences _prefs;

  Future<void> setMode(AppThemeMode mode) async {
    emit(mode);
    await _prefs.setString(_kThemePrefKey, mode.storageValue);
  }

  /// Convenience for a "tap to flip" toggle that ignores System.
  Future<void> toggle() async {
    final next = state == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    await setMode(next);
  }
}
