// Deep conformance for the last nine untested widgets — the ones that read
// cubits off the tree.
//
// These were the tail of the 2026-08-17 audit, and they were the tail for a
// reason: each needs part of the app's object graph standing up before it will
// render at all, so they are the widgets most likely to be skipped and
// therefore the ones with the least coverage. Between them they hold the
// account's two editable forms, the password change, the credential form, the
// biometric gate and the chat's two drawers — which is to say most of the
// places a user types something that matters.
//
// App-wide providers come from `support/responsive_harness.dart`'s `appChrome`
// so this file only has to supply the feature cubits each widget adds on top.
// Reusing it also means a provider added to the real `app.dart` is added here
// once rather than in every conformance file.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// `SingleChildWidget` via provider's own re-export — importing `nested`
// directly would add a dependency the app does not declare.
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/theme/view_model/theme_cubit.dart';
import 'package:saqqar_app/features/account/widgets/change_password_card.dart';
import 'package:saqqar_app/features/account/widgets/personal_info_card.dart';
import 'package:saqqar_app/features/account/widgets/preferences_card.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/auth/view_model/auth_flow_cubit.dart';

import 'package:saqqar_app/features/auth/widgets/social_auth_buttons.dart';
import 'package:saqqar_app/features/chat/view_model/chat_cubit.dart';
import 'package:saqqar_app/features/chat/widgets/chat_header_controls.dart';
import 'package:saqqar_app/features/chat/widgets/chat_rail_drawer.dart';
import 'package:saqqar_app/features/chat/widgets/chat_sidebar_drawer.dart';
import 'package:saqqar_app/features/vault/data/vault_cache.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/push/data/push_notifications_service.dart';
import 'package:saqqar_app/features/security/view/app_lock_gate.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/features/vault/widgets/credential_form.dart';

import 'support/responsive_harness.dart' hide Viewport;
import 'support/widget_conformance.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────
//
// `noSuchMethod` answers everything a first paint does not touch. Only the
// reads that actually happen while laying these widgets out are given real
// answers — a fake that returns data nobody asked for is a second
// implementation to keep in sync.

