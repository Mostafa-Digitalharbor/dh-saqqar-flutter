// Polling cadence around a send.
//
// `POST /messages/` answers with the snapshot the server holds at the moment
// the row is persisted, which can be before a worker has picked the turn up.
// Scheduling the next poll purely off `is_running` in that response risks
// putting it 15 s away for a reply that lands in ~3.4 s — the shape of the
// "the reply takes forever and I have to refresh a few times" report.
//
// Measured against production on 2026-07-29: driving 30 consecutive turns
// through the real API, 8 came back `409 the agent is still working on the
// previous request` when sent 1.5–3 s after the one before. A run the client
// cannot yet see is a real state, so waiting out an idle tick before looking
// is the wrong default. The grace is dropped the instant a snapshot does
// report a run, so a prompt flag costs at most one extra tick — that is what
// the third case below pins down.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

final _t0 = DateTime.utc(2026, 7, 29, 9);

Conversation _conv({required bool isRunning}) => Conversation(
      id: 'c1',
      title: 'Perf probe',
      createdAt: _t0,
      updatedAt: _t0,
      autoApprove: false,
      deepThink: false,
      isRunning: isRunning,
      stopRequested: false,
    );

ConversationSnapshot _snap({required bool isRunning}) => ConversationSnapshot(
      conversation: _conv(isRunning: isRunning),
      messages: const [],
      delta: false,
      cursor: _t0,
    );

/// Counts polls and lets each test decide what the server claims about
/// `is_running`.
class _PollRepo implements ConversationsRepository {
  _PollRepo({this.runningInSendResponse = false, this.runningInPolls = false});

  /// What `POST /messages/` reports. False mirrors production.
  final bool runningInSendResponse;

  /// What subsequent `GET /conversations/<id>/` polls report.
  bool runningInPolls;

  int polls = 0;

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    polls++;
    return _snap(isRunning: runningInPolls);
  }

  @override
  Future<ConversationSnapshot> getSnapshotOffIsolate(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) =>
      getSnapshot(id, since: since, limit: limit, before: before);

  @override
  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool taskPrep = true,
  }) async =>
      _snap(isRunning: runningInSendResponse);

  @override
  Future<({bool isRunning, bool stopRequested})> stop(String id) async =>
      (isRunning: false, stopRequested: true);

  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs [body] inside a fake clock, then tears the cubit down.
void _withCubit(_PollRepo repo, void Function(FakeAsync, ChatCubit) body) {
  fakeAsync((async) {
    final cubit = ChatCubit(conversationId: 'c1', repository: repo);
    cubit.load();
    async.flushMicrotasks();
    body(async, cubit);
    cubit.pause();
    cubit.close();
    async.flushMicrotasks();
  });
}

void main() {
  group('poll cadence after a send', () {
    test('keeps the fast cadence when the send response says not-running', () {
      final repo = _PollRepo(runningInSendResponse: false);
      _withCubit(repo, (async, cubit) {
        final before = repo.polls;

        cubit.sendMessage(content: 'hi');
        async.flushMicrotasks();

        // Four seconds is under the 15 s idle tick but covers two 1.5 s
        // running ticks. Before the grace window this was exactly zero.
        async.elapse(const Duration(seconds: 4));
        expect(repo.polls - before, greaterThanOrEqualTo(2));
      });
    });

    test('drops back to the idle cadence once the grace expires', () {
      final repo = _PollRepo(runningInSendResponse: false);
      _withCubit(repo, (async, cubit) {
        cubit.sendMessage(content: 'hi');
        async.flushMicrotasks();

        // Burn the whole 30 s grace with the server never admitting a run.
        async.elapse(const Duration(seconds: 31));
        final afterGrace = repo.polls;

        // A further 10 s must not fit a single tick if we are back on 15 s.
        async.elapse(const Duration(seconds: 10));
        expect(repo.polls, afterGrace);
      });
    });

    test('a run the server confirms keeps polling past the grace', () {
      final repo = _PollRepo(runningInSendResponse: false, runningInPolls: true);
      _withCubit(repo, (async, cubit) {
        cubit.sendMessage(content: 'hi');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 40));
        final afterGrace = repo.polls;

        // Still running → still 1.5 s, so 10 s is ~6 more ticks. The grace
        // must not be what was holding the cadence up.
        async.elapse(const Duration(seconds: 10));
        expect(repo.polls, greaterThan(afterGrace + 3));
      });
    });

    test('stopping the agent ends the grace immediately', () {
      final repo = _PollRepo(runningInSendResponse: false);
      _withCubit(repo, (async, cubit) {
        cubit.sendMessage(content: 'hi');
        async.flushMicrotasks();

        cubit.stopGeneration();
        async.flushMicrotasks();
        // stopGeneration fires one immediate poll of its own; let it land and
        // schedule the next tick before measuring.
        async.elapse(const Duration(milliseconds: 10));
        final afterStop = repo.polls;

        async.elapse(const Duration(seconds: 10));
        expect(repo.polls, afterStop);
      });
    });

    test('an idle chat with no send stays on the slow cadence', () {
      final repo = _PollRepo();
      _withCubit(repo, (async, cubit) {
        final before = repo.polls;
        async.elapse(const Duration(seconds: 10));
        expect(repo.polls, before);
      });
    });
  });
}
