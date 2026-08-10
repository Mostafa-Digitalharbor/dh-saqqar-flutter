// §3 — the Task-prep preference, end to end through the state layer.
//
// `task_prep_send_body_test` pins the HTTP body. This pins everything above
// it: the cubit that owns the preference, and the ChatCubit → repository hop
// that carries the user's choice to the API. A default that silently flips,
// or a `taskPrep` argument dropped between cubit and repo, produces a build
// that compiles, passes every widget test, and quietly ignores the toggle.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/task_prep_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';

/// Records what `sendMessage` was called with.
class _RecordingRepo implements ConversationsRepository {
  final calls = <({String content, bool taskPrep})>[];

  @override
  Future<ConversationSnapshot> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachmentIds = const [],
    String? model,
    bool taskPrep = true,
  }) async {
    calls.add((content: content, taskPrep: taskPrep));
    return ConversationSnapshot.fromJson(const {
      'conversation': {
        'id': 'c1',
        'title': 'T',
        'auto_approve': false,
        'is_running': false,
        'stop_requested': false,
      },
      'messages': <Map<String, dynamic>>[],
    });
  }

  ConversationSnapshot get _empty => ConversationSnapshot.fromJson(const {
        'conversation': {
          'id': 'c1',
          'title': 'T',
          'auto_approve': false,
          'is_running': false,
          'stop_requested': false,
        },
        'messages': <Map<String, dynamic>>[],
      });

  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async =>
      _empty;

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
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;

  @override
  void cacheSnapshot(String id, ConversationSnapshot snapshot) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TaskPrepCubit', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to ON, matching the server default', () async {
      // The server reads `payload.get("task_prep", True)`. Seeding false here
      // would silently change behaviour for every existing user on upgrade.
      final prefs = await SharedPreferences.getInstance();

      expect(TaskPrepCubit(prefs).state, isTrue);
    });

    test('reads a stored preference back', () async {
      SharedPreferences.setMockInitialValues({
        UiStrings.taskPrepPreferenceKey: false,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(TaskPrepCubit(prefs).state, isFalse);
    });

    test('persists a flip so it survives a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = TaskPrepCubit(prefs);

      await cubit.set(false);

      expect(cubit.state, isFalse);
      expect(prefs.getBool(UiStrings.taskPrepPreferenceKey), isFalse);
      // A fresh cubit over the same prefs — i.e. the next app launch.
      expect(TaskPrepCubit(prefs).state, isFalse);
    });

    test('setting the same value emits nothing', () async {
      // The chat screen can call this from a rebuild; at a 1.5 s poll cadence
      // a non-idempotent `set` would rewrite the prefs file all day.
      final prefs = await SharedPreferences.getInstance();
      final cubit = TaskPrepCubit(prefs);
      final emitted = <bool>[];
      cubit.stream.listen(emitted.add);

      await cubit.set(true); // already true
      await cubit.set(false);
      await cubit.set(false);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [false]);
    });

    test('toggle flips', () async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = TaskPrepCubit(prefs);

      await cubit.toggle();
      expect(cubit.state, isFalse);
      await cubit.toggle();
      expect(cubit.state, isTrue);
    });
  });

  group('ChatCubit carries the choice to the repository', () {
    test('forwards taskPrep verbatim, both ways', () async {
      for (final value in [true, false]) {
        final repo = _RecordingRepo();
        final cubit = ChatCubit(conversationId: 'c1', repository: repo);

        await cubit.sendMessage(content: 'hello', taskPrep: value);

        expect(repo.calls.single.taskPrep, value, reason: 'taskPrep=$value');
        expect(repo.calls.single.content, 'hello');
        await cubit.close();
      }
    });

    test('defaults to true when the caller omits it', () async {
      final repo = _RecordingRepo();
      final cubit = ChatCubit(conversationId: 'c1', repository: repo);

      await cubit.sendMessage(content: 'hello');

      expect(repo.calls.single.taskPrep, isTrue);
      await cubit.close();
    });
  });

  // The product decision (2026-08-10) is that Task prep becomes
  // per-conversation, mirroring `auto_approve`. The client reads the field
  // NOW, ahead of the server, so the day it appears in the snapshot the
  // toggle starts syncing on builds already in users' hands — no release.
  //
  // Which makes the absent case the one that must be pinned hardest: every
  // deployment today omits the field, so a parse that turned "absent" into
  // `false` would silently disable Task prep for every user of every build.
  group('conversation.task_prep — reading ahead of the server', () {
    Conversation parse(Map<String, dynamic> extra) =>
        ConversationSnapshot.fromJson({
          'conversation': {
            'id': 'c1',
            'title': 'T',
            'auto_approve': false,
            'is_running': false,
            'stop_requested': false,
            ...extra,
          },
          'messages': const <Map<String, dynamic>>[],
        }).conversation;

    test('absent stays null — the server owns nothing, so the app decides',
        () {
      expect(
        parse(const {}).taskPrep,
        isNull,
        reason: 'absent must NOT collapse to false — that would turn Task '
            'prep off for everyone on every build shipped so far',
      );
    });

    test('an explicit value is read, both ways', () {
      expect(parse(const {'task_prep': true}).taskPrep, isTrue);
      expect(parse(const {'task_prep': false}).taskPrep, isFalse);
    });

    test('a non-boolean reads as absent rather than throwing', () {
      // This parse sits in front of the whole snapshot. A cast would take out
      // the transcript, the plan and the quota state over one odd field.
      expect(parse(const {'task_prep': 'yes'}).taskPrep, isNull);
      expect(parse(const {'task_prep': 1}).taskPrep, isNull);
      expect(parse(const {'task_prep': null}).taskPrep, isNull);
    });

    test('copyWith preserves it, and equality accounts for it', () {
      final off = parse(const {'task_prep': false});

      expect(off.copyWith(title: 'renamed').taskPrep, isFalse);
      expect(off.copyWith(taskPrep: true).taskPrep, isTrue);
      // Equatable must see the field, or a poll that only changes task_prep
      // would be treated as "no change" and never repaint the switch.
      expect(off == parse(const {'task_prep': true}), isFalse);
    });
  });
}
