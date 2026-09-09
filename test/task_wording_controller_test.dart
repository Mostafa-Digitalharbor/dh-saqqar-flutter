// The "shall I structure this first?" offer and its docked card.
//
// The sequence guard is what this file exists for. A rewrite takes seconds,
// and during those seconds the user can type again, close the card, or leave.
// Each has to make the in-flight answer land nowhere — and none of it was
// reachable from a test while the state lived as six fields on
// `_ChatScreenState` and the handlers sat 1,400 lines below them.
//
// Getting it wrong reopens a card the user dismissed, or fills it with the
// answer to their previous sentence. Both read as the app acting on its own.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/features/chat/data/prompt_memory_api.dart';
import 'package:saqqar_app/features/chat/view_model/task_wording_controller.dart';

void main() {
  group('the docked card', () {
    test('opens in its loading state before the draft exists', () async {
      // A tap that produces nothing visible reads as a tap that missed.
      final api = _FakeApi(hold: true);
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final pending = c.prepare('close the books for last quarter', lang: 'en');

      expect(c.isCardOpen, isTrue);
      expect(c.loading, isTrue);
      expect(c.draft, isEmpty);

      api.release(_result('Close the books for Q3.'));
      await pending;

      expect(c.loading, isFalse);
      expect(c.draft, 'Close the books for Q3.');
    });

    test('a missing draft falls back to the rough text, not to an error',
        () async {
      // The server can rank past tasks without producing a rewrite. The user
      // still has something to edit and send.
      final api = _FakeApi()..result = _result(null);
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final outcome = await c.prepare('reconcile the bank feed', lang: 'en');

      expect(outcome, isA<TaskWordingReady>());
      expect(c.draft, 'reconcile the bank feed');
    });

    test('empty input opens nothing', () async {
      final api = _FakeApi();
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final outcome = await c.prepare('   ', lang: 'en');

      expect(outcome, isA<TaskWordingStale>());
      expect(c.isCardOpen, isFalse);
      expect(api.calls, 0);
    });

    test('a failure closes the card and hands the raw error up', () async {
      // Raw, so the screen can map it through `ApiErrorMapper` in the user's
      // language — which is why this class does not stringify it here.
      final api = _FakeApi()..error = StateError('boom');
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final outcome = await c.prepare('run payroll', lang: 'en');

      expect(outcome, isA<TaskWordingFailed>());
      expect((outcome as TaskWordingFailed).error, isA<StateError>());
      expect(c.isCardOpen, isFalse);
      expect(c.loading, isFalse);
    });

    test('the conversation id rides along, and is null for a new chat',
        () async {
      final api = _FakeApi();
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      await c.prepare('x', lang: 'ar', conversationId: 'conv-7');
      expect(api.lastConversationId, 'conv-7');
      expect(api.lastLang, 'ar');

      await c.prepare('y', lang: 'en');
      expect(api.lastConversationId, isNull);
    });
  });

  group('the staleness guard', () {
    test('closing the card discards the answer that was already in flight',
        () async {
      // The user dismissed it. Nothing may re-open it seconds later.
      final api = _FakeApi(hold: true);
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final pending = c.prepare('a long task', lang: 'en');
      c.close();
      api.release(_result('a rewritten task'));

      expect(await pending, isA<TaskWordingStale>());
      expect(c.isCardOpen, isFalse);
      expect(c.draft, isEmpty);
    });

    test('a newer request wins, and the older one lands nowhere', () async {
      // Otherwise the card fills with the answer to the previous sentence.
      final first = _FakeApi(hold: true);
      var api = first;
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final older = c.prepare('first phrasing', lang: 'en');

      final second = _FakeApi()..result = _result('SECOND');
      api = second;
      final newer = await c.prepare('second phrasing', lang: 'en');

      expect(newer, isA<TaskWordingReady>());
      expect(c.draft, 'SECOND');

      first.release(_result('FIRST'));
      expect(await older, isA<TaskWordingStale>());
      expect(c.draft, 'SECOND', reason: 'the late answer must not overwrite');
    });

    test('a failure that arrives after the card moved on stays silent',
        () async {
      // A `TaskWordingFailed` here would toast an error for a request the
      // user has already replaced.
      final slow = _FakeApi(hold: true);
      var api = slow;
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final older = c.prepare('first', lang: 'en');

      final fresh = _FakeApi()..result = _result('OK');
      api = fresh;
      await c.prepare('second', lang: 'en');

      slow.releaseError(StateError('too late'));

      expect(await older, isA<TaskWordingStale>());
      expect(c.draft, 'OK');
    });

    test('an answer arriving after disposal is dropped', () async {
      final api = _FakeApi(hold: true);
      final c = TaskWordingController(api: () => api);

      final pending = c.prepare('leaving now', lang: 'en');
      c.dispose();
      api.release(_result('too late'));

      expect(await pending, isA<TaskWordingStale>());
    });
  });

  group('the offer bar', () {
    test('offers a long task and stays quiet for a short one', () {
      final c = TaskWordingController(api: _FakeApi.new);
      addTearDown(c.dispose);

      c.refreshHint(_longPrompt, enabled: true);
      expect(c.hint, isNotNull);

      c.refreshHint('hi', enabled: true);
      expect(c.hint, isNull);
    });

    test('is silent when task prep is off', () {
      // Someone who turned the toggle off has said they do not want to be
      // asked. Same setting as the send path, on purpose.
      final c = TaskWordingController(api: _FakeApi.new);
      addTearDown(c.dispose);

      c.refreshHint(_longPrompt, enabled: false);

      expect(c.hint, isNull);
    });

    test('turning task prep off retracts an offer already on screen', () {
      final c = TaskWordingController(api: _FakeApi.new);
      addTearDown(c.dispose);

      c.refreshHint(_longPrompt, enabled: true);
      expect(c.hint, isNotNull);

      c.refreshHint(_longPrompt, enabled: false);
      expect(c.hint, isNull);
    });

    test('a dismissal is per-text, not forever', () {
      // Rewriting the message brings the offer back — that is what makes the
      // bar an offer rather than a nag.
      final c = TaskWordingController(api: _FakeApi.new);
      addTearDown(c.dispose);

      c.refreshHint(_longPrompt, enabled: true);
      c.dismissHint(_longPrompt);
      expect(c.hint, isNull);

      c.refreshHint(_longPrompt, enabled: true);
      expect(c.hint, isNull, reason: 'same text, still dismissed');

      c.refreshHint('$_longPrompt and also reconcile the petty cash account',
          enabled: true);
      expect(c.hint, isNotNull, reason: 'rewritten, so ask again');
    });

    test('an open card suppresses the offer — the card IS the answer',
        () async {
      final api = _FakeApi(hold: true);
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      final pending = c.prepare('something else entirely', lang: 'en');
      c.refreshHint(_longPrompt, enabled: true);

      expect(c.hint, isNull);
      api.release(_result('x'));
      await pending;
    });

    test('opening a card for a text also marks it acted on', () async {
      final api = _FakeApi()..result = _result('structured');
      final c = TaskWordingController(api: () => api);
      addTearDown(c.dispose);

      await c.prepare(_longPrompt, lang: 'en');
      c.close();
      c.refreshHint(_longPrompt, enabled: true);

      expect(c.hint, isNull,
          reason: 'it has been structured once; do not offer again');
    });

    test('markActedOn silences the offer without a repaint', () {
      final c = TaskWordingController(api: _FakeApi.new);
      addTearDown(c.dispose);
      var notifications = 0;
      c.addListener(() => notifications++);

      c.markActedOn(_longPrompt);
      expect(notifications, 0);

      c.refreshHint(_longPrompt, enabled: true);
      expect(c.hint, isNull);
    });

    test('an unchanged offer does not repaint', () {
      final c = TaskWordingController(api: _FakeApi.new);
      addTearDown(c.dispose);
      c.refreshHint(_longPrompt, enabled: true);

      var notifications = 0;
      c.addListener(() => notifications++);
      c.refreshHint(_longPrompt, enabled: true);

      expect(notifications, 0, reason: 'this runs on every keystroke');
    });
  });
}

