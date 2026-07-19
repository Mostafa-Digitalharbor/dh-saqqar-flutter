import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/shared/widgets/confirm_dialog.dart';

/// Found by driving the real app: the Sign-out dialog's icon "box" renders as
/// a full-width bar instead of the 46×46 square the code asks for.
///
/// Cause: the dialog's body Column uses `CrossAxisAlignment.stretch`, which
/// hands every child a TIGHT full-width constraint. `Container(width: 46)`
/// resolves its own constraints via `constraints.enforce(parent)`, and a tight
/// parent wins — so the declared width is silently discarded. The icon still
/// centers itself, which is exactly why this reads as "intentional" in code
/// review and only shows up on a screen.
void main() {
  Widget harness(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      home: child,
    );
  }

  testWidgets('the confirm dialog icon stays a square, not a full-width bar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context,
                  title: 'Sign out',
                  body: 'You will need to sign in again to access your '
                      'projects and chats.',
                  confirmLabel: 'Yes',
                  cancelLabel: 'No',
                  icon: AppIcons.signOut,
                  destructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Measured via the icon's own enclosing Container rather than a named
    // widget type, so this holds regardless of how the box is implemented
    // (raw Container vs. the shared ColoredIconBox).
    final boxFinder = find
        .ancestor(
          of: find.byIcon(AppIcons.signOut),
          matching: find.byType(Container),
        )
        .first;
    final box = tester.getSize(boxFinder);

    expect(
      box.width,
      closeTo(46, 0.5),
      reason: 'The icon box asks for size: 46 but the dialog Column\'s '
          'CrossAxisAlignment.stretch forces it full-width (~${box.width}px). '
          'It must not stretch — wrap it so the tight constraint stops there.',
    );
    expect(box.height, closeTo(46, 0.5));
  });
}
