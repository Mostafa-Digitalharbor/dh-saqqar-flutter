import 'package:shared_preferences/shared_preferences.dart';

/// Whether the welcome (onboarding) screen has been shown on this install.
/// Loaded once while the launch splash is up so the router gate can read it
/// synchronously.
class OnboardingFlag {
  OnboardingFlag._();

  static const _key = 'saqqar.onboarding.seen';
  static bool seen = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    seen = prefs.getBool(_key) ?? false;
  }

  static Future<void> markSeen() async {
    seen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
