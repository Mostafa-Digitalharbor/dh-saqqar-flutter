import 'package:flutter/foundation.dart';

import '../../conversations/data/conversation_models.dart';

/// Public read-only transcript shape returned by `GET /api/v1/shares/<token>/`.
/// Only `user` and `assistant` rows are exposed (tool/system are hidden).
@immutable
class SharedTranscript {
  const SharedTranscript({
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String title;
  final DateTime updatedAt;
  final List<Message> messages;

  factory SharedTranscript.fromJson(Map<String, dynamic> json) {
    final conv = json['conversation'] as Map<String, dynamic>;
    return SharedTranscript(
      title: conv['title'] as String? ?? '',
      updatedAt: _parseDate(conv['updated_at']) ?? DateTime.now(),
      messages: (json['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Message.fromJson)
          .toList(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