class _FakeProjectsApi implements ProjectsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeCredentialsApi implements CredentialsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeApprovalsApi implements ApprovalsApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePush implements PushNotificationsService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeConversationsRepo implements ConversationsRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  VaultCubit vaultCubit() => VaultCubit(
        repository: VaultRepository(
          projectsApi: _FakeProjectsApi(),
          credentialsApi: _FakeCredentialsApi(),
          cache: VaultCache(prefs),
        ),
      );

  /// Wraps [child] in the app-wide chrome plus whatever feature cubits the
  /// widget under test reads.
  Widget provided(Widget child, {List<SingleChildWidget> extra = const []}) {
    final body = extra.isEmpty
        ? child
        : MultiProvider(providers: extra, child: child);
    return appChrome(body, prefs);
  }

  /// Reproduces the box the chat screen actually gives a drawer.
  ///
  /// `chat_screen.dart` lays both drawers out inside an
  /// `AnimatedPositionedDirectional` with
  /// `width: min(screenW * 0.86, 320)` and the full body height. Pumping them
  /// at the raw viewport width instead would be testing a 568 px-wide sidebar
  /// that no user can ever produce — and would report overflows against a
  /// layout the app never asks for, which is worse than no test at all
  /// because it trains everyone to ignore the file.
  ///
  /// The formula is duplicated from the screen on purpose: if it changes
  /// there, this should be updated to match, and a drawer that only fits at
  /// the old width is exactly what that update should surface.
  Widget asDrawer(Widget child) => LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth * 0.86 > 320.0
              ? 320.0
              : constraints.maxWidth * 0.86;
          return SizedBox(
            width: w,
            height: constraints.maxHeight,
            child: child,
          );
        },
      );

  // The conformance harness builds its own MaterialApp, so the providers have
  // to sit ABOVE it — same order as `app.dart`, where app chrome wraps the
  // router rather than living inside a screen.
  Widget Function() cased(
    Widget Function() build, {
    List<SingleChildWidget> Function()? extra,
  }) =>
      () => provided(build(), extra: extra?.call() ?? const []);

  final cases = <String, Widget Function()>{
    'ChangePasswordCard': cased(() => const ChangePasswordCard()),
    'PersonalInfoCard': cased(() => const PersonalInfoCard()),
    'PreferencesCard': cased(
      () => const PreferencesCard(mode: AppThemeMode.system, locale: null),
      extra: () => [
        Provider<PushNotificationsService>.value(value: _FakePush()),
      ],
    ),
    'SocialAuthButtons': cased(
      () => const SocialAuthButtons(),
      extra: () => [
        BlocProvider<AuthFlowCubit>(
          create: (_) => AuthFlowCubit(
            api: FakeAuthApi(),
            authCubit: AuthCubit(api: FakeAuthApi(), tokenStore: NoopTokenStore()),
            socialAuth: FakeSocialAuth(),
            initial: AuthFlowStep.signInEmail,
          ),
        ),
      ],
    ),
    'AppLockGate': cased(() => const AppLockGate(child: Text(kLongArabic))),
    'CredentialForm': cased(
      () => const CredentialForm(envId: 'env-1', kind: CredentialKind.xmlrpc),
      extra: () => [
        BlocProvider<VaultCubit>(create: (_) => vaultCubit()),
        Provider<CredentialsApi>.value(value: _FakeCredentialsApi()),
      ],
    ),
    'ChatHeaderControls': cased(
      () => ChatHeaderControls(
        projectId: null,
        environmentId: null,
        selectedEnvironmentIds: const [],
        onProjectChanged: (_) {},
        onEnvironmentsChanged: (_) {},
        onCreateEnvironmentRequested: (_) {},
        onCreateProjectRequested: () {},
      ),
      extra: () => [BlocProvider<VaultCubit>(create: (_) => vaultCubit())],
    ),
    'ChatSidebarDrawer': cased(
      () => asDrawer(ChatSidebarDrawer(
        currentConversationId: 'conv-1',
        onPickConversation: (_) {},
        onNewConversation: () {},
        onOpenVault: () {},
        onGoHome: () {},
        onClose: () {},
      )),
      extra: () => [
        BlocProvider<ConversationsCubit>(
          create: (_) =>
              ConversationsCubit(repository: _FakeConversationsRepo()),
        ),
      ],
    ),
    'ChatRailDrawer': cased(
      () => asDrawer(ChatRailDrawer(conversationId: 'conv-1', onClose: () {})),
      extra: () => [
        BlocProvider<ChatCubit>(
          create: (_) => ChatCubit(
            conversationId: 'conv-1',
            repository: _FakeConversationsRepo(),
          ),
        ),
        Provider<ApprovalsApi>.value(value: _FakeApprovalsApi()),
        Provider<Dio>.value(value: Dio()),
      ],
    ),
  };

  /// The two drawers fill a `Drawer`, which hands them a BOUNDED height, and
  /// they use `Expanded` to divide it. Pumping them inside the harness's
  /// default `SingleChildScrollView` gives them infinite height instead, which
  /// makes `Expanded` illegal and reports a framework assertion that has
  /// nothing to do with the widget. They get the unscrolled harness, which is
  /// what a `Drawer` actually gives them.
  const unscrolled = {'ChatSidebarDrawer', 'ChatRailDrawer'};

  group('every provider-backed widget survives the layout matrix', () {
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await sweepWidget(
          tester,
          build,
          name: name,
          scroll: !unscrolled.contains(name),
        );
      });
    });
  });

  group('every provider-backed widget renders in the dark theme', () {
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await rendersInDark(
          tester,
          build,
          name: name,
          scroll: !unscrolled.contains(name),
        );
      });
    });
  });

  // ── Behaviour ─────────────────────────────────────────────────────────

  group('ChangePasswordCard', () {
    // The card is an `AnimatedCrossFade`, which keeps BOTH branches mounted
    // and cross-fades between them. So `find.byType(TextField)` locates the
    // fields whether the card is open or shut, and the state has to be read
    // off the cross-fade rather than inferred from what exists in the tree.
    CrossFadeState fadeState(WidgetTester tester) =>
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade).first)
            .crossFadeState;

    testWidgets('starts collapsed, so the form is opt-in', (tester) async {
      // Three password fields open by default on the account screen is both
      // noisy and an invitation to type a password nobody asked for.
      await tester.pumpWidget(
        conformanceHarness(
          provided(const ChangePasswordCard()),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.pump();
      expect(fadeState(tester), CrossFadeState.showFirst);
    });

    testWidgets('opens on tap and offers exactly three fields',
        (tester) async {
      // Current + new + confirm. A card that dropped the confirm field would
      // let a typo become the account's new password with no second chance.
      await tester.pumpWidget(
        conformanceHarness(
          provided(const ChangePasswordCard()),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(ChangePasswordCard));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(fadeState(tester), CrossFadeState.showSecond);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('every field is obscured', (tester) async {
      // The security-relevant assertion, and the reason this card is worth a
      // test at all: a field that quietly stopped obscuring looks completely
      // normal to everyone except the person standing behind the user.
      await tester.pumpWidget(
        conformanceHarness(
          provided(const ChangePasswordCard()),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(ChangePasswordCard));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(3));
      for (final f in fields) {
        expect(
          f.obscureText,
          isTrue,
          reason: 'A password field on the account screen renders in clear '
              'text.',
        );
      }
    });
  });

  group('AppLockGate', () {
    testWidgets('passes its child through when the lock is not engaged',
        (tester) async {
      // The gate wraps the whole app. If it rendered the lock by default,
      // every launch would demand a fingerprint — and if it never rendered it,
      // the feature does nothing. The default must be "show the app".
      await tester.pumpWidget(
        conformanceHarness(
          provided(const AppLockGate(child: Text('the app'))),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.pump();
      expect(find.text('the app'), findsOneWidget);
    });
  });

  group('SocialAuthButtons', () {
    testWidgets('offers Google on every platform', (tester) async {
      // Apple is deliberately NOT asserted here. It is gated behind
      // `Platform.isIOS` because App Store rule 4.8 requires Apple sign-in
      // only where a third-party option is offered on iOS — and a widget test
      // runs on the host, so asserting it would fail everywhere except a Mac
      // and would be testing `Platform`, not the widget.
      await tester.pumpWidget(
        conformanceHarness(
          provided(
            const SocialAuthButtons(),
            extra: [
              BlocProvider<AuthFlowCubit>(
                create: (_) => AuthFlowCubit(
                  api: FakeAuthApi(),
                  authCubit:
                      AuthCubit(api: FakeAuthApi(), tokenStore: NoopTokenStore()),
                  socialAuth: FakeSocialAuth(),
                  initial: AuthFlowStep.signInEmail,
                ),
              ),
            ],
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.pump();
      expect(find.textContaining('Google'), findsWidgets);
    });
  });
}
