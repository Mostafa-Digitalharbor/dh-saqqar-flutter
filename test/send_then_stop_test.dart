// The composer must offer Stop from the moment a message is sent.
//
// The send response usually still says `is_running: false` — the server has
// not picked the turn up yet — so a Stop button keyed on that flag alone
// showed Send for the first second or two of every run, exactly when the user
// wants to cancel a task they just realised was wrong. `awaitingReply` covers
// that gap, and must not outlive it.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

final _t0 = DateTime.utc(2026, 8, 15, 9);

ConversationSnapshot _snap({
  required bool isRunning,
  List<Message> messages = const [],
}) => ConversationSnapshot(
  conversation: Conversation(
    id: 'c1',
    title: 'Task',
    createdAt: _t0,
    updatedAt: _t0,
    autoApprove: false,
    deepThink: false,
    isRunning: isRunning,
    stopRequested: false,
  ),
  messages: messages,
  delta: false,
  cursor: _t0,
);

class _Backend implements ConversationsRepository {
  /// What `GET` reports; the send response always says "not running yet".
  bool runningOnServer = false;
  int stops = 0;

  @override
  Future<({bool isRunning, bool stopRequested})> stop(String id) async {
    stops++;
    return (isRunning: runningOnServer, stopRequested: true);
  }

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async => _snap(isRunning: runningOnServer);

  @override
  Future<ConversationSnapshot> getSnapshotOffIsolate(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) => getSnapshot(id, since: since, limit: limit, before: before);

  @override
  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool taskPrep = true,
  }) async => _snap(isRunning: false);

  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _run(_Backend backend, void Function(FakeAsync, ChatCubit) body) {
  fakeAsync((async) {
    final cubit = ChatCubit(conversationId: 'c1', repository: backend);
    cubit.load();
    async.flushMicrotasks();
    body(async, cubit);
    cubit.pause();
    cubit.close();
    async.flushMicrotasks();
  });
}

void main() {
  test('Stop is offered right after a send, before the server says running', () {
    final backend = _Backend();
    _run(backend, (async, cubit) {
      expect(cubit.state.awaitingReply, isFalse);

      cubit.sendMessage(content: 'do it');
      async.flushMicrotasks();

      expect(cubit.state.isRunning, isFalse);
      expect(cubit.state.awaitingReply, isTrue);
    });
  });

  test('it hands over to the server flag once a run is reported', () {
    final backend = _Backend();
    _run(backend, (async, cubit) {
      cubit.sendMessage(content: 'do it');
      async.flushMicrotasks();

      backend.runningOnServer = true;
      async.elapse(const Duration(seconds: 5));

      expect(cubit.state.isRunning, isTrue);
      expect(cubit.state.awaitingReply, isFalse);
    });
  });

  test('tapping Stop clears it at once and sends the cancel', () {
    final backend = _Backend();
    _run(backend, (async, cubit) {
      cubit.sendMessage(content: 'do it');
      async.flushMicrotasks();
      expect(cubit.state.awaitingReply, isTrue);

      cubit.stopGeneration();
      async.flushMicrotasks();

      expect(cubit.state.awaitingReply, isFalse);
      expect(backend.stops, 1);
    });
  });

  test('a send that never becomes a run does not leave Stop up forever', () {
    final backend = _Backend();
    _run(backend, (async, cubit) {
      cubit.sendMessage(content: 'do it');
      async.flushMicrotasks();

      // Well past the post-send grace, with the server never reporting a run.
      async.elapse(const Duration(minutes: 2));

      expect(cubit.state.awaitingReply, isFalse);
    });
  });
}
