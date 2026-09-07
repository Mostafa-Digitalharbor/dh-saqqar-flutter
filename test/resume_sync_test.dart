// Task 2 (MOBILE_TASKS_2026-09.md) — the Resume banner's contract.
//
// A run can end without finishing and without anything waiting on the user;
// the server flags that dead end as `conversation.needs_resume == true` and
// offers `POST /conversations/<id>/resume/` to restart it. This pins the
// same shape of contract `stop_sync_test.dart` pins for Stop: the button
// reaches the server exactly once per tap, a second tap while the first is
// in flight is a no-op, success merges the fresh snapshot and kicks the fast
// poll cadence, and a failure re-enables the button silently — no toast,
// per the web behaviour the spec calls out explicitly.

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/chat_state.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

final _t0 = DateTime.utc(2026, 9, 5, 9);

Conversation _conv({required bool isRunning, required bool needsResume}) =>
    Conversation(
      id: 'c1',
      title: 'Build sale orders from the price list',
      createdAt: _t0,
      updatedAt: _t0,
      autoApprove: false,
      deepThink: false,
      isRunning: isRunning,
      stopRequested: false,
      needsResume: needsResume,
    );

ConversationSnapshot _snap({
  required bool isRunning,
  bool needsResume = false,
}) =>
    ConversationSnapshot(
      conversation: _conv(isRunning: isRunning, needsResume: needsResume),
      messages: const [],
      delta: false,
      cursor: _t0,
    );

/// A repository standing in for the backend, scoped to exactly what Resume
/// touches. `noSuchMethod` covers everything else the interface declares.
class _Backend implements ConversationsRepository {
  _Backend({this.runningOnServer = false, this.needsResumeOnServer = true});

  bool runningOnServer;
  bool needsResumeOnServer;

  /// Ids passed to `POST /resume/`. A list, not a bool, for the same reason
  /// `stop_sync_test.dart` keeps one for Stop: a resume that fires twice
  /// while the first is in flight is the bug the `isResuming` guard exists
  /// to prevent, and a counter that only remembers "at least once" would not
  /// see a second call happen.
  final resumeCalls = <String>[];

  /// When set, `resume()` throws it instead of reaching the server.
  Object? resumeThrows;

  int polls = 0;

  @override
  Future<ConversationSnapshot> resume(String id) async {
    resumeCalls.add(id);
    final failure = resumeThrows;
    if (failure != null) throw failure;
    // What the real endpoint does: the run restarts server-side, so
    // `needs_resume` clears even though `is_running` may not have flipped
    // yet for this very response.
    needsResumeOnServer = false;
    return _snap(isRunning: runningOnServer, needsResume: false);
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
      needsResume: needsResumeOnServer,
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
  ConversationSnapshot? cachedSnapshot(String id) => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _withCubit(_Backend backend, void Function(FakeAsync, ChatCubit) body) {
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
    test('Resume reaches the server exactly once', () {
      final backend = _Backend();
      _withCubit(backend, (async, cubit) {
        cubit.resumeRun();
        async.flushMicrotasks();
        expect(backend.resumeCalls, ['c1']);
      });
    });

    test('a second tap while the first is in flight sends nothing', () {
      final backend = _Backend();
      _withCubit(backend, (async, cubit) {
        cubit.resumeRun();
        cubit.resumeRun();
        async.flushMicrotasks();
        expect(backend.resumeCalls, ['c1']);
      });
    });
  });

  group('a successful resume', () {
    test('merges the fresh snapshot, clearing needs_resume', () {
      final backend = _Backend(needsResumeOnServer: true);
      _withCubit(backend, (async, cubit) {
        expect(cubit.state.data.dataOrNull?.conversation.needsResume, isTrue);
        cubit.resumeRun();
        async.flushMicrotasks();
        expect(
          cubit.state.data.dataOrNull?.conversation.needsResume,
          isFalse,
          reason: 'resumeRun() must merge through the same path a poll does '
              '(_mergeSnapshot), not just paint the button back to idle.',
        );
        expect(cubit.state.isResuming, isFalse);
      });
    });

    test('kicks the fast poll cadence immediately', () {
      // Same reasoning `chat_poll_cadence_test.dart` pins for sendMessage:
      // the very first snapshot back from resume() may still read
      // `is_running: false` for a beat, so the cadence must be forced rather
      // than left to notice on the next idle-interval (15 s) tick.
      final backend = _Backend(runningOnServer: false);
      _withCubit(backend, (async, cubit) {
        cubit.resumeRun();
        async.flushMicrotasks();
        final pollsAtResume = backend.polls;

        // Idle cadence is 15 s; if the grace kick had no effect, nothing new
        // would have polled by 3 s. The running cadence is 1.5 s, so two
        // more polls easily land in that window if the kick worked.
        async.elapse(const Duration(seconds: 3));
        expect(
          backend.polls,
          greaterThan(pollsAtResume),
          reason: 'resumeRun() did not force the fast poll cadence — the '
              'banner would clear but new messages would take up to 15 s to '
              'show up with no manual refresh.',
        );
      });
    });
  });

  group('a resume that never reached the server', () {
    test('is reported as a failure, with no toast either way', () {
      final backend = _Backend()
        ..resumeThrows = DioException.connectionError(
          requestOptions: RequestOptions(path: '/resume/'),
          reason: 'network unreachable',
        );

      _withCubit(backend, (async, cubit) {
        cubit.resumeRun();
        async.flushMicrotasks();

        expect(cubit.state.actionFailure?.action, ChatAction.resume);
        expect(cubit.state.actionFailure?.failure, isA<NetworkFailure>());
        expect(
          cubit.state.actionToast,
          isNull,
          reason: 'Resume must not toast on failure — the spec is explicit '
              'that the user can just tap again, unlike Stop which does '
              'toast on its own failure.',
        );
      });
    });

    test('re-enables the button so the user can tap again', () {
      final backend = _Backend()
        ..resumeThrows = DioException.connectionError(
          requestOptions: RequestOptions(path: '/resume/'),
          reason: 'network unreachable',
        );

      _withCubit(backend, (async, cubit) {
        cubit.resumeRun();
        async.flushMicrotasks();
        expect(
          cubit.state.isResuming,
          isFalse,
          reason: 'the banner must return to "Resume" so the user can retry',
        );
        // needs_resume was never cleared server-side, so the banner itself
        // must still be showing — asserted via the flag it reads.
        expect(cubit.state.data.dataOrNull?.conversation.needsResume, isTrue);
      });
    });
  });
}
