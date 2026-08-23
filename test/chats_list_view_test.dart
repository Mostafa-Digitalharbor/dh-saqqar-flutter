// The Chats list used to be derived by three helper methods that the screen
// ALSO passed down to its body as callbacks. Both layers called them, so the
// same conversations were walked five times per build — and a keystroke in
// the search box is a build. Worse, the header's row count and the rendered
// rows were two independent filter passes: nothing but a reviewer reading
// both call sites kept them agreeing.
//
// `ChatsListView` is that derivation as one object, produced in one pass.
// These tests pin the behaviour it has to preserve — including the two
// asymmetries that look like bugs until you know why they are there.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/view_model/chats_list_view.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_state.dart';

final _now = DateTime.now();

ConversationSummary _c(
  String id, {
  String title = '',
  String preview = '',
  bool archived = false,
  Duration age = Duration.zero,
}) =>
    ConversationSummary(
      id: id,
      title: title.isEmpty ? 'Conversation $id' : title,
      createdAt: _now.subtract(age),
      updatedAt: _now.subtract(age),
      isArchived: archived,
      messageCount: 1,
      lastMessagePreview: preview,
    );

ConversationsData _data(
  List<ConversationSummary> rows, {
  Map<String, int> pending = const {},
  Set<String> pinned = const {},
}) =>
    ConversationsData(
      conversations: rows,
      pendingByConv: pending,
      pinnedIds: pinned,
    );

