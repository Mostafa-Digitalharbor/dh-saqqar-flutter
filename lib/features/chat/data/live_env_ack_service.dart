import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which (conversation, environment) pairs have already had their
/// live-environment confirmation acknowledged. Mirrors the web's
/// `localStorage["odoo-agent.liveAck.<convId>.<envId>"]` flag.
///
/// Modeled as a pure service (no emitted state) because the consumer only
/// needs synchronous reads + writes — there's no UI to rebuild when the
/// ack flips. Wired via `RepositoryProvider<LiveEnvAckService>` and read
/// from the chat send flow with `context.read<LiveEnvAckService>()`.
class LiveEnvAckService {
  LiveEnvAckService(this._prefs);

  final SharedPreferences _prefs;

  static const _convPrefix = 'liveAck.conv.';
  static const _globalPrefix = 'liveAck.global.';

  /// True when the user already acknowledged the warning for this env in
  /// this conversation OR globally for the env.
  bool isAcknowledged({
    required String conversationId,
    required String envId,
  }) {
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
