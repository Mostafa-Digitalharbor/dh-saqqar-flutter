// Regression tests for `ChatCubit._mergeSnapshot`.
//
// The chat polls `GET /conversations/<id>/` every 1.5 s while the agent is
// running, and every response goes through `_mergeSnapshot`. Two properties
// of that merge are load-bearing and neither had coverage:
//
//   1. **Nothing the server sent may be dropped.** The merge used to build a
//      fresh `ConversationSnapshot(...)` by hand, listing fields one by one.
//      Any field not on that list silently reverted to its default — which is
//      exactly what happened to `quotaExceeded`: the send response correctly
//      reported the user was over their cap, the banner painted, and 1.5 s
//      later the first poll wiped the flag and re-enabled Send.
//
//   2. **An unchanged poll must not emit.** `ConversationSnapshot` and every
//      model it contains are now value-equal, so a poll that returns what is
//      already on screen produces a state equal to the current one and Bloc
//      drops it. Without that, the chat screen rebuilt its entire tree — both
//      drawers, the composer, the message list — 40 times a minute while
//      literally nothing had changed.
//
// Both are invisible in normal use and expensive when broken, which is the
// definition of something that belongs in a test.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/chat_state.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────

final _t0 = DateTime.utc(2026, 7, 25, 10);

Message _msg(String id, {String content = 'hi', int minute = 0}) => Message(
      id: id,
      role: MessageRole.user,
      content: content,
      createdAt: _t0.add(Duration(minutes: minute)),
    );

Conversation _conv({bool isRunning = true, String title = 'Ledger close'}) =>
    Conversation(
      id: 'c1',
      title: title,
      createdAt: _t0,
      updatedAt: _t0,
      autoApprove: false,
      deepThink: false,
      isRunning: isRunning,
      stopRequested: false,
    );

ConversationSnapshot _snapshot({
  required List<Message> messages,
  bool delta = false,
  QuotaWindow? quotaExceeded,
  bool isRunning = true,
  String title = 'Ledger close',
  DateTime? cursor,
}) =>
    ConversationSnapshot(
      conversation: _conv(isRunning: isRunning, title: title),
      messages: messages,
      delta: delta,
      cursor: cursor ?? _t0,
      quotaExceeded: quotaExceeded,
    );

/// Repository stub that hands back a scripted queue of snapshots, one per
/// `getSnapshot` call, and records how many times it was asked.
class _ScriptedRepo implements ConversationsRepository {
  _ScriptedRepo(this._queue);

  final List<ConversationSnapshot> _queue;
  int calls = 0;

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    calls++;
    // Repeat the last scripted entry once the queue runs dry, so a stray
    // poll tick can't blow the test up with a range error.
    return _queue[calls - 1 < _queue.length ? calls - 1 : _queue.length - 1];
  }

  // Same scripted answer for both fetch paths. The production repo decodes
  // this one off the UI isolate; under `flutter_test` there is no isolate
  // boundary worth modelling, and a fake that answered only one of them
  // would make `load()` fail for a reason the test is not about.
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
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ConversationSnapshot _dataOf(ChatCubit cubit) =>
    cubit.state.data.dataOrNull!;

