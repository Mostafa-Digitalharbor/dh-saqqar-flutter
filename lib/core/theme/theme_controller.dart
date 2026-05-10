import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/ui_strings.dart';

const _kThemePrefKey = UiStrings.themePreferenceKey;

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

/// Provided once at app boot via `ProviderScope(overrides: [...])`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

class ThemeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppThemeModeX.parse(prefs.getString(_kThemePrefKey));
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kThemePrefKey, mode.storageValue);
  }

  /// Convenience for a "tap to flip" toggle that ignores System.
  Future<void> toggle() async {
    final next = state == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    await setMode(next);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, AppThemeMode>(
  ThemeController.new,
);
