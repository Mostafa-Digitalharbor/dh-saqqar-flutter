import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/theme/theme_controller.dart';

/// "Deep think" toggle — gives Saqqar more reasoning budget on harder
/// questions. The toggle is GLOBAL (not per-conversation) so the user only
/// has to set their preference once. Mirrors the web's
/// `localStorage["saqqar.deepThink"]` behaviour so a single setting follows
/// the user across every chat.
///
/// When enabled, the chat send flow attaches `deep_think: true` to the
/// outgoing message body. The backend uses that flag to raise the model's
/// thinking budget for that turn.
class DeepThinkController extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(UiStrings.deepThinkPreferenceKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(UiStrings.deepThinkPreferenceKey, value);
  }

  Future<void> toggle() => set(!state);
}

final deepThinkControllerProvider =
    NotifierProvider<DeepThinkController, bool>(DeepThinkController.new);
