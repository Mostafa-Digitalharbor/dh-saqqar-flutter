
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'support/app_strings_source.dart';

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
/// The literal value for [key] inside a map [body], including every line of a
/// multi-line adjacent-string concatenation.
///
/// The lookahead has to match the start of the **next key** — `'snake_case':`
/// — and nothing else. An earlier version stopped at any line beginning
/// `'[A-Za-z]`, which is also what a wrapped English sentence looks like:
///
/// ```dart
/// 'billing_pending_note':
///     'Waiting for confirmation. If you completed '
///         'this payment, contact support with reference '   // ← stopped here
///         '{ref}.',
/// ```
///
/// So English values were silently truncated at their second line while
/// Arabic ones (no Latin first letter) were captured whole — which reported a
/// placeholder mismatch that did not exist, and, worse, would have hidden any
/// real mismatch living past an English line break.
String? _valueOf(String body, String key) => RegExp(
  "'$key'\\s*:\\s*(.+?)(?=\\n\\s*'[a-z0-9_]+'\\s*:|\\n\\s*\\}\$)",
  dotAll: true,
).firstMatch(body)?.group(1);

void main() {
  final source = appStringsSource();

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

  /// The CLDR categories `AppStrings._category` can return. Arabic uses all
  /// six; English only ever asks for `one` and `other`, but a plural key
  /// still defines the full set in both tables so resolution never has to
  /// fall back (see `_p`'s doc).
  const pluralCategories = ['zero', 'one', 'two', 'few', 'many', 'other'];

  /// Base names of the plural key families, recovered from the tables by
  /// stripping a category suffix. Derived from the source rather than
  /// hand-listed so a new plural key is covered the moment it is added.
  ///
  /// A family is recognised by `_one` **and** `_other` both being present,
  /// not by `_other` alone. Four of the six CLDR category words are also
  /// ordinary English — `one`, `two`, `few`, `many`, `other` — so keying on
  /// a single suffix makes any lone key that happens to end in one of them
  /// look like a plural family and then reports its five imaginary siblings
  /// as missing. `app_group_other` (the taxonomy label "Other") did exactly
  /// that. English's own rule is `n == 1 ? one : other`, so a real family
  /// always has both halves and this cannot miss one.
  ///
  /// Nothing is lost by the tightening: a family reached through `_p` is
  /// independently expanded to all six categories and checked against the
  /// English table by the reference test below, so a family that somehow
  /// declared only `_other` is still caught there.
  final pluralBases = <String>{
    for (final k in enSet)
      for (final c in pluralCategories)
        if (k.endsWith('_$c'))
          if (enSet.contains(
                '${k.substring(0, k.length - c.length - 1)}_other',
              ) &&
              enSet.contains('${k.substring(0, k.length - c.length - 1)}_one'))
            k.substring(0, k.length - c.length - 1),
  };

  bool isPluralForm(String key) => pluralCategories.any(
    (c) =>
        key.endsWith('_$c') &&
        pluralBases.contains(key.substring(0, key.length - c.length - 1)),
  );

  test('every English key has an Arabic translation', () {
    final missing = enSet.difference(arSet).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'These keys exist in `_en` but not `_ar`, so an Arabic user '
          'sees English for them. Add an Arabic entry for each:\n'
          '${missing.join('\n')}',
    );
  });

  test('the Arabic table has no orphan keys', () {
    final orphans = arSet.difference(enSet).toList()..sort();
    expect(
      orphans,
      isEmpty,
      reason:
          'These keys exist in `_ar` but not `_en`. Since `_en` is the '
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
        reason:
            'Duplicate keys in `_$table` — the later entry silently '
            'wins over the earlier one.',
      );
    }

    expectNoDuplicates(enKeys, 'en');
    expectNoDuplicates(arKeys, 'ar');
  });

  test('every key referenced by a getter is defined in the English table', () {
    // `_t('key')` falls through to returning the raw `key` string when it
    // resolves nowhere — which leaks an identifier like `sign_in_subtitle`
    // into the UI instead of copy. Catch the typo here instead of on screen.
    // Both readers: `_t('key')` and `_f('key', {...})`. Missing `_f` here
    // would leave every interpolated string unguarded — which is most of
    // the copy that carries a user's own data.
    // Three readers, not two: `_p('key', n)` resolves `key_<category>`, so
    // its literal is a BASE name and has to be expanded before the lookup.
    // Scanning only `_t`/`_f` would leave every pluralized string unguarded
    // — and a plural key is six entries, six chances to typo one.
    final referenced =
        RegExp(
          r"_[tf]\(\s*'([A-Za-z][A-Za-z0-9_]*)'",
        ).allMatches(source).map((m) => m.group(1)!).toSet()..addAll(
          RegExp(r"_p\(\s*'([A-Za-z][A-Za-z0-9_]*)'")
              .allMatches(source)
              .expand((m) => pluralCategories.map((c) => '${m.group(1)!}_$c')),
        );

    final undefined = referenced.difference(enSet).toList()..sort();
    expect(
      undefined,
      isEmpty,
      reason:
          'These keys are read via `_t(...)` but have no `_en` entry, '
          'so `_t` would render the raw key string to the user:\n'
          '${undefined.join('\n')}',
    );
  });

  test('a translation keeps every placeholder its English source declares', () {
    // `_f` substitutes `{name}` slots. If `_ar` drops one, nothing throws —
    // the sentence just renders without the user's value ("Resend in  s",
    // "منذ  د"), which reads as a rendering glitch and is impossible to
    // spot in a 3,000-line table by eye. An *extra* placeholder is worse:
    // `_f` leaves unknown slots verbatim, so the user sees a literal
    // `{count}` on screen.
    String? valueOf(String body, String key) => _valueOf(body, key);

    final enBody = mapBody('en');
    final arBody = mapBody('ar');
    final slots = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

    final mismatches = <String>[];
    for (final key in enKeys) {
      final en = valueOf(enBody, key);
      final ar = valueOf(arBody, key);
      if (en == null || ar == null) continue;
      final enSlots = slots.allMatches(en).map((m) => m.group(1)!).toSet();
      final arSlots = slots.allMatches(ar).map((m) => m.group(1)!).toSet();
      // A plural form may legitimately drop `{n}`: Arabic carries small
      // counts in the noun's own inflection, so the natural wording of the
      // dual is "منذ يومين", with no numeral at all. Requiring equality
      // there would force "منذ 2 يومين", which is the bug this whole plural
      // pass exists to remove. The half of the rule that matters is kept —
      // Arabic must not introduce a slot English lacks, because `_f` leaves
      // an unknown `{slot}` on screen verbatim.
      if (isPluralForm(key)) {
        if (!enSlots.containsAll(arSlots)) {
          mismatches.add(
            '$key — ar declares ${arSlots.difference(enSlots).toList()..sort()} '
            'which en does not; a raw {slot} would render.',
          );
        }
        continue;
      }
      if (enSlots.length != arSlots.length || !enSlots.containsAll(arSlots)) {
        mismatches.add(
          '$key — en: ${enSlots.toList()..sort()}, '
          'ar: ${arSlots.toList()..sort()}',
        );
      }
    }

    expect(
      mismatches,
      isEmpty,
      reason:
          'These Arabic templates declare a different placeholder set '
          'than their English source, so a value goes missing (or a raw '
          '{slot} renders) for Arabic users:\n${mismatches.join('\n')}',
    );
  });

  test('every plural key defines all six CLDR categories in both tables', () {
    // `_p` builds `<base>_<category>` and hands it to `_t`, which falls back
    // to `_en[key] ?? key`. So a missing `_two` in `_ar` renders the ENGLISH
    // dual inside an Arabic sentence, and a category missing from BOTH
    // tables renders the raw identifier — `thinking_steps_two` — on screen.
    // Neither throws, neither is visible to `flutter analyze`, and Arabic's
    // `zero`/`two`/`few`/`many` are exactly the forms an English-speaking
    // author forgets. Completeness is the contract `_p` documents; this is
    // the test that holds it.
    expect(
      pluralBases,
      isNotEmpty,
      reason:
          'The scan found no plural key families — did the `_<category>` '
          'suffix convention change?',
    );

    final gaps = <String>[];
    for (final base in pluralBases.toList()..sort()) {
      for (final c in pluralCategories) {
        if (!enSet.contains('${base}_$c')) {
          gaps.add('_en is missing ${base}_$c');
        }
        if (!arSet.contains('${base}_$c')) {
          gaps.add('_ar is missing ${base}_$c');
        }
      }
    }
    expect(gaps, isEmpty, reason: gaps.join('\n'));
  });

  test('English plural forms it can never select mirror `other`', () {
    // English's CLDR rule is `n == 1 ? one : other` — it never asks for
    // `zero`, `two`, `few` or `many`. Those four entries exist only because
    // `_p` resolves without a fallback chain and so needs the full set
    // present. That makes them a trap: they sit in the table looking like
    // copy, invite an author to write "None selected" in the `zero` slot,
    // and then never render. (Which is exactly what happened here first
    // time round — English kept printing "0 selected".) Pinning them equal
    // to `other` says out loud that they are structural, not editorial.
    const unreachableInEnglish = ['zero', 'two', 'few', 'many'];
    final enBody = mapBody('en');
    final drifted = <String>[];
    for (final base in pluralBases.toList()..sort()) {
      final other = _valueOf(enBody, '${base}_other')?.trim();
      if (other == null) continue;
      for (final c in unreachableInEnglish) {
        final form = _valueOf(enBody, '${base}_$c')?.trim();
        if (form != null && form != other) {
          drifted.add('${base}_$c: $form  (≠ ${base}_other: $other)');
        }
      }
    }
    expect(
      drifted,
      isEmpty,
      reason:
          'These English plural forms differ from `_other` but English '
          'can never select them, so the wording is dead on arrival. Either '
          'copy `_other` into them, or — if the distinction is real — it '
          'belongs somewhere a call site can actually reach:\n'
          '${drifted.join('\n')}',
    );
  });

  test('no plural family keeps a pre-plural key of the same name', () {
    // Converting `foo` into `foo_one`/`foo_other`/… while leaving the old
    // flat `foo` behind leaves a key that still resolves and still reads
    // fine in review, but is now reachable only from a call site that was
    // supposed to have been migrated. The stale copy then drifts from the
    // six that are actually rendered.
    final stale = pluralBases.where(enSet.contains).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'These keys exist both as a flat entry and as a plural family. '
          'The flat one is leftover from before the conversion — delete it '
          'and point its caller at the `_p` getter:\n${stale.join('\n')}',
    );
  });

  test('Arabic copy writes its numbers in the same digits everywhere', () {
    // Arabic has two digit sets — Western (0-9) and Arabic-Indic (٠-٩) — and
    // both are correct Arabic. What is not correct is using both, because
    // the app has a third source of digits it cannot restyle: the values
    // `_f` interpolates. `{seconds}` is a Dart `int`, so it renders Western
    // whatever the surrounding sentence does.
    //
    // Five auth strings had drifted to Arabic-Indic against 1,100+ Western
    // ones, and the result was visible in a single glance on the OTP screen:
    //
    //     أرسلنا رمزًا من ٦ أرقام … تنتهي صلاحيته خلال ١٠ دقائق
    //     إعادة الإرسال خلال 51 ث          ← `{seconds}`, Western
    //
    // The password field was worse — its placeholder read '٨ أحرف على الأقل'
    // and its own validation error read 'كلمة المرور لازم تكون 8 أحرف على
    // الأقل.' Two spellings of the same number, one above the other.
    //
    // Western is the side that wins because it is the side the interpolated
    // values are already on; switching those instead would mean a digit
    // conversion at every `_f` call in the app. If that conversion is ever
    // written, this rule is what flips — deliberately, in one place.
    final arBody = mapBody('ar');
    final entry = RegExp(r"^\s*'([a-z0-9_]+)'\s*:\s*(.+)$", multiLine: true);
    final easternDigit = RegExp(r'[٠-٩]');

    final offenders = <String>[];
    for (final m in entry.allMatches(arBody)) {
      final key = m.group(1)!;
      final value = _valueOf(arBody, key);
      if (value == null) continue;
      if (easternDigit.hasMatch(value)) offenders.add('$key — $value');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These Arabic strings use Arabic-Indic digits (٠-٩) while the '
          'rest of the table — and every number `_f` interpolates — uses '
          'Western digits, so the two render side by side on one '
          'screen:\n${offenders.join('\n')}',
    );
  });

  test('every Arabic entry is actually written in Arabic', () {
    // Key parity proves an `_ar` entry EXISTS; it says nothing about whether
    // anyone translated it. A copy-pasted English value passes every other
    // check in this file and then renders Latin text inside an otherwise
    // Arabic screen — which is exactly how `english` came to read 'English'
    // beside 'العربية' on the Preferences card, and how the account footer
    // read 'Powered by Digital Harbor'.
    //
    // The test is "does this value contain any Arabic script at all", not a
    // translation-quality check. That's deliberately weak, because the
    // failure it catches is the one that actually happens: nobody typing
    // Arabic produces a value with zero Arabic letters.
    //
    // Everything below is exempt for a stated reason. Keep this list short —
    // an entry here is a promise that the value reads correctly to an Arabic
    // user *as Latin text*, which is only true for names and symbols.
    const untranslatable = <String, String>{
      // Trademarks and product names — never transliterated.
      'digital_harbor': 'company name',
      'credKindPostgres': 'product name',
      'production_domain': 'domain name',
      'product_initial': 'brand glyph',
      // The language switcher deliberately labels each target language in
      // that language, so an Arabic UI offers 'Switch language to English'.
      // Its sibling `switch_language_to_arabic` is Arabic in BOTH tables for
      // the same reason.
      'switch_language_to_english': 'labelled in its target language',
      // Format / syntax examples, identical in every locale.
      'auth_email_placeholder': 'email example',
      'email_hint': 'email example',
      'header_none_option': 'em dash',
      // File formats on the report card's chips. The web's own Arabic table
      // leaves all three Latin, and so does every Arabic Office UI — an
      // Arabic user looking for an Excel export is looking for "Excel".
      'rbFormat_excel': 'file format',
      'rbFormat_pdf': 'file format',
      'rbFormat_html': 'file format',
      // "SO/0042: Steel bracket ← Copper bracket" — three server-authored
      // product/order names joined by an arrow. Every word in it comes from
      // Odoo; the only difference between the locales is which way the
      // arrow points, which the Arabic entry already flips.
      'pulse_act_quality_swap_main': 'server-authored names and an arrow',
      // A currency figure. The rest of the price UI already renders Western
      // digits in Arabic ('$20 / شهرياً'), so a translated zero would be the
      // one price on the screen written differently from its neighbours.
      'pricing_zero': 'currency figure',
      // Internal storybook screen — developer-facing, never shipped copy.
      'storybook': 'dev screen',
      'storybook_eyebrow_mini_chip': 'dev screen',
      'storybook_eyebrow_label': 'dev screen',
      'storybook_status_pills': 'dev screen',
      'storybook_buttons': 'dev screen',
      'storybook_inputs': 'dev screen',
      'storybook_switches': 'dev screen',
      'storybook_avatars': 'dev screen',
      'storybook_glass_card': 'dev screen',
      'storybook_empty_state': 'dev screen',
      'field_rules_hint': 'dev screen',
      'with_error': 'dev screen',
      'try_again': 'dev screen',
      'sample_username': 'dev screen sample',
      'sample_user_sarah': 'dev screen sample',
      'sample_password_hint': 'dev screen sample',
    };

    final arBody = mapBody('ar');
    String? valueOf(String key) => _valueOf(arBody, key);

    final arabicScript = RegExp(r'[؀-ۿ]');
    final offenders = <String>[];
    for (final key in arKeys) {
      if (untranslatable.containsKey(key)) continue;
      final value = valueOf(key);
      if (value == null) continue;
      if (!arabicScript.hasMatch(value)) {
        offenders.add('$key = ${value.trim()}');
      }
    }
    offenders.sort();

    expect(
      offenders,
      isEmpty,
      reason:
          'These `_ar` entries contain no Arabic script, so an Arabic '
          'user reads Latin text for them. Translate each one, or — if it is '
          'a trademark, a domain or a syntax example — add it to the '
          '`untranslatable` map above with the reason:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the untranslatable allowlist has no stale entries', () {
    // An exemption that outlives its key silently grants cover to whatever
    // key is added under that name next. Fails loudly instead.
    const allowlisted = <String>[
      'digital_harbor',
      'credKindPostgres',
      'production_domain',
      'product_initial',
      'switch_language_to_english',
      'auth_email_placeholder',
      'email_hint',
      'header_none_option',
      'pricing_zero',
      'storybook',
      'storybook_eyebrow_mini_chip',
      'storybook_eyebrow_label',
      'storybook_status_pills',
      'storybook_buttons',
      'storybook_inputs',
      'storybook_switches',
      'storybook_avatars',
      'storybook_glass_card',
      'storybook_empty_state',
      'field_rules_hint',
      'with_error',
      'try_again',
      'sample_username',
      'sample_user_sarah',
      'sample_password_hint',
    ];
    final stale = allowlisted.where((k) => !arSet.contains(k)).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'These keys are exempted from the Arabic-script check but no '
          'longer exist in `_ar`. Drop them from both lists:\n'
          '${stale.join('\n')}',
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

  test('no getter picks its copy with an inline `_isArabic` ternary', () {
    // `_t` / `_f` read from the `_en` and `_ar` tables, which is what every
    // rule in this file inspects. A getter written as
    //
    //   String deleteProjectBody(String name) => _isArabic
    //       ? 'حذف الشركة "$name"؟ …'
    //       : 'Delete company "$name"? …';
    //
    // returns perfectly good Arabic and is invisible to all of them: the
    // string is not IN `_ar`, so "every English key has an Arabic
    // translation" cannot see it, "a translation keeps every placeholder"
    // cannot check it, and "every Arabic entry is actually written in
    // Arabic" never reaches it. The class doc has warned about this since
    // the interpolated getters were migrated — two survived the migration
    // anyway, which is the argument for a rule over a comment.
    final src = appStringsSource().split('\n');
    final hits = <String>[];
    for (var i = 0; i < src.length; i++) {
      final line = src[i];
      if (line.trimLeft().startsWith('///') ||
          line.trimLeft().startsWith('//')) {
        continue;
      }
      // The two legitimate readers: the table selector and the public flag.
      if (line.contains('get _table =>') || line.contains('get isArabic =>')) {
        continue;
      }
      if (RegExp(r'_isArabic\s*\?').hasMatch(line)) {
        hits.add(
          '  lib/core/i18n/app_strings.dart:${i + 1}\n      '
          '${line.trim()}',
        );
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'Copy chosen by an inline `_isArabic` ternary:\n'
          '${hits.join('\n')}\n\n'
          'Fix: add the key to BOTH `_en` and `_ar` and read it with `_t` '
          '(plain) or `_f` (with `{placeholder}` substitution). Only then '
          'do the parity rules in this file cover it.',
    );
  });

  test('lookup() falls back instead of leaking the raw key', () {
    // The credential form resolves backend-supplied `label_key`s through
    // `lookup`. An unknown key must degrade to the server's own label
    // rather than surfacing an underscore_case identifier.
    final tr = AppStrings(const Locale('ar'));
    expect(
      tr.lookup('definitely_not_a_real_key', fallback: 'Server label'),
      'Server label',
    );
    expect(tr.lookup('', fallback: 'Server label'), 'Server label');
    // A known key still resolves to real Arabic copy.
    expect(tr.lookup('credUrl'), isNotEmpty);
    expect(tr.lookup('credUrl'), isNot('credUrl'));
  });
}
