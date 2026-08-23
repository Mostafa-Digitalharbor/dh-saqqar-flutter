// Proves the thing that actually matters on a low-end phone: an idle chat
// must not repaint itself.
//
// `ChatScreen` reads `ChatCubit` with `context.watch`, so one emit rebuilds
// the whole subtree — app bar, header dropdowns, message list, composer, both
// drawers. The cubit polls `GET /conversations/<id>/` every 1.5 s while the
// agent runs and every 15 s when it doesn't, and it emitted on EVERY tick
// because `ConversationSnapshot` had reference equality: a fresh object off
// the wire is never `==` the one already on screen, however identical its
// contents.
//
// That is 40 full-tree rebuilds a minute for a conversation where nothing is
// happening. On a flagship it hides inside the frame budget. On the low-end
// hardware this app is aimed at it is a constant background tax on the UI
// thread and the battery.
//
// This can't be measured on-device without a signed-in account, and a frame
// profile would only tell us about the surface the harness happened to be
// showing anyway. Counting rebuilds is the direct, deterministic measurement:
// it asserts the property itself rather than a proxy for it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

final _t0 = DateTime.utc(2026, 7, 25, 10);

Message _msg(String id) => Message(
      id: id,
      role: MessageRole.assistant,
      content: 'Reconciled 42 orders.',
      createdAt: _t0,
    );

ConversationSnapshot _snapshot({
  required List<Message> messages,
  bool delta = false,
  bool isRunning = true,
}) =>
    ConversationSnapshot(
      conversation: Conversation(
        id: 'c1',
        title: 'Q3 close',
        createdAt: _t0,
        updatedAt: _t0,
        autoApprove: false,
        deepThink: false,
        isRunning: isRunning,
        stopRequested: false,
      ),
      messages: messages,
      delta: delta,
      cursor: _t0,
    );

/// Returns the same snapshot for every poll — i.e. a conversation where the
/// server has nothing new to say, which is what the overwhelming majority of
/// polls look like.
class _IdleRepo implements ConversationsRepository {
  _IdleRepo(this._initial, this._steady);

  final ConversationSnapshot _initial;
  final ConversationSnapshot _steady;
  int calls = 0;

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    calls++;
    return calls == 1 ? _initial : _steady;
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

/// Stands in for `ChatScreen`: a widget whose build depends on the whole
/// `ChatCubit` state, exactly as the real screen's `context.watch` does.
class _WatchingSubtree extends StatelessWidget {
  const _WatchingSubtree({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    final snapshot = context.watch<ChatCubit>().state.data.dataOrNull;
    return Text(
      '${snapshot?.messages.length ?? 0}',
      textDirection: TextDirection.ltr,
    );
  }
}

void main() {
  testWidgets('ten idle polls cause zero rebuilds', (tester) async {
    final repo = _IdleRepo(
      _snapshot(messages: [_msg('m1'), _msg('m2')]),
      _snapshot(messages: const [], delta: true),
    );
    final cubit = ChatCubit(conversationId: 'c1', repository: repo);
    addTearDown(cubit.close);

    var builds = 0;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: _WatchingSubtree(onBuild: () => builds++),
      ),
    );

    await cubit.load();
    await tester.pump();
    final buildsAfterLoad = builds;

    for (var i = 0; i < 10; i++) {
      await cubit.refresh();
      await tester.pump();
    }
    // The cubit re-arms its poll timer after every fetch. Cancel it inside the
    // test body, not in `addTearDown` — the binding checks for pending timers
    // before tear-downs run.
    cubit.pause();

    expect(repo.calls, 11, reason: 'all eleven polls must have been made');
    expect(
      builds - buildsAfterLoad,
      0,
      reason: 'ten polls that returned nothing new rebuilt the subtree '
          '${builds - buildsAfterLoad} time(s). Before the models were made '
          'value-equal this was ten — one per poll — which at the 1.5 s '
          'running cadence is ~40 full-tree rebuilds a minute on an idle '
          'conversation.',
    );
  });

  testWidgets('a poll that changes something still rebuilds exactly once',
      (tester) async {
    // The saving must not come at the cost of missing a real update. This is
    // the other half of the contract and the one a careless "just stop
    // emitting" optimisation breaks.
    final repo = _IdleRepo(
      _snapshot(messages: [_msg('m1')]),
      _snapshot(messages: [_msg('m2')], delta: true),
    );
    final cubit = ChatCubit(conversationId: 'c1', repository: repo);
    addTearDown(cubit.close);

    var builds = 0;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: _WatchingSubtree(onBuild: () => builds++),
      ),
    );

    await cubit.load();
    await tester.pump();
    final buildsAfterLoad = builds;

    // First poll appends m2 → one rebuild. The second delivers m2 again,
    // which dedupes to nothing → no further rebuild.
    await cubit.refresh();
    await tester.pump();
    await cubit.refresh();
    await tester.pump();
    cubit.pause();

    expect(builds - buildsAfterLoad, 1);
    expect(find.text('2'), findsOneWidget);
  });
}
