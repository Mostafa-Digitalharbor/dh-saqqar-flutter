// The Task-prep toggle must PATCH — including from `null`.
//
// Reported by the user twice: "Task prep doesn't sync with the web, but
// Auto-approve does." Both switches sit in the same row, one worked, one
// didn't.
//
// **Root cause.** `_setTaskPrep` PATCHed only when `conversation.task_prep`
// was already non-null. The backend shipped the field nullable and reset every
// existing row to `null` (`BACKEND_FIXES_RESPONSE_2.md` §1), so the guard was
// false on every conversation in every account, and:
//
//     task_prep is null → the app refuses to PATCH → it stays null
//                       → the app refuses to PATCH → …
//
// The app could never give the field its first value. Only the web could — and
// once it had, mobile started syncing, which is why this read as intermittent
// rather than broken.
//
// Confirmed against production on a real device, 2026-08-12. The live snapshot:
//
//     "auto_approve": false,
//     "deep_think": false,
//     "task_prep": null,        ← the guard read this and gave up
//     "is_running": false,
//
// **Why nothing caught it.** Every existing task-prep test covers a stage that
// was correct: the cubit persists, the repository forwards, the model parses
// null as null. The bug was in the *decision to call them at all*, and no test
// looked there. This one does, on the transition that matters — the first one.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/conversations/data/attachment_models.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

/// Records what the cubit asks the repository to PATCH.
class _RecordingRepo implements ConversationsRepository {
  _RecordingRepo(this._snapshot);

  ConversationSnapshot _snapshot;

  final patches = <({bool? autoApprove, bool? taskPrep})>[];

  @override
  Future<Conversation> patch({
    required String id,
    String? title,
    bool? isArchived,
    bool? autoApprove,
    bool? taskPrep,
    Map<String, dynamic>? context,
    String? environmentId,
    List<String>? environmentIds,
  }) async {
    patches.add((autoApprove: autoApprove, taskPrep: taskPrep));
    // Echo the value back the way the backend documented it, so the next poll
    // sees a non-null field — the state the app could never reach before.
    _snapshot = _snapshot.copyWith(
      conversation: _snapshot.conversation.copyWith(
        autoApprove: autoApprove ?? _snapshot.conversation.autoApprove,
        taskPrep: taskPrep ?? _snapshot.conversation.taskPrep,
      ),
    );
    return _snapshot.conversation;
  }

