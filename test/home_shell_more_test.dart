// The ⋮ menu's screens keep the bar, but highlight the ⋮ pill, not Home.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/routing/route_names.dart';
import 'package:saqqar_app/navigation/home_shell.dart';

void main() {
  test('the vault belongs to the ⋮ menu, not to a tab', () {
    expect(HomeShell.isMoreLocation(RouteNames.vaultPath), isTrue);
    expect(HomeShell.indexFor(RouteNames.vaultPath), -1);
  });

  test('tabs keep their own index', () {
    expect(HomeShell.indexFor(RouteNames.homePath), 0);
    expect(HomeShell.indexFor(RouteNames.appsPath), 2);
    expect(HomeShell.indexFor(RouteNames.tasksPath), 3);
    expect(HomeShell.isMoreLocation(RouteNames.tasksPath), isFalse);
  });
}
