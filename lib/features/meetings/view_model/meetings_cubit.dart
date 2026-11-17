import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../data/meeting_models.dart';
import '../data/meetings_api.dart';
import 'meetings_state.dart';

/// Drives the meetings screen against the Vexa endpoints
/// (API_MOBILE_NEW_ENDPOINTS.md §4.1): start a transcription, poll the
/// transcript while it's live, stop, summarize, and ask a question over it.
///
/// Payload shapes are assumed (see [MeetingSession]); the request keys used
/// here (`url` to start, `message` to chat) are the conventional ones —
/// confirm against `odoo_agent/views_meetings.py`.
class MeetingsCubit extends Cubit<MeetingsState> {
  MeetingsCubit(this._api) : super(const MeetingsState());

  static const _tag = 'MeetingsCubit';
  static const _pollInterval = Duration(seconds: 5);

  final MeetingsApi _api;
  Timer? _poll;

  /// `POST /meetings/ { url }` — begin transcribing the meeting at [url].
  Future<void> start(String url) async {
    if (state.busy || url.trim().isEmpty) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final res = await _api.start({'url': url.trim()});
      final session = MeetingSession.fromJson(res);
      emit(state.copyWith(session: session, busy: false));
      AppLogger.info(_tag, 'meeting started → ${session.status}');
      _syncPolling(session);
    } catch (e, st) {
      AppLogger.warn(_tag, 'start failed', error: e, stackTrace: st);
      emit(state.copyWith(busy: false, error: e));
    }
  }

  /// `GET /meetings/<id>/transcript` — refresh the transcript text.
  Future<void> refreshTranscript() async {
    final id = state.session?.id;
    if (id == null || id.isEmpty) return;
    try {
      final res = await _api.transcript(id);
      final t = MeetingTranscript.fromJson(res);
      // Keep the session status in sync with the transcript endpoint's view
      // of it, so polling stops once the meeting ends.
      final session = state.session;
      final nextSession = (session != null && t.status.isNotEmpty)
          ? MeetingSession(id: session.id, status: t.status, raw: session.raw)
          : session;
      emit(state.copyWith(session: nextSession, transcript: t.text));
      if (nextSession != null) _syncPolling(nextSession);
    } catch (e, st) {
      if (isClosed) return;
      AppLogger.warn(_tag, 'transcript fetch failed', error: e, stackTrace: st);
      // Silent on poll failure — keep whatever transcript we already show.
    }
  }

  /// `POST /meetings/<id>/stop` — end the meeting, then one final refresh.
  Future<void> stop() async {
    final id = state.session?.id;
    if (id == null || id.isEmpty || state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _api.stop(id);
      emit(state.copyWith(busy: false));
      _poll?.cancel();
      _poll = null;
      await refreshTranscript();
    } catch (e, st) {
      AppLogger.warn(_tag, 'stop failed', error: e, stackTrace: st);
      emit(state.copyWith(busy: false, error: e));
    }
  }

  /// `POST /meetings/<id>/summarize` — generate a summary.
  Future<void> summarize() async {
    final id = state.session?.id;
    if (id == null || id.isEmpty || state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final res = await _api.summarize(id);
      final summary = (res['summary'] ?? res['text'] ?? res['result'] ?? '')
          .toString();
      emit(state.copyWith(summary: summary, busy: false));
    } catch (e, st) {
      AppLogger.warn(_tag, 'summarize failed', error: e, stackTrace: st);
      emit(state.copyWith(busy: false, error: e));
    }
  }

  /// `POST /meetings/<id>/chat { message }` — ask a question over the
  /// transcript; surfaces the latest reply.
  Future<void> ask(String question) async {
    final id = state.session?.id;
    if (id == null || id.isEmpty || state.busy || question.trim().isEmpty) {
      return;
    }
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final res = await _api.chat(id, {'message': question.trim()});
      final reply = (res['reply'] ?? res['answer'] ?? res['text'] ?? '')
          .toString();
      emit(state.copyWith(chatReply: reply, busy: false));
    } catch (e, st) {
      AppLogger.warn(_tag, 'chat failed', error: e, stackTrace: st);
      emit(state.copyWith(busy: false, error: e));
    }
  }

  void _syncPolling(MeetingSession session) {
    if (session.isActive) {
      _poll ??= Timer.periodic(_pollInterval, (_) => refreshTranscript());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
