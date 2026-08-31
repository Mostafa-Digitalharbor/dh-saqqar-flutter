// Does a PENDING approval in the snapshot actually reach the screen?
//
// Reported by the team: "when Saqqar asks for approval to modify something,
// the approval card never appears". Every existing approval test pumps
// `ChatApprovalCard` directly, so the whole path from `snapshot.approvals`
// through the list-index arithmetic to the card was never covered.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
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
import 'package:saqqar_app/features/chat/widgets/chat_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/chat_typing_row.dart';
import 'package:saqqar_app/features/conversations/data/attachment_models.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/share/intake/share_intake_service.dart';
import 'package:saqqar_app/shared/widgets/ghost_button.dart';
import 'package:saqqar_app/shared/widgets/primary_button.dart';
import 'package:saqqar_app/features/support/data/voice_support_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';

import 'support/responsive_harness.dart';

/// Drains the decision tap: the POST's future, the snapshot re-read that
/// follows it, and the toast that reports the outcome.
///
/// Not `pumpAndSettle` — the chat's ambient background animates forever, so
/// settling never arrives and the timeout reads as a broken tap rather than a
/// screen that is simply never idle.
Future<void> _settleDecision(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

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

/// Records the decision POST the card actually fires. `noSuchMethod` would
/// answer `null`, which an `await` turns into a type error inside the
/// screen's own try/catch — the tap would look handled and assert nothing.
class _FakeApprovals implements ApprovalsApi {
  final decisions = <({String id, bool approved, bool batch, String? phrase})>[];

  @override
  Future<ApprovalDecisionResult> decide({
    required String id,
    required bool approved,
    String? note,
    bool batchScope = false,
    String? confirmPhrase,
  }) async {
    decisions.add((
      id: id,
      approved: approved,
      batch: batchScope,
      phrase: confirmPhrase,
    ));
    return ApprovalDecisionResult(
      approval: Approval.fromJson(<String, dynamic>{
        'id': id,
        'action_type': 'odoo_write',
        'status': approved ? 'approved' : 'rejected',
        'prompt': '',
        'payload': const <String, dynamic>{},
      }),
    );
  }

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

class _SeededChatCubit extends ChatCubit {
  _SeededChatCubit(ConversationSnapshot snapshot)
      : super(conversationId: 'c1', repository: _FakeRepo()) {
    emit(ChatState(data: DataSuccess(snapshot)));
  }

  int refreshes = 0;

  @override
  Future<void> load({bool force = false}) async {}

  /// Stands in for the server confirming the decision: the approval the user
  /// just resolved is no longer pending. `_decideApprovalInline` awaits this
  /// straight after the POST, and it is what makes the card leave the screen
  /// without waiting for a poll tick.
  @override
  Future<void> refresh() async {
    refreshes++;
    final current = state.data.dataOrNull;
    if (current == null) return;
    emit(state.copyWith(
      data: DataSuccess(current.copyWith(approvals: const [])),
    ));
  }
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

/// A live conversation carrying one PENDING `odoo_write` approval — the shape
/// the backend sends when the agent wants to modify records.
ConversationSnapshot _snapshotWithApproval({
  bool isRunning = false,
  String operation = 'write',
  int messages = 1,
  int approvals = 1,
}) =>
    ConversationSnapshot.fromJson(<String, dynamic>{
      'conversation': <String, dynamic>{
        'id': 'c1',
        'title': 'T',
        'auto_approve': false,
        'is_running': isRunning,
        'stop_requested': false,
      },
      'messages': <Map<String, dynamic>>[
        for (var i = 0; i < messages; i++)
          {
            'id': 'm$i',
            'role': i.isEven ? 'user' : 'assistant',
            'content': 'message $i',
            'created_at': '2026-08-30T10:00:00Z',
          },
      ],
      'approvals': <Map<String, dynamic>>[
        for (var i = 0; i < approvals; i++)
          {
            'id': 'ap$i',
            'action_type': 'odoo_write',
            'status': 'pending',
            'prompt': 'Saqqar wants to modify 1 record.',
            'record_count': 1,
            'model_label': const {'en': 'Sales Order', 'ar': 'Sales Order AR'},
            'payload': {'operation': operation, 'model': 'sale.order'},
          },
      ],
    });

void main() {
  Future<({_FakeApprovals api, _SeededChatCubit cubit})> pumpChat(
    WidgetTester tester,
    ConversationSnapshot snapshot, {
    TargetPlatform platform = TargetPlatform.android,
    Locale locale = const Locale('en'),
    bool reduceMotion = false,
    Size size = const Size(430, 932),
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final approvalsApi = _FakeApprovals();
    final cubit = _SeededChatCubit(snapshot);

    // The real thing an iPhone changes about this tree. The override drives
    // `defaultTargetPlatform`, which seeds `ThemeData.platform` and through it
    // every platform switch Flutter makes while building — scroll physics,
    // page transitions, text selection, the refresh indicator.
    //
    // Cleared before this returns, not in `addTearDown`: the test binding
    // asserts every foundation debug variable is unset when the test body
    // ends, and tear-downs run after that check. The tree is fully built by
    // then, and the `Theme` override below keeps the platform identity for
    // anything that rebuilds after.
    debugDefaultTargetPlatformOverride = platform;

    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget chatProviders(Widget child) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConversationsRepository>(
                create: (_) => _FakeRepo()),
            RepositoryProvider<ProjectsApi>(create: (_) => _FakeProjects()),
            RepositoryProvider<VaultRepository>(create: (_) => _FakeVault()),
            RepositoryProvider<ApprovalsApi>(create: (_) => approvalsApi),
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
              BlocProvider<ChatCubit>(create: (_) => cubit),
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
        // Reduce Motion and the home-indicator inset are the two things an
        // iPhone hands this tree that a test phone does not.
        // `disableAnimations` is the flag iOS sets for Reduce Motion, and it
        // is read by `FadeSlideIn` — the only wrapper the approval card has
        // and ordinary message bubbles do not.
        Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(platform: platform),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
                viewPadding: viewPadding,
                padding: viewPadding,
              ),
              child: const ChatScreen(conversationId: 'c1'),
            ),
          ),
        ),
        locale: locale,
        scale: 1.0,
        wrap: (Widget app) => appChrome(chatProviders(app), prefs),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    debugDefaultTargetPlatformOverride = null;
    return (api: approvalsApi, cubit: cubit);
  }

  testWidgets('a pending odoo_write approval renders inline in the chat',
      (tester) async {
    await pumpChat(tester, _snapshotWithApproval());

    expect(
      find.byType(ChatApprovalCard),
      findsOneWidget,
      reason: 'the snapshot carries one pending approval — the user has no '
          'other way to unblock the run.',
    );
  });

  testWidgets('it renders while the agent is still marked running',
      (tester) async {
    await pumpChat(tester, _snapshotWithApproval(isRunning: true));

    expect(find.byType(ChatApprovalCard), findsOneWidget);
  });

  // ── The iPhone cells ───────────────────────────────────────────────────
  //
  // Reported after the delivery fix: the card shows on Android and not on
  // iOS. Everything an iPhone changes about this tree, swept — the platform
  // Flutter switches its scroll physics and transitions on, Reduce Motion,
  // the home-indicator inset, and Arabic (an iPhone in this office is far
  // likelier to be running the app in Arabic than a test handset).
  group('the card must survive everything an iPhone does to this tree', () {
    for (final platform in const [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        testWidgets('$platform · ${locale.languageCode}', (tester) async {
          await pumpChat(
            tester,
            _snapshotWithApproval(),
            platform: platform,
            locale: locale,
            // The iPhone 14/15 home-indicator + notch insets.
            viewPadding: platform == TargetPlatform.iOS
                ? const EdgeInsets.only(top: 47, bottom: 34)
                : EdgeInsets.zero,
          );

          expect(find.byType(ChatApprovalCard), findsOneWidget);
        });
      }
    }

    testWidgets('iOS with Reduce Motion on', (tester) async {
      // `FadeSlideIn` starts at `Opacity(0)` and only reaches 1 by running an
      // AnimationController. Reduce Motion takes the branch that skips the
      // controller entirely — if that branch failed to pin the value at 1,
      // the card would mount, occupy its space, and paint nothing. Every
      // ordinary message bubble renders without `FadeSlideIn`, so the chat
      // would look completely normal apart from the one card that matters.
      await pumpChat(
        tester,
        _snapshotWithApproval(),
        platform: TargetPlatform.iOS,
        reduceMotion: true,
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      expect(find.byType(ChatApprovalCard), findsOneWidget);

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(ChatApprovalCard),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(
        opacity.opacity,
        1.0,
        reason: 'Reduce Motion skips the entrance animation — it must land on '
            'fully visible, not on the 0 the animation starts from.',
      );
    });

    testWidgets('iOS on the smallest supported iPhone', (tester) async {
      await pumpChat(
        tester,
        _snapshotWithApproval(),
        platform: TargetPlatform.iOS,
        size: const Size(320, 568),
      );

      expect(find.byType(ChatApprovalCard), findsOneWidget);
    });
  });

  // ── The state that hides it on BOTH platforms ──────────────────────────
  group('a chat with no visible messages', () {
    testWidgets('still shows a pending approval', (tester) async {
      // `_buildMessageList` is only reached when `_effectiveMessages` is
      // non-empty; the empty branch renders `EmptyChatSuggestions` instead,
      // and the inline approval cards live inside the list it skipped.
      //
      // "No visible messages" is not an exotic state. `isVisibleMessage`
      // drops every `tool` row and every empty-content assistant row, which
      // is most of what a run emits — so a conversation whose whole turn so
      // far is tool calls ending at an approval gate has a pending approval
      // and nothing to render it next to.
      await pumpChat(tester, _snapshotWithApproval(messages: 0));

      expect(
        find.byType(ChatApprovalCard),
        findsOneWidget,
        reason: 'an approval is the one thing on this screen the user MUST '
            'be able to act on — an empty transcript is no reason to hide it.',
      );
    });

    testWidgets('and the same on iOS', (tester) async {
      await pumpChat(
        tester,
        _snapshotWithApproval(messages: 0),
        platform: TargetPlatform.iOS,
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      expect(find.byType(ChatApprovalCard), findsOneWidget);
    });

    testWidgets('with the agent still running, beside the typing row',
        (tester) async {
      // Empty transcript AND a thinking row AND approvals — all three index
      // ranges in the list builder are live at once, with no messages to
      // separate them. The arithmetic has no room to be off by one here.
      await pumpChat(
        tester,
        _snapshotWithApproval(messages: 0, isRunning: true),
        platform: TargetPlatform.iOS,
      );

      expect(find.byType(ChatApprovalCard), findsOneWidget);
      expect(find.byType(ChatTypingRow), findsOneWidget);
    });

    testWidgets('three approvals and nothing else render all three',
        (tester) async {
      await pumpChat(
        tester,
        _snapshotWithApproval(messages: 0, approvals: 3),
        platform: TargetPlatform.iOS,
        // Tall enough for all three at once. On a phone-sized viewport the
        // list lazily builds only what fits, and a count assertion would be
        // measuring virtualisation rather than the index arithmetic.
        size: const Size(430, 1600),
      );

      expect(find.byType(ChatApprovalCard), findsNWidgets(3));
    });

    testWidgets('and in Arabic', (tester) async {
      await pumpChat(
        tester,
        _snapshotWithApproval(messages: 0),
        platform: TargetPlatform.iOS,
        locale: const Locale('ar'),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      expect(find.byType(ChatApprovalCard), findsOneWidget);
    });
  });

  // ── The tap the whole feature exists for ───────────────────────────────
  //
  // Rendering the card is half of it. These drive the buttons on the real
  // screen, so the wiring from card → `_decideApprovalInline` → the decision
  // POST is covered end to end rather than at the widget's own callback.
  group('deciding from the chat', () {
    testWidgets('Approve posts the decision and clears the card',
        (tester) async {
      final h = await pumpChat(
        tester,
        _snapshotWithApproval(),
        platform: TargetPlatform.iOS,
      );

      await tester.tap(find.descendant(
        of: find.byType(ChatApprovalCard),
        matching: find.byType(PrimaryButton),
      ));
      await _settleDecision(tester);

      expect(h.api.decisions, hasLength(1));
      expect(h.api.decisions.single.id, 'ap0');
      expect(h.api.decisions.single.approved, isTrue);
      expect(h.api.decisions.single.batch, isFalse);
      expect(
        h.cubit.refreshes,
        1,
        reason: 'the screen re-reads the snapshot so the resolved row leaves '
            'immediately instead of lingering until the next poll tick.',
      );
      expect(find.byType(ChatApprovalCard), findsNothing);
    });

    testWidgets('Reject posts approved:false', (tester) async {
      final h = await pumpChat(
        tester,
        _snapshotWithApproval(),
        platform: TargetPlatform.iOS,
      );

      await tester.tap(find.descendant(
        of: find.byType(ChatApprovalCard),
        matching: find.widgetWithText(GhostButton, 'Reject'),
      ));
      await _settleDecision(tester);

      expect(h.api.decisions.single.approved, isFalse);
      expect(find.byType(ChatApprovalCard), findsNothing);
    });

    testWidgets('the tap works from the empty-transcript state too',
        (tester) async {
      // The state this session fixed. A card that renders but whose buttons
      // sit outside the hit-testable area would pass every finder above and
      // still leave the run blocked.
      final h = await pumpChat(
        tester,
        _snapshotWithApproval(messages: 0),
        platform: TargetPlatform.iOS,
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      await tester.tap(find.descendant(
        of: find.byType(ChatApprovalCard),
        matching: find.byType(PrimaryButton),
      ));
      await _settleDecision(tester);

      expect(h.api.decisions.single.id, 'ap0');
      expect(find.byType(ChatApprovalCard), findsNothing);
    });
  });
}