/// Long enough for `looksLikeLongTaskPrompt` to treat it as a task.
const _longPrompt =
    'please close the books for last quarter and send me the summary report '
    'with the outstanding invoices grouped by customer';

PromptMemoryResult _result(String? template) => PromptMemoryResult(
      draft: template == null
          ? null
          : PromptMemoryItem(
              id: 'draft-1',
              source: 'draft',
              title: '',
              description: '',
              promptTemplate: template,
            ),
      matches: const [],
    );

/// One canned answer, optionally held open so a second request can overtake
/// it.
class _FakeApi implements PromptMemoryApi {
  _FakeApi({this.hold = false});

  final bool hold;
  PromptMemoryResult result = PromptMemoryResult.empty;
  Object? error;

  int calls = 0;
  String? lastLang;
  String? lastConversationId;

  final _gate = Completer<void>();

  @override
  Future<PromptMemoryResult> fetch({
    required String lang,
    String query = '',
    String? conversationId,
    int limit = 8,
  }) async {
    calls++;
    lastLang = lang;
    lastConversationId = conversationId;
    if (hold) await _gate.future;
    if (error != null) throw error!;
    return result;
  }

  void release(PromptMemoryResult r) {
    result = r;
    if (!_gate.isCompleted) _gate.complete();
  }

  void releaseError(Object e) {
    error = e;
    if (!_gate.isCompleted) _gate.complete();
  }
}
