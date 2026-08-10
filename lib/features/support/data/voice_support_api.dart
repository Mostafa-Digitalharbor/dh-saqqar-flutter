import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
import 'voice_support_models.dart';

/// §8 — the voice-support workspace.
///
/// Named for the web page it mirrors (`/voice-support/`), not for telephony:
/// nothing here dials, calls, or opens a messaging thread. The user describes
/// a problem in text, the server drafts a structured diagnosis, and the user
/// may file it as a real Odoo `helpdesk.ticket`.
///
/// TTS is deliberately absent. Speaking the reply needs the BILLING `voice`
/// entitlement (the endpoint 403s on Free) and returns audio this app has no
/// player for; adding a button that fails for most accounts and plays nothing
/// for the rest would be worse than not offering it. The written reply is the
/// substance and every account gets it.
class VoiceSupportApi {
  VoiceSupportApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/voice-support/draft/` — the core call.
  ///
  /// The problem text goes on the wire as **`transcript`**, not `problem`.
  /// The field name was never documented — the web team's note said only
  /// "send the user's problem text", and `problem` was a guess this side made
  /// and listed as an open question in the hand-off. It was the wrong guess:
  /// the server answers `{"ok": false, "error": "`transcript` is required."}`,
  /// so **§8 never once produced a draft**. Confirmed on a real device against
  /// production on 2026-08-09; the name comes from the server's own error.
  ///
  /// It failed quietly for a reason worth remembering: the request 400s, the
  /// error path is correct, and the screen simply returns to its empty state —
  /// which looks exactly like a feature nobody has tried yet. Only the console
  /// said otherwise.
  Future<VoiceSupportDraft> draft({
    required String problem,
    required String lang,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.voiceSupportDraft,
      data: {'transcript': problem, 'lang': lang},
    );
    return VoiceSupportDraft.fromJson(res.requiredBody);
  }

  /// `POST /api/v1/voice-support/ticket/` — creates a real
  /// `helpdesk.ticket` in the user's bound Odoo over XML-RPC.
  ///
  /// **There is no approval card for this**, by the backend's design: the
  /// user's explicit tap IS the consent. That is why the UI asks before
  /// calling rather than after — this is the one write in the whole feature
  /// and it lands in a live database.
  ///
  /// Degrades with a clear server error when the Odoo Helpdesk module isn't
  /// installed, which is a normal outcome rather than a bug.
  Future<void> createTicket({
    required String title,
    required String priority,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.voiceSupportTicket,
      data: {
        'title': title,
        if (priority.isNotEmpty) 'priority': priority,
      },
    );
    res.requiredBody;
  }
}
