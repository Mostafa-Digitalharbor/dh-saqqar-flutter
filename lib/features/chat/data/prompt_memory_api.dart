import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';

/// One entry from the saved-task catalogue.
///
/// Two sources arrive on the same shape:
///
///  * `memory` — a task this user has actually run before, ranked by the
///    server against the current query.
///  * `draft` — the structured rewrite of the rough text that was sent as
///    `q`. There is at most one, and it is the whole point of the feature.
@immutable
class PromptMemoryItem extends Equatable {
  const PromptMemoryItem({
    required this.id,
    required this.source,
    required this.title,
    required this.description,
    required this.promptTemplate,
  });

  final String id;
  final String source;
  final String title;
  final String description;

  /// The text that goes into the composer. The server sends the long form
  /// under `prompt_template` and, on some rows, a short `prompt` — the web
  /// reads the first that is present, so this does too.
  final String promptTemplate;

  bool get isDraft => source == 'draft';

  /// Null for a row with no usable text: a prompt that cannot be inserted is
  /// a menu entry that does nothing when tapped.
  static PromptMemoryItem? fromJson(Map<String, dynamic> json) {
    final text = _str(json['prompt_template']).isNotEmpty
        ? _str(json['prompt_template'])
        : _str(json['prompt']);
    if (text.trim().isEmpty) return null;
    return PromptMemoryItem(
      id: _str(json['id']),
      source: _str(json['source']).isEmpty ? 'memory' : _str(json['source']),
      title: _str(json['title']),
      description: _str(json['description']),
      promptTemplate: text,
    );
  }

  @override
  List<Object?> get props => [id, source, title, description, promptTemplate];
}

/// What one "Structure task" round trip produced.
@immutable
class PromptMemoryResult extends Equatable {
  const PromptMemoryResult({required this.draft, required this.matches});

  static const empty = PromptMemoryResult(draft: null, matches: []);

  /// The structured rewrite, when the server managed one.
  final PromptMemoryItem? draft;

  /// The user's closest past tasks. The web fetches these and deliberately
  /// does NOT list them — they sharpen the draft server-side and stay out of
  /// the card. Kept on the model because the response carries them and a
  /// caller may want the count; nothing renders them.
  final List<PromptMemoryItem> matches;

  @override
  List<Object?> get props => [draft, matches];
}

/// `GET /api/v1/prompt-memory/` — the backend behind "Task wording".
///
/// The app used to show four hardcoded starter prompts here, on the reasoning
/// that "the backend exposes no saved-prompt catalogue". That was true when it
/// was written and is not true now: this route returns the user's own past
/// tasks plus an LLM-written structured version of whatever rough text it is
/// given. The web has shipped it for a while; the phone was showing four
/// generic examples in its place.
class PromptMemoryApi {
  PromptMemoryApi(this._dio);

  final Dio _dio;

  /// [query] is the rough task. Sending it is what produces `draft`; without
  /// it the server can only rank saved prompts.
  Future<PromptMemoryResult> fetch({
    required String lang,
    String query = '',
    String? conversationId,
    int limit = 8,
  }) async {
    final json = await _dio.getJson(
      ApiEndpoints.promptMemory,
      queryParameters: {
        'limit': limit,
        'lang': lang,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
      },
    );

    final rawDraft = json['draft'];
    final draft = rawDraft is Map<String, dynamic>
        ? PromptMemoryItem.fromJson(rawDraft)
        : null;

    final matches = <PromptMemoryItem>[];
    final rawPrompts = json['prompts'];
    if (rawPrompts is List) {
      for (final row in rawPrompts) {
        if (row is! Map<String, dynamic>) continue;
        final item = PromptMemoryItem.fromJson(row);
        // The draft can also arrive inside `prompts`; it is rendered from
        // `draft` and must not be counted twice.
        if (item != null && !item.isDraft) matches.add(item);
      }
    }

    return PromptMemoryResult(draft: draft, matches: matches);
  }
}

String _str(Object? v) => v == null ? '' : v.toString();
