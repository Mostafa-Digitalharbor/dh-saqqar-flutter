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
  /// **Send the whole draft, not just its header.** `title` and `priority`
  /// were the right names, but they are the only two fields that map onto
  /// Odoo columns — the ticket's *description* is composed server-side out of
  /// `summary` / `transcript` / `reproduction_steps` / `questions` /
  /// `customer_reply` / `module` / `category`. Sending the header alone, which
  /// is what shipped, created a real ticket carrying a subject line and an
  /// empty body: support got nothing to act on, and the user was told it was
  /// sent. Contract captured from the live code in
  /// `docs/BACKEND_FIXES_RESPONSE_2.md`, Appendix B.
  ///
  /// `priority` is a **label** (`High` / `Medium` / `Normal` / `Low`, or the
  /// Arabic equivalents), not a numeric code — echo the draft's value back
  /// verbatim; the server maps it to Odoo's 0–3 and falls back to `Normal`.
  ///
  /// [environmentId] picks which bound Odoo database to write to. Optional:
  /// omitted, the server uses the user's first. The chat passes the
  /// conversation's own environment so a user with more than one database
  /// doesn't have the ticket land in whichever happens to sort first.
  ///
  /// Degrades with a clear server error when the Odoo Helpdesk module isn't
  /// installed — or, when Project *is* installed, silently succeeds as a
  /// `project.task` instead. [VoiceSupportTicket.isProjectTask] is how the
  /// caller tells those apart; both are real saved records.
  Future<VoiceSupportTicket> createTicket({
    required VoiceSupportDraft draft,
    required String transcript,
    String? environmentId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.voiceSupportTicket,
      data: {
        ...draft.toTicketPayload(transcript: transcript),
        if (environmentId != null && environmentId.isNotEmpty)
          'env_id': environmentId,
      },
    );
    return VoiceSupportTicket.fromJson(res.requiredBody);
  }
}
