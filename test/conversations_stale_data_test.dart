// A failed refresh must not throw away the list the user is looking at.
//
// Found by killing the backend mid-session on the emulator: the Chats list
// blanked to full-screen skeletons and stayed there. The cause was a two-step
// loss, and both steps have to be tested because fixing only one still leaves
// the list disappearing:
//
//   1. `load()` decided "cold open, show a skeleton" with
//      `state.data.dataOrNull == null`. `dataOrNull` reports null for a
//      `DataFailure` even when it carries `previous`, so the first failed
//      refresh made the next poll paint shimmers over rows it still had.
//   2. The failure handler then stored `previous: state.data.dataOrNull` —
//      also null by then — so the SECOND consecutive failure lost the rows
//      permanently. Nothing short of a successful request brought them back.
//
// That is the worst-case shape for a mobile client: a tunnel, a lift, one
// dropped request, and the user's conversations are gone.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_state.dart';

final _t0 = DateTime.utc(2026, 7, 25, 12);

ConversationSummary _row(String id) => ConversationSummary(
      id: id,
      title: 'Conversation $id',
      createdAt: _t0,
      updatedAt: _t0,
      isArchived: false,
      messageCount: 12,
    );

/// Serves one good page, then fails every subsequent call — a backend that
/// goes away while the app is running.
class _FlakyRepo implements ConversationsRepository {
  int listCalls = 0;
  bool failing = false;

  @override
  Future<({List<ConversationSummary> conversations, int? total})> list({
    int limit = 30,
    bool includeArchived = false,
  }) async {
    listCalls++;
    if (failing) throw Exception('connection refused');
    return (conversations: [_row('c1'), _row('c2')], total: 2);
  }

  @override
  Future<({Map<String, int> pendingByConv, Map<String, int> filesByConv})>
      conversationMeta() async =>
          (pendingByConv: const <String, int>{}, filesByConv: const <String, int>{});

  @override
  Future<void> prefetchSnapshots(List<String> ids) async {}

  @override
  Future<void> writeCachedList({
    required List<ConversationSummary> conversations,
    required Map<String, int> pendingByConv,
    required Map<String, int> filesByConv,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group('DataState.dataOrPrevious', () {
    test('unwraps success, loading-previous and failure-previous', () {
      const data = 'rows';
      expect(const DataSuccess<String>(data).dataOrPrevious, data);
      expect(
        const DataLoading<String>(previous: data).dataOrPrevious,
        data,
      );
      expect(
        const DataFailure<String>(message: 'x', previous: data).dataOrPrevious,
        data,
      );
      expect(const DataIdle<String>().dataOrPrevious, isNull);
    });

    test('dataOrNull stays strict — it means "current", not "anything"', () {
      // The two getters must not converge; plenty of call sites legitimately
      // want "is what I hold up to date?".
      expect(
        const DataFailure<String>(message: 'x', previous: 'rows').dataOrNull,
        isNull,
      );
    });
  });

  group('a backend that disappears mid-session', () {
    test('two consecutive failed refreshes keep the rows on screen', () async {
      final repo = _FlakyRepo();
      final cubit = ConversationsCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.data.dataOrNull?.conversations, hasLength(2));

      repo.failing = true;

      await cubit.load();
      expect(
        cubit.state.data.dataOrPrevious?.conversations,
        hasLength(2),
        reason: 'the first failure must carry the rows forward',
      );

      await cubit.load();
      expect(
        cubit.state.data.dataOrPrevious?.conversations,
        hasLength(2),
        reason: 'the SECOND failure is where the rows used to vanish — the '
            'handler read them back with `dataOrNull`, which reports null '
            'for the failure state the first one just emitted',
      );

      // And it must never have asked the view to paint a cold-open skeleton,
      // which is what actually blanked the screen.
      expect(cubit.state.data, isNot(isA<DataLoading<ConversationsData>>()));
    });

    test('recovers to fresh data once the backend returns', () async {
      final repo = _FlakyRepo();
      final cubit = ConversationsCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.load();
      repo.failing = true;
      await cubit.load();
      repo.failing = false;
      await cubit.load();

      expect(cubit.state.data, isA<DataSuccess<ConversationsData>>());
      expect(cubit.state.data.dataOrNull?.conversations, hasLength(2));
    });

    test('a genuinely cold open still shows the skeleton', () async {
      // The fix must not cost us the loading state when there really is
      // nothing to show.
      final repo = _FlakyRepo()..failing = true;
      final cubit = ConversationsCubit(repository: repo);
      addTearDown(cubit.close);

      final seen = <DataState<ConversationsData>>[];
      final sub = cubit.stream.listen((s) => seen.add(s.data));
      addTearDown(sub.cancel);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(
        seen.any((s) => s is DataLoading<ConversationsData>),
        isTrue,
        reason: 'no cached rows, so the skeleton is the right answer here',
      );
      expect(cubit.state.data, isA<DataFailure<ConversationsData>>());
    });
  });
}
