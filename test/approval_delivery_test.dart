// Everything between "the agent asked for approval" and "the card is on
// screen", tested as the pipeline it is.
//
// Reported by the team: Saqqar asks for permission to modify something and no
// approval card ever appears. The card widget itself was covered three times
// over (`approval_parity_test`, `destructive_delete_approval_test`,
// `approval_batch_test`) and the screen renders it correctly given the data
// (`approval_inline_render_test`) — so every existing test passed while the
// approval never reached any of them.
//
// The two ways it could not reach them, both fixed here:
//
//   1. **One malformed row took the whole snapshot down.** The list decode
//      claimed in its own comment to skip a bad element and did not: a `map`
//      over `Approval.fromJson` throws out of `ConversationSnapshot.fromJson`
//      for any row whose `id` is missing or numeric. On the poll path that
//      throw is caught and logged as a warning nobody reads, so the chat kept
//      showing the last good snapshot and never moved again — no card, no new
//      messages, no error.
//
//   2. **A response that never mentioned approvals was read as "none".**
//      After the first tick every poll asks `?since=`, so if a delta omits
//      the key, the approval lands in one snapshot and the tick 1.5 s later
//      erases it — permanently, because nothing asks for a full snapshot
//      again.
//
// The distinction that makes (2) safe is that an EXPLICIT empty list still
// clears the card immediately. That is what the last group pins.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';

// ── Wire fixtures ────────────────────────────────────────────────────────

/// One pending `odoo_write` approval, exactly as §3 documents it.
Map<String, dynamic> _approvalRow({
  String id = 'ap1',
  String status = 'pending',
  String operation = 'write',
}) =>
    <String, dynamic>{
      'id': id,
      'action_type': 'odoo_write',
      'status': status,
      'prompt': 'Saqqar wants to modify 1 record.',
      'record_count': 1,
      'model_label': {'en': 'Sales Order'},
      'payload': {'operation': operation, 'model': 'sale.order'},
    };

Map<String, dynamic> _messageRow(String id, {int minute = 0}) =>
    <String, dynamic>{
      'id': id,
      'role': 'assistant',
      'content': 'row $id',
      'created_at': '2026-08-30T10:${minute.toString().padLeft(2, '0')}:00Z',
    };

/// A snapshot body. [approvals] `null` means the key is ABSENT — the case the
/// client used to read as "nothing is pending".
Map<String, dynamic> _body({
  List<Map<String, dynamic>>? approvals,
  List<Map<String, dynamic>> messages = const [],
  bool delta = false,
  String cursor = '2026-08-30T10:00:00Z',
}) =>
    <String, dynamic>{
      'conversation': <String, dynamic>{
        'id': 'c1',
        'title': 'T',
        'auto_approve': false,
        'is_running': false,
        'stop_requested': false,
      },
      'messages': messages,
      'delta': delta,
      'cursor': cursor,
      if (approvals != null) 'approvals': approvals,
    };

ConversationSnapshot _snap(Map<String, dynamic> body) =>
    ConversationSnapshot.fromJson(body);

// ── Repo stub ────────────────────────────────────────────────────────────

/// Hands back a scripted queue of snapshots, one per fetch, and records the
/// `since` each call carried so a "full" request can be told from a delta.
class _ScriptedRepo implements ConversationsRepository {
  _ScriptedRepo(this._queue);

