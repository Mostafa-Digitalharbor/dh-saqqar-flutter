import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/app.dart';
import 'package:saqqar_app/core/theme/theme_controller.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
import 'package:saqqar_app/features/inbox/state/approvals_controller.dart';
import 'package:saqqar_app/shared/widgets/primary_button.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SaqqarApp(),
    ),
  );
  // The in-app launch splash holds for ~1.4 s (its minDuration) before
  // handing off to MaterialApp.router. Pump past that so the rest of the
  // shell mounts. Avoid pumpAndSettle — the home shell contains looping
  // animations (connectivity strip, shimmer placeholders) that never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('App boots into the Chats tab', (tester) async {
    await _pumpApp(tester);

    // The conversations screen renders the workspace hero card title.
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('New conversation'), findsWidgets);
  });

  test('Approval decision updates pending count', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialPending = container.read(pendingApprovalsCountProvider);
    expect(initialPending, greaterThan(0));

    // Approve the first pending approval and confirm the count drops by 1.
    final firstPending = demoApprovals.firstWhere(
      (a) => a.status == DemoApprovalStatus.pending,
    );
    container
        .read(approvalsControllerProvider.notifier)
        .decide(firstPending.id, DemoApprovalStatus.approved);

    final after = container.read(pendingApprovalsCountProvider);
    expect(after, initialPending - 1);
  });

  test('Dismissing an action shrinks the open list', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(approvalsControllerProvider).openActionsCount;
    expect(before, greaterThan(0));

    container
        .read(approvalsControllerProvider.notifier)
        .dismissAction(demoPendingActions.first.id);

    final after = container.read(approvalsControllerProvider).openActionsCount;
    expect(after, before - 1);
  });

  testWidgets('PrimaryButton survives tight RTL + scaled-text layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 159,
                child: PrimaryButton(
                  label: 'Save credential',
                  icon: Icons.save_outlined,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
