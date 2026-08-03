// Backwards paging through a chat, via the server's `?before=` cursor.
//
// This replaced a strategy that re-fetched the whole conversation with an
// ever-larger `?limit=` and swapped the transcript wholesale. That was wrong
// twice over: every step re-downloaded what was already on screen, and
// because `?limit=` is capped at 500 rows server-side, the "did we get a full
// page?" test that decided *is there more history* answered **no** the moment
// the cap was hit. On the 5,340-message conversation this was verified
// against, 4,840 messages were unreachable from the app.
//
// The cases below are the ones that make cursor paging either work or quietly
// corrupt the transcript.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

final _t0 = DateTime.utc(2026, 7, 25, 12);

Message _msg(String id, {int minutesAgo = 0}) => Message(
      id: id,
      role: MessageRole.user,
      content: 'message $id',
      createdAt: _t0.subtract(Duration(minutes: minutesAgo)),
    );

Conversation _conv() => Conversation(
      id: 'c1',
      title: 'Q3 close',
      createdAt: _t0,
      updatedAt: _t0,
      autoApprove: false,
      deepThink: false,
      isRunning: false,
      stopRequested: false,
    );

ConversationSnapshot _snap({
  required List<Message> messages,
  String? oldestCursor,
  bool hasMoreBefore = false,
  bool delta = false,
}) =>
    ConversationSnapshot(
      conversation: _conv(),
      messages: messages,
      delta: delta,
      cursor: _t0,
      oldestCursor: oldestCursor,
      hasMoreBefore: hasMoreBefore,
    );

/// Serves a scripted newest page, then scripted older pages keyed by the
/// `before` cursor it is asked for. Records every cursor it saw.
class _PagingRepo implements ConversationsRepository {
  _PagingRepo({required this.newest, this.olderByCursor = const {}});

  final ConversationSnapshot newest;
  final Map<String, ConversationSnapshot> olderByCursor;

  final List<String?> beforeSeen = [];
  final List<int?> limitsSeen = [];