  final List<ConversationSnapshot> _queue;
  final since = <DateTime?>[];
  int calls = 0;

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    calls++;
    this.since.add(since);
    return _queue[calls - 1 < _queue.length ? calls - 1 : _queue.length - 1];
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

ChatCubit _cubit(_ScriptedRepo repo) {
  final cubit = ChatCubit(conversationId: 'c1', repository: repo);
  addTearDown(() {
    cubit.pause();
    return cubit.close();
  });
  return cubit;
}

List<Approval> _pending(ChatCubit cubit) => cubit.state.data.dataOrNull!.approvals
    .where((a) => a.status == ApprovalStatus.pending)
    .toList();

void main() {
  group('a malformed row must not take the snapshot with it', () {
    // The whole point: these are rows a server can and does emit — a pk
    // serialized as a number, a row missing the field entirely. Each one used
    // to abort the parse of the entire conversation.
    for (final bad in <({String name, Map<String, dynamic> row})>[
      (name: 'an id the server sent as a number', row: {..._approvalRow(), 'id': 7}),
      (name: 'a row with no id at all', row: {..._approvalRow()}..remove('id')),
      (
        name: 'a payload the server sent as a string',
        row: {..._approvalRow(), 'payload': 'not-a-map'},
      ),
    ]) {
      test('${bad.name} is skipped, not fatal', () {
        final snapshot = _snap(_body(
          messages: [_messageRow('m1')],
          approvals: [bad.row, _approvalRow(id: 'good')],
        ));

        expect(
          snapshot.messages.map((m) => m.id),
          ['m1'],
          reason: 'the rest of the snapshot has to survive one bad row — this '
              'is the only feed the chat has.',
        );
        expect(snapshot.approvals.map((a) => a.id), ['good']);
      });
    }

    test('an action_type the client has never heard of still renders', () {
      // Not the same thing as malformed, and it must NOT be dropped:
      // `fromWire` maps anything unrecognised onto `unknown` precisely so a
      // new server-side action still reaches the user as a decision to make.
      final snapshot = _snap(_body(approvals: [
        {..._approvalRow(), 'action_type': 'odoo_archive'},
      ]));

      expect(snapshot.approvals, hasLength(1));
      expect(snapshot.approvals.single.actionType, ApprovalActionType.unknown);
    });

    test('a malformed MESSAGE row does not drop the approvals beside it', () {
      final snapshot = _snap(_body(
        messages: [
          _messageRow('m1'),
          <String, dynamic>{'role': 'assistant', 'content': 'no id'},
        ],
        approvals: [_approvalRow()],
      ));

      expect(snapshot.approvals.map((a) => a.id), ['ap1']);
    });

    test('a non-map element is still skipped', () {
      final snapshot = ConversationSnapshot.fromJson(<String, dynamic>{
        'conversation': const {'id': 'c1', 'title': 'T'},
        'messages': const <Object>[],
        'approvals': <Object>['nonsense', 42, _approvalRow()],
      });

      expect(snapshot.approvals.map((a) => a.id), ['ap1']);
    });
  });

  group('an absent approvals key is not an empty one', () {
    test('the model records which of the two arrived', () {
      expect(_snap(_body()).carriesApprovals, isFalse);
      expect(_snap(_body(approvals: const [])).carriesApprovals, isTrue);
      expect(_snap(_body(approvals: [_approvalRow()])).carriesApprovals, isTrue);
    });

    test('a delta poll that omits the key keeps the pending approval',
        () async {
      // The reported failure, as the poll loop produces it: the approval
      // arrives, and the very next tick — a delta with no `approvals` key and
      // nothing new to say — used to erase it. The loop never asks for a full
      // snapshot again, so the card was gone for good.
      final repo = _ScriptedRepo([
        _snap(_body(messages: [_messageRow('m1')])),
        _snap(_body(
          messages: [_messageRow('m2', minute: 1)],
          approvals: [_approvalRow()],
          delta: true,
        )),
        _snap(_body(delta: true, cursor: '2026-08-30T10:01:00Z')),
        _snap(_body(delta: true, cursor: '2026-08-30T10:01:00Z')),
      ]);
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();
      expect(_pending(cubit).map((a) => a.id), ['ap1']);

      await cubit.refresh();
      await cubit.refresh();

      expect(
        _pending(cubit).map((a) => a.id),
        ['ap1'],
        reason: 'no response since has said anything about approvals, so the '
            'one control that can unblock the run must still be on screen.',
      );
    });

    test('an EXPLICIT empty list clears it on the next tick', () async {
      // The other half, and the reason the rule above is safe: when the
      // server does answer the question, its answer wins immediately —
      // whether the decision was made here, on the web, or by a batch scope.
      final repo = _ScriptedRepo([
        _snap(_body(
          messages: [_messageRow('m1')],
          approvals: [_approvalRow()],
        )),
        _snap(_body(
          messages: [_messageRow('m2', minute: 1)],
          approvals: const [],
          delta: true,
        )),
      ]);
      final cubit = _cubit(repo);

      await cubit.load();
      expect(_pending(cubit), hasLength(1));

      await cubit.refresh();

      expect(_pending(cubit), isEmpty);
    });

    test('a resolved status clears it too', () async {
      final repo = _ScriptedRepo([
        _snap(_body(
          messages: [_messageRow('m1')],
          approvals: [_approvalRow()],
        )),
        _snap(_body(
          approvals: [_approvalRow(status: 'approved')],
          delta: true,
        )),
      ]);
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();

      expect(_pending(cubit), isEmpty);
    });

    test('a full snapshot that omits the key keeps them as well', () async {
      // Same rule on the non-delta branch — a full refresh is the path
      // `_decideApprovalInline` and pull-to-refresh take, and adopting it
      // verbatim would drop an approval the response never discussed.
      final repo = _ScriptedRepo([
        _snap(_body(
          messages: [_messageRow('m1')],
          approvals: [_approvalRow()],
        )),
        _snap(_body(messages: [_messageRow('m1')])),
      ]);
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();

      expect(_pending(cubit).map((a) => a.id), ['ap1']);
    });
  });

  group('refresh() asks for a full snapshot, not a delta', () {
    test('the polling tick sends ?since=, refresh() does not', () async {
      // Every `refresh()` caller is confirming something the message stream
      // does not carry — an approval decided, an environment bound. Asking
      // "what is newer than this cursor" cannot answer any of them.
      final repo = _ScriptedRepo([
        _snap(_body(messages: [_messageRow('m1')])),
        _snap(_body(messages: [_messageRow('m1')])),
      ]);
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();

      expect(repo.since.last, isNull);
    });
  });

  group('an empty window must not erase the transcript', () {
    test('a non-delta response with no messages keeps every row', () async {
      // `overlaps` is `fresh.length < incoming.messages.length`, which for a
      // zero-message window is `0 < 0` — false. That fell through to "adopt
      // verbatim" and replaced a loaded conversation with an empty one.
      final repo = _ScriptedRepo([
        _snap(_body(messages: [
          _messageRow('m1'),
          _messageRow('m2', minute: 1),
        ])),
        _snap(_body(approvals: [_approvalRow()])),
      ]);
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();

      expect(
        cubit.state.data.dataOrNull!.messages.map((m) => m.id),
        ['m1', 'm2'],
      );
      expect(
        _pending(cubit).map((a) => a.id),
        ['ap1'],
        reason: 'the rest of that response is still adopted — it is how an '
            'approval raised with no accompanying message arrives.',
      );
    });
  });
}
