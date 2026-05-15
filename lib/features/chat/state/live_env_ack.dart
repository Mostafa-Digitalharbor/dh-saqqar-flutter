import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme_controller.dart';

/// Tracks which (conversation, environment) pairs have already had their
/// live-environment confirmation acknowledged. Mirrors the web's
/// `localStorage["odoo-agent.liveAck.<convId>.<envId>"]` flag.
///
/// "Don't ask again" stores the env id under a global ack instead, so any
/// future conversation against that env skips the warning.
class LiveEnvAckController {
  LiveEnvAckController(this._prefs);

  final SharedPreferences _prefs;

  static const _convPrefix = 'liveAck.conv.';
  static const _globalPrefix = 'liveAck.global.';

  /// True when the user already acknowledged the warning for this env in
  /// this conversation OR globally for the env.
  bool isAcknowledged({required String conversationId, required String envId}) {
    if (_prefs.getBool('$_globalPrefix$envId') == true) return true;
    return _prefs.getBool('$_convPrefix$conversationId.$envId') == true;
  }

  Future<void> acknowledgeForConversation({
    required String conversationId,
    required String envId,
  }) {
    return _prefs.setBool('$_convPrefix$conversationId.$envId', true);
  }

  Future<void> acknowledgeGlobally({required String envId}) {
    return _prefs.setBool('$_globalPrefix$envId', true);
  }
}

final liveEnvAckProvider = Provider<LiveEnvAckController>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LiveEnvAckController(prefs);
});
