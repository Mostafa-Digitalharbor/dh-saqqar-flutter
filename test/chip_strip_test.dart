import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/shared/widgets/chip_strip.dart';
import 'package:saqqar_app/shared/widgets/search_and_filters_bar.dart';

/// Guards the chip strips against silent text clipping.
///
/// These need a MEASUREMENT, not `expect(takeException(), isNull)` — which is
/// how this class of bug hid for so long. A horizontal `ListView` hands its
/// children a tight cross-axis constraint, so `RenderParagraph` reports the
/// clamped height while painting the full one: the glyphs are cut, no
/// overflow banner fires, and every "does it overflow?" test stays green.
///
/// So instead: pump at 1.4× (the ceiling `app.dart` clamps to) and assert the
/// text's painted height actually FITS inside its strip. Arabic is the
/// binding case — its descenders are what got clipped.
void main() {
  Widget harness(Widget child, {double scale = 1.0, Locale? locale}) {
    final l = locale ?? const Locale('ar');
    return MaterialApp(
      locale: l,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(l),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    );
  }

  group('ChipStrip grows with text instead of clipping', () {
    for (final scale in const [1.0, 1.4]) {
      testWidgets('every label fits its strip at ${scale}x', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Arabic labels with descenders (ج / ق / ي) — the glyphs that were
        // being cut. Long enough to force horizontal scrolling too.
        const labels = ['الموافقات', 'التقارير الجاهزة', 'المهام', 'الكل'];
        await tester.pumpWidget(
          harness(
            ChipStrip(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              children: [
                for (final l in labels)
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border.all()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(l, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
            scale: scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final stripHeight = tester.getSize(find.byType(ChipStrip)).height;
        for (final label in labels) {
          final textBox = tester.getRect(find.text(label));
          final chipBox = tester.getRect(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          // The assertion that actually matters: the glyphs are inside the
          // chip that draws them, and the chip is inside the strip.
          expect(
            textBox.height,
            lessThanOrEqualTo(chipBox.height + 0.01),
            reason: '"$label" paints ${textBox.height}px inside a '
                '${chipBox.height}px chip at ${scale}x — it would be clipped.',
          );
          expect(
            chipBox.height,
            lessThanOrEqualTo(stripHeight + 0.01),
            reason: 'chip (${chipBox.height}px) exceeds the strip '
                '(${stripHeight}px) at ${scale}x.',
          );
        }
      });
    }

    testWidgets('the strip is TALLER at 1.4x than at 1.0x', (tester) async {
      // Proves the fix is real. A fixed-height SizedBox would report an
      // identical height at both scales while quietly clipping the second —
      // so equality here is the bug's own signature.
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<double> heightAt(double scale) async {
        await tester.pumpWidget(
          harness(
            const ChipStrip(
              children: [Text('الموافقات', style: TextStyle(fontSize: 12))],
            ),
            scale: scale,
          ),
        );
        await tester.pump();
        return tester.getSize(find.byType(ChipStrip)).height;
      }

      final small = await heightAt(1.0);
      final large = await heightAt(1.4);
      expect(
        large,
        greaterThan(small),
        reason: 'The strip must absorb the larger text, not clip it.',
      );
    });
  });

  group('SearchAndFiltersBar filter chips survive scaling', () {
    testWidgets('Arabic filter labels fit at 1.4x', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          SearchAndFiltersBar<String>(
            controller: controller,
            hintText: 'بحث',
            query: '',
            onQueryChanged: (_) {},
            selectedFilter: 'all',
            filters: const [
              SearchFilterOption(value: 'all', label: 'الكل'),
              SearchFilterOption(value: 'pinned', label: 'المثبّتة'),
              SearchFilterOption(value: 'archived', label: 'المؤرشفة'),
            ],
            onFilterSelected: (_) {},
          ),
          scale: 1.4,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (final label in ['الكل', 'المثبّتة', 'المؤرشفة']) {
        final text = tester.getRect(find.text(label));
        final strip = tester.getRect(find.byType(ChipStrip));
        expect(
          text.bottom,
          lessThanOrEqualTo(strip.bottom + 0.01),
          reason: '"$label" paints below the strip\'s bottom edge at 1.4x — '
              'its descenders would be cut.',
        );
      }
    });
  });
}
