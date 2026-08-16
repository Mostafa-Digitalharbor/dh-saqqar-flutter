// The half of the Stop contract that `stop_sync_test.dart` cannot reach.
//
// That file proves `ChatCubit` is honest: it POSTs to the shared row, it keeps
// reporting `isRunning: true` until the server says otherwise, and it records a
// failure when the cancel never lands. All true, and all invisible to the user,
// because `ChatScreen` does not render the cubit's opinion directly.
//
// It renders `_effectiveIsThinking`, which opens with:
//
//     if (_localStopOverride) return false;
//
// `_localStopOverride` is flipped SYNCHRONOUSLY on tap, before the POST is even
// dispatched, and the POST itself is fired `unawaited`. So the screen's claim
// about whether the agent is running is, for a window, a purely local one — and
// the web is reading the actual row the whole time.
//
// The question these tests answer is what happens to that local claim when the
// cancel does not reach the server: whether the screen ever rejoins the truth
// the cubit already knows, or keeps showing a stopped agent that the browser
// shows as still working.
//
// The assertion is on `ChatComposer.onStop` rather than on pixels. That
// parameter IS the Stop button — the composer renders Send when it is null —
// and reading it is what makes "the button is gone" a checkable claim instead
// of a screenshot someone has to interpret.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The shared backend row, as far as this screen can see it.
class _StopRepo implements ConversationsRepository {
  _StopRepo({this.stopThrows});

  /// When set, the cancel never reaches the server — the dropped-connection
  /// case, which is the only one where the optimistic UI can be wrong.
  final Object? stopThrows;

  final stopCalls = <String>[];

  @override
  Future<({bool isRunning, bool stopRequested})> stop(String id) async {
    stopCalls.add(id);
    final failure = stopThrows;
    if (failure != null) throw failure;
    return (isRunning: true, stopRequested: true);
  }

