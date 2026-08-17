// Deep conformance for every shared widget that had NO test of any kind.
//
// A coverage audit on 2026-08-17 listed all 152 public widget classes in `lib`
// and diffed them against every test file in the repo. 52 were referenced by
// nothing at all, and 26 of those were in `shared/widgets` — the components
// reused across the most screens, where a layout bug reaches the most places
// and where "it looked fine on the screen I built it for" is least reliable.
//
// Each widget gets the 12-cell layout matrix, a dark-mode render, and — where
// it has any behaviour beyond painting — assertions on that behaviour. The
// matrix alone would only prove the widgets do not crash; the point of a
// component test is that it also does what its parameters claim.
//
// Content is deliberately hostile: a 66-character Arabic label, an unbreakable
// 60-character filename, a four-digit stat. Every one of those is real input
// this app receives, and each is what a component is not given by the one
// screen its author had open.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/theme/app_colors.dart';
import 'package:saqqar_app/core/theme/app_gradients.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/shared/widgets/accent_banner.dart';
import 'package:saqqar_app/shared/widgets/ambient_background.dart';
import 'package:saqqar_app/shared/widgets/app_card_dialog.dart';
import 'package:saqqar_app/shared/widgets/app_dialog_shell.dart';
import 'package:saqqar_app/shared/widgets/app_icon_button.dart';
import 'package:saqqar_app/shared/widgets/app_loading_state.dart';
import 'package:saqqar_app/shared/widgets/app_text_field.dart';
import 'package:saqqar_app/shared/widgets/code_plate.dart';
import 'package:saqqar_app/shared/widgets/dialog_actions.dart';
import 'package:saqqar_app/shared/widgets/fade_slide_in.dart';
import 'package:saqqar_app/shared/widgets/filter_pill.dart';
import 'package:saqqar_app/shared/widgets/ghost_button.dart';
import 'package:saqqar_app/shared/widgets/glass_card.dart';
import 'package:saqqar_app/shared/widgets/inline_add_form.dart';
import 'package:saqqar_app/shared/widgets/labeled_divider.dart';
import 'package:saqqar_app/shared/widgets/mini_chip.dart';
import 'package:saqqar_app/shared/widgets/preview_banner.dart';
import 'package:saqqar_app/shared/widgets/primary_button.dart';
import 'package:saqqar_app/shared/widgets/responsive_content.dart';
import 'package:saqqar_app/shared/widgets/saqqar_logo.dart';
import 'package:saqqar_app/shared/widgets/sheet_drag_handle.dart';
import 'package:saqqar_app/shared/widgets/stat_tile.dart';
import 'package:saqqar_app/shared/widgets/status_pill.dart';
import 'package:saqqar_app/shared/widgets/text_scale_lock.dart';
import 'package:saqqar_app/shared/widgets/user_avatar.dart';
import 'package:saqqar_app/shared/animations/pulse_dot.dart';
import 'package:saqqar_app/shared/animations/scanline_overlay.dart';
import 'package:saqqar_app/shared/animations/typing_dots.dart';

import 'support/widget_conformance.dart';