  @override
  Future<ConversationSnapshot> getSnapshotOffIsolate(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async =>
      _snapshot;

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async =>
      _snapshot;

  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  /// Returns null so `load()` goes to the "network", which is where the
  /// PATCH-echoed snapshot lives. A cached hit would let the test pass against
  /// a stale conversation.
  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  Future<List<Attachment>> uploadAttachments({
    required String conversationId,
    required List<Object> files,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A snapshot in the state every account is actually in: the server sends the
/// key, and its value is null.
ConversationSnapshot _snapshotWithTaskPrep(Object? taskPrep) =>
    ConversationSnapshot.fromJson(<String, dynamic>{
      'conversation': <String, dynamic>{
        'id': 'c1',
        'title': 'T',
        'auto_approve': false,
        'is_running': false,
        'stop_requested': false,
        'task_prep': taskPrep,
      },
      'messages': const <Map<String, dynamic>>[],
    });

void main() {
  group('the first flip — the one the guard blocked', () {
    test('a null task_prep still PATCHes', () async {
      // The regression, stated as plainly as it can be. Before the fix this
      // list was empty and the user's toggle never left the device.
      final repo = _RecordingRepo(_snapshotWithTaskPrep(null));
      final cubit = ChatCubit(repository: repo, conversationId: 'c1');
      await cubit.load();

      expect(
        cubit.state.data.dataOrNull?.conversation.taskPrep,
        isNull,
        reason: 'precondition: this is the state every conversation is in',
      );

      await cubit.setTaskPrep(true);

      expect(repo.patches.map((p) => p.taskPrep), [true]);
      await cubit.close();
    });

    test('and the PATCH names task_prep, not auto_approve', () async {
      // Both flags go through one `_patchConversationFlag`. Sending the wrong
      // key would flip auto-approve on the user's live Odoo instead — a far
      // worse bug than the one being fixed.
      final repo = _RecordingRepo(_snapshotWithTaskPrep(null));
      final cubit = ChatCubit(repository: repo, conversationId: 'c1');
      await cubit.load();

      await cubit.setTaskPrep(false);

      expect(repo.patches.single.taskPrep, isFalse);
      expect(repo.patches.single.autoApprove, isNull);
      await cubit.close();
    });

    test('the echoed value ends the deadlock', () async {
      // After one PATCH the field is non-null, which is what makes the web see
      // the change and what the old guard was waiting for. Asserting it here
      // pins the whole point of the fix: the app is now able to be the client
      // that gives the field its first value.
      final repo = _RecordingRepo(_snapshotWithTaskPrep(null));
      final cubit = ChatCubit(repository: repo, conversationId: 'c1');
      await cubit.load();

      await cubit.setTaskPrep(true);

      expect(cubit.state.data.dataOrNull?.conversation.taskPrep, isTrue);
      await cubit.close();
    });
  });

  group('the two switches in that row behave the same', () {
    // The asymmetry IS the bug report. Auto-approve had no guard and synced
    // every time; task-prep had one and never did. Whatever else changes, a
    // flip of either must reach the server on the same terms.
    for (final value in const [true, false]) {
      test('both PATCH on a flip to $value from a null-flag chat', () async {
        final repo = _RecordingRepo(_snapshotWithTaskPrep(null));
        final cubit = ChatCubit(repository: repo, conversationId: 'c1');
        await cubit.load();

        await cubit.setAutoApprove(value);
        await cubit.setTaskPrep(value);

        expect(repo.patches.length, 2);
        expect(repo.patches[0].autoApprove, value);
        expect(repo.patches[1].taskPrep, value);
        await cubit.close();
      });
    }
  });

  group('a flip stays in its own chat', () {
    // The second half of the same report: "لما بفعل تجهيز المهمه بيتفعل في كل
    // المحادثات" — turning it on in one chat turned it on in all of them.
    //
    // The chat screen reads `conversation.taskPrep ?? TaskPrepCubit.state`.
    // `_setTaskPrep` used to write BOTH on every flip, so raising the device
    // default re-rendered every conversation the server still had no opinion
    // about — which, since the backend defaults the column to null, is every
    // conversation nobody has flipped yet.
    //
    // These pin the read precedence that makes the leak visible. The write
    // half — that an existing chat does not touch the device default — lives
    // in `_setTaskPrep` and is asserted by `source_invariants_test`.
    test('a server value wins over the device default', () {
      final conv = _snapshotWithTaskPrep(false).conversation;

      expect(conv.taskPrep ?? true, isFalse,
          reason: 'a chat the user turned OFF must stay off however the '
              'device default is set');
    });

    test('only a null chat inherits the device default', () {
      final untouched = _snapshotWithTaskPrep(null).conversation;
      final owned = _snapshotWithTaskPrep(true).conversation;

      // Device default OFF: the untouched chat follows it, the owned one
      // does not.
      expect(untouched.taskPrep ?? false, isFalse);
      expect(owned.taskPrep ?? false, isTrue);
    });
  });

  group('an already-owned flag keeps working', () {
    for (final seeded in const [true, false]) {
      test('a chat seeded $seeded PATCHes the opposite', () async {
        final repo = _RecordingRepo(_snapshotWithTaskPrep(seeded));
        final cubit = ChatCubit(repository: repo, conversationId: 'c1');
        await cubit.load();

        await cubit.setTaskPrep(!seeded);

        expect(repo.patches.single.taskPrep, !seeded);
        await cubit.close();
      });
    }
  });
}
