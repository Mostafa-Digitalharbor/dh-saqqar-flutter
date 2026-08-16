// Does the Stop button actually agree with the web, or only with itself?
//
// Stop is the one control in the app whose whole job is to change state on a
// server that a second client (saqqaar.com) is looking at. It is also the one
// control that reports success BEFORE the server has answered: `_stopGeneration`
// in `chat_screen.dart` flips the UI, clears the Chats-list pulse dot, and
// toasts "Generation stopped" synchronously, then fires the POST unawaited.
//
// That optimism is deliberate and correct for the common case — the backend
// cancel is COOPERATIVE (it sets `stop_requested=true` and the agent exits
// between tool rounds), so waiting for confirmation would leave the button
// looking dead for a poll or two, which testers already reported once as "the
// Stop button does nothing".
//
// What the optimism must not do is survive a cancel that never reached the
// server. These tests pin the two directions of the sync plus that failure.

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/chat_state.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

final _t0 = DateTime.utc(2026, 8, 15, 9);

Conversation _conv({required bool isRunning, required bool stopRequested}) =>
    Conversation(
      id: 'c1',
      title: 'Add 30 users to live',
      createdAt: _t0,
      updatedAt: _t0,
      autoApprove: false,
      deepThink: false,
      isRunning: isRunning,
      stopRequested: stopRequested,
    );

ConversationSnapshot _snap({
  required bool isRunning,
  bool stopRequested = false,
}) =>
    ConversationSnapshot(
      conversation: _conv(isRunning: isRunning, stopRequested: stopRequested),
      messages: const [],
      delta: false,
      cursor: _t0,
    );

/// A repository standing in for the backend both clients share.
///
/// `runningOnServer` / `stopRequestedOnServer` are the row the web is also
/// reading, so a test can move them the way the WEB would and watch what the
/// app does — which is the only way to check the direction that has no call
/// site in this codebase at all.
class _SharedBackend implements ConversationsRepository {
  _SharedBackend({this.runningOnServer = true});

  bool runningOnServer;
  bool stopRequestedOnServer = false;

  /// Ids passed to `POST /stop/`. The list, not a bool: a Stop that fires
  /// twice is a real bug (the button is meant to be inert while stopping) and
  /// a counter that only records "at least one" would not see it.
  final stopCalls = <String>[];

  /// When set, `stop()` throws it instead of reaching the server — the
  /// dropped-connection case.
  Object? stopThrows;

  int polls = 0;