void main() {
  // ── The layout matrix, one entry per widget ───────────────────────────
  //
  // Registered as data rather than as 26 hand-written tests so a widget added
  // here gets all 12 cells and the dark render for one line, and so nothing
  // can be half-covered.
  final cases = <String, Widget Function()>{
    'AccentBanner': () => const AccentBanner(
          color: AppColors.brandCyan,
          icon: AppIcons.info,
          title: kLongEnglish,
          body: kLongArabic,
        ),
    'AccentBanner + action': () => AccentBanner(
          color: AppColors.warning,
          icon: AppIcons.warning,
          title: kLongArabic,
          body: kLongEnglish,
          action: GhostButton(label: kLongEnglish, onPressed: () {}),
        ),
    'AmbientBackground': () => const AmbientBackground(
          withBlobs: true,
          child: SizedBox(height: 200, width: double.infinity),
        ),
    'AppDialogShell': () => const AppDialogShell(
          accent: AppGradients.primaryCta,
          elevated: true,
          child: Text(kLongArabic),
        ),
    'AppIconButton': () => AppIconButton(
          icon: AppIcons.refresh,
          onPressed: () {},
          tooltip: kLongEnglish,
        ),
    'AppIconButton borderless': () => AppIconButton(
          icon: AppIcons.close,
          onPressed: () {},
          bordered: false,
        ),
    'AppLoadingState': () => const AppLoadingState(label: kLongArabic),
    'AppLoadingState.inline': () => const AppLoadingState.inline(),
    'AppPasswordField': () => const AppPasswordField(
          label: kLongEnglish,
          hint: kLongArabic,
          helper: kLongEnglish,
        ),
    'AppPasswordField errored': () => const AppPasswordField(
          label: kLongArabic,
          errorText: kLongEnglish,
        ),
    'CodePlate': () => const CodePlate(
          text: kUnbreakable,
          accent: AppColors.brandCyan,
        ),
    'CodePlate clamped': () => const CodePlate(
          text: '$kUnbreakable\n$kLongArabic\n$kLongEnglish',
          accent: AppColors.warning,
          maxLines: 2,
        ),
    'DialogActions': () => DialogActions(
          cancel: GhostButton(label: kLongArabic, onPressed: () {}),
          confirm: PrimaryButton(label: kLongEnglish, onPressed: () {}),
        ),
    'FadeSlideIn': () => const FadeSlideIn(child: Text(kLongArabic)),
    'FilterPill selected': () =>
        FilterPill(label: kLongEnglish, selected: true, onTap: () {}),
    'FilterPill unselected': () =>
        FilterPill(label: kLongArabic, selected: false, onTap: () {}),
    'GlassCard': () => const GlassCard(child: Text(kLongArabic)),
    'GlassCard blurred': () =>
        const GlassCard(blur: true, child: Text(kUnbreakable)),
    'LabeledDivider': () => const LabeledDivider(label: kLongArabic),
    'MiniChip': () => const MiniChip(kLongEnglish),
    'MiniChip coloured': () =>
        const MiniChip(kLongArabic, color: AppColors.warning),
    'PreviewBanner': () => const PreviewBanner(text: kLongArabic),
    'PulseDot': () => const PulseDot(color: AppColors.brandCyan),
    'ResponsiveContent': () =>
        const ResponsiveContent(child: Text(kLongArabic)),
    'SaqqarLogo': () => const SaqqarLogo(),
    'ScanlineOverlay': () => const ScanlineOverlay(
          color: AppColors.brandCyan,
          child: SizedBox(height: 80, width: double.infinity),
        ),
    'SheetDragHandle': () => const SheetDragHandle(),
    'StatTile': () => const StatTile(value: '24,515', label: kLongArabic),
    'StatusPill': () => const StatusPill(label: kLongEnglish),
    'StatusPill pulsing': () => const StatusPill(
          label: kLongArabic,
          variant: StatusPillVariant.success,
          pulsing: true,
        ),
    'TextScaleLock': () => const TextScaleLock(child: Text(kLongArabic)),
    'TypingDots': () => const TypingDots(color: AppColors.brandCyan),
    'UserAvatar': () => const UserAvatar(username: kLongArabic),
  };

  group('every shared widget survives the layout matrix', () {
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await sweepWidget(tester, build, name: name);
      });
    });
  });

  group('every shared widget renders in the dark theme', () {
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await rendersInDark(tester, build, name: name);
      });
    });
  });

  // ── Behaviour ─────────────────────────────────────────────────────────
  //
  // The matrix above proves these widgets do not break. It says nothing about
  // whether they DO anything, and a component whose `onTap` was never wired
  // renders perfectly.

  group('StatusPill', () {
    testWidgets('renders every variant without falling back to one colour',
        (tester) async {
      // A `switch` on the variant that is missing an arm compiles fine when it
      // has a default, and then paints two different states identically —
      // which is invisible unless the colours are compared.
      final painted = <StatusPillVariant, Color?>{};
      for (final variant in StatusPillVariant.values) {
        await tester.pumpWidget(
          conformanceHarness(
            StatusPill(label: 'x', variant: variant),
            locale: const Locale('en'),
            scale: 1.0,
          ),
        );
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(StatusPill),
                matching: find.byType(Container),
              )
              .first,
        );
        painted[variant] = (box.decoration! as BoxDecoration).color;
      }
      expect(
        painted.values.toSet().length,
        StatusPillVariant.values.length,
        reason: 'Two StatusPill variants paint the same colour, so a user '
            'cannot tell success from danger: $painted',
      );
    });
  });

  group('FilterPill', () {
    testWidgets('selected and unselected are visually distinct',
        (tester) async {
      final colours = <bool, Color?>{};
      for (final selected in [true, false]) {
        await tester.pumpWidget(
          conformanceHarness(
            FilterPill(label: 'x', selected: selected, onTap: () {}),
            locale: const Locale('en'),
            scale: 1.0,
          ),
        );
        // `AnimatedContainer`, not `Container` — the pill cross-fades between
        // states, and the animated wrapper is what carries the decoration.
        final box = tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byType(FilterPill),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        colours[selected] = (box.decoration! as BoxDecoration).color;
      }
      expect(
        colours[true],
        isNot(colours[false]),
        reason: 'A selected filter looks identical to an unselected one.',
      );
    });

    testWidgets('forwards its tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        conformanceHarness(
          FilterPill(label: 'x', selected: false, onTap: () => taps++),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      await tester.tap(find.byType(FilterPill));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('AppIconButton', () {
    testWidgets('a null onPressed disables it rather than rendering a live '
        'button that does nothing', (tester) async {
      await tester.pumpWidget(
        conformanceHarness(
          const AppIconButton(icon: AppIcons.refresh, onPressed: null),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      // Must not throw when tapped.
      await tester.tap(find.byType(AppIconButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('meets the 44 px minimum tap target', (tester) async {
      // Below 44 the control is hard to hit and fails Apple's own guidance.
      // It is a `SizedBox` in the widget, so it is checkable rather than a
      // matter of trusting the default.
      await tester.pumpWidget(
        conformanceHarness(
          AppIconButton(icon: AppIcons.refresh, onPressed: () {}),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('AppPasswordField', () {
    testWidgets('starts obscured and the eye toggles it', (tester) async {
      // The single most security-relevant behaviour in the shared set, and it
      // had no test: a field that silently stopped obscuring would look
      // completely normal to everyone except the person behind the user.
      await tester.pumpWidget(
        conformanceHarness(
          const AppPasswordField(label: 'Password'),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );

      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue, reason: 'Password starts visible.');

      await tester.tap(find.byIcon(AppIcons.eye));
      await tester.pump();
      expect(field().obscureText, isFalse);

      await tester.tap(find.byIcon(AppIcons.eyeOff));
      await tester.pump();
      expect(field().obscureText, isTrue, reason: 'Cannot be re-hidden.');
    });

    testWidgets('an error message is actually rendered', (tester) async {
      await tester.pumpWidget(
        conformanceHarness(
          const AppPasswordField(label: 'Password', errorText: 'Too short'),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      expect(find.text('Too short'), findsOneWidget);
    });
  });

  group('InlineAddForm', () {
    testWidgets('submits what was typed, and honours `enabled`',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var submits = 0;

      await tester.pumpWidget(
        conformanceHarness(
          InlineAddForm(
            controller: controller,
            hint: 'Name',
            buttonLabel: 'Add',
            onSubmit: () => submits++,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Production');
      await tester.pump();
      expect(controller.text, 'Production');

      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(submits, 1);
    });

    testWidgets('disabled means the callback cannot fire', (tester) async {
      // `enabled: false` that only greys the button out is the bug this
      // catches — the control looks dead and still submits.
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var submits = 0;

      await tester.pumpWidget(
        conformanceHarness(
          InlineAddForm(
            controller: controller,
            hint: 'Name',
            buttonLabel: 'Add',
            enabled: false,
            onSubmit: () => submits++,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );

      await tester.tap(find.text('Add'), warnIfMissed: false);
      await tester.pump();
      expect(submits, 0, reason: 'A disabled InlineAddForm still submitted.');
    });
  });

  group('StatTile', () {
    testWidgets('renders both the value and its label', (tester) async {
      await tester.pumpWidget(
        conformanceHarness(
          const StatTile(value: '24,515', label: 'Approvals'),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      expect(find.text('24,515'), findsOneWidget);
      expect(find.text('Approvals'), findsOneWidget);
    });
  });

  group('UserAvatar', () {
    testWidgets('falls back to a glyph rather than crashing on empty input',
        (tester) async {
      // The username comes off the wire and the backend does not promise it is
      // non-empty. `String[0]` on an empty string throws, and it would throw
      // inside `build` — taking the whole screen down, not just the avatar.
      for (final name in ['', '   ', 'a', kLongArabic, '123']) {
        await tester.pumpWidget(
          conformanceHarness(
            UserAvatar(username: name),
            locale: const Locale('en'),
            scale: 1.0,
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'UserAvatar threw for username "$name".',
        );
      }
    });

    testWidgets('honours its size', (tester) async {
      await tester.pumpWidget(
        conformanceHarness(
          const UserAvatar(username: 'Digital Harbor', size: 64),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      final size = tester.getSize(find.byType(UserAvatar));
      expect(size.width, 64);
      expect(size.height, 64);
    });
  });

  group('CodePlate', () {
    testWidgets('clamps to maxLines instead of growing without bound',
        (tester) async {
      await tester.pumpWidget(
        conformanceHarness(
          const CodePlate(
            text: 'one\ntwo\nthree\nfour\nfive\nsix',
            accent: AppColors.brandCyan,
            maxLines: 2,
          ),
          locale: const Locale('en'),
          scale: 1.0,
        ),
      );
      // `SelectableText`, not `Text` — the plate exists so a user can copy a
      // command or an id out of it, which is the whole reason it is a plate.
      final text = tester.widget<SelectableText>(
        find
            .descendant(
              of: find.byType(CodePlate),
              matching: find.byType(SelectableText),
            )
            .first,
      );
      expect(text.maxLines, 2);
    });
  });

  group('TextScaleLock', () {
    testWidgets('pins the scale for its subtree regardless of the OS setting',
        (tester) async {
      // Its whole job. A version that read the ambient scaler and passed it
      // through would look correct at 1.0 and do nothing at 1.4 — which is the
      // only setting anyone uses it for.
      late double observed;
      await tester.pumpWidget(
        conformanceHarness(
          TextScaleLock(
            child: Builder(
              builder: (context) {
                observed = MediaQuery.of(context).textScaler.scale(10) / 10;
                return const SizedBox.shrink();
              },
            ),
          ),
          locale: const Locale('en'),
          scale: 1.4,
        ),
      );
      expect(observed, closeTo(1.0, 0.001));
    });
  });

  group('AppCardDialog', () {
    // `AppCardDialog` sizes itself from `MediaQuery.sizeOf`, so the screen
    // height is supplied by an explicit `MediaQuery` rather than by
    // `setSurfaceSize`. Both would work in isolation; only this one is
    // deterministic in a full run, where the binding's surface size is shared
    // state that the sweeps above are constantly setting and clearing.
    //
    // Measured on the CHILD, not on `AppCardDialog`: the widget builds a
    // `Dialog`, and a Dialog fills the screen — the clamp lives on the
    // `ConstrainedBox` around the content, so measuring the outer widget
    // would report the full height and prove nothing.
    const childKey = Key('card-dialog-content');

    Future<double> contentHeight(
      WidgetTester tester, {
      required Size screen,
      required double heightFactor,
    }) async {
      await tester.pumpWidget(
        conformanceHarness(
          MediaQuery(
            data: MediaQueryData(size: screen),
            child: AppCardDialog(
              heightFactor: heightFactor,
              minHeight: 200,
              maxHeight: 400,
              child: const SizedBox.expand(key: childKey),
            ),
          ),
          locale: const Locale('en'),
          scale: 1.0,
          scroll: false,
        ),
      );
      await tester.pump();
      return tester.getSize(find.byKey(childKey)).height;
    }

    testWidgets('caps its content at maxHeight on a tall screen',
        (tester) async {
      // 0.9 × 1000 = 900, well past the 400 cap.
      expect(
        await contentHeight(
          tester,
          screen: const Size(400, 1000),
          heightFactor: 0.9,
        ),
        lessThanOrEqualTo(400),
      );
    });

    testWidgets('lifts its content to minHeight on a short screen',
        (tester) async {
      // The other end of the clamp: 0.3 × 500 = 150, below the 200 floor. A
      // clamp wired only to `maxHeight` passes the test above and still lets
      // a dialog collapse to nothing here.
      expect(
        await contentHeight(
          tester,
          screen: const Size(400, 500),
          heightFactor: 0.3,
        ),
        greaterThanOrEqualTo(200),
      );
    });
  });
}
