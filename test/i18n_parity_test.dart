import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';

/// Guards the invariant that makes `app_strings.dart` trustworthy: the
/// English and Arabic tables must define exactly the same keys.
///
/// `AppStrings._t` falls back to `_en[key]` when the active locale has no
/// entry, so a key missing from `_ar` doesn't crash — it silently renders
/// ENGLISH inside an otherwise-Arabic screen. That's invisible to
/// `flutter analyze` and easy to miss in review, which is exactly the kind
/// of rot a guard test exists to catch.
///
/// These parse the source file rather than reading the maps directly
/// because `_en` / `_ar` are private to the `app_strings` library. Parsing
/// keeps the production file free of `@visibleForTesting` hatches opened
/// purely for a test.
void main() {
  final source =
      File('lib/core/i18n/app_strings.dart').readAsStringSync();

  /// Extracts the body of a top-level `const Map<String, String> _<name>`
  /// by brace-matching from its opening `{`.
  // Throws rather than `expect`s: this runs at collection time, outside any
  // test body, where `expect` isn't legal (OutsideTestException).
  String mapBody(String name) {
    const declSuffix = ' = {';
    final marker = '_$name$declSuffix';
    final start = source.indexOf(marker);
    if (start == -1) {
      throw StateError(
        'Could not find the `_$name` table — did app_strings.dart rename or '
        'restructure its locale maps? Update this test to match.',
      );
    }

    var i = start + marker.length;
    final bodyStart = i;
    var depth = 1;
    while (depth > 0 && i < source.length) {
      final c = source[i];
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
      }
      i++;
    }
    if (depth != 0) {
      throw StateError('Unbalanced braces while scanning `_$name`.');
    }
    return source.substring(bodyStart, i - 1);
  }

  /// Matches every `'some_key':` / `'someKey':` entry. Both cases are in
  /// use — snake_case for hand-written getters, camelCase for the keys the
  /// backend credential schema resolves through `AppStrings.lookup`.
  final keyPattern = RegExp(r"'([A-Za-z][A-Za-z0-9_]*)'\s*:");

  List<String> keysIn(String body) =>
      keyPattern.allMatches(body).map((m) => m.group(1)!).toList();

  final enKeys = keysIn(mapBody('en'));
  final arKeys = keysIn(mapBody('ar'));
  final enSet = enKeys.toSet();
  final arSet = arKeys.toSet();

  test('every English key has an Arabic translation', () {
    final missing = enSet.difference(arSet).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'These keys exist in `_en` but not `_ar`, so an Arabic user '
          'sees English for them. Add an Arabic entry for each:\n'
          '${missing.join('\n')}',
    );
  });

  test('the Arabic table has no orphan keys', () {
    final orphans = arSet.difference(enSet).toList()..sort();
    expect(
      orphans,
      isEmpty,
      reason: 'These keys exist in `_ar` but not `_en`. Since `_en` is the '
          'fallback table, an `_ar`-only key is unreachable from any getter '
          '— either the English entry was dropped or the key is dead:\n'
          '${orphans.join('\n')}',
    );
  });

  test('neither table declares a key twice', () {
    // Dart silently keeps the LAST value for a duplicated map key, so a
    // duplicate is a copy-paste bug that quietly overrides real copy.
    void expectNoDuplicates(List<String> keys, String table) {
      final seen = <String>{};
      final duplicates = <String>{};
      for (final k in keys) {
        if (!seen.add(k)) duplicates.add(k);
      }
      expect(
        duplicates.toList()..sort(),
        isEmpty,
        reason: 'Duplicate keys in `_$table` — the later entry silently '
            'wins over the earlier one.',
      );
    }

    expectNoDuplicates(enKeys, 'en');
    expectNoDuplicates(arKeys, 'ar');
  });

  test('every key referenced by a getter is defined in the English table',
      () {
    // `_t('key')` falls through to returning the raw `key` string when it
    // resolves nowhere — which leaks an identifier like `sign_in_subtitle`
    // into the UI instead of copy. Catch the typo here instead of on screen.
    final referenced = RegExp(r"_t\(\s*'([A-Za-z][A-Za-z0-9_]*)'\s*\)")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    final undefined = referenced.difference(enSet).toList()..sort();
    expect(
      undefined,
      isEmpty,
      reason: 'These keys are read via `_t(...)` but have no `_en` entry, '
          'so `_t` would render the raw key string to the user:\n'
          '${undefined.join('\n')}',
    );
  });

  test('both locales resolve real copy rather than echoing the key back', () {
    // End-to-end check through the public API: proves the tables are
    // actually wired to the getters, not just internally consistent.
    for (final locale in AppStrings.supported) {
      final tr = AppStrings(locale);
      expect(tr.appName, isNotEmpty);
      expect(tr.signIn, isNotEmpty);
      // `_t` echoes the key on a miss — assert we got copy, not 'sign_in'.
      expect(tr.signIn, isNot('sign_in'));
      expect(tr.errorNetwork, isNot('error_network'));
    }
  });

  test('lookup() falls back instead of leaking the raw key', () {
    // The credential form resolves backend-supplied `label_key`s through
    // `lookup`. An unknown key must degrade to the server's own label
    // rather than surfacing an underscore_case identifier.
    final tr = AppStrings(const Locale('ar'));
    expect(tr.lookup('definitely_not_a_real_key', fallback: 'Server label'),
        'Server label');
    expect(tr.lookup('', fallback: 'Server label'), 'Server label');
    // A known key still resolves to real Arabic copy.
    expect(tr.lookup('credUrl'), isNotEmpty);
    expect(tr.lookup('credUrl'), isNot('credUrl'));
  });
}
