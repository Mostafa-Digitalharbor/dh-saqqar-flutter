// Does the chat screen RENDER the server's `task_prep`, or its own default?
//
// This is the direction that decides whether mobile picks up a change made
// anywhere else — the web, another phone, a future admin tool. The write
// direction is proven on a real device (`task_prep_sync_test.dart` plus the
// console capture in `WEB_TASK_PREP_NOT_SYNCING.md` §2); the read direction had
// only ever been checked by reading the source and by asserting `?? ` semantics
// in a test that could not fail.
//
// So this pumps the real `ChatScreen`, with the real precedence expression in
// play, and reads the value the composer was actually handed:
//
//     conversation.taskPrep ?? TaskPrepCubit.state
//
// The cases that matter are the ones where the two DISAGREE. A test where both
// say `true` proves nothing about which one was used.

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

/// One stub per interface. They cannot share a class: `ProjectsApi.list`,
/// `ApprovalsApi.list` and `ArtifactsApi.list` have incompatible signatures, so
/// a single `implements` of all three has no valid override for `list`.
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

/// Holds whatever snapshot the test seeds, and never polls over it.
class _SeededChatCubit extends ChatCubit {
  _SeededChatCubit(ConversationSnapshot snapshot)
      : super(conversationId: 'c1', repository: _FakeRepo()) {
    emit(ChatState(data: DataSuccess(snapshot)));
  }

  @override
  Future<void> load({bool force = false}) async {}
}

class _SeededFeaturesCubit extends SaqqarFeaturesCubit {
  _SeededFeaturesCubit() : super(_FakeUsage()) {
    // Task prep must be an ALLOWED capability, or the composer hides the
    // toggle entirely and the test would assert on a control that isn't there.
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
  /// Pumps the real chat screen and returns the value the composer was handed.
  Future<bool> renderedTaskPrep(
    WidgetTester tester, {
    required Object? serverValue,
    required bool devicePreference,
  }) async {
    SharedPreferences.setMockInitialValues({
      UiStrings.taskPrepPreferenceKey: devicePreference,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // `appChrome` supplies the providers `app.dart` installs above the router
    // — Connectivity, RunningAgents, Auth, AppLock, Theme, Locale and the
    // notifications store. `ChatScreen` reaches for several of them through
    // shared chrome, and a missing one renders as an unbounded ErrorWidget
    // rather than throwing somewhere legible.
    Widget chatProviders(Widget child) =>
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ConversationsRepository>(create: (_) => _FakeRepo()),
          RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjects()),
          RepositoryProvider<VaultRepository>(create: (_) => _FakeVault()),
          RepositoryProvider<ApprovalsApi>(create: (_) => _FakeApprovals()),
          RepositoryProvider<ArtifactsApi>(create: (_) => _FakeArtifacts()),
          RepositoryProvider<OdooDataApi>(create: (_) => _FakeOdoo()),
          RepositoryProvider<TranscribeApi>(create: (_) => _FakeTranscribe()),
          RepositoryProvider<SaqqarToolsApi>(create: (_) => _FakeTools()),
          RepositoryProvider<VoiceSupportApi>(create: (_) => _FakeVoiceSupport()),
          RepositoryProvider<UsageApi>(create: (_) => _FakeUsage()),
          RepositoryProvider<LiveEnvAckService>(
              create: (_) => LiveEnvAckService(prefs)),
          RepositoryProvider<Dio>(create: (_) => Dio()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ChatCubit>(
                create: (_) => _SeededChatCubit(_snapshot(serverValue))),
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

    return tester.widget<ChatComposer>(find.byType(ChatComposer)).taskPrep;
  }

  group('the server wins whenever it has an opinion', () {
    // The two cells where server and device DISAGREE. These are the whole
    // test — the agreeing cells cannot tell the two sources apart.
    testWidgets('server ON beats a device default of OFF', (tester) async {
      final rendered = await renderedTaskPrep(
        tester,
        serverValue: true,
        devicePreference: false,
      );

      expect(
        rendered,
        isTrue,
        reason: 'the conversation is stored ON — a phone whose local default '
            'is OFF must still show ON, or a change made on any other surface '
            'never arrives.',
      );
    });

    testWidgets('server OFF beats a device default of ON', (tester) async {
      final rendered = await renderedTaskPrep(
        tester,
        serverValue: false,
        devicePreference: true,
      );

      expect(
        rendered,
        isFalse,
        reason: 'the conversation is stored OFF — the local default must not '
            'resurrect it.',
      );
    });
  });

  group('a conversation the server has no opinion about', () {
    // `null` is the backend's deliberate default on every untouched row, so
    // this is the common case, not an edge one.
    for (final devicePreference in const [true, false]) {
      testWidgets('null falls back to the device default ($devicePreference)',
          (tester) async {
        final rendered = await renderedTaskPrep(
          tester,
          serverValue: null,
          devicePreference: devicePreference,
        );

        expect(rendered, devicePreference);
      });
    }
  });
}
