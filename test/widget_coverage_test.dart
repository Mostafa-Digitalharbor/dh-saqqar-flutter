import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source.dart';

/// The backstop under the two per-directory coverage guards.
///
/// `widget_conformance_features_test.dart` watches `lib/features/**` and
/// `widget_conformance_shared_test.dart` watches `lib/shared/widgets/`. Both
/// are strict, and between them they cover most of the app — but "most of the
/// app" is a property of where widgets happen to live today, not a rule. Six
/// widget classes already sit outside both: `HomeShell`, `SaqqarApp`, and the
/// four in `lib/shared/animations/`. A seventh added to a new directory
/// tomorrow would be caught by nothing, and the suite would stay green while
/// coverage quietly fell.
///
/// So this scans **all of `lib/`** and asserts the leftovers are constructed
/// somewhere. It deliberately does not re-test what the other two files
/// cover; it only refuses to let a directory escape by being new.
void main() {
  test('no widget in lib/ escapes every coverage guard', () {
    final all = declaredWidgetsIn('lib', recursive: true);
    expect(all, isNotEmpty, reason: 'The scan found no widgets at all in lib/.');

    // What the two per-directory guards already own. Subtracted rather than
    // re-checked so their failure messages — which name the exact `cases` map
    // to add to — stay the ones a developer sees.
    final alreadyGuarded = {
      ...declaredWidgetsIn('lib/features', recursive: true),
      ...declaredWidgetsIn('lib/shared/widgets'),
    };

    // Deliberately not constructed by a test, each with the reason.
    const exempt = <String, String>{
      'SaqqarApp':
          'the root `MaterialApp.router`. Pumping it boots the real router, '
              'the whole provider stack and every bootstrap side effect; '
              'app_launch_dialog_test.dart and deep_links_test.dart drive '
              'those paths through the router instead, which is where the '
              'behaviour actually lives.',
    };

    final unguarded = all.difference(alreadyGuarded).toList()..sort();
    final missing = unguarded
        .where((w) => !exempt.containsKey(w))
        .where((w) => !isConstructedByATest(w))
        .toList();

    expect(
      missing,
      isEmpty,
      reason: 'These widgets live outside both conformance guards and no '
          'test constructs them:\n${missing.map((w) => '  • $w').join('\n')}\n\n'
          'Fix: give it a case in the conformance file for its area, or — if '
          'it genuinely cannot be pumped standalone — add it to `exempt` here '
          'WITH the reason.',
    );

    for (final name in exempt.keys) {
      expect(
        all,
        contains(name),
        reason: '`$name` is exempted here but no longer exists in lib/. '
            'Drop the entry.',
      );
    }
  });

  test('the guards between them still cover the whole tree', () {
    // The subtraction above is only honest if `alreadyGuarded` really is what
    // the other two files scan. If one of them narrows its directory — or is
    // deleted — the widgets it used to own would silently move into this
    // test's blind spot rather than into its `missing` list, because they
    // would still be subtracted. Pin the two scan roots to the paths those
    // files actually read.
    for (final entry in {
      'test/widget_conformance_features_test.dart': "'lib/features'",
      'test/widget_conformance_shared_test.dart': "'lib/shared/widgets'",
    }.entries) {
      final source = stripComments(File(entry.key).readAsStringSync());
      expect(
        source,
        contains(entry.value),
        reason: '${entry.key} no longer scans ${entry.value}. This backstop '
            'subtracts that directory on the assumption it does — update '
            '`alreadyGuarded` to match, or those widgets are now covered by '
            'nothing.',
      );
    }
  });
}