void main() {
  group('_mergeSnapshot preserves server fields', () {
    test('quotaExceeded survives a delta poll that omits new messages',
        () async {
      // The server blocked the turn for being over the daily cap, then the
      // next poll comes back as a delta with nothing new. Before the fix the
      // hand-rolled merge dropped `quotaExceeded` here and the composer
      // silently re-enabled itself.
      final repo = _ScriptedRepo([
        _snapshot(messages: [_msg('m1')], quotaExceeded: QuotaWindow.day),
        _snapshot(
          messages: const [],
          delta: true,
          quotaExceeded: QuotaWindow.day,
        ),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(cubit.close);

      await cubit.load();
      expect(_dataOf(cubit).quotaExceeded, QuotaWindow.day);

      await cubit.refresh();
      expect(
        _dataOf(cubit).quotaExceeded,
        QuotaWindow.day,
        reason: 'a delta poll must not clear the quota flag the server is '
            'still reporting — that re-enables Send while the user is '
            'genuinely over their cap',
      );
    });

    test('quotaExceeded survives the shorter-non-delta preservation branch',
        () async {
      // A non-delta poll carrying FEWER messages than we hold takes the
      // "preserve our transcript, adopt their metadata" path. That branch had
      // its own hand-rolled constructor, and its own copy of the same bug.
      final repo = _ScriptedRepo([
        _snapshot(messages: [_msg('m1'), _msg('m2', minute: 1)]),
        _snapshot(messages: [_msg('m2', minute: 1)],
            quotaExceeded: QuotaWindow.month),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.refresh();

      final data = _dataOf(cubit);
      expect(data.quotaExceeded, QuotaWindow.month);
      expect(
        data.messages.map((m) => m.id),
        ['m1', 'm2'],
        reason: 'the shorter response must not truncate history the user '
            'has already paged in',
      );
    });
  });

  group('value equality suppresses redundant emits', () {
    test('an unchanged delta poll produces no new state', () async {
      final repo = _ScriptedRepo([
        _snapshot(messages: [_msg('m1')]),
        // Same conversation, no new rows — i.e. "nothing happened".
        _snapshot(messages: const [], delta: true),
        _snapshot(messages: const [], delta: true),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(cubit.close);

      await cubit.load();

      final emitted = <ChatState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      await cubit.refresh();
      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(
        emitted,
        isEmpty,
        reason: 'two polls that returned nothing new must not wake the '
            'widget tree — this is what stops the chat rebuilding itself '
            '40×/min on an idle conversation',
      );
    });

    test('a poll carrying a real change still emits', () async {
      final repo = _ScriptedRepo([
        _snapshot(messages: [_msg('m1')]),
        _snapshot(messages: [_msg('m2', minute: 1)], delta: true),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(cubit.close);

      await cubit.load();

      final emitted = <ChatState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isNotEmpty);
      expect(_dataOf(cubit).messages.map((m) => m.id), ['m1', 'm2']);
    });

    test('a flag flip with no new messages still emits', () async {
      // The suppression must key off content, not off "did any message
      // arrive". `is_running` going false is the signal that stops the
      // typing row — dropping it would hang the indicator forever.
      final repo = _ScriptedRepo([
        _snapshot(messages: [_msg('m1')]),
        _snapshot(messages: const [], delta: true, isRunning: false),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(cubit.close);

      await cubit.load();

      final emitted = <ChatState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isNotEmpty);
      expect(_dataOf(cubit).conversation.isRunning, isFalse);
    });
  });

  group('delta de-duplication', () {
    test('a re-delivered row is not appended twice', () async {
      // A poll requested against the OLD cursor can land after a send has
      // already adopted the same row.
      final repo = _ScriptedRepo([
        _snapshot(messages: [_msg('m1'), _msg('m2', minute: 1)]),
        _snapshot(
          messages: [_msg('m2', minute: 1), _msg('m3', minute: 2)],
          delta: true,
        ),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.refresh();

      expect(_dataOf(cubit).messages.map((m) => m.id), ['m1', 'm2', 'm3']);
    });
  });

  // Opening a chat paints the cache first, then reconciles against a bounded
  // `?limit=` window. That window is SHORTER than a long cached transcript, so
  // the "don't let a short response shrink the transcript" guard fires — and
  // it used to throw the whole fresh window away. Observed on a device
  // 2026-07-29: a chat whose cache held 95 rows opened on a nine-minute-old
  // tail and only caught up when a delta poll landed, up to 15 s later.
  group('a short refresh window keeps history AND lands new rows', () {
    test('stitches rows the cache had not seen onto the end', () async {
      final repo = _ScriptedRepo([
        // What we hold: a long transcript, as if restored from cache.
        _snapshot(messages: [
          _msg('m1', minute: 0),
          _msg('m2', minute: 1),
          _msg('m3', minute: 2),
        ]),
        // The fresh bounded window: overlaps on m3, and carries m4 — fewer
        // rows than we hold, which is what used to make it disappear.
        _snapshot(messages: [_msg('m3', minute: 2), _msg('m4', minute: 3)]),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.refresh();

      expect(
        _dataOf(cubit).messages.map((m) => m.id),
        ['m1', 'm2', 'm3', 'm4'],
      );
    });

    test('a window with nothing new leaves the transcript untouched', () async {
      final repo = _ScriptedRepo([
        _snapshot(messages: [
          _msg('m1', minute: 0),
          _msg('m2', minute: 1),
          _msg('m3', minute: 2),
        ]),
        _snapshot(messages: [_msg('m2', minute: 1), _msg('m3', minute: 2)]),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.refresh();

      expect(_dataOf(cubit).messages.map((m) => m.id), ['m1', 'm2', 'm3']);
    });

    test('adopts the window outright when it shares no row with ours', () async {
      // More than a page arrived while we were away. Stitching would leave a
      // hole in the middle of the transcript; showing the true newest rows and
      // letting the user page back for the rest is the honest answer.
      final repo = _ScriptedRepo([
        _snapshot(messages: [
          _msg('m1', minute: 0),
          _msg('m2', minute: 1),
          _msg('m3', minute: 2),
        ]),
        _snapshot(messages: [_msg('m90', minute: 90), _msg('m91', minute: 91)]),
      ]);
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.refresh();

      expect(_dataOf(cubit).messages.map((m) => m.id), ['m90', 'm91']);
    });
  });

  group('model value equality', () {
    test('two snapshots built from the same data compare equal', () {
      expect(
        _snapshot(messages: [_msg('m1')]),
        _snapshot(messages: [_msg('m1')]),
      );
    });

    test('a changed nested field breaks equality', () {
      expect(
        _snapshot(messages: [_msg('m1')]),
        isNot(_snapshot(messages: [_msg('m1')], title: 'Renamed')),
      );
      expect(
        _snapshot(messages: [_msg('m1')]),
        isNot(_snapshot(messages: [_msg('m1', content: 'different')])),
      );
    });
  });
}
