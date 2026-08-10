import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';

/// Voice transcription endpoint wrapper.
///
/// `POST /api/v1/transcribe/` (multipart) → `{ ok: true, text: "..." }`.
/// Server-side runs OpenAI Whisper on the uploaded audio file. See
/// `SAQQAR_MOBILE_VOICE.md` (§2) for the full contract.
///
/// The Dio instance already carries the `Authorization: Bearer <token>`
/// header set by [DioClient]'s auth interceptor, so this class only
/// owns the multipart envelope.
class TranscribeApi {
  TranscribeApi(this._dio);

  final Dio _dio;

  /// Sends [audio] to Whisper and returns the transcript text (already
  /// trimmed server-side). Empty string is a legitimate result —
  /// callers should map it to the `transcribeEmpty` toast and leave
  /// the composer untouched.
  ///
  /// [language] is optional. Pass `null` (default) for auto-detect —
  /// matches the web client and handles AR↔EN code-switch / dialects.
  /// Pass `"ar"` or `"en"` to force.
  ///
  /// Throws [DioException] on transport / non-200 responses; the chat
  /// screen funnels those through [ApiErrorMapper] for the toast text.
  Future<String> transcribe({
    required File audio,
    String? language,
  }) async {
    final filename = audio.uri.pathSegments.isNotEmpty
        ? audio.uri.pathSegments.last
        : 'voice.m4a';
    final form = FormData();
    form.files.add(
      MapEntry(
        'audio',
        await MultipartFile.fromFile(
          audio.path,
          filename: filename,
          // Whisper accepts the m4a/webm/mp3/wav/ogg/flac container set
          // — the server forwards our Content-Type to OpenAI verbatim,
          // so a sensible audio/m4a is what we ship by default.
          contentType: DioMediaType.parse(_mimeForFilename(filename)),
        ),
      ),
    );
    if (language != null && language.isNotEmpty) {
      form.fields.add(MapEntry('language', language));
    }
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.transcribe,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    // `?? ''` handed back an empty transcript, which the composer treats as
    // "the user said nothing" — the recording is discarded, no error is
    // shown, and there is nothing to retry. The audio is gone by then.
    final body = res.requiredBody;
    return (body['text'] as String? ?? '').trim();
  }

  /// Cheap extension → MIME map. Whisper doesn't actually require this
  /// to match the container — but a correct Content-Type is what Apple's
  /// recorder writes by default for .m4a files, so we mirror that.
  String _mimeForFilename(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'm4a' || 'aac' => 'audio/m4a',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' || 'opus' => 'audio/ogg',
      'webm' => 'audio/webm',
      'flac' => 'audio/flac',
      _ => 'audio/m4a',
    };
  }
}
