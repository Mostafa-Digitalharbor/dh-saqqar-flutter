import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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
  });

  final String title;
  final String module;
  final String category;
  final String priority;

  /// One-line restatement of the problem, in the user's own dialect. The
  /// server sends it; the card had no slot for it because this model never
  /// read it.
  final String summary;

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
      steps.isNotEmpty ||
      questions.isNotEmpty;

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
      questions: _strings(d['questions']),
      steps: _strings(d['reproduction_steps'] ?? d['steps']),
      reply: _str(d['customer_reply'] ?? d['reply']),
    );
  }

  @override
  List<Object?> get props =>
      [title, module, category, priority, summary, questions, steps, reply];
}

String _str(Object? value) {
  if (value is String) return value.trim();
  if (value is num || value is bool) return '$value';
  return '';
}

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
