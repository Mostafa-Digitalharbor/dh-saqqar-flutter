import 'package:flutter/foundation.dart';

/// A live meeting-transcription session (API_MOBILE_NEW_ENDPOINTS.md §4.1,
/// Vexa).
///
/// ⚠️ The hand-off documents only method + path + purpose for §4 — NOT the
/// request/response payloads (it defers to `odoo_agent/views_meetings.py`).
/// So these models parse DEFENSIVELY against the conventional shapes and
/// tolerate envelopes; confirm the exact wire contract with the backend and
/// tighten if needed.
@immutable
class MeetingSession {
  const MeetingSession({
    required this.id,
    required this.status,
    this.raw = const {},
  });

  final String id;
  final String status;

  /// The raw object, kept so the UI can fall back to showing unmapped fields
  /// rather than hiding data we didn't model.
  final Map<String, dynamic> raw;

  bool get isActive =>
      status == 'active' || status == 'recording' || status == 'running';

  factory MeetingSession.fromJson(Map<String, dynamic> json) {
    // Accept a bare object or a `{ meeting: {...} }` envelope.
    final obj = (json['meeting'] as Map?)?.cast<String, dynamic>() ?? json;
    return MeetingSession(
      id: (obj['id'] ?? obj['meeting_id'] ?? '').toString(),
      status: (obj['status'] ?? '').toString(),
      raw: obj,
    );
  }

  bool get isValid => id.isNotEmpty;
}

/// A meeting transcript flattened to plain text from whatever shape the
/// endpoint returns — a string, or a list of `{ speaker, text }` segments.
@immutable
class MeetingTranscript {
  const MeetingTranscript({required this.status, required this.text});

  final String status;
  final String text;

  factory MeetingTranscript.fromJson(Map<String, dynamic> json) {
    final t = json['transcript'] ?? json['segments'] ?? json['text'];
    return MeetingTranscript(
      status: (json['status'] ?? '').toString(),
      text: _flatten(t),
    );
  }

  static String _flatten(Object? t) {
    if (t == null) return '';
    if (t is String) return t;
    if (t is List) {
      return t.map((seg) {
        if (seg is Map) {
          final speaker = seg['speaker'] ?? seg['name'] ?? seg['author'];
          final text = seg['text'] ?? seg['content'] ?? '';
          return speaker != null ? '$speaker: $text' : '$text';
        }
        return seg.toString();
      }).join('\n');
    }
    return t.toString();
  }
}
