// The closing confirmation for `WEB_TASK_PREP_NOT_SYNCING_RESPONSE.md`.
//
// The web shipped its half on 2026-08-15: its Task-prep toggle now PATCHes
// `conversation.task_prep` on every flip and hydrates from it on every
// snapshot, exactly as `auto_approve` already did. Their note closes by asking
// for one thing back — a re-run of the §4.0 / §4.1 measurement, "server `true`
// → the app shows on; flip on one side → the other picks it up".
//
// That measurement was originally taken by hand against a browser and a device.
// It cannot be re-taken here, and it should not have to be: the interesting
// half is what MOBILE does when the stored value changes underneath it, and
// that is checkable deterministically.
//
// `task_prep_read_from_server_test.dart` already proves the precedence on FIRST
// paint. What it cannot show is convergence, because its cubit emits one
// snapshot and never moves — so a screen that read the server value once and
// then cached it locally would pass every test in that file and still ignore
// every flip made anywhere else. Convergence is the entire subject of the web's
// note, so it gets its own file.
//
// Three things are asserted, in the order a user would meet them:
//
//   1. A flip made elsewhere arrives on the next poll, with no reopen.
//   2. The message body sent AFTER that flip carries the server's value, not
//      the device default it superseded — the web's §3 says their per-message
//      key "now agrees with the stored value"; this is mobile agreeing too.
//   3. A conversation nobody has flipped stays `null`, and nothing mobile does
//      writes over it. The web's note leans on that null surviving.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/saqqar_features_cubit.dart';
import 'package:saqqar_app/features/chat/data/live_env_ack_service.dart';
import 'package:saqqar_app/features/chat/data/saqqar_tools_api.dart';
import 'package:saqqar_app/features/chat/data/transcribe_api.dart';
import 'package:saqqar_app/features/chat/view/chat_screen.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/view_model/chat_state.dart';
import 'package:saqqar_app/features/chat/view_model/task_prep_cubit.dart';
import 'package:saqqar_app/features/chat/widgets/chat_composer.dart';
import 'package:saqqar_app/features/conversations/data/attachment_models.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/share/intake/share_intake_service.dart';
import 'package:saqqar_app/features/support/data/voice_support_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';

import 'support/responsive_harness.dart';

// ── Fakes ────────────────────────────────────────────────────────────────

class _FakeRepo implements ConversationsRepository {
  @override
  ConversationSnapshot? cachedSnapshot(String id) => null;
  @override
  Future<ConversationSnapshot?> diskCachedSnapshot(String id) async => null;
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

class _FakeProjects implements ProjectsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeVault implements VaultRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeApprovals implements ApprovalsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeArtifacts implements ArtifactsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeOdoo implements OdooDataApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTranscribe implements TranscribeApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTools implements SaqqarToolsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeVoiceSupport implements VoiceSupportApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeUsage implements UsageApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A `ChatCubit` a test can push new snapshots through, standing in for the
/// poll that would deliver a change made on another client.
///
/// `load` is neutered so nothing else can move the state — every emit in these
/// tests is one the test asked for, which is what makes a failure mean
/// something.
class _PollableChatCubit extends ChatCubit {
  _PollableChatCubit(ConversationSnapshot initial)
      : super(conversationId: 'c1', repository: _FakeRepo()) {
    emit(ChatState(data: DataSuccess(initial)));
  }

  /// Stands in for "the web flipped it, and our next poll brought it back".
  void deliverPoll(ConversationSnapshot snapshot) {
    emit(ChatState(data: DataSuccess(snapshot)));
  }

  @override
  Future<void> load({bool force = false}) async {}
}

class _SeededFeaturesCubit extends SaqqarFeaturesCubit {
  _SeededFeaturesCubit() : super(_FakeUsage()) {
    emit(SaqqarFeatures.fromJson(const {'task_prep': true}));
  }
  @override
  Future<void> ensureLoaded({bool force = false}) async {}
}

class _SeededPlanCubit extends PlanCubit {
  _SeededPlanCubit() {
    update(PlanSnapshot.fromJson(const {
      'plan': 'max-20x',
      'plan_name': 'Business',
      'exempt': true,
      'features': {'voice': true},
    }));
  }
}

/// A conversation whose stored `task_prep` is exactly [taskPrep].
///
/// Built through `fromJson` rather than a constructor so the wire shape the
/// backend actually serialises (`views.py:565`) is the thing under test.
ConversationSnapshot _snapshot(Object? taskPrep) =>
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
  late _PollableChatCubit chat;