  @override
  Future<({bool isRunning, bool stopRequested})> stop(String id) async {
    stopCalls.add(id);
    final failure = stopThrows;
    if (failure != null) throw failure;
    // What the real endpoint does: flips the cooperative flag and reports the
    // run as STILL RUNNING, because the agent has not reached its next
    // checkpoint yet. A fixture that answered `isRunning: false` here would
    // be testing an endpoint the backend does not have.
    stopRequestedOnServer = true;
    return (isRunning: runningOnServer, stopRequested: true);
  }

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    polls++;
    return _snap(
      isRunning: runningOnServer,
      stopRequested: stopRequestedOnServer,
    );
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
      _snap(isRunning: runningOnServer);

  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _withCubit(
  _SharedBackend backend,
  void Function(FakeAsync, ChatCubit) body,
) {
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
  group('app → server', () {
    test('Stop reaches the shared row exactly once', () {
      final backend = _SharedBackend();
      _withCubit(backend, (async, cubit) {
        cubit.stopGeneration();
        async.flushMicrotasks();

        // The whole sync rests on this: the app does not merely re-render
        // itself, it writes `stop_requested` on the row the web reads. If this
        // list is empty the button is a local animation and the web would
        // never learn the user asked for anything.
        expect(backend.stopCalls, ['c1']);
        expect(backend.stopRequestedOnServer, isTrue);
      });
    });

    test('a second tap while the first is in flight sends nothing', () {
      final backend = _SharedBackend();
      _withCubit(backend, (async, cubit) {
        cubit.stopGeneration();
        cubit.stopGeneration();
        async.flushMicrotasks();

        // `isStopping` guards the re-entry. Two POSTs would be harmless on the
        // backend (the endpoint is idempotent) but they are two round-trips
        // charged to a user on a bad connection, and the guard is what the
        // spinner-and-disable on the button is derived from.
        expect(backend.stopCalls, ['c1']);
      });
    });
  });

  group('server → app', () {
    test('a stop performed on the WEB clears the running state here', () {
      // The direction with no call site in this repo: the user hits Stop in
      // the browser, so nothing in the app is ever told. The only way the
      // phone finds out is the poll, which makes the poll the sync.
      final backend = _SharedBackend(runningOnServer: true);
      _withCubit(backend, (async, cubit) {
        async.elapse(const Duration(seconds: 2));
        expect(
          cubit.state.isRunning,
          isTrue,
          reason: 'precondition: the app should see the run the web started',
        );

        // The web cancels. Only the shared row moves.
        backend.runningOnServer = false;
        backend.stopRequestedOnServer = true;

        // One running-cadence tick is 1.5 s; give it two so the assertion is
        // about the sync working rather than about landing on the exact tick.
        async.elapse(const Duration(seconds: 3));

        expect(
          cubit.state.isRunning,
          isFalse,
          reason: 'A stop issued from the web left the app still showing the '
              'agent as working. The app never observes the web directly, so '
              'the running-cadence poll is the entire sync — if it stops '
              'reading `is_running` off the snapshot, the phone shows a '
              'thinking indicator for a run that ended minutes ago.',
        );
      });
    });

    test('the app keeps showing the run until the server actually ends it',
        () {
      // The other half of the same contract, and the reason the optimistic UI
      // in `chat_screen` is a VIEW-level override rather than cubit state: the
      // cancel is cooperative, so the server legitimately keeps answering
      // `is_running: true` for a poll or two after `stop_requested` flips.
      //
      // The cubit must report that truthfully. If it faked `isRunning: false`
      // on the stop response, the Chats list would show the conversation as
      // idle while the agent was still writing to it — and the web, reading
      // the same row, would disagree with the phone on screen.
      final backend = _SharedBackend(runningOnServer: true);
      _withCubit(backend, (async, cubit) {
        cubit.stopGeneration();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        expect(
          cubit.state.isRunning,
          isTrue,
          reason: 'The cubit reported the run as finished while the server '
              'still had it running. Stop is cooperative — only the server '
              'can say when the agent actually exited.',
        );

        // …and once the worker does exit, the next poll agrees.
        backend.runningOnServer = false;
        async.elapse(const Duration(seconds: 3));
        expect(cubit.state.isRunning, isFalse);
      });
    });
  });

  group('a cancel that never reached the server', () {
    test('is reported as a failure, not as a stop', () {
      final backend = _SharedBackend()
        ..stopThrows = DioException.connectionError(
          requestOptions: RequestOptions(path: '/stop/'),
          reason: 'network unreachable',
        );

      _withCubit(backend, (async, cubit) {
        cubit.stopGeneration();
        async.flushMicrotasks();

        // The distinction that matters to the user: the agent is still
        // running, still consuming quota, and still visibly working on the
        // web. Anything that reads as "stopped" here is the app telling them
        // something it has no basis for.
        expect(
          cubit.state.actionFailure?.action,
          ChatAction.stop,
          reason: 'A stop that never reached the server produced no failure. '
              'The run is still going — the user has to be able to tell, or '
              'they walk away from an agent they believe they cancelled.',
        );
        expect(
          cubit.state.actionFailure?.failure,
          isA<NetworkFailure>(),
          reason: 'so the toast says "check your connection" rather than the '
              'generic fallback',
        );
        expect(
          cubit.state.actionToast,
          isNot(ChatToast.generationStopped),
          reason: 'The cubit queued the success toast for a cancel that '
              'failed. Two contradictory messages for one tap, and the '
              'reassuring one is the lie.',
        );
        expect(
          cubit.state.isStopping,
          isFalse,
          reason: 'the button must return to Stop so the user can retry',
        );
      });
    });

    test('leaves the run visible so the user can try again', () {
      final backend = _SharedBackend(runningOnServer: true)
        ..stopThrows = DioException.connectionError(
          requestOptions: RequestOptions(path: '/stop/'),
          reason: 'network unreachable',
        );

      _withCubit(backend, (async, cubit) {
        cubit.stopGeneration();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        // `stop_requested` was never written, so the web still shows the agent
        // working — and so must this. A cubit that went idle here would put
        // the two clients in permanent disagreement over a row neither of them
        // changed.
        expect(backend.stopRequestedOnServer, isFalse);
        expect(
          cubit.state.isRunning,
          isTrue,
          reason: 'The app went idle after a cancel the server never '
              'received. The web would still show the run — and the Stop '
              'button here is gone, so the user has no way to retry the one '
              'action that would end it.',
        );
      });
    });
  });
}
