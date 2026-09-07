import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/account/view/account_screen.dart';
import '../../features/apps/data/apps_api.dart';
import '../../features/apps/view/apps_screen.dart';
import '../../features/apps/view_model/apps_cubit.dart';
import '../../features/auth/view/auth_flow_screen.dart';
import '../../features/auth/view_model/auth_cubit.dart';
import '../../features/auth/view_model/auth_flow_cubit.dart';
import '../../features/auth/view_model/auth_state.dart';
import '../../features/billing/view/billing_history_screen.dart';
import '../../features/billing/view/pricing_screen.dart';
import '../../features/billing/view/usage_screen.dart';
import '../../features/support/view/voice_support_screen.dart';
import '../../features/data_api/data/odoo_data_api.dart';
import '../../features/data_api/view/data_explorer_screen.dart';
import '../../features/data_api/view_model/data_explorer_cubit.dart';
import '../../features/meetings/data/meetings_api.dart';
import '../../features/meetings/view/meetings_screen.dart';
import '../../features/meetings/view_model/meetings_cubit.dart';
import '../../features/chat/view/chat_screen.dart';
import '../../features/chat/view_model/chat_cubit.dart';
import '../../features/conversations/data/conversations_repository.dart';
import '../../features/conversations/view/conversations_screen.dart';
import '../../features/notifications/view/notifications_inbox_screen.dart';
import '../../features/push/view/devices_screen.dart';
import '../../features/share/data/shares_api.dart';
import '../../features/share/view/shared_transcript_screen.dart';
import '../../features/share/view_model/shared_transcript_cubit.dart';
import '../../features/storybook/storybook_screen.dart';
import '../../features/trial/data/trial_api.dart';
import '../../features/trial/view/trial_screen.dart';
import '../../features/trial/view_model/trial_cubit.dart';
import '../../features/vault/data/projects_api.dart';
import '../../features/vault/view/vault_screen.dart';
import '../constants/ui_strings.dart';
import '../../navigation/home_shell.dart';
import '../i18n/app_localizations.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
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
bool _isPublicShare(String location) =>
    location.startsWith(RouteNames.sharedTranscriptPrefix);

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
        // No guard: the screen self-censors. With [showPaidUpsell] off it
        // still renders the tier comparison — caps, limits, which features
        // each plan unlocks — and drops only the prices, the cycle switch and
        // the Subscribe button. That is informational, not a purchase path,
        // so the route is safe to leave open for a `saqqaar.com/pricing`
        // universal link even in the most conservative build.
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const PricingScreen(),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      GoRoute(
        path: RouteNames.usagePath,
        name: RouteNames.usage,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const UsageScreen(),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      GoRoute(
        path: RouteNames.voiceSupportPath,
        name: RouteNames.voiceSupport,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: VoiceSupportScreen(
            // Which database a filed ticket lands in. Carried on the URL
            // rather than in `extra` so it survives the route restoration
            // that `extra` does not.
            environmentId:
                state.uri.queryParameters[RouteNames.voiceSupportEnvQuery],
          ),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      GoRoute(
        path: RouteNames.notificationsPath,
        name: RouteNames.notifications,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const NotificationsInboxScreen(),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      GoRoute(
        path: RouteNames.devicesPath,
        name: RouteNames.devices,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const DevicesScreen(),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      // Saqqar Apps gallery (API_MOBILE_NEW_ENDPOINTS.md §1). Per-route
      // AppsCubit so its lifetime matches the screen; AppsApi is the
      // boot-scoped instance from main.dart's RepositoryProvider.
      GoRoute(
        path: RouteNames.appsPath,
        name: RouteNames.apps,
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: BlocProvider<AppsCubit>(
            create: (ctx) => AppsCubit(ctx.read<AppsApi>()),
            child: const AppsScreen(),
          ),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      // Managed Odoo trial (§2). Per-route TrialCubit so its poll timer is
      // cancelled on pop (close()).
      GoRoute(
        path: RouteNames.trialPath,
        name: RouteNames.trial,
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: BlocProvider<TrialCubit>(
            create: (ctx) => TrialCubit(ctx.read<TrialApi>()),
            child: const TrialScreen(),
          ),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      // Billing history & receipts (§3). Read-only; uses local screen state
      // + the boot-scoped BillingHistoryApi, so no cubit provider needed.
      GoRoute(
        path: RouteNames.billingHistoryPath,
        name: RouteNames.billingHistory,
        pageBuilder: (_, state) => _transitionPage(
          state: state,
          child: const BillingHistoryScreen(),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      // Meetings transcription (§4.1). Per-route MeetingsCubit cancels its
      // poll timer on pop.
      GoRoute(
        path: RouteNames.meetingsPath,
        name: RouteNames.meetings,
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: BlocProvider<MeetingsCubit>(
            create: (ctx) => MeetingsCubit(ctx.read<MeetingsApi>()),
            child: const MeetingsScreen(),
          ),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      // Read-only Odoo data explorer (§4.2).
      GoRoute(
        path: RouteNames.dataExplorerPath,
        name: RouteNames.dataExplorer,
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: BlocProvider<DataExplorerCubit>(
            create: (ctx) => DataExplorerCubit(
              projects: ctx.read<ProjectsApi>(),
              data: ctx.read<OdooDataApi>(),
            ),
            child: const DataExplorerScreen(),
          ),
          kind: _RouteTransitionKind.detail,
        ),
      ),
      // Billing checkout — **gone**. The app takes no payment and holds no
      // payment state: subscribing opens saqqaar.com/pricing/ in the browser
      // and the server is the only thing that decides what someone is on.
      // The screen, its API client and its models were deleted with it.
      //
      // The path survives as a pure redirect so an old deep link, a push
      // payload or a stale shortcut lands on the plan catalogue rather than a
      // "no route" error. There is no builder — this route can only forward.
      GoRoute(
        path: RouteNames.checkoutPath,
        name: RouteNames.checkout,
        redirect: (_, __) => RouteNames.pricingPath,
      ),
      GoRoute(
        path: RouteNames.sharedTranscriptPattern,
        name: RouteNames.sharedTranscript,
        pageBuilder: (context, state) {
          final token = state.pathParameters['token']!;
          return _transitionPage(
            state: state,
            // Per-route cubit: fetches the public read-only transcript for
            // this token on mount and closes on pop. `SharesApi` is the
            // boot-scoped instance from main.dart's RepositoryProvider.
            child: BlocProvider<SharedTranscriptCubit>(
              create: (ctx) =>
                  SharedTranscriptCubit(ctx.read<SharesApi>())..load(token),
              child: SharedTranscriptScreen(token: token),
            ),
            kind: _RouteTransitionKind.fade,
          );
        },
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
                    // Per-conversation page key — without it, switching from
                    // /chats/A to /chats/B reuses A's page (GoRouter keys by
                    // route pattern, not param) and the screen never loads B.
                    key: ValueKey('chat-$id'),
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
  LocalKey? key,
}) {
  return CustomTransitionPage<void>(
    // [key] overrides the default `state.pageKey` when a route needs a key
    // that varies by path parameter. GoRouter derives `pageKey` from the
    // route *pattern* (`/chats/:id`), so two different conversations
    // (`/chats/A` vs `/chats/B`) would otherwise share one page — Flutter
    // would reuse the same element and the chat screen would stay on the old
    // conversation instead of loading the picked one. The chat route passes
    // a per-id key so each conversation gets its own page.
    key: key ?? state.pageKey,
    child: child,
    transitionDuration: AppDurations.routeIn,
    reverseTransitionDuration: AppDurations.routeOut,
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
      final detailOffset = isRtl ? const Offset(-AppSlideFractions.detailPush, 0)
          : const Offset(AppSlideFractions.detailPush, 0);
      final beginOffset = switch (kind) {
        _RouteTransitionKind.detail => detailOffset,
        _RouteTransitionKind.fade => Offset.zero,
        _RouteTransitionKind.scale => Offset.zero,
        _RouteTransitionKind.tab => const Offset(0, AppSlideFractions.tabRise),
      };

      final faded = FadeTransition(opacity: curve, child: child);

      if (kind == _RouteTransitionKind.scale) {
        return ScaleTransition(
          scale: Tween<double>(begin: AppScaleFractions.routePush, end: 1)
              .animate(curve),
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
