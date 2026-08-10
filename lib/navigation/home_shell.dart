import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:go_router/go_router.dart';

import '../core/i18n/app_localizations.dart';
import '../core/routing/route_names.dart';
import '../core/theme/app_icons.dart';
import '../shared/extensions/context_extensions.dart';
import '../shared/widgets/confirm_dialog.dart';
import '../core/theme/app_radius.dart';

/// 3-tab bottom shell — Chats / Vault / Account. Inbox + Files were folded
/// into the chat's own ⋯ menu (approvals and artifacts now live per-chat).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  // 3-tab shell. Inbox + Files were retired: approvals and artifacts now
  // live inside the chat's own menu so users never have to leave a chat to
  // act on its pending work.
  static const _tabs = <_TabSpec>[
    _TabSpec(
      routeName: RouteNames.chats,
      path: RouteNames.chatsPath,
      icon: AppIcons.chats,
    ),
    _TabSpec(
      routeName: RouteNames.vault,
      path: RouteNames.vaultPath,
      icon: AppIcons.projects,
    ),
    _TabSpec(
      routeName: RouteNames.account,
      path: RouteNames.accountPath,
      icon: AppIcons.account,
    ),
  ];

  int _indexFor(String location, List<_TabSpec> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      if (location == tabs[i].path || location.startsWith('${tabs[i].path}/')) {
        return i;
      }
    }
    return 0;
  }

  /// Label by route name (not index) so the visible-tab list can be filtered
  /// per plan without the labels shifting onto the wrong tabs.
  String _labelForRoute(String routeName, BuildContext context) {
    return switch (routeName) {
      RouteNames.chats => context.tr.tabChats,
      RouteNames.vault => context.tr.tabVault,
      _ => context.tr.tabAccount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final s = context.saqqar;

    // All three tabs (Chats / Vault / Account) are always shown. We used to
    // hide Vault for Free users, but that (a) dropped the tab entirely and
    // (b) desynced the bottom bar when the drawer's "Vault" action routed to
    // /vault — `_indexFor` couldn't find the missing tab and fell back to
    // Chats, so the Vault screen rendered under the Chats highlight.
    const tabs = _tabs;
    final selected = _indexFor(location, tabs);

    // Per-tab transitions are owned by the GoRouter `CustomTransitionPage`
    // pageBuilders. We MUST NOT wrap `child` in an AnimatedSwitcher here:
    // ShellRoute hands us the same Navigator (with a single GlobalKey) on
    // every rebuild, so keeping the previous instance alive during a switch
    // animation duplicates that GlobalKey and tears the tree.
    return PopScope(
      // System back at the shell root would close the app on Android.
      // Intercept it so the user gets the same Yes/No confirmation as the
      // sign-out flow — protects against accidental exits.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit(context);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: s.surface.withValues(alpha: context.isDark ? 0.94 : 0.98),
              borderRadius: AppRadius.navBarR,
              border: Border.all(color: s.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF020617,
                  ).withValues(alpha: context.isDark ? 0.32 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _NavTab(
                        spec: tabs[i],
                        label: _labelForRoute(tabs[i].routeName, context),
                        selected: i == selected,
                        onTap: () => context.go(tabs[i].path),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
    );
  }

  /// Confirms the user really wants to leave the app, then yields back to
  /// the OS via [SystemNavigator.pop]. Uses the same destructive Yes/No
  /// confirm as sign-out so the two "you're about to lose state" moments
  /// stay visually consistent.
  Future<void> _confirmExit(BuildContext context) async {
    final tr = context.tr;
    final confirmed = await ConfirmDialog.show(
      context,
      title: tr.exitAppConfirmTitle,
      body: tr.exitAppConfirmBody,
      confirmLabel: tr.confirmYes,
      cancelLabel: tr.confirmNo,
      icon: AppIcons.signOut,
      destructive: true,
    );
    if (confirmed) {
      await SystemNavigator.pop();
    }
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.spec,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = selected ? s.brandCyan : s.muted;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.bubbleR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.bubbleR,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? s.brandCyan.withValues(alpha: context.isDark ? 0.14 : 0.10)
                : Colors.transparent,
            borderRadius: AppRadius.bubbleR,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Icon(spec.icon, size: 22, color: color),
              ),
              // Material 3 pattern: only the active tab shows its label.
              // Cuts visual noise on a 5-tab bar without losing the icon
              // legend on the tab the user is currently on.
              AnimatedSize(
                duration: AppDurations.fast,
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: (context.text.labelSmall ?? const TextStyle())
                              .copyWith(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.routeName,
    required this.path,
    required this.icon,
  });

  final String routeName;
  final String path;
  final IconData icon;
}
