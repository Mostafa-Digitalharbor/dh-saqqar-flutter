import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/ui_strings.dart';

/// Global "Deep think" preference (NOT per-conversation). Persists via
/// SharedPreferences to mirror the web's `localStorage["saqqar.deepThink"]`
/// — a single setting follows the user across every chat.
///
/// When enabled, the chat send flow attaches `deep_think: true` to the
/// outgoing message body so the backend raises the model's thinking
/// budget for that turn.
class DeepThinkCubit extends Cubit<bool> {
  DeepThinkCubit(this._prefs)
      : super(_prefs.getBool(UiStrings.deepThinkPreferenceKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> set(bool value) async {
    emit(value);
    await _prefs.setBool(UiStrings.deepThinkPreferenceKey, value);
  }

  Future<void> toggle() => set(!state);
}
