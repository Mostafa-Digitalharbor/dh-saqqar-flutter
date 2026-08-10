import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';

/// The three §6 Odoo tools, documented by the web team on 2026-08-06.
///
/// All are **read-only** and all behave the same way: they run server-side
/// against the conversation's bound Odoo XML-RPC credential and post their
/// report into the conversation as an assistant message. There is no stream
/// to consume — the existing snapshot poll surfaces the new message a beat
/// later, which is what "streamed into chat" meant.
///
/// An earlier build sent locally-authored prompt text through the composer
/// instead, on a probe that found no route. The routes existed under names
/// the probe didn't guess (`radar/run`, not `health-radar`). Calling them
/// directly is better than a prompt for one concrete reason: the agent may
/// paraphrase, decline, or run a different tool given free-text wording,
/// whereas these always run the specific scan the row names.
class SaqqarToolsApi {
  SaqqarToolsApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/radar/run/` — Odoo Health Radar.
  Future<void> runHealthRadar({
    required String conversationId,
    required String lang,
  }) =>
      _run(ApiEndpoints.radarRun, conversationId, lang);

  /// `POST /api/v1/pulse/run/` — Business Pulse / executive brief.
  Future<void> runBusinessPulse({
    required String conversationId,
    required String lang,
  }) =>
      _run(ApiEndpoints.pulseRun, conversationId, lang);

  /// `POST /api/v1/whatif/intro/` — posts the "describe your decision"
  /// primer.
  ///
  /// Deliberately NOT `whatif/run/`. That endpoint needs a `scenario` from a
  /// fixed set of four plus a `percent`, which would mean a form asking the
  /// user to classify their own question before they've phrased it. The
  /// intro lets them describe the scenario in plain language and the agent's
  /// `simulate_what_if` tool routes it to the same engine.
  Future<void> runWhatIfIntro({
    required String conversationId,
    required String lang,
  }) =>
      _run(ApiEndpoints.whatIfIntro, conversationId, lang);

  /// Every one of the three takes the same body and returns a body the app
  /// does not read: the report reaches the user as a posted message, not as
  /// this response. [requiredBody] still runs so a stripped/empty 200 raises
  /// a parse error rather than being reported as a scan that succeeded and
  /// produced nothing.
  Future<void> _run(String path, String conversationId, String lang) async {
    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: {'conversation_id': conversationId, 'lang': lang},
    );
    res.requiredBody;
  }
}
