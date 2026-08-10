// docs/WEB_UI_PARITY_GAPS.md §2 + §3 — what the client puts on the wire.
//
// The two halves of the deep-think → task-prep swap that no widget test can
// see, because they happen inside the request body:
//
//   * `deep_think` must be GONE from every body the app sends. The web removed
//     the manual toggle; a client that keeps sending the key is fighting the
//     backend's own routing.
//   * `task_prep` must be PRESENT on every send, `true` or `false`. The server
//     reads it as `payload.get("task_prep", True)`, so omitting it when the
//     user turned the toggle OFF silently gives them the ON behaviour — the
//     one failure mode a "did we send it?" test has to catch.
//
// And `Conversation` must still DECODE `deep_think` (§2: "keep the model
// tolerant"): the server still serializes the key, and a stricter model would
// fail the whole snapshot parse over a field nothing reads.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_api.dart';

/// Records the body of the last request and answers with [reply].
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.reply);

  final Object reply;
  Map<String, dynamic>? lastBody;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    final data = options.data;
    lastBody = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Minimal snapshot body — enough for `ConversationSnapshot.fromJson`.
const _snapshotReply = {
  'conversation': {
    'id': 'c1',
    'title': 'T',
    'auto_approve': false,
    'is_running': false,
    'stop_requested': false,
    // The server still sends this. Decoding must survive it.
    'deep_think': true,
  },
  'messages': <Map<String, dynamic>>[],
};

const _patchReply = {
  'conversation': {
    'id': 'c1',
    'title': 'T',
    'auto_approve': true,
    'is_running': false,
    'stop_requested': false,
    'deep_think': false,
  },
};

void main() {
  group('send body', () {
    test('carries task_prep and never deep_think', () async {
      for (final taskPrep in [true, false]) {
        final adapter = _CapturingAdapter(_snapshotReply);
        final api = ConversationsApi(Dio()..httpClientAdapter = adapter);

        await api.sendMessage(
          conversationId: 'c1',
          content: 'hello',
          taskPrep: taskPrep,
        );

        expect(
          adapter.lastBody!['task_prep'],
          taskPrep,
          reason: 'task_prep=$taskPrep must reach the server verbatim — the '
              'server defaults it to true when the key is absent, so an '
              'omitted `false` reads as "on".',
        );
        expect(
          adapter.lastBody!.containsKey('deep_think'),
          isFalse,
          reason: 'deep_think was removed with the web toggle (§2)',
        );
      }
    });

    test('defaults to task_prep: true, matching the server default', () async {
      final adapter = _CapturingAdapter(_snapshotReply);
      final api = ConversationsApi(Dio()..httpClientAdapter = adapter);

      await api.sendMessage(conversationId: 'c1', content: 'hello');

      expect(adapter.lastBody!['task_prep'], isTrue);
    });
  });

  group('PATCH body', () {
    test('no longer carries deep_think', () async {
      final adapter = _CapturingAdapter(_patchReply);
      final api = ConversationsApi(Dio()..httpClientAdapter = adapter);

      await api.patch(id: 'c1', autoApprove: true);

      expect(adapter.lastBody!['auto_approve'], isTrue);
      expect(adapter.lastBody!.containsKey('deep_think'), isFalse);
    });

    // Task prep became a per-conversation field by product decision on
    // 2026-08-10, mirroring `auto_approve`. The client sends it ahead of the
    // server so the sync fix needs no mobile release — which makes the
    // "omitted unless set" half load-bearing: a build that put `task_prep`
    // in every PATCH would be writing a key today's server does not know,
    // on requests the user only meant to rename a chat with.
    test('carries task_prep when set, on the documented key', () async {
      for (final value in [true, false]) {
        final adapter = _CapturingAdapter(_patchReply);
        final api = ConversationsApi(Dio()..httpClientAdapter = adapter);

        await api.patch(id: 'c1', taskPrep: value);

        expect(adapter.lastBody!['task_prep'], value, reason: 'value=$value');
      }
    });

    test('omits task_prep entirely when the caller has no opinion', () async {
      final adapter = _CapturingAdapter(_patchReply);
      final api = ConversationsApi(Dio()..httpClientAdapter = adapter);

      await api.patch(id: 'c1', title: 'renamed');

      expect(adapter.lastBody!.containsKey('task_prep'), isFalse);
      expect(adapter.lastBody!['title'], 'renamed');
    });
  });

  group('model tolerance (§2 — parse and ignore)', () {
    test('a snapshot carrying deep_think still decodes', () {
      final snapshot = ConversationSnapshot.fromJson(
        Map<String, dynamic>.from(_snapshotReply),
      );

      expect(snapshot.conversation.id, 'c1');
      // Still parsed — just no longer sent or rendered anywhere.
      expect(snapshot.conversation.deepThink, isTrue);
    });

    test('a snapshot WITHOUT deep_think decodes to null, not false', () {
      final snapshot = ConversationSnapshot.fromJson(const {
        'conversation': {
          'id': 'c2',
          'title': 'T',
          'auto_approve': false,
          'is_running': false,
          'stop_requested': false,
        },
        'messages': <Map<String, dynamic>>[],
      });

      expect(snapshot.conversation.deepThink, isNull);
    });
  });
}
