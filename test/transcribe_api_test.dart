// `POST /api/v1/transcribe/` — the multipart envelope the voice composer
// depends on.
//
// This was the only API client in the app with no test at all. Everything it
// does is envelope construction, and every part of that envelope is a
// silent-failure risk: the server reads exactly one file field (`audio`), and
// a wrong field name, a dropped `language`, or a `Content-Type` the Whisper
// proxy rejects all surface the same way — the recording ends, the composer
// stays empty, and nothing in the UI says why.
//
// The assertions read the actual `FormData` off the outgoing request rather
// than trusting the constructor, because that is the artifact the server
// parses.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/network/api_endpoints.dart';
import 'package:saqqar_app/core/network/api_error_mapper.dart';
import 'package:saqqar_app/core/network/error_interceptor.dart';
import 'package:saqqar_app/features/chat/data/transcribe_api.dart';

/// Captures the request it was asked to send, then answers with [body].
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({this.status = 200, this.body = const {'text': 'ok'}});

  final int status;
  final Object body;
  RequestOptions? captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('saqqar_transcribe_test');
  });

  tearDown(() async {
    // `MultipartFile.fromFile` holds the handle open past the request on
    // Windows, so the delete races it and throws errno 32. The temp dir is
    // disposable either way — failing the test over cleanup would be noise.
    try {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Left for the OS to reap.
    }
  });

  /// A real on-disk file — `MultipartFile.fromFile` reads it, so an in-memory
  /// fake would not exercise the path the app actually takes.
  File audioNamed(String filename) {
    final f = File('${tmp.path}${Platform.pathSeparator}$filename');
    f.writeAsBytesSync(List<int>.filled(64, 7));
    return f;
  }

  ({TranscribeApi api, _CapturingAdapter adapter}) build({
    int status = 200,
    Object body = const {'text': 'ok'},
  }) {
    final adapter = _CapturingAdapter(status: status, body: body);
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    return (api: TranscribeApi(dio), adapter: adapter);
  }

  group('the multipart envelope', () {
    test('posts to the pinned endpoint as multipart', () async {
      final t = build();
      await t.api.transcribe(audio: audioNamed('voice.m4a'));

      expect(t.adapter.captured!.method, 'POST');
      expect(t.adapter.captured!.path, ApiEndpoints.transcribe);
      expect(
        t.adapter.captured!.contentType,
        contains('multipart/form-data'),
        reason: 'the server parses this as a file upload; a JSON content type '
            'makes it read the body as a single string field and return no '
            'transcript',
      );
    });

    test('the file rides in the `audio` field, keeping its filename', () async {
      final t = build();
      await t.api.transcribe(audio: audioNamed('recording-42.m4a'));

      final form = t.adapter.captured!.data as FormData;
      expect(
        form.files.map((e) => e.key),
        ['audio'],
        reason: 'the server reads exactly one file field, named `audio`',
      );
      expect(form.files.single.value.filename, 'recording-42.m4a');
    });

    test('omits `language` entirely when auto-detecting', () async {
      // Null means auto-detect, which is what handles AR↔EN code-switching.
      // Sending an empty string instead would pin Whisper to a blank locale.
      final t = build();
      await t.api.transcribe(audio: audioNamed('voice.m4a'));

      final form = t.adapter.captured!.data as FormData;
      expect(form.fields.map((e) => e.key), isNot(contains('language')));
    });

    test('sends `language` when one is forced', () async {
      final t = build();
      await t.api.transcribe(audio: audioNamed('voice.m4a'), language: 'ar');

      // `MapEntry` has no value equality, so `contains` on the entry itself
      // compares identity and always fails — assert on the pair.
      final form = t.adapter.captured!.data as FormData;
      expect(
        form.fields.any((e) => e.key == 'language' && e.value == 'ar'),
        isTrue,
      );
    });

    test('an empty language string is treated as auto-detect', () async {
      final t = build();
      await t.api.transcribe(audio: audioNamed('voice.m4a'), language: '');

      final form = t.adapter.captured!.data as FormData;
      expect(form.fields.map((e) => e.key), isNot(contains('language')));
    });
  });

  group('content type follows the container', () {
    // The server forwards our Content-Type to OpenAI verbatim, so a wrong one
    // is rejected upstream rather than by us — the user sees a failed
    // transcription with no local cause.
    const expected = {
      'voice.m4a': 'audio/m4a',
      'voice.aac': 'audio/m4a',
      'voice.mp3': 'audio/mpeg',
      'voice.wav': 'audio/wav',
      'voice.ogg': 'audio/ogg',
      'voice.opus': 'audio/ogg',
      'voice.webm': 'audio/webm',
      'voice.flac': 'audio/flac',
      // Anything unrecognised falls back to the recorder's own default rather
      // than to a type Whisper would reject outright.
      'voice.weird': 'audio/m4a',
    };

    for (final entry in expected.entries) {
      test('${entry.key} → ${entry.value}', () async {
        final t = build();
        await t.api.transcribe(audio: audioNamed(entry.key));

        final form = t.adapter.captured!.data as FormData;
        expect(
          form.files.single.value.contentType.toString(),
          entry.value,
        );
      });
    }

    test('uppercase extensions map the same way', () async {
      final t = build();
      await t.api.transcribe(audio: audioNamed('VOICE.MP3'));

      final form = t.adapter.captured!.data as FormData;
      expect(form.files.single.value.contentType.toString(), 'audio/mpeg');
    });
  });

  group('reading the reply', () {
    test('returns the transcript, trimmed', () async {
      final t = build(body: const {'ok': true, 'text': '  مرحبا بك  '});
      expect(await t.api.transcribe(audio: audioNamed('v.m4a')), 'مرحبا بك');
    });

    test('a missing text key is an empty transcript, not a crash', () async {
      // Empty is a legitimate result — silence, or audio Whisper could not
      // resolve. The composer maps it to a toast and leaves the draft alone,
      // so this must not throw.
      final t = build(body: const {'ok': true});
      expect(await t.api.transcribe(audio: audioNamed('v.m4a')), isEmpty);
    });

    test('a non-string text surfaces as "unexpected response"', () async {
      // The cast throws a `TypeError`, which is deliberate rather than
      // defensive: `text: 42` is the server breaking its own contract, and
      // `ApiErrorMapper` turns a TypeError into `ParseFailure` →
      // "unexpected response from the server".
      //
      // Coercing it to '' instead would be indistinguishable from a silent
      // recording, so the user would retry the one thing that cannot fix it.
      // This pins the classification so the error stays legible if the parse
      // ever moves behind a `try`.
      final t = build(body: const {'ok': true, 'text': 42});
      Object? thrown;
      try {
        await t.api.transcribe(audio: audioNamed('v.m4a'));
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull);
      expect(ApiErrorMapper.toFailure(thrown), isA<ParseFailure>());
    });
  });

  group('failures reach the localized path', () {
    test('the ok:false envelope throws rather than returning empty', () async {
      // Returning '' here would be the worst outcome: identical to a silent
      // recording, so the user retries the one thing that cannot help.
      final t = build(
        body: const {'ok': false, 'error': 'Audio too long'},
      );
      await expectLater(
        t.api.transcribe(audio: audioNamed('v.m4a')),
        throwsA(anything),
      );
    });

    test('413 classifies as payload-too-large', () async {
      // The one failure with advice the user can act on: record something
      // shorter. It must not collapse into the generic message.
      final t = build(status: 413, body: const {'error': 'too large'});
      Object? thrown;
      try {
        await t.api.transcribe(audio: audioNamed('v.m4a'));
      } catch (e) {
        thrown = e;
      }
      expect(ApiErrorMapper.toFailure(thrown), isA<PayloadTooLargeFailure>());
    });

    test('415 classifies as unsupported media', () async {
      final t = build(status: 415, body: const {'error': 'bad container'});
      Object? thrown;
      try {
        await t.api.transcribe(audio: audioNamed('v.m4a'));
      } catch (e) {
        thrown = e;
      }
      expect(ApiErrorMapper.toFailure(thrown), isA<UnsupportedMediaFailure>());
    });
  });
}
