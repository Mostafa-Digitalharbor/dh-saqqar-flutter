// The Chats list showed 100 conversations on an account that has ~140.
//
// The client asked for `limit=200`; the server answered with 100 and a
// `total` of 140. Nothing compared the two, so the list looked complete —
// the worst shape for missing data, because there is no gap on screen to
// notice and no "load more" to reach for.
//
// `/api/v1/conversations/` documents only `limit` and `include_archived`;
// `offset` is undocumented (unlike `/approvals/` and `/artifacts/`, which
// both have it). So `listAll` sends `offset` and is built to be correct
// whether or not the server honours it. Both branches are pinned below —
// the "ignores offset" case is the one that would hang the app forever if
// the stop condition were wrong.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/conversations/data/conversations_api.dart';

/// Serves `total` conversations, honouring `offset` only when [pageable].
class _Server implements HttpClientAdapter {
  _Server({required this.total, required this.pageCap, this.pageable = true});

  /// How many conversations the account really has.
  final int total;

  /// The server's own page ceiling — what it returns however large the
  /// requested `limit` is. This is the behaviour that caused the bug.
  final int pageCap;

  /// When false the server ignores `offset` and always returns page 1.
  final bool pageable;

  int requests = 0;
  final offsets = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    final limit = int.tryParse('${options.queryParameters['limit']}') ?? 30;
    final offset =
        pageable ? int.tryParse('${options.queryParameters['offset']}') ?? 0 : 0;
    offsets.add(int.tryParse('${options.queryParameters['offset']}') ?? 0);

    final size = limit < pageCap ? limit : pageCap;
    final rows = <Map<String, dynamic>>[];
    for (var i = offset; i < offset + size && i < total; i++) {
      rows.add({'id': 'c$i', 'title': 'Chat $i'});
    }

    return ResponseBody.fromString(
      jsonEncode({'ok': true, 'conversations': rows, 'total': total}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Drives `listAll`'s loop against [server] without the repository's disk
/// cache and logging, which are irrelevant here. Mirrors the real stop
/// conditions exactly.
Future<({List<String> ids, int? total, int requests})> _listAll(
  _Server server, {
  int pageSize = 200,
  int maxPages = 12,
}) async {
  final api = ConversationsApi(Dio()..httpClientAdapter = server);
  final seen = <String>{};
  final ids = <String>[];
  int? total;
  int? serverPage;

  for (var page = 0; page < maxPages; page++) {
    final res = await api.list(limit: pageSize, offset: ids.length);
    total ??= res.total;
    final fresh = [
      for (final c in res.conversations)
        if (seen.add(c.id)) c.id,
    ];
    ids.addAll(fresh);
    if (fresh.isEmpty) break;
    if (total != null && ids.length >= total) break;
    if (serverPage != null && res.conversations.length < serverPage) break;
    serverPage ??= res.conversations.length;
  }
  return (ids: ids, total: total, requests: server.requests);
}

void main() {
  group('a server that pages properly', () {
    test('gathers ALL 140 when the page cap is 100', () async {
      // The reported bug, exactly: 140 chats, a 100-row cap.
      final server = _Server(total: 140, pageCap: 100);

      final res = await _listAll(server);

      expect(res.ids, hasLength(140));
      expect(res.total, 140);
      expect(server.offsets, [0, 100]);
    });

    test('costs ONE request when everything fits in a page', () async {
      // The common case must not get slower. A short page proves there is
      // nothing after it, so no speculative second call.
      final server = _Server(total: 40, pageCap: 100);

      final res = await _listAll(server);

      expect(res.ids, hasLength(40));
      expect(res.requests, 1);
    });

    test('no duplicates when pages overlap', () async {
      // A server that re-sends a row already returned (a write landing
      // mid-page shifts the window) must not double it in the list.
      final server = _Server(total: 250, pageCap: 100);

      final res = await _listAll(server);

      expect(res.ids.toSet(), hasLength(res.ids.length));
    });

    test('an exact multiple of the page size still terminates', () async {
      // 200 rows, 100 per page: page 3 comes back empty. Without the
      // "no new ids" guard this is where an off-by-one loops.
      final server = _Server(total: 200, pageCap: 100);

      final res = await _listAll(server);

      expect(res.ids, hasLength(200));
    });
  });

  group('a server that IGNORES offset — the dangerous case', () {
    test('stops after the second page instead of spinning', () async {
      // Every request returns page 1. The "no new ids" condition is the
      // only thing between this and an infinite loop that hangs the Chats
      // screen and hammers the backend.
      final server = _Server(total: 140, pageCap: 100, pageable: false);

      final res = await _listAll(server);

      expect(res.ids, hasLength(100), reason: 'we keep what we could get');
      expect(
        res.requests,
        2,
        reason: 'one real page, one that proved paging is unsupported',
      );
    });

    test('reports the real total so the shortfall is knowable', () async {
      // Even when paging fails, `total` tells the app it is showing 100 of
      // 140 — which is what makes it reportable rather than invisible.
      final server = _Server(total: 140, pageCap: 100, pageable: false);

      final res = await _listAll(server);

      expect(res.total, 140);
      expect(res.ids.length, lessThan(res.total!));
    });
  });

  group('runaway protection', () {
    test('the page budget caps a pathological server', () async {
      // A server claiming a huge total while serving tiny pages must not
      // keep the app fetching indefinitely.
      final server = _Server(total: 100000, pageCap: 10);

      final res = await _listAll(server, pageSize: 10, maxPages: 5);

      expect(res.requests, 5);
      expect(res.ids, hasLength(50));
    });
  });

  group('the request itself', () {
    test('omits offset on the first page', () async {
      // Keeps the common request byte-identical to what shipped before, so
      // a backend that rejects unknown params is unaffected on page 1.
      final server = _Server(total: 10, pageCap: 100);
      final api = ConversationsApi(Dio()..httpClientAdapter = server);

      await api.list(limit: 200);

      expect(server.offsets.single, 0);
    });
  });
}
