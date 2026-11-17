import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user wants push notifications. Persisted; defaults ON.
///
/// Separate from the OS-level permission — this is Saqqar's own switch. When
/// toggled OFF the app unregisters the device server-side (via the push
/// service) so the backend stops sending; ON re-registers it.
class NotificationsSettingsCubit extends Cubit<bool> {
  NotificationsSettingsCubit(this._prefs) : super(_prefs.getBool(_key) ?? true);

  static const _key = 'saqqar.notifications.push_enabled';

  final SharedPreferences _prefs;

  Future<void> setEnabled(bool value) async {
    if (value == state) return;
    await _prefs.setBool(_key, value);
    emit(value);
  }
}
