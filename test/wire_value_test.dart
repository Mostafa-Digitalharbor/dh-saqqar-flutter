// The wire-coercion primitives every parser reads a JSON field through.
//
// These exist because five parsers had each grown a private copy and the
// copies had drifted — one trimmed and the others didn't, `_int` meant
// "unknown" in two files and "zero" in a third, and one `_str` was a bare
// `toString()` that would have rendered `{en: …, ar: …}` into the prompt
// bank. Every case below is one of those disagreements, pinned.
//
// The bar for all of them is *totality*: a parser runs over every message of
// every snapshot on a 1.5 s poll, so a single wrong-typed field must degrade
// to a usable value rather than throw and take the conversation down.

import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/format/wire_value.dart';

void main() {
  group('wireString', () {
    test('passes a string through untouched by default', () {
      expect(wireString('hello'), 'hello');
      expect(wireString('  padded  '), '  padded  ');
    });

    test('trims only when asked', () {
      expect(wireString('  padded  ', trim: true), 'padded');
      expect(wireString('\n line \t', trim: true), 'line');
    });

    test('stringifies numbers and bools — they are still values worth showing',
        () {
      expect(wireString(42), '42');
      expect(wireString(3.5), '3.5');
      expect(wireString(true), 'true');
      expect(wireString(false), 'false');
    });

    test('screens out maps and lists rather than printing Dart syntax', () {
      // The prompt-bank bug: a backend that starts localizing `title` sends
      // an object, and `toString()` would have rendered `{en: …, ar: …}` to
      // the user. Empty is what every caller already treats as "absent".
      expect(wireString({'en': 'Title', 'ar': 'عنوان'}), '');
      expect(wireString(['a', 'b']), '');
    });

    test('null is empty, never the word "null"', () {
      expect(wireString(null), '');
    });
  });

  group('wireList', () {
    test('passes a list through', () {
      expect(wireList([1, 2]), [1, 2]);
    });

    test('a scalar where a list was documented is empty, not a throw', () {
      expect(wireList('nope'), isEmpty);
      expect(wireList(7), isEmpty);
      expect(wireList(null), isEmpty);
      expect(wireList({'a': 1}), isEmpty);
    });
  });

  group('wireMap', () {
    test('casts a decoded JSON object to String keys', () {
      final out = wireMap(<dynamic, dynamic>{'a': 1});
      expect(out, {'a': 1});
      expect(out, isA<Map<String, dynamic>>());
    });

    test('a scalar or list is an empty map, not a throw', () {
      expect(wireMap('nope'), isEmpty);
      expect(wireMap([1]), isEmpty);
      expect(wireMap(null), isEmpty);
    });
  });

  group('wireInt', () {
    test('reads numbers, truncating a double the way the wire means it', () {
      expect(wireInt(5), 5);
      expect(wireInt(5.9), 5);
      expect(wireInt(-3), -3);
    });

    test('reads a numeric string, whitespace included', () {
      expect(wireInt('12'), 12);
      expect(wireInt('  12  '), 12);
    });

    test('null for anything that is not a number — "unknown", not zero', () {
      // This is the distinction the copies lost: a card that shows "—" for an
      // unknown count must not be handed a 0 it will render as a real answer.
      expect(wireInt('abc'), isNull);
      expect(wireInt(''), isNull);
      expect(wireInt(null), isNull);
      expect(wireInt(true), isNull);
      expect(wireInt(['1']), isNull);
    });
  });

  group('wireIntOr', () {
    test('substitutes only where the call site asked for it', () {
      expect(wireIntOr('abc', 0), 0);
      expect(wireIntOr(null, -1), -1);
      expect(wireIntOr('7', 0), 7);
      expect(wireIntOr(7, 0), 7);
    });
  });

  group('wireNum / wireDouble', () {
    test('keep fractional precision a wireInt would drop', () {
      expect(wireNum(5.5), 5.5);
      expect(wireNum('5.5'), 5.5);
      expect(wireDouble(5), 5.0);
      expect(wireDouble('  2.25 '), 2.25);
    });

    test('null for non-numeric input', () {
      expect(wireNum('abc'), isNull);
      expect(wireDouble(null), isNull);
      expect(wireDouble({'a': 1}), isNull);
    });
  });

  group('wireBool', () {
    test('only a literal true is true', () {
      expect(wireBool(true), isTrue);
      expect(wireBool(false), isFalse);
    });

    test('a truthy-looking non-bool reads false — under-warn, never over-warn',
        () {
      // `"truncated": "yes"` from a partial backend rollout must not light a
      // warning banner the user has no way to clear.
      expect(wireBool('true'), isFalse);
      expect(wireBool('yes'), isFalse);
      expect(wireBool(1), isFalse);
      expect(wireBool(null), isFalse);
    });
  });

  group('totality', () {
    test('no coercion throws on any shape the wire can produce', () {
      const shapes = <Object?>[
        null,
        '',
        'text',
        0,
        -1,
        1.5,
        true,
        false,
        <Object?>[],
        <Object?>[1, 'a'],
        <String, Object?>{},
        <String, Object?>{'k': 'v'},
      ];
      for (final v in shapes) {
        expect(() => wireString(v), returnsNormally, reason: '$v');
        expect(() => wireString(v, trim: true), returnsNormally, reason: '$v');
        expect(() => wireList(v), returnsNormally, reason: '$v');
        expect(() => wireMap(v), returnsNormally, reason: '$v');
        expect(() => wireInt(v), returnsNormally, reason: '$v');
        expect(() => wireIntOr(v, 0), returnsNormally, reason: '$v');
        expect(() => wireNum(v), returnsNormally, reason: '$v');
        expect(() => wireDouble(v), returnsNormally, reason: '$v');
        expect(() => wireBool(v), returnsNormally, reason: '$v');
      }
    });
  });
}
