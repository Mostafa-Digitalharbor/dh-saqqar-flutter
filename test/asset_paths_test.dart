// Every path in `AssetPaths` must exist on disk AND be reachable through
// pubspec's `assets:` declaration.
//
// A wrong asset path fails at RUNTIME, not compile time: `Image.asset`
// falls through to its `errorBuilder`, which for the logo means the app
// quietly renders the text wordmark instead of the brand lockup. That is
// subtle enough to ship — the screen still looks deliberate. These assert
// the two ways it can break.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/constants/asset_paths.dart';

void main() {
  const declared = <String, String>{
    'AssetPaths.logo': AssetPaths.logo,
  };

  test('every declared asset exists on disk', () {
    final missing = <String>[];
    declared.forEach((name, path) {
      if (!File(path).existsSync()) missing.add('$name → $path');
    });
    expect(
      missing,
      isEmpty,
      reason: 'These asset paths point at files that are not in the repo, '
          'so they resolve to an errorBuilder at runtime:\n'
          '${missing.join('\n')}',
    );
  });

  test('every declared asset is covered by a pubspec assets entry', () {
    // Existing on disk is not enough — an asset outside the `assets:`
    // section is never bundled, so it is missing on device while passing
    // the check above on a developer machine.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final entries = RegExp(r'^\s+-\s+(assets/\S*)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();

    expect(entries, isNotEmpty,
        reason: 'Found no `assets:` entries in pubspec.yaml — did the '
            'section move or change shape?');

    final uncovered = <String>[];
    declared.forEach((name, path) {
      // A pubspec entry is either the exact file or a directory prefix
      // ending in `/`, which bundles everything directly inside it.
      final covered = entries.any(
        (e) => e.endsWith('/') ? path.startsWith(e) : e == path,
      );
      if (!covered) uncovered.add('$name → $path');
    });

    expect(
      uncovered,
      isEmpty,
      reason: 'These assets exist but no pubspec `assets:` entry bundles '
          'them, so they are absent from the built app:\n'
          '${uncovered.join('\n')}',
    );
  });
}