void main() {
  group('slicing', () {
    test('splits archived rows out of the active list', () {
      final view = ChatsListView.of(_data([
        _c('1'),
        _c('2', archived: true),
        _c('3'),
      ]));

      expect([for (final c in view.active) c.id], ['1', '3']);
      expect([for (final c in view.archived) c.id], ['2']);
    });

    test('honours the pinned ordering the data exposes', () {
      final view = ChatsListView.of(
        _data([_c('1'), _c('2'), _c('3')], pinned: {'3'}),
      );

      expect(view.active.first.id, '3');
    });
  });

  group('search', () {
    test('matches the title and the preview, case-insensitively', () {
      final rows = [
        _c('1', title: 'Q3 Invoice close'),
        _c('2', title: 'Bank feed', preview: 'Reconciled the INVOICE batch'),
        _c('3', title: 'Payroll'),
      ];

      final view = ChatsListView.of(_data(rows), query: 'invoice');

      expect([for (final c in view.active) c.id], ['1', '2']);
    });

    test('an empty or whitespace query matches everything', () {
      final rows = [_c('1'), _c('2')];

      expect(ChatsListView.of(_data(rows), query: '').active, hasLength(2));
      expect(ChatsListView.of(_data(rows), query: '   ').active, hasLength(2));
    });

    test('cannot match by straddling the title/preview boundary', () {
      // The haystack joins the two fields with a newline precisely so this
      // does not match — otherwise a row titled "…invoice" sitting above a
      // preview starting "draft…" would answer a search for "invoice draft".
      final rows = [_c('1', title: 'Q3 invoice', preview: 'draft sent')];

      expect(ChatsListView.of(_data(rows), query: 'invoice draft').active,
          isEmpty);
      expect(ChatsListView.of(_data(rows), query: 'invoice').active,
          hasLength(1));
    });

    test('searches archived rows too', () {
      // Deliberate: a query should surface a match wherever it lives, so the
      // user does not have to remember whether they archived it.
      final rows = [
        _c('1', title: 'Payroll'),
        _c('2', title: 'Payroll 2025', archived: true),
      ];

      final view = ChatsListView.of(_data(rows), query: 'payroll');

      expect(view.active, hasLength(1));
      expect(view.archived, hasLength(1));
    });
  });

  group('triage modes', () {
    final rows = [
      _c('1'),
      _c('2'),
      _c('3', age: const Duration(days: 2)),
    ];
    final data = _data(rows, pending: const {'2': 3});

    test('all keeps every non-archived row', () {
      expect(ChatsListView.of(data, mode: ChatsFilterMode.all).active,
          hasLength(3));
    });

    test('pending keeps only rows with a pending approval', () {
      final view = ChatsListView.of(data, mode: ChatsFilterMode.pending);

      expect([for (final c in view.active) c.id], ['2']);
    });

    test('live keeps only recently-active rows', () {
      final view = ChatsListView.of(data, mode: ChatsFilterMode.live);

      expect([for (final c in view.active) c.id], ['1', '2']);
    });

    test('the triage chip does NOT filter the archived shelf', () {
      // The archived card is its own surface; scoping it by the active chip
      // would make rows vanish from a list the chip does not describe.
      final view = ChatsListView.of(
        _data([_c('1', archived: true)], pending: const {}),
        mode: ChatsFilterMode.pending,
      );

      expect(view.archived, hasLength(1));
    });
  });

  group('the pending badge', () {
    test('counts every non-archived conversation awaiting approval', () {
      final view = ChatsListView.of(_data(
        [_c('1'), _c('2'), _c('3', archived: true)],
        pending: const {'1': 1, '2': 2, '3': 5},
      ));

      expect(view.pendingCount, 2, reason: 'the archived row does not count');
    });

    test('does not shrink as the user types', () {
      // The badge answers "how much work is waiting", not "how much work
      // matches your search". Filtering it by the query made approvals look
      // like they were disappearing while the user typed.
      final data = _data(
        [_c('1', title: 'Payroll'), _c('2', title: 'Invoices')],
        pending: const {'1': 1, '2': 1},
      );

      expect(ChatsListView.of(data, query: 'payroll').pendingCount, 2);
      expect(ChatsListView.of(data, query: 'payroll').active, hasLength(1));
    });

    test('agrees with what tapping the chip reveals', () {
      // The count and the filtered rows come out of the same pass, so this
      // is true by construction — which is the point. It used to be two
      // separate derivations that merely happened to match.
      final data = _data(
        [_c('1'), _c('2'), _c('3')],
        pending: const {'1': 1, '3': 4},
      );

      final all = ChatsListView.of(data);
      final pendingOnly = ChatsListView.of(data, mode: ChatsFilterMode.pending);

      expect(all.pendingCount, pendingOnly.active.length);
    });
  });

  group('pagination', () {
    final data = _data([for (var i = 0; i < 25; i++) _c('$i')]);

    test('slices the active rows, not the archived ones', () {
      final view = ChatsListView.of(data);

      expect(view.page(0, 10), hasLength(10));
      expect(view.page(2, 10), hasLength(5));
    });

    test('a partial last page still counts as a page', () {
      expect(ChatsListView.of(data).pageCount(10), 3);
    });

    test('an exact multiple does not add an empty trailing page', () {
      final exact = _data([for (var i = 0; i < 20; i++) _c('$i')]);

      expect(ChatsListView.of(exact).pageCount(10), 2);
    });

    test('an empty list is one empty page, never zero', () {
      // Zero pages would make the pager render "Page 1 of 0".
      final view = ChatsListView.of(_data(const []));

      expect(view.pageCount(10), 1);
      expect(view.page(0, 10), isEmpty);
    });

    test('a page past the end is empty rather than an error', () {
      expect(ChatsListView.of(data).page(99, 10), isEmpty);
    });
  });

  group('the row search text is memoized', () {
    test('repeated queries against one row return a stable answer', () {
      // `_searchHaystack` is `late final`, so the first `matchesQuery` builds
      // it and every later call reuses it. If the memoization were ever
      // rewritten as an eager field on a const constructor this still holds —
      // what must not happen is the answer changing between calls.
      final row = _c('1', title: 'Q3 Invoice', preview: 'Sent to ACME');

      for (var i = 0; i < 3; i++) {
        expect(row.matchesQuery('invoice'), isTrue);
        expect(row.matchesQuery('acme'), isTrue);
        expect(row.matchesQuery('payroll'), isFalse);
        expect(row.matchesQuery(''), isTrue);
      }
    });
  });
}