  /// Cursor whose fetch should throw, for the failure cases.
  String? failOn;

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async {
    beforeSeen.add(before);
    limitsSeen.add(limit);
    if (before != null && before == failOn) {
      throw Exception('connection refused');
    }
    if (before != null) return olderByCursor[before] ?? _snap(messages: const []);
    return newest;
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

List<String> _ids(ChatCubit c) =>
    c.state.data.dataOrNull!.messages.map((m) => m.id).toList();

void main() {
  group('paging backwards', () {
    test('sends the server cursor and PREPENDS the page', () async {
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m3', minutesAgo: 3), _msg('m4', minutesAgo: 2)],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          'CUR-A': _snap(
            messages: [_msg('m1', minutesAgo: 9), _msg('m2', minutesAgo: 8)],
            oldestCursor: 'CUR-B',
            hasMoreBefore: true,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      expect(_ids(cubit), ['m3', 'm4']);
      expect(cubit.state.hasMoreOlder, isTrue);

      await cubit.loadOlder();

      expect(repo.beforeSeen, contains('CUR-A'));
      expect(
        _ids(cubit),
        ['m1', 'm2', 'm3', 'm4'],
        reason: 'the older page belongs at the FRONT — appending it would put '
            'the start of the conversation after its end',
      );
    });

    test('advances the cursor so the next page is a different one', () async {
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m5')],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          'CUR-A': _snap(
            messages: [_msg('m3'), _msg('m4')],
            oldestCursor: 'CUR-B',
            hasMoreBefore: true,
          ),
          'CUR-B': _snap(
            messages: [_msg('m1'), _msg('m2')],
            oldestCursor: 'CUR-C',
            hasMoreBefore: false,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.loadOlder();
      await cubit.loadOlder();

      expect(repo.beforeSeen.whereType<String>().toList(), ['CUR-A', 'CUR-B']);
      expect(_ids(cubit), ['m1', 'm2', 'm3', 'm4', 'm5']);
      expect(
        cubit.state.hasMoreOlder,
        isFalse,
        reason: 'the server said has_more_before:false — stop asking',
      );
    });

    test('fetches ONE page per step, not the whole transcript', () async {
      // The regression this replaced grew `limit` on every step.
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m9')],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          'CUR-A': _snap(
            messages: [_msg('m8')],
            oldestCursor: 'CUR-B',
            hasMoreBefore: true,
          ),
          'CUR-B': _snap(
            messages: [_msg('m7')],
            oldestCursor: 'CUR-C',
            hasMoreBefore: true,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.loadOlder();
      await cubit.loadOlder();

      final pagedLimits = [
        for (var i = 0; i < repo.beforeSeen.length; i++)
          if (repo.beforeSeen[i] != null) repo.limitsSeen[i],
      ];
      expect(
        pagedLimits.toSet(),
        hasLength(1),
        reason: 'every backwards page must request the SAME fixed size; a '
            'growing limit is what re-downloaded the transcript and hit the '
            '500-row server cap',
      );
    });
  });

  group('termination', () {
    test('an empty page stops paging even if the flag says otherwise', () async {
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m1')],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          // Server contradicts itself: nothing returned, but "more before".
          'CUR-A': _snap(
            messages: const [],
            oldestCursor: 'CUR-B',
            hasMoreBefore: true,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.loadOlder();

      expect(
        cubit.state.hasMoreOlder,
        isFalse,
        reason: 'trusting the flag over an empty page is an infinite loop',
      );
      expect(_ids(cubit), ['m1']);
    });

    test('a server with no cursor disables paging instead of guessing',
        () async {
      final repo = _PagingRepo(
        newest: _snap(messages: [_msg('m1'), _msg('m2')]),
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      // No `oldest_cursor` → the old length heuristic decides, and 2 < 40
      // means "that's the whole transcript".
      expect(cubit.state.hasMoreOlder, isFalse);
    });

    test('duplicate rows on a cursor boundary are not re-inserted', () async {
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m2'), _msg('m3')],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          // m2 comes back again — the cursor sat on it.
          'CUR-A': _snap(
            messages: [_msg('m1'), _msg('m2')],
            oldestCursor: 'CUR-B',
            hasMoreBefore: false,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.loadOlder();

      expect(_ids(cubit), ['m1', 'm2', 'm3']);
    });
  });

  group('polling must not rewind the paging position', () {
    test('a poll keeps the cursor the user has paged back to', () async {
      // The poll asks for the DEFAULT window, so its `oldest_cursor` points at
      // the newest page. Adopting it would send the next "load earlier" back
      // to fetch history already on screen — an invisible infinite loop.
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m3')],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          'CUR-A': _snap(
            messages: [_msg('m1'), _msg('m2')],
            oldestCursor: 'CUR-B',
            hasMoreBefore: true,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.loadOlder();
      expect(cubit.state.data.dataOrNull!.oldestCursor, 'CUR-B');

      // A poll lands, carrying the newest window's cursor.
      await cubit.refresh();

      expect(
        cubit.state.data.dataOrNull!.oldestCursor,
        'CUR-B',
        reason: 'the poll must not rewind us to CUR-A',
      );
      expect(
        _ids(cubit),
        containsAll(['m1', 'm2']),
        reason: 'and must not drop the history already paged in',
      );
    });

    test('a re-load() does not throw away pages already scrolled back through',
        () async {
      // `load()` asks for the newest `_initialLimit` rows. Adopting that reply
      // verbatim is correct on a cold open and destructive afterwards: once
      // the user has paged backwards, the reply is a SHORTER window than what
      // the cubit holds. Replacing dropped the history and reset the cursor to
      // the newest page, so the next backwards step re-requested the page it
      // had just discarded, deduped it against itself, and stood still.
      //
      // The symptom is silent and easy to misread as "the server has no more
      // history": no error, no spinner stuck on, the transcript simply stops
      // growing. On a live 857-message chat every automatic page reported the
      // same `cur=40 page=100 older=100` and the visible count sat at 52
      // across six consecutive fetches, with the same `?before=` cursor sent
      // every time.
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m3', minutesAgo: 3), _msg('m4', minutesAgo: 2)],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        olderByCursor: {
          'CUR-A': _snap(
            messages: [_msg('m1', minutesAgo: 9), _msg('m2', minutesAgo: 8)],
            oldestCursor: 'CUR-B',
            hasMoreBefore: true,
          ),
          'CUR-B': _snap(
            messages: [_msg('m0', minutesAgo: 20)],
            oldestCursor: 'CUR-C',
            hasMoreBefore: true,
          ),
        },
      );
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await cubit.loadOlder();
      expect(_ids(cubit), ['m1', 'm2', 'm3', 'm4']);

      // Anything that re-runs the bounded initial fetch: a pull-to-refresh,
      // a reconnect, the screen re-attaching to the cubit.
      await cubit.load();

      expect(
        _ids(cubit),
        ['m1', 'm2', 'm3', 'm4'],
        reason: 'the newest-window reply is shorter than what we hold — it '
            'must not replace the transcript',
      );
      expect(
        cubit.state.data.dataOrNull!.oldestCursor,
        'CUR-B',
        reason: 'and it must not rewind the paging cursor to the newest page',
      );

      // The decisive part: the NEXT step has to keep moving backwards rather
      // than re-fetching the page it already holds.
      repo.beforeSeen.clear();
      await cubit.loadOlder();

      expect(repo.beforeSeen, ['CUR-B']);
      expect(_ids(cubit), ['m0', 'm1', 'm2', 'm3', 'm4']);
    });
  });

  group('page-ahead', () {
    // Paging on demand means every step costs a round trip the user watches:
    // they scroll to the top, the transcript stops, a spinner runs for as long
    // as the request takes, and only then do rows appear. Fetching the next
    // page while they are still reading the current one turns the same scroll
    // into a window-widen with no network in it.
    _PagingRepo threePageRepo() => _PagingRepo(
          newest: _snap(
            messages: [_msg('m3', minutesAgo: 3), _msg('m4', minutesAgo: 2)],
            oldestCursor: 'CUR-A',
            hasMoreBefore: true,
          ),
          olderByCursor: {
            'CUR-A': _snap(
              messages: [_msg('m1', minutesAgo: 9), _msg('m2', minutesAgo: 8)],
              oldestCursor: 'CUR-B',
              hasMoreBefore: true,
            ),
            'CUR-B': _snap(
              messages: [_msg('m0', minutesAgo: 20)],
              oldestCursor: 'CUR-C',
              hasMoreBefore: true,
            ),
          },
        );

    test('opening a chat banks the next page without being asked', () async {
      final repo = threePageRepo();
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      // The page-ahead is deliberately not awaited by `load()` — the first
      // paint must not wait on it. Let the microtask settle.
      await Future<void>.delayed(Duration.zero);

      expect(repo.beforeSeen, contains('CUR-A'));
      expect(
        _ids(cubit),
        ['m1', 'm2', 'm3', 'm4'],
        reason: 'the banked page is merged, so the view can reveal it with no '
            'network — it is not parked in a side buffer',
      );
    });

    test('the page-ahead is silent — no spinner, no error surfaced', () async {
      final repo = _PagingRepo(
        newest: _snap(
          messages: [_msg('m3')],
          oldestCursor: 'CUR-A',
          hasMoreBefore: true,
        ),
        // No entry for CUR-A and `failOn` set below: the fetch throws.
      )..failOn = 'CUR-A';
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isLoadingOlder, isFalse);
      expect(
        cubit.state.actionFailure,
        isNull,
        reason: 'nobody asked for this page; a toast about it would be noise '
            'about work the user never requested',
      );
      expect(
        cubit.state.hasMoreOlder,
        isTrue,
        reason: 'a failed page-ahead must not be read as "no more history" — '
            'the next user-driven step has to be allowed to try',
      );
    });

    test('a scroll that lands mid-page-ahead rides it, it does not double-fetch',
        () async {
      final repo = threePageRepo();
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);
      addTearDown(() {
        cubit.pause();
        return cubit.close();
      });

      await cubit.load();
      // Settle the page-ahead `load()` starts by riding it to completion, so
      // what follows measures one clean round and not a race with the open.
      await cubit.prefetchOlder();
      repo.beforeSeen.clear();

      // Both started before either resolves — the shape of a user scrolling
      // into a page that is already on the wire.
      final prefetch = cubit.prefetchOlder();
      final user = cubit.loadOlder();
      await Future.wait([prefetch, user]);

      expect(
        repo.beforeSeen,
        ['CUR-B'],
        reason: 'one cursor, one request — two in-flight fetches from the same '
            'position would both dedupe to nothing',
      );
      expect(_ids(cubit), ['m0', 'm1', 'm2', 'm3', 'm4']);
    });
  });
}
