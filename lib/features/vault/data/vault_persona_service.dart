import 'package:shared_preferences/shared_preferences.dart';

/// Which credential kinds the environment sheet shows, remembered per
/// environment. Mirrors the web's
/// `localStorage["saqqar.vaultPersona.<envId>"]`.
///
/// The web defaults a never-opened environment to the *user* view and then
/// restores whatever was chosen last time. Without the second half, a
/// developer who flipped the switch to reach the Postgres tab had to flip it
/// again on every single visit — the app was resetting to `false` in
/// `initState` because the choice lived nowhere.
///
/// Modeled as a pure service like [LiveEnvAckService]: reads are synchronous
/// so the sheet can pick the right tab count on its first build, and there is
/// no state for anyone to rebuild on.
class VaultPersonaService {
  VaultPersonaService(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'vaultPersona.';

  /// False (the "I'm a user" view) for an environment never opened before —
  /// the same default the web applies.
  bool isDeveloper(String envId) => _prefs.getBool('$_prefix$envId') ?? false;

  Future<void> setDeveloper(String envId, {required bool developer}) =>
      _prefs.setBool('$_prefix$envId', developer);
}