  /// Pumps the real chat screen over a cubit the test can push polls through.
  Future<void> pumpChat(
    WidgetTester tester, {
    required Object? initialServerValue,
    required bool devicePreference,
  }) async {
    SharedPreferences.setMockInitialValues({
      UiStrings.taskPrepPreferenceKey: devicePreference,
    });
    final prefs = await SharedPreferences.getInstance();
    chat = _PollableChatCubit(_snapshot(initialServerValue));

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget chatProviders(Widget child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConversationsRepository>(
                create: (_) => _FakeRepo()),
            RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjects()),
            RepositoryProvider<VaultRepository>(create: (_) => _FakeVault()),
            RepositoryProvider<ApprovalsApi>(create: (_) => _FakeApprovals()),
            RepositoryProvider<ArtifactsApi>(create: (_) => _FakeArtifacts()),
            RepositoryProvider<OdooDataApi>(create: (_) => _FakeOdoo()),
            RepositoryProvider<TranscribeApi>(create: (_) => _FakeTranscribe()),
            RepositoryProvider<SaqqarToolsApi>(create: (_) => _FakeTools()),
            RepositoryProvider<VoiceSupportApi>(
                create: (_) => _FakeVoiceSupport()),
            RepositoryProvider<UsageApi>(create: (_) => _FakeUsage()),
            RepositoryProvider<LiveEnvAckService>(
                create: (_) => LiveEnvAckService(prefs)),
            RepositoryProvider<Dio>(create: (_) => Dio()),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ChatCubit>.value(value: chat),
              BlocProvider<PlanCubit>(create: (_) => _SeededPlanCubit()),
              BlocProvider<SaqqarFeaturesCubit>(
                  create: (_) => _SeededFeaturesCubit()),
              BlocProvider<TaskPrepCubit>(create: (_) => TaskPrepCubit(prefs)),
              BlocProvider<ConversationsCubit>(
                  create: (_) => ConversationsCubit(repository: _FakeRepo())),
              BlocProvider<VaultCubit>(
                  create: (_) => VaultCubit(repository: _FakeVault())),
            ],
            child: ChangeNotifierProvider<ShareIntakeService>(
              create: (_) => ShareIntakeService(),
              child: child,
            ),
          ),
        );

    await tester.pumpWidget(
      buildHarness(
        const ChatScreen(conversationId: 'c1'),
        locale: const Locale('en'),
        scale: 1.0,
        wrap: (Widget app) => appChrome(chatProviders(app), prefs),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// What the composer is currently rendering — the same value the send path
  /// reads, so it stands in for both.
  bool renderedTaskPrep(WidgetTester tester) =>
      tester.widget<ChatComposer>(find.byType(ChatComposer)).taskPrep;

  group('a flip made on another client arrives without a reopen', () {
    testWidgets('null → true: the first time the server takes an opinion',
        (tester) async {
      // The exact §4.0 shape. The chat starts untouched (`null`), so mobile is
      // showing its own default of OFF. Then a web user flips Task prep on,
      // the web PATCHes it, and our next snapshot poll carries `true`.
      await pumpChat(
        tester,
        initialServerValue: null,
        devicePreference: false,
      );
      expect(
        renderedTaskPrep(tester),
        isFalse,
        reason: 'nobody has flipped this chat, so the device default stands.',
      );

      chat.deliverPoll(_snapshot(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        renderedTaskPrep(tester),
        isTrue,
        reason: 'The server now stores `true` and the poll delivered it, but '
            'the toggle still shows the device default. A change made on the '
            'web never reaches a phone with the chat already open — which is '
            'the whole symptom this fix was for, moved one layer down.',
      );
    });

    testWidgets('true → false: a flip OFF propagates as readily as a flip ON',
        (tester) async {
      // Asserted separately because `??` only falls through on null: an
      // implementation that treated `false` as "no opinion" would pass the
      // case above and strand every user who turns the feature off.
      await pumpChat(
        tester,
        initialServerValue: true,
        devicePreference: true,
      );
      expect(renderedTaskPrep(tester), isTrue);

      chat.deliverPoll(_snapshot(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        renderedTaskPrep(tester),
        isFalse,
        reason: 'A stored `false` was treated as absent and the device '
            'default of ON resurrected it.',
      );
    });

    testWidgets('the device default never overrides a value the server owns',
        (tester) async {
      // Both directions of disagreement, delivered by poll rather than seeded
      // at build — the case a locally-cached read would get wrong.
      await pumpChat(
        tester,
        initialServerValue: null,
        devicePreference: true,
      );
      expect(renderedTaskPrep(tester), isTrue);

      chat.deliverPoll(_snapshot(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(renderedTaskPrep(tester), isFalse);

      chat.deliverPoll(_snapshot(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(renderedTaskPrep(tester), isTrue);
    });
  });

  group('a conversation nobody has flipped keeps its null', () {
    testWidgets('a poll that carries null leaves the device default in charge',
        (tester) async {
      // The web's note leans on this explicitly: it reads `task_prep` only
      // when non-null "so nothing overwrites the null you rely on". Mobile has
      // to hold the same line from the other side — a null arriving on a poll
      // must not be read as `false`.
      await pumpChat(
        tester,
        initialServerValue: null,
        devicePreference: true,
      );
      expect(renderedTaskPrep(tester), isTrue);

      chat.deliverPoll(_snapshot(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        renderedTaskPrep(tester),
        isTrue,
        reason: 'A null `task_prep` was coerced to false. Every untouched '
            'conversation on the backend is null, so this would silently turn '
            'Task prep off across the entire account.',
      );
    });

    testWidgets('a malformed value is treated as no opinion, not as false',
        (tester) async {
      // The backend is not the only thing that can put a value on this key —
      // a proxy, a stale client, a future migration. Parsing has to degrade to
      // "no opinion" rather than to `false`, or a bad deploy turns the feature
      // off for everyone instead of leaving them on their own default.
      await pumpChat(
        tester,
        initialServerValue: 'yes',
        devicePreference: true,
      );

      expect(
        renderedTaskPrep(tester),
        isTrue,
        reason: 'A non-boolean `task_prep` was read as false rather than as '
            'absent.',
      );
    });
  });
}
