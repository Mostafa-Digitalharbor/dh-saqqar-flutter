import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/conversations/presentation/conversations_screen.dart';
import '../../features/files/presentation/files_screen.dart';
import '../../features/inbox/presentation/inbox_screen.dart';
import '../../features/storybook/storybook_screen.dart';
import '../../features/vault/presentation/vault_screen.dart';
import '../../navigation/home_shell.dart';
import '../i18n/app_localizations.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// GoRouter config. Auth-aware redirects will be added when the auth
/// controller is wired in Sprint 2 (currently every route is reachable).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.chatsPath,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: RouteNames.signInPath,
        name: RouteNames.signIn,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const SignInScreen(),
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
                pageBuilder: (_, state) => _transitionPage(
                  state: state,
                  child: ChatScreen(
                    conversationId: state.pathParameters['id']!,
                  ),
                  kind: _RouteTransitionKind.detail,
                ),
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
            path: RouteNames.inboxPath,
            name: RouteNames.inbox,
            pageBuilder: (_, state) =>
                _transitionPage(state: state, child: const InboxScreen()),
          ),
          GoRoute(
            path: RouteNames.filesPath,
            name: RouteNames.files,
            pageBuilder: (_, state) =>
                _transitionPage(state: state, child: const FilesScreen()),
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
});

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

      final beginOffset = switch (kind) {
        _RouteTransitionKind.detail => const Offset(0.06, 0),
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
