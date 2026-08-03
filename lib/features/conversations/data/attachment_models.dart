import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_endpoints.dart';

/// Server-side processing state for a user-uploaded attachment.
enum AttachmentStatus {
  pending,
  ready,
  failed;

  static AttachmentStatus fromWire(String? value) {
    return switch (value) {
      'ready' => AttachmentStatus.ready,
      'failed' => AttachmentStatus.failed,
      _ => AttachmentStatus.pending,
    };
  }
}

/// A user-uploaded file attached to a message.
///
/// Schema per SAQQAR_MOBILE_API.md §6. The upload returns one of these
/// per file; the client polls `/attachments/<id>/status/` while
/// [status] is [AttachmentStatus.pending] until OCR / text extraction
/// completes — the agent will eager-wait if the user sends before then.
@immutable
class Attachment extends Equatable {
  const Attachment({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
    required this.status,
    required this.url,
    this.createdAt,
  });

  final String id;
  final String originalName;
  final String mimeType;
  final int sizeBytes;

  /// `image | pdf | csv | xlsx | docx | other`. Used by the chip render.
  final String kind;

  final AttachmentStatus status;

  /// Server-relative URL. Use [absoluteUrl] for a ready-to-fetch link.
  final String url;

  final DateTime? createdAt;

  String get absoluteUrl {
    if (url.startsWith('http')) return url;
    return '${ApiEndpoints.baseUrl}$url';
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      originalName: json['original_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? 'other',
      status: AttachmentStatus.fromWire(json['status'] as String?),
      url: json['url'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        originalName,
        mimeType,
        sizeBytes,
        kind,
        status,
        url,
        createdAt,
      ];
}
