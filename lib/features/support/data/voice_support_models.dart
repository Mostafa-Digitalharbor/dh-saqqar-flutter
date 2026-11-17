import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../core/format/wire_value.dart';

/// Structured draft returned by `POST /api/v1/voice-support/draft/` (§8).
///
/// Every field is server-authored. The parsers are type-tolerant for the same
/// reason the interactive-card parsers are: a `priority` that arrives as the
/// number `2` instead of `"2"` must not take down the screen the user opened
/// because something was already broken.
@immutable
class VoiceSupportDraft extends Equatable {
  const VoiceSupportDraft({
    required this.title,
    required this.module,
    required this.category,
    required this.priority,
    required this.questions,
    required this.steps,
    required this.reply,
    this.summary = '',
    this.diagnosis = '',
  });

  final String title;
  final String module;
  final String category;
  final String priority;

  /// One-line restatement of the problem, in the user's own dialect. The
  /// server sends it; the card had no slot for it because this model never
  /// read it.
  final String summary;

  /// The server's reading of the likely cause. Optional on the wire (the
  /// backend documents it as `diagnosis?`), and rendered only when present —
  /// an empty heading over nothing is worse than no heading.
  final String diagnosis;

  /// Follow-up questions the diagnosis still needs answered.
  final List<String> questions;

  /// Suggested resolution steps.
  final List<String> steps;

  /// The Saudi-dialect reply. This is the part the user reads, and the part
  /// TTS speaks.
  final String reply;

  /// Whether there is anything worth rendering. A draft with no reply, no
  /// steps and no questions is an empty card — better to show the raw
  /// failure than a card with a title and nothing under it.
  bool get hasContent =>
      reply.isNotEmpty ||
      summary.isNotEmpty ||
      diagnosis.isNotEmpty ||
      steps.isNotEmpty ||
      questions.isNotEmpty;

  /// The draft as `POST /voice-support/ticket/` wants it.
  ///
  /// The backend composes the Odoo ticket **description** out of these keys
  /// (Appendix B, 2026-08-12) — `title` and `priority` are the only two that
  /// map onto Odoo fields directly. Sending just those two, which is what
  /// this feature did until now, filed a real ticket in a real database with
  /// a title and an **empty body**: support would have received a subject
  /// line and nothing to act on, and the user would have been told it was
  /// sent.
  ///
  /// [transcript] is the user's own words — what they typed into the box.
  /// The server uses it as the summary only when [summary] is empty, so it is
  /// both a fallback and the verbatim record of the report.
  Map<String, Object?> toTicketPayload({required String transcript}) => {
    if (title.isNotEmpty) 'title': title,
    if (priority.isNotEmpty) 'priority': priority,
    if (summary.isNotEmpty) 'summary': summary,
    if (transcript.isNotEmpty) 'transcript': transcript,
    if (steps.isNotEmpty) 'reproduction_steps': steps,
    if (questions.isNotEmpty) 'questions': questions,
    if (reply.isNotEmpty) 'customer_reply': reply,
    if (module.isNotEmpty) 'module': module,
    if (category.isNotEmpty) 'category': category,
  };

  /// Reads the draft, wherever the server put it and whichever spelling it
  /// used.
  ///
  /// **The response nests it.** `POST /voice-support/draft/` answers
  /// `{"ok": true, "draft": {...}}`, and this parser was pointed at the root —
  /// so every field resolved to null and the screen rendered its "no diagnosis
  /// arrived" state against a perfectly good reply. [unwrap] takes the nested
  /// object when it is there and the body itself when it is not.
  ///
  /// **Two fields were also named wrong**: the wire says
  /// `reproduction_steps` and `customer_reply`, not `steps` and `reply`. Both
  /// spellings are accepted — the short ones cost nothing to keep and mean a
  /// server that ever simplifies its keys does not break the screen.
  ///
  /// All three were invented on this side when §8 was built against prose
  /// rather than a captured payload. Confirmed against production 2026-08-09.
  static Map<String, dynamic> unwrap(Map<String, dynamic> body) {
    final nested = body['draft'];
    return nested is Map ? nested.cast<String, dynamic>() : body;
  }

  factory VoiceSupportDraft.fromJson(Map<String, dynamic> json) {
    final d = unwrap(json);
    return VoiceSupportDraft(
      title: _str(d['title']),
      module: _str(d['module']),
      category: _str(d['category']),
      priority: _str(d['priority']),
      summary: _str(d['summary']),
      diagnosis: _str(d['diagnosis']),
      questions: _strings(d['questions']),
      steps: _strings(d['reproduction_steps'] ?? d['steps']),
      reply: _str(d['customer_reply'] ?? d['reply']),
    );
  }

  @override
  List<Object?> get props => [
    title,
    module,
    category,
    priority,
    summary,
    diagnosis,
    questions,
    steps,
    reply,
  ];
}

/// What `POST /api/v1/voice-support/ticket/` created.
///
/// The call used to return `void`, so the screen said "ticket filed" for any
/// 200 — including a 200 that created nothing. The backend's contract is that
/// **a row exists iff `ok` is true and `ticket_id` is present**, so that pair
/// is what [created] tests, and the screen only claims success when it holds.
///
/// [kind] matters to the user, not just to us: when Odoo Helpdesk isn't
/// installed the server falls back to creating a `project.task` instead. That
/// is still a real, saved record — but calling it a support ticket would send
/// someone looking in a Helpdesk app that isn't there.
@immutable
class VoiceSupportTicket extends Equatable {
  const VoiceSupportTicket({
    required this.ticketId,
    required this.name,
    required this.target,
    required this.kind,
  });

  /// The Odoo record id. Null when the server answered without one.
  final int? ticketId;

  /// The record's title, as Odoo stored it.
  final String name;

  /// Odoo model the row lives in — `helpdesk.ticket` or `project.task`.
  final String target;

  /// `helpdesk` or `task`. Empty when the server didn't say.
  final String kind;

  /// Whether a real row exists. See the class doc: presence of the id is the
  /// server's own success signal.
  bool get created => ticketId != null;

  /// True when the fallback fired and this is a project task, not a helpdesk
  /// ticket. Reads [target] as well as [kind] so either field alone answers.
  bool get isProjectTask => kind == kindTask || target == targetProjectTask;

  static const String kindTask = 'task';
  static const String targetProjectTask = 'project.task';

  factory VoiceSupportTicket.fromJson(Map<String, dynamic> json) {
    final id = json['ticket_id'];
    return VoiceSupportTicket(
      ticketId: id is int
          ? id
          : id is num
          ? id.toInt()
          // A string id is not in the contract, but costs one line to
          // accept and would otherwise read as "nothing was created".
          : int.tryParse(_str(id)),
      name: _str(json['name']),
      target: _str(json['target']),
      kind: _str(json['kind']),
    );
  }

  @override
  List<Object?> get props => [ticketId, name, target, kind];
}

/// Trimming, unlike the pulse/card parsers: these values go straight into
/// single-line ticket rows, where a leading newline from a transcript shifts
/// the whole row. See `core/format/wire_value.dart`.
String _str(Object? value) => wireString(value, trim: true);

/// Accepts a list of strings, and tolerates a list of `{text: …}`-ish maps or
/// a single string where a list was documented.
List<String> _strings(Object? value) {
  if (value is String) {
    final one = value.trim();
    return one.isEmpty ? const [] : [one];
  }
  if (value is! List) return const [];
  final out = <String>[];
  for (final item in value) {
    final text = item is Map
        ? _str(item['text'] ?? item['label'] ?? item['value'])
        : _str(item);
    if (text.isNotEmpty) out.add(text);
  }
  return out;
}
