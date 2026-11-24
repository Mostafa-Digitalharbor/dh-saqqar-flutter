import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:go_router/go_router.dart';

import '../core/constants/ui_strings.dart';
import '../core/i18n/app_localizations.dart';
import '../core/routing/route_names.dart';
import '../core/theme/app_icons.dart';
import '../shared/fig/fig.dart';
import '../shared/fig/tools_sheet.dart';
import '../shared/widgets/confirm_dialog.dart';

/// Tab shell: Home / Chat / Apps / Tasks behind the floating black pill bar
/// (plus the detached ⋮ pill that opens Saqqar Tools). Chat is a full-screen
/// route that draws the same bar itself, so the shell only hosts the other
/// three tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  /// Screens reached from the ⋮ menu. They sit in the shell for its bar, but
  /// belong to no tab, so the ⋮ pill is the one highlighted.
  static bool isMoreLocation(String location) =>
      location.startsWith(RouteNames.vaultPath);

  /// The selected tab, or -1 for a [isMoreLocation] screen.
  static int indexFor(String location) {
    if (isMoreLocation(location)) return -1;
    if (location.startsWith(RouteNames.appsPath)) return 2;
    if (location.startsWith(RouteNames.tasksPath)) return 3;
    return 0;
  }

  /// Shared tab navigation used by the shell and by the chat screen's bar.
  static void go(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go(RouteNames.homePath);
      case 1:
        context.push(RouteNames.chatPath(UiStrings.newConversationId));
      case 2:
        context.go(RouteNames.appsPath);
      case 3:
        context.go(RouteNames.tasksPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selected = indexFor(location);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (selected != 0) {
          // A ⋮ screen was pushed over the tab the user came from: Back goes
          // there rather than to Home.
          if (selected == -1 && context.canPop()) {
            context.pop();
            return;
          }
          context.go(RouteNames.homePath);
          return;
        }
        await _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: 0,
              right: 0,
              bottom: (bottomInset - 10).clamp(12.0, 40.0),
              child: Center(
                child: FigNavBar(
                  index: selected,
                  showMore: selected != 0,
                  moreSelected: selected == -1,
                  onSelect: (i) => go(context, i),
                  onMore: () => showSaqqarTools(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
