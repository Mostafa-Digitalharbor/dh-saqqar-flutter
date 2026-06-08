import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/account/view/account_screen.dart';
import '../../features/auth/view/auth_flow_screen.dart';
import '../../features/auth/view_model/auth_cubit.dart';
import '../../features/auth/view_model/auth_flow_cubit.dart';
import '../../features/auth/view_model/auth_state.dart';
import '../../features/billing/view/pricing_screen.dart';
import '../../features/chat/view/chat_screen.dart';
import '../../features/chat/view_model/chat_cubit.dart';
import '../../features/conversations/data/conversations_repository.dart';
import '../../features/conversations/view/conversations_screen.dart';
import '../../features/share/view/shared_transcript_screen.dart';
import '../../features/storybook/storybook_screen.dart';
import '../../features/vault/view/vault_screen.dart';
import '../constants/ui_strings.dart';
import '../../navigation/home_shell.dart';
import '../i18n/app_localizations.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Public reference to the live [GoRouter] instance. Populated by
/// [buildAppRouter] at app boot. Callers that live ABOVE the router
/// in the widget tree (e.g. `ShareIntentBootstrap`, which is mounted
/// inside `MaterialApp.router`'s `builder:` — outside the
/// `InheritedGoRouter`) use this to navigate without needing
/// `context.go(...)`, which would throw "No GoRouter found in context"
/// at that level.
///
/// Never read this before `runApp` — it's null until [buildAppRouter]
/// returns.
GoRouter? appRouter;
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Public routes that don't require an authenticated session. Used by the
/// gate below to decide whether to redirect to `/sign-in`.
const _publicPaths = <String>{
  RouteNames.signInPath,
  RouteNames.signUpPath,
};

/// `/share/<token>` is public — anyone with the token can read.
bool _isPublicShare(String location) => location.startsWith('/share/');

/// Builds a GoRouter wired against the supplied [AuthCubit].
///
/// The gate:
///   - While `status == initial` or `loading`, defer redirect decisions
///     (the launch splash is still on screen, then awaits the bootstrap
///     before handing off).
///   - When unauthenticated, force `/sign-in` for any protected route.
///   - When authenticated, bounce off `/sign-in` and `/sign-up`.
///
/// The router is rebuilt as a singleton inside `app.dart` (kept in a
/// `late final` so it survives hot reloads / theme changes).
GoRouter buildAppRouter(AuthCubit authCubit) {
  return appRouter = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.chatsPath,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _AuthRefreshNotifier(authCubit),
    redirect: (context, state) {
      final auth = authCubit.state;
      // Wait for bootstrap to resolve — the splash holds the UI in the
      // meantime, so no flash of /chats before the gate decides.
      if (!auth.isResolved) return null;

      final location = state.matchedLocation;
      final isPublic =
          _publicPaths.contains(location) || _isPublicShare(location);
      final isAuthed = auth.isAuthenticated;

      if (!isAuthed && !isPublic) return RouteNames.signInPath;
      if (isAuthed && _publicPaths.contains(location)) {
        return RouteNames.chatsPath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.signInPath,
        name: RouteNames.signIn,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const AuthFlowScreen(initial: AuthFlowStep.signInEmail),
          kind: _RouteTransitionKind.fade,
        ),
      ),
      GoRoute(
        path: RouteNames.signUpPath,
        name: RouteNames.signUp,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const AuthFlowScreen(initial: AuthFlowStep.signUpEmail),
          kind: _RouteTransitionKind.fade,
        ),
      ),
      GoRoute(
        path: RouteNames.storybookPath,
        name: RouteNames.storybook,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const StorybookScreen(),
          kind: _RouteTransitionKind.scale,
        ),
      ),
      GoRoute(
        path: RouteNames.pricingPath,
        name: RouteNames.pricing,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const PricingScreen(),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      GoRoute(
        path: '/share/:token',
        name: RouteNames.sharedTranscript,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: SharedTranscriptScreen(token: state.pathParameters['token']!),
          kind: _RouteTransitionKind.fade,
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.chatsPath,
            name: RouteNames.chats,
            pageBuilder: (_, state) => _transitionPage(
              state: state,
              child: const ConversationsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: RouteNames.chat,
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (_, state) {
                  final id = state.pathParameters['id']!;
                  final isNewChat = id == UiStrings.newConversationId;
                  return _transitionPage(
                    state: state,
                    // Per-route BlocProvider: ChatCubit instance lives
                    // for the lifetime of one chat route. On pop, close()
                    // fires, cancelling the snapshot poll timer +
                    // attachment status pollers. The "new chat"
                    // sentinel skips the cubit (no server conversation
                    // to poll yet) — the screen falls back to the
                    // create-then-route flow.
                    child: isNewChat
                        ? ChatScreen(conversationId: id)
                        : BlocProvider<ChatCubit>(
                            create: (ctx) => ChatCubit(
                              conversationId: id,
                              repository: ctx.read<ConversationsRepository>(),
                            )..load(),
                            child: ChatScreen(conversationId: id),
                          ),
                    kind: _RouteTransitionKind.detail,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.vaultPath,
            name: RouteNames.vault,
            pageBuilder: (_, state) =>
                _transitionPage(state: state, child: const VaultScreen()),
          ),
          GoRoute(
            path: RouteNames.accountPath,
            name: RouteNames.account,
            pageBuilder: (_, state) =>
                _transitionPage(state: state, child: const AccountScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(context.tr.routeNotFound(state.uri))),
    ),
  );
}

/// Bridges [AuthCubit]'s stream to GoRouter's `refreshListenable` so the
/// gate re-runs `redirect` whenever the auth status flips.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._cubit) {
    _sub = _cubit.stream.listen((_) => notifyListeners());
  }

  final AuthCubit _cubit;
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

enum _RouteTransitionKind { tab, detail, fade, scale }

CustomTransitionPage<void> _transitionPage({
  required GoRouterState state,
  required Widget child,
  _RouteTransitionKind kind = _RouteTransitionKind.tab,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) return child;

      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      // Detail routes slide in from the trailing edge so the motion
      // mirrors the user's reading direction — push from right in LTR,
      // push from left in RTL (Arabic). Without the flip, RTL users
      // see the new screen come from the "back" side of their visual
      // flow, which reads as the route-reverse animation and breaks
      // the affordance "deeper in" = forward motion.
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      final detailOffset = isRtl ? const Offset(-0.06, 0) : const Offset(0.06, 0);
      final beginOffset = switch (kind) {
        _RouteTransitionKind.detail => detailOffset,
        _RouteTransitionKind.fade => Offset.zero,
        _RouteTransitionKind.scale => Offset.zero,
        _RouteTransitionKind.tab => const Offset(0, 0.025),
      };

      final faded = FadeTransition(opacity: curve, child: child);

      if (kind == _RouteTransitionKind.scale) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curve),
          child: faded,
        );
      }

      return SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(curve),
        child: faded,
      );
    },
  );
}
