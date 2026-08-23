// Source-scanning helpers shared by the guards that ask "is this widget
// actually tested?".
//
// The guards work by reading `lib/` for widget declarations and `test/` for
// constructions of them. That is a text search, and a text search that reads
// comments as code is worse than no guard at all: it reports coverage that
// does not exist, which is the one failure mode a coverage guard must not
// have.
//
// This has bitten twice. `widget_conformance_features_test.dart` passed with
// `ChatMarkdown` commented out of its own case list. Then
// `widget_conformance_shared_test.dart` — which never got the fix — passed
// while `EyebrowLabel` was constructed by nothing at all: its only mention
// anywhere in `test/` was the sentence "AppTextField labels render through
// EyebrowLabel (uppercased)" inside a `//` comment, and
// `RegExp('EyebrowLabel\s*\(')` matched the "(uppercased)" that followed it.
//
// One implementation, imported by both, so the next guard cannot inherit the
// bug by being written before it remembers to strip.

import 'dart:convert';
import 'dart:io';

/// [source] with `//` lines and `/* */` blocks removed.
///
/// Line-oriented rather than a full lexer, which is the right trade for
/// scanning test files: it handles the shapes Dart tests actually contain
/// (leading `//`, doc comments, block comments opened and closed on one
/// line, block comments spanning lines) and deliberately leaves a `//`
/// appearing inside a string literal alone — see the `'` check below, which
/// keeps a URL in `'https://…'` from swallowing the rest of the line.
String stripComments(String source) {
  final out = StringBuffer();
  var inBlock = false;
  for (final raw in const LineSplitter().convert(source)) {
    final trimmed = raw.trimLeft();
    if (inBlock) {
      final end = raw.indexOf('*/');
      if (end == -1) continue;
      inBlock = false;
      out.writeln(raw.substring(end + 2));
      continue;
    }
    if (trimmed.startsWith('//')) continue;
    final block = raw.indexOf('/*');
    if (block != -1 && !raw.substring(0, block).contains("'")) {
      final end = raw.indexOf('*/', block);
      if (end == -1) {
        inBlock = true;
        out.writeln(raw.substring(0, block));
      } else {
        out.writeln(raw.substring(0, block) + raw.substring(end + 2));
      }
      continue;
    }
    out.writeln(raw);
  }
  return out.toString();
}

/// Every `.dart` file under `test/`, concatenated with comments stripped.
///
/// Cached because three guards ask for it and the tree is ~100 files; the
/// scan is pure and the files do not change mid-run.
String? _testSourceCache;
String everyTestSource() => _testSourceCache ??= Directory('test')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => stripComments(f.readAsStringSync()))
    .join('\n');

/// Names of the public widget classes declared under [dir].
///
/// [recursive] follows subdirectories, which is what `lib/features` needs and
/// `lib/shared/widgets` does not.
Set<String> declaredWidgetsIn(String dir, {bool recursive = false}) {
  final pattern = RegExp(
    r'^class ([A-Z]\w+) extends State(?:less|ful)Widget',
    multiLine: true,
  );
  return {
    for (final entity in Directory(dir).listSync(recursive: recursive))
      if (entity is File && entity.path.endsWith('.dart'))
        for (final m in pattern.allMatches(entity.readAsStringSync()))
          m.group(1)!,
  };
}

/// Whether any test constructs [widget] — `Widget(`, or a named constructor
/// `Widget.variant(`.
///
/// Constructed, not merely imported or referenced: `find.byType(Foo)` proves
/// something rendered `Foo`, but it does not prove any test chose `Foo`'s
/// own inputs, which is the coverage these guards are about.
bool isConstructedByATest(String widget) =>
    RegExp('$widget' r'(?:\.\w+)?\s*\(').hasMatch(everyTestSource());
