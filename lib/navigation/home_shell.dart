import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/app_localizations.dart';
import '../core/routing/route_names.dart';
import '../core/theme/app_icons.dart';
import '../features/inbox/state/approvals_controller.dart';
import '../shared/extensions/context_extensions.dart';

/// Spec §4.1 — Bottom Tab Bar (5 tabs).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_TabSpec>[
    _TabSpec(
      routeName: RouteNames.chats,
      path: RouteNames.chatsPath,
      icon: AppIcons.chats,
    ),
    _TabSpec(
      routeName: RouteNames.vault,
      path: RouteNames.vaultPath,
      icon: AppIcons.key,
    ),
    _TabSpec(
      routeName: RouteNames.inbox,
      path: RouteNames.inboxPath,
      icon: AppIcons.shieldCheck,
      tracksApprovals: true,
    ),
    _TabSpec(
      routeName: RouteNames.files,
      path: RouteNames.filesPath,
      icon: AppIcons.files,
    ),
    _TabSpec(
      routeName: RouteNames.account,
      path: RouteNames.accountPath,
      icon: AppIcons.account,
    ),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path ||
          location.startsWith('${_tabs[i].path}/')) {
        return i;
      }
    }
    return 0;
  }

  String _labelFor(int i, BuildContext context) {
    return switch (i) {
      0 => context.tr.tabChats,
      1 => context.tr.tabVault,
      2 => context.tr.tabInbox,
      3 => context.tr.tabFiles,
      _ => context.tr.tabAccount,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final selected = _indexFor(location);
    final s = context.saqqar;
    final pendingApprovals = ref.watch(pendingApprovalsCountProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: s.surface.withValues(alpha: context.isDark ? 0.94 : 0.98),
              borderRadius: BorderRadius.circular(22),
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
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _NavTab(
                        spec: _tabs[i],
                        label: _labelFor(i, context),
                        selected: i == selected,
                        badgeCount: _tabs[i].tracksApprovals
                            ? pendingApprovals
                            : 0,
                        onTap: () => context.go(_tabs[i].path),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.spec,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final _TabSpec spec;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = selected ? s.brandCyan : s.muted;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? s.brandCyan.withValues(alpha: context.isDark ? 0.14 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: badgeCount > 0
                    ? Badge(
                        offset: const Offset(8, -4),
                        label: Text('$badgeCount'),
                        backgroundColor: s.warning,
                        textColor: Colors.white,
                        child: Icon(spec.icon, size: 22, color: color),
                      )
                    : Icon(spec.icon, size: 22, color: color),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style:
                    (context.text.labelSmall ?? const TextStyle()).copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
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
    this.tracksApprovals = false,
  });

  final String routeName;
  final String path;
  final IconData icon;

  /// If true, the badge count for this tab is wired to the live pending
  /// approvals provider (so it updates as the user approves/rejects).
  final bool tracksApprovals;
}
