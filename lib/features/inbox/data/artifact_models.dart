import 'package:flutter/foundation.dart';

import '../../../core/format/byte_size.dart';
import '../../../core/network/api_endpoints.dart';

/// Pointer to the conversation an artifact came from. Only present on the
/// flat `/api/v1/artifacts/` list response.
@immutable
class ArtifactConversationRef {
  const ArtifactConversationRef({required this.id, required this.title});
  final String id;
  final String title;

  factory ArtifactConversationRef.fromJson(Map<String, dynamic> json) {
    return ArtifactConversationRef(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
    );
  }
}

/// A file the agent produced — xlsx, pdf, docx, json reports.
/// Schema per SAQQAR_MOBILE_API.md §3 / §9.
///
/// [url] is server-relative. Use [absoluteUrl] to get the full URL ready
/// for download / share. The URL itself is the auth token — anyone with
/// the link can fetch the file. Paths are UUID-segmented and unguessable.
@immutable
class Artifact {
  const Artifact({
    required this.id,
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.url,
    this.filePath,
    this.metadata = const {},
    this.createdAt,
    this.conversation,
  });

  final String id;
  final String name;

  /// `xlsx | json | pdf | docx | …` — free-form string; treat unknown
  /// values as generic file downloads.
  final String kind;

  final String mimeType;

  /// Server-relative path (e.g. `/media/reports/...`). Prepend the API
  /// host before download — use [absoluteUrl].
  final String url;

  /// Server-side storage path (e.g. `reports/<filename>`). Not generally
  /// needed by the client — kept for completeness.
  final String? filePath;

  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final ArtifactConversationRef? conversation;

  String get absoluteUrl {
    if (url.startsWith('http')) return url;
    return '${ApiEndpoints.baseUrl}$url';
  }

  /// Size in bytes, from the server's `metadata.size_kb`.
  ///
  /// Exposed in bytes rather than KB so the view can hand it straight to
  /// `humanBytes` and get the right unit. The previous `sizeKb` getter
  /// pushed the caller into rendering `'$sizeKb KB'`, which showed a 40 MB
  /// addon bundle as "40960 KB".
  int? get sizeBytes {
    final v = metadata['size_kb'];
    if (v is num) return v.toInt() * kBytesPerKb;
    return null;
  }

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      url: json['url'] as String? ?? '',
      filePath: json['file_path'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ??
          const {},
      createdAt: _parseDate(json['created_at']),
      conversation: json['conversation'] is Map<String, dynamic>
          ? ArtifactConversationRef.fromJson(
              json['conversation'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

/// Result of `GET /api/v1/artifacts/` — paginated list across all
/// conversations.
@immutable
class ArtifactsPage {
  const ArtifactsPage({
    required this.artifacts,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Artifact> artifacts;
  final int total;
  final int limit;
  final int offset;

  factory ArtifactsPage.fromJson(Map<String, dynamic> json) {
    return ArtifactsPage(
      artifacts: (json['artifacts'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Artifact.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 30,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