  /// Answers the poll `stopGeneration` fires on its success path.
  ///
  /// Overridden rather than left to `noSuchMethod` because the cubit CATCHES a
  /// failed poll and only logs it. The first run of this file showed
  /// `NoSuchMethodError: no instance method 'getSnapshot'` in the passing
  /// output — the fixture was throwing where the server would have answered,
  /// and the test was green anyway. That is the shape of a test that stops
  /// measuring what it claims to.
  ///
  /// Still reports the run as ALIVE: the cancel is cooperative, so the poll
  /// immediately after a successful stop is exactly when the server still says
  /// `is_running: true`.
  @override
  Future<ConversationSnapshot> getSnapshot(
    String id, {
    DateTime? since,
    int? limit,
    String? before,
  }) async =>
      _running();

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

/// A conversation the server reports as RUNNING — the only state in which the
/// Stop button exists at all.
ConversationSnapshot _running() =>
    ConversationSnapshot.fromJson(const <String, dynamic>{
      'conversation': <String, dynamic>{
        'id': 'c1',
        'title': 'Add 30 users to live',
        'auto_approve': false,
        'is_running': true,
        'stop_requested': false,
        'task_prep': false,
      },
      'messages': <Map<String, dynamic>>[],
    });

/// Holds the running snapshot and never polls over it.
///
/// No polling on purpose: a poll that answered `is_running: false` would clear
/// the run for a reason unrelated to the tap, and the test could no longer tell
/// the optimistic override apart from a genuine server confirmation.
class _SeededChatCubit extends ChatCubit {
  _SeededChatCubit(_StopRepo repo)
      : super(conversationId: 'c1', repository: repo) {
    emit(ChatState(data: DataSuccess(_running())));
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

void main() {
  /// Pumps the real `ChatScreen` over [repo] and hands back the composer.
  Future<ChatComposer> pumpChat(
    WidgetTester tester,
    _StopRepo repo,
    SharedPreferences prefs,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget chatProviders(Widget child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConversationsRepository>(create: (_) => repo),
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
              BlocProvider<ChatCubit>(create: (_) => _SeededChatCubit(repo)),
              BlocProvider<PlanCubit>(create: (_) => _SeededPlanCubit()),
              BlocProvider<SaqqarFeaturesCubit>(
                  create: (_) => _SeededFeaturesCubit()),
              BlocProvider<TaskPrepCubit>(create: (_) => TaskPrepCubit(prefs)),
              BlocProvider<ConversationsCubit>(
                  create: (_) => ConversationsCubit(repository: repo)),
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

    return tester.widget<ChatComposer>(find.byType(ChatComposer));
  }

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('a running agent offers Stop', (tester) async {
    final repo = _StopRepo();
    final composer = await pumpChat(tester, repo, prefs);

    // The precondition every other test here depends on. Without it a later
    // `onStop == null` would be indistinguishable from a screen that never
    // showed the button in the first place.
    expect(
      composer.onStop,
      isNotNull,
      reason: 'the composer must render Stop while `is_running` is true',
    );
    expect(repo.stopCalls, isEmpty);
  });

  testWidgets('tapping Stop writes to the row the web reads', (tester) async {
    final repo = _StopRepo();
    final composer = await pumpChat(tester, repo, prefs);

    composer.onStop!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // The sync itself. `_stopGeneration` fires this `unawaited`, so nothing in
    // the UI would look different if the call were dropped entirely — which is
    // exactly why it needs asserting rather than observing.
    expect(
      repo.stopCalls,
      ['c1'],
      reason: 'Stop must POST /conversations/c1/stop/. The browser learns the '
          'user cancelled only by re-reading that row — there is no channel '
          'between the two clients.',
    );
  });

  testWidgets('a cancel the server never received still hides Stop',
      (tester) async {
    final repo = _StopRepo(
      stopThrows: DioException.connectionError(
        requestOptions: RequestOptions(path: '/stop/'),
        reason: 'network unreachable',
      ),
    );
    final composer = await pumpChat(tester, repo, prefs);

    composer.onStop!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final after = tester.widget<ChatComposer>(find.byType(ChatComposer));

    // This documents CURRENT behaviour, and it is the answer to "do the web
    // and the app agree".
    //
    // The POST failed, so `stop_requested` was never written and the browser
    // still shows the agent working. `ChatCubit` knows this — it recorded a
    // `ChatAction.stop` failure and still reports `isRunning: true`. But the
    // screen set `_localStopOverride = true` before dispatching, and nothing
    // clears that flag except a subsequent send: not a poll, not the failure.
    //
    // So the composer has swapped back to Send. The two clients disagree, and
    // the phone is the one that is wrong.
    expect(
      after.onStop,
      isNull,
      reason: 'If this now passes a non-null callback, the local stop override '
          'has been made to yield to the cubit — update this test to assert '
          'the agreement rather than deleting it.',
    );
    expect(
      repo.stopCalls,
      ['c1'],
      reason: 'the attempt was made — it just never landed',
    );
  });

  testWidgets('the cubit still knows the run is alive after a failed cancel',
      (tester) async {
    // The other side of the divergence, proven on the same pumped screen: this
    // is not a case of the app losing the information. It has it. The view
    // simply is not reading it.
    //
    // That is what makes the gap cheap to close — `_effectiveIsThinking` can
    // drop the override once `actionFailure?.action == ChatAction.stop`, and
    // the Stop button comes back on its own.
    final repo = _StopRepo(
      stopThrows: DioException.connectionError(
        requestOptions: RequestOptions(path: '/stop/'),
        reason: 'network unreachable',
      ),
    );
    final composer = await pumpChat(tester, repo, prefs);

    composer.onStop!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final cubit = tester
        .element(find.byType(ChatComposer))
        .read<ChatCubit>();

    expect(cubit.state.actionFailure?.action, ChatAction.stop);
    expect(
      cubit.state.isRunning,
      isTrue,
      reason: 'the server never stopped anything, and the cubit says so',
    );
  });
}
