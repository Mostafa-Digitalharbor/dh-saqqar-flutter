// Source-level guards for the invariants that keep this app localizable,
// re-themeable and RTL-correct.
//
// Every rule here exists because the codebase already drifted against it at
// least once, and because `flutter analyze` cannot see any of them — they are
// conventions, not type errors. A widget test would only catch the specific
// screen it pumps; these scan the whole tree, so a violation is caught in the
// file it is written in rather than the screen someone remembers to test.
//
// Each rule names the fix in its failure message. If a rule ever blocks
// something legitimate, widen the allowlist beside the rule — do not delete
// the rule.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/constants/ui_strings.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';

/// One scanned line of Dart source, with comments and imports already gone.
typedef _Line = ({String path, int number, String text});

/// Reads every `.dart` file under `lib/`, stripping block comments, line
/// comments and directives.
///
/// Comment stripping is what makes these rules usable: nearly every rule
/// below is *discussed* in a doc comment somewhere (often the comment
/// explaining the very bug the rule guards), and a naive `grep` would flag
/// the explanation as a violation.
List<_Line> _scanLib({List<String> exclude = const []}) {
  final out = <_Line>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (exclude.any(path.contains)) continue;

    var inBlockComment = false;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trim();

      if (inBlockComment) {
        if (trimmed.contains('*/')) inBlockComment = false;
        continue;
      }
      if (trimmed.startsWith('/*')) {
        if (!trimmed.contains('*/')) inBlockComment = true;
        continue;
      }
      if (trimmed.startsWith('//')) continue;
      if (trimmed.startsWith('import ') ||
          trimmed.startsWith('export ') ||
          trimmed.startsWith('part ')) {
        continue;
      }
      out.add((path: path, number: i + 1, text: raw));
    }
  }
  return out;
}

/// Every `.dart` file under `lib/` as whole text, with comment lines blanked
/// out but line numbering preserved.
///
/// The line-at-a-time [_scanLib] cannot see a construct that wraps, and after
/// the spacing migration most `EdgeInsets` calls DO wrap:
///
/// ```dart
/// padding: const EdgeInsets.fromLTRB(
///   AppSpacing.s16,
///   AppSpacing.s48,
/// ),
/// ```
///
/// A line-based rule looking for a bare number here would be reading
/// `AppSpacing.s16,` on its own line, with no way to tell that a `16,` there
/// is an inset rather than any other numeric argument in the app. So the
/// spacing rule needs the whole file and real paren balancing.
List<({String path, String text})> _scanFiles() {
  final out = <({String path, String text})>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    var inBlock = false;
    final kept = <String>[];
    for (final raw in file.readAsLinesSync()) {
      final trimmed = raw.trim();
      if (inBlock) {
        if (trimmed.contains('*/')) inBlock = false;
        kept.add('');
        continue;
      }
      if (trimmed.startsWith('/*')) {
        if (!trimmed.contains('*/')) inBlock = true;
        kept.add('');
        continue;
      }
      // Blank rather than drop, so a reported line number still points at the
      // right line in the editor.
      kept.add(trimmed.startsWith('//') ? '' : raw);
    }
    out.add((
      path: file.path.replaceAll(r'\', '/'),
      text: kept.join('\n'),
    ));
  }
  return out;
}

/// Index of the `)` matching the `(` at [open], skipping string literals so a
/// paren inside `'…)…'` cannot throw off the balance.
int _matchParen(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < s.length) {
        if (s[i] == r'\') {
          i += 2;
          continue;
        }
        if (s[i] == quote) break;
        i++;
      }
      continue;
    }
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _report(String rule, List<_Line> hits, String fix) {
  final where =
      hits.map((h) => '  ${h.path}:${h.number}\n      ${h.text.trim()}');
  return '$rule\n${where.join('\n')}\n\nFix: $fix';
}

/// Named parameters whose value is rendered to the user verbatim.
///
/// Declared once because the two copy rules below both need it, and a list
/// maintained in two places is one that grows in one place: the rule that
/// keeps the shorter copy silently stops covering whatever the other one
/// learned about.
///
/// Scoped to parameters that carry *sentences*. `name:`, `id:`, `slug:`,
/// `key:` and `code:` take identifiers, and including them would flag every
/// route name and wire constant in the app.
const _copyParams = [
  'label', 'hint', 'title', 'subtitle', 'message', 'tooltip',
  'semanticsLabel', 'helperText', 'errorText', 'placeholder',
  'confirmLabel', 'cancelLabel', 'retryLabel', 'actionContext',
  'emptyLabel', 'description',
  // Added after a sweep for copy-bearing parameters that no rule screened.
  // All clean at the time — which is the moment to pin them, not after the
  // first one drifts. `hintText`/`labelText` are Flutter's own spellings and
  // would otherwise have slipped past a list that only knew `hint`.
  'hintText', 'labelText', 'counterText', 'prefixText', 'suffixText',
  'semanticLabel', 'buttonLabel', 'actionLabel', 'primaryLabel',
  'secondaryLabel', 'okLabel', 'dismissLabel', 'eyebrow', 'caption',
  'headline', 'bodyText', 'footnote',
];

/// Two or more English words inside a single-quoted literal — i.e. a sentence.
///
/// Excludes anything containing `/`, `_`, `$`, `{` or a backslash: those are
/// paths, wire keys, interpolations and format strings, none of which are copy.
final _prose = RegExp(
  r"'([A-Za-z][A-Za-z0-9,\.\!\?:\-]*(?: [A-Za-z0-9,\.\!\?:\-']+)+)'",
);

/// Multi-word literals inside a view that are genuinely not user-facing copy.
///
/// Every entry needs a reason. The list existing is not a licence to add to it
/// — the default answer to a new hit is a key in `app_strings.dart`.
/// Files allowed to hold a hex colour, because the colour is not ours.
///
/// Google's sign-in mark is specified by Google's brand guidelines down to the
/// exact hex, and rendering it in Saqqar's palette would make it a different
/// logo. It is already declared as `static const` beside the painter that uses
/// it, which is where a fixed third-party constant belongs — putting it in
/// `AppColors` would imply it is themeable.
const _brandLockedColours = <String>[
  'features/auth/widgets/social_auth_buttons.dart',
];

/// Routed screens that legitimately render no `AppBar`, because they provide
/// their own way out.
///
/// Every entry needs the control named. "It looked fine when I ran it" is how
/// a screen ends up with no exit on the one path nobody opened.
const _ownsItsOwnExit = <String>{
  // The signed-out root. There is no route beneath it to go back to, and its
  // multi-step flow carries its own navigation: every step past the first
  // offers "back to sign in", and the OTP step also offers "use a different
  // email" so a typo is recoverable without restarting the app.
  'AuthFlowScreen',
};

/// Intentionally empty. The one file that legitimately carries inline English
/// — `app_error_screen.dart`, which renders when the localization scope itself
/// may have died — is exempted by path in the rule and pinned by a dedicated
/// sync test instead. Nothing else in the app has earned an exemption.
const _allowedNonCopy = <String>{};

/// `(path, line)` pairs whose literal is compiler- or developer-facing.
///
/// Computed rather than listed, because both categories span multiple source
/// lines and a line-at-a-time filter cannot see them:
///
///   * `AppLogger.warn('ChatAttachments', 'camera capture failed', …)` puts
///     its message on the third line of the call.
///   * `assert(cond, 'Either icon or hasTrack must be supplied')` wraps.
///
/// Neither is ever read by a user; asserts do not even survive a release
/// build.
final _developerFacing = () {
  final opener = RegExp(r'\b(AppLogger\.\w+|assert)\s*\(');
  final out = <(String, int)>{};
  final byFile = <String, List<_Line>>{};
  for (final l in _scanLib()) {
    byFile.putIfAbsent(l.path, () => []).add(l);
  }
  for (final lines in byFile.values) {
    for (var i = 0; i < lines.length; i++) {
      if (!opener.hasMatch(lines[i].text)) continue;
      // The opener plus the next three source lines. A window rather than
      // paren-balancing: both call shapes put their message within a line or
      // two of the opener, and a counter that mis-balances once would suppress
      // the rest of the file silently — the failure mode this rule exists to
      // prevent.
      for (var j = i; j < lines.length && j <= i + 3; j++) {
        out.add((lines[j].path, lines[j].number));
      }
    }
  }
  return out;
}();

void main() {
  final lib = _scanLib();

  group('Bundled assets are named in one place', () {
    test('no `assets/…` path is written inline', () {
      // A second copy of a path is a rename waiting to half-happen: the
      // `pubspec.yaml` entry moves, one call site follows, the other falls
      // through to an `errorBuilder` at runtime with nothing failing at
      // build time. `asset_paths_test.dart` asserts every `AssetPaths`
      // entry exists on disk — a path that never reaches that class is
      // outside that safety net entirely.
      final hits = lib
          .where((l) => !l.path.endsWith('core/constants/asset_paths.dart'))
          .where((l) => RegExp("['\"]assets/").hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Asset paths must live in `AssetPaths`:',
          hits,
          'add a `static const` to lib/core/constants/asset_paths.dart and '
              'reference it instead of the literal.',
        ),
      );
    });
  });

  group('Icons are chosen in one place', () {
    test('no bare `Icons.` reference outside AppIcons', () {
      // The app's icon set is Lucide, declared in `AppIcons`. An audit on
      // 2026-08-09 found 67 raw `Icons.*` (Material) references across 24
      // files — and two thirds of them named a concept `AppIcons` already
      // had. `Icons.error_outline` sat beside `AppIcons.error`,
      // `Icons.info_outline` beside `AppIcons.info`, `Icons.grid_view_rounded`
      // beside `AppIcons.grid`.
      //
      // So this was never only a tidiness rule: the same idea was rendering
      // in two different icon families depending on which screen you were on,
      // which is visible to anyone using the app for more than a minute.
      //
      // `AppIcons` may still reach for Material where Lucide has no
      // equivalent — biometrics, the two platform device glyphs, the
      // storybook's text-direction pair — and each of those says so at its
      // declaration. The rule is that the *choice* happens in one file.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_icons.dart'))
          .where((l) => RegExp(r'(^|[^A-Za-z_])Icons\.').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Material icon referenced directly:',
          hits,
          'use the matching `AppIcons.<role>` constant, or add one to '
              'lib/core/theme/app_icons.dart named after what it means — not '
              'after the glyph it happens to be today.',
        ),
      );
    });
  });

  group('Colours are named, not typed', () {
    test('no `Color(0x…)` literal outside app_colors.dart', () {
      // A hex colour at a call site is invisible to the theme: it does not
      // change between light and dark, it does not move when the brand does,
      // and it cannot be found by anyone grepping `AppColors`. The radius and
      // duration rules below exist for the same reason — this one closes the
      // last of the three.
      //
      // `Colors.white` / `Colors.black` are deliberately NOT flagged. They are
      // used for text and scrims painted on a brand fill, where the point is
      // that the colour does NOT follow the theme — white on the cyan pill
      // must stay white in both modes. Routing those through a token would
      // invert them in dark mode and break contrast on exactly the surfaces
      // that need it most.
      // The exemption is ONE FILE, not the theme directory. It used to be
      // `core/theme/`, and that extra breadth is exactly how five literals
      // survived a sweep: `app_theme.dart` grew its own `Color(0x40000000)`
      // and `saqqar_theme_extension.dart` grew four shadow tints, all inside
      // the blind spot — while `app_colors.dart`'s own doc comment claimed to
      // be the single home for brand hex. A palette with two homes is not a
      // palette, so the guard now names the one that counts.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_colors.dart'))
          .where((l) => RegExp(r'Color\(0x').hasMatch(l.text))
          .where((l) => !_brandLockedColours.any(l.path.endsWith))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Hex colour outside app_colors.dart:',
          hits,
          'add it to lib/core/theme/app_colors.dart and read it through '
              '`context.saqqar.<role>`, so it follows the theme and a rebrand '
              'is one file.',
        ),
      );
    });
  });

  group('Corner radii are named, not typed', () {
    test('no `BorderRadius.circular(<number>)` at a call site', () {
      // 51 radius literals had drifted across 40 files — twenty-one `12`s,
      // fifteen `10`s — while `AppRadius` already named most of those values.
      // A re-theme then has to grep for numbers, which cannot distinguish a
      // tool card's 10 from a code block's 10 from a header button's 10, and
      // cannot find the ones written as `circular(12)` when the token moved
      // to 14.
      //
      // Only *literal* radii are caught: `circular(radius)` and
      // `circular(widget.radius)` forward a caller's value, and those
      // callers' defaults are themselves `AppRadius` constants.
      //
      // The pattern is `Radius.circular(` and NOT `BorderRadius.circular(`,
      // because the second is a substring of the first and the narrower
      // spelling was the whole hole: this rule shipped watching only
      // `BorderRadius.circular(12)` while eighteen literals sat in the four
      // other spellings of the same decision —
      // `BorderRadius.all(Radius.circular(20))`,
      // `BorderRadius.vertical(top: Radius.circular(20))`,
      // `BorderRadiusDirectional.only(topStart: Radius.circular(14))` and a
      // bare `Radius.circular(999)`. Every one of them is a corner radius
      // typed at a call site, which is the thing this rule exists to stop;
      // the rule simply could not see the way they were written.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_radius.dart'))
          .where((l) => RegExp(r'Radius\.circular\(\s*[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Radius literals must come from `AppRadius`:',
          hits,
          'use the matching `AppRadius.<role>R` constant, or add one to '
              'lib/core/theme/app_radius.dart named after the surface it '
              'shapes — not after its size.',
        ),
      );
    });
  });

  group('Type and icon sizes are named, not typed', () {
    test('no `fontSize:` takes a numeric literal', () {
      // The same drift as the radius and duration rules, in the one place a
      // user reads rather than glances at. An audit on 2026-08-17 found 77
      // raw `fontSize:` literals across 36 files, and below `labelSmall` (11)
      // they had spread into SIX sizes — 9, 10, 10.5, 11, 11.5 and 12.5 —
      // with nothing recording which badge was supposed to match which.
      //
      // That is not a tidiness problem. `attachment_chip` stamped its file
      // type at 9 while `artifact_pill` stamped its kind at 10, and the two
      // render on the same message. A number cannot say whether it is the
      // same decision as its neighbour; `AppFontSizes.microCaps` can.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(r'fontSize\s*[:=]\s*[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Type size literals must come from `AppFontSizes`:',
          hits,
          'use the matching `AppFontSizes.<role>` constant, or add one to '
              'lib/core/theme/app_sizes.dart named after what the text IS — '
              'not after how big it is. Most call sites should reach for a '
              '`context.text.<style>` and not name a size at all.',
        ),
      );
    });

    test('no icon `size:` takes a numeric literal', () {
      // 139 raw icon sizes across 61 files, and the ramp they formed had
      // filled in nearly every integer from 9 to 22 — which is what a scale
      // looks like when nobody is choosing from one.
      //
      // Deliberately narrow on the two shapes that are always a design
      // decision: a `size:` NAMED ARGUMENT (`Icon(…, size: 18)`) and a
      // `this.size = 18` constructor default. A bare `size = 0` assignment is
      // excluded because `size` is also the name of a file's byte count —
      // `chat_screen.dart` computes one per attachment — and flagging that
      // would push the rule toward an allowlist of things that are not sizes
      // at all.
      final named = RegExp(r'(^|[^A-Za-z_.])(size|iconSize|dotSize)\s*:\s*[0-9]');
      final fieldDefault =
          RegExp(r'this\.(size|iconSize|dotSize)\s*=\s*[0-9]');
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) =>
              named.hasMatch(l.text) || fieldDefault.hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Icon/control size literals must come from `AppSizes`:',
          hits,
          'use `AppIconSizes.<role>` for a glyph, `AppControlSizes.<role>` '
              'for a tap target, or `AppAvatarSizes.<role>` for an avatar — '
              'or add one to lib/core/theme/app_sizes.dart named after what '
              'the glyph is doing, not how big it is.',
        ),
      );
    });
  });

  group('Spacing is named, not typed', () {
    // The last untokenized design axis, and by far the largest: a census on
    // 2026-08-17 counted 1,127 spacing literals across 118 files — more than
    // the colour, radius, duration, type and icon literals of every previous
    // sweep put together.
    //
    // It also turned up the thing none of those sweeps could: `AppSpacing`
    // already existed, was exported to Figma as the published `space/*` scale,
    // and was referenced by **zero** widgets. The design system was shipping a
    // 4 px grid (4/8/12/16/20/24/32) while the app laid out on a 2 px one —
    // its three most-used gaps (14, 10, 6) had no name on the published scale
    // at all. Nothing could have noticed, because there was no rule requiring
    // spacing to come from anywhere.

    /// The `AppSpacing` scale, read from the source so the rule can never
    /// disagree with the class about which values have names.
    final scale = () {
      final src = File('lib/core/theme/app_sizes.dart').readAsStringSync();
      final body = src.substring(src.indexOf('class AppSpacing'));
      return RegExp(r'static const double s(\d+) = ')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
    }();

    test('the scale is actually read from the class', () {
      // If the parse above ever silently returns nothing, every rule below
      // passes vacuously.
      expect(scale, isNotEmpty);
      expect(scale, contains('14'));
    });

    test('no EdgeInsets argument is a bare number', () {
      // Balanced rather than line-based: most of these calls wrap across four
      // lines, and `16,` alone on a line is indistinguishable from any other
      // numeric argument in the app.
      //
      // `0` is deliberately allowed. It is the ABSENCE of spacing — the third
      // slot of `fromLTRB(16, 4, 0, 8)` says "nothing on the end edge", which
      // is not a value anyone would re-tune and not a step on any grid.
      // `fromSTEB` is in this list because leaving it out is exactly how nine
      // sites survived the first sweep. It is `EdgeInsetsDirectional`'s own
      // spelling of `fromLTRB` — start/top/end/bottom — so it is the one an
      // RTL-correct codebase reaches for most, and a rule that knows only the
      // LTR spelling is blind in the direction this app actually ships.
      final ctor = RegExp(
        r'EdgeInsets(?:Directional)?'
        r'\.(?:all|symmetric|only|fromLTRB|fromSTEB)\(',
      );
      final bare = RegExp(r'(?<![\w.$])(\d+)(?![\d.\w])');
      final hits = <_Line>[];

      for (final file in _scanFiles()) {
        if (file.path.endsWith('core/theme/app_sizes.dart')) continue;
        var from = 0;
        while (true) {
          final m = ctor.firstMatch(file.text.substring(from));
          if (m == null) break;
          final open = from + m.end - 1;
          final close = _matchParen(file.text, open);
          if (close == -1) {
            from = open + 1;
            continue;
          }
          final region = file.text.substring(open + 1, close);
          for (final n in bare.allMatches(region)) {
            if (n.group(1) == '0') continue;
            final at = open + 1 + n.start;
            hits.add((
              path: file.path,
              number: '\n'.allMatches(file.text.substring(0, at)).length + 1,
              text: '${m.group(0)}… ${n.group(1)} …',
            ));
          }
          from = close;
        }
      }

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number inside an EdgeInsets:',
          hits,
          'use the matching `AppSpacing.s<N>` constant from '
              'lib/core/theme/app_sizes.dart. If the value has no step yet, '
              'add one — and if it is odd, prefer the neighbouring even step: '
              'the off-grid section of that class is an inventory of drift, '
              'not a menu.',
        ),
      );
    });

    test('no single-argument SizedBox gap is a bare number', () {
      // `SizedBox(height: 12)` is a GAP. The two-argument form
      // (`SizedBox(width: 20, height: 20)`) is a sized BOX — a control
      // dimension that belongs to `AppControlSizes`, not to the spacing grid —
      // so it is deliberately outside this rule.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(r'SizedBox\(\s*(?:height|width):\s*[0-9]')
              .hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a SizedBox gap:',
          hits,
          'use `AppSpacing.s<N>`. A gap is spacing; if this is really a fixed '
              'control size, give it both dimensions and name it in '
              '`AppControlSizes`.',
        ),
      );
    });

    test('no `spacing:` / `runSpacing:` gutter is a bare number', () {
      // The gutters on `Wrap`, `Row` and `Column`. Same grid as every other
      // gap, and easy to miss because they are named differently.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) =>
              RegExp(r'(?<![\w.])(?:spacing|runSpacing):\s*[0-9]')
                  .hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a layout gutter:',
          hits,
          'use `AppSpacing.s<N>`.',
        ),
      );
    });

    test('the published design scale stays wired to the step scale', () {
      // `space/xs` … `space/xxxl` are exported to Figma. They used to be their
      // own literals, which meant the export could drift from the app without
      // anything failing — the export WAS the only reader, so nothing else
      // could notice. They are aliases now, and this keeps them that way.
      final src = File('lib/core/theme/app_sizes.dart').readAsStringSync();
      const aliases = {
        'xs': 's4',
        'sm': 's8',
        'md': 's12',
        'lg': 's16',
        'xl': 's20',
        'xxl': 's24',
        'xxxl': 's32',
      };
      aliases.forEach((name, step) {
        expect(
          RegExp('static const double $name = $step;').hasMatch(src),
          isTrue,
          reason: '`AppSpacing.$name` is no longer an alias for `$step`. It is '
              'exported to Figma as `space/$name`, so a literal here lets the '
              'published design scale drift from the one the app lays out on.',
        );
      });
    });
  });

  group('Motion timings are named, not typed', () {
    test('no `duration:` takes a `Duration(...)` literal', () {
      // The same drift the radius rule above exists for, one file over.
      // `Duration(milliseconds: 220)` alone had been re-typed at ten call
      // sites across nine files while `AppDurations.cardIn` already named
      // it; 160, 200 and 280 each at two or more.
      //
      // A number cannot say whether this 200 is a control settling or a
      // panel expanding, so a re-timing of the design system's motion
      // changes some of them and misses the rest — and the ones it misses
      // are invisible until someone notices two cards animating at
      // different speeds beside each other.
      //
      // Scoped to `duration:`-family parameters on purpose. Request
      // timeouts, poll cadences and prefetch gaps are policy rather than
      // motion: they already sit in named `static const`s beside the code
      // that owns them, and they do not move when the animations are
      // re-timed.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_radius.dart'))
          .where((l) => RegExp(
                r'(duration|transitionDuration|reverseTransitionDuration)\s*:'
                r'\s*(const\s+)?Duration\(',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Motion literals must come from `AppDurations`:',
          hits,
          'use the matching `AppDurations.<role>` constant, or add one to '
              'lib/core/theme/app_radius.dart named after what is moving — '
              'not after how long it takes.',
        ),
      );
    });
  });

  group('Toasts go through the branded surface', () {
    test('`SnackBar(` is constructed only inside AppToast', () {
      // `AppToast` is the whole toast design: brand colours, the
      // success/error/info icon, the 5s-vs-3s duration split, the 420 px
      // cap and the wrapped action that dismisses before it navigates. A
      // bare `SnackBar` silently opts out of all of it — the user gets a
      // grey Material bar, and an error gets the same 3 seconds as a
      // confirmation. Seven screens had drifted this way.
      final hits = lib
          .where((l) => !l.path.endsWith('shared/widgets/app_toast.dart'))
          .where((l) => l.text.contains('SnackBar('))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Raw SnackBars bypass the app toast:',
          hits,
          'call `AppToast.show(context, message: …, variant: …)` instead.',
        ),
      );
    });
  });

  group('Locale is not compared against inline codes', () {
    test('no `languageCode == \'xx\'` literal', () {
      // `UiStrings.localeArabicCode` exists precisely so the wire code is
      // written once. Inline comparisons also tend to stand in for a
      // *direction* question, which `context.isRtl` answers correctly even
      // when a locale is forced by a parent `Directionality`.
      final hits = lib
          .where((l) => RegExp(r"""languageCode\s*==\s*['"]""").hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Locale codes must come from `UiStrings`:',
          hits,
          'use `UiStrings.localeArabicCode` / `localeEnglishCode`, or '
              '`context.isRtl` when the real question is layout direction.',
        ),
      );
    });
  });

  group('Direction-sensitive glyphs are not baked into copy', () {
    test('no ← / → inside view or widget strings', () {
      // A '←' concatenated onto a translated label keeps pointing left after
      // the tree flips to RTL, where "back" is to the right — the arrow ends
      // up aimed at the direction the user came *from*. An `Icon` chosen from
      // `context.isRtl` mirrors with the layout; a glyph in a string cannot.
      //
      // Scoped to view/widget code on purpose: cubits and services use these
      // arrows in `AppLogger` output, which no user ever sees, and
      // `app_strings` uses the direction-correct arrow per locale.
      final hits = lib
          .where((l) => l.path.contains('/view/') || l.path.contains('/widgets/'))
          .where((l) => RegExp(r"['\x22][^'\x22]*[←→][^'\x22]*['\x22]")
              .hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Directional arrows must be Icons, not string glyphs:',
          hits,
          'render `Icon(context.isRtl ? AppIcons.chevronRight : '
              'AppIcons.chevronLeft)` beside the label.',
        ),
      );
    });
  });

  group('User-facing copy is translated', () {
    test('no prose literal is passed straight to `Text()`', () {
      // The single most common way English reaches an Arabic screen. Matches
      // a literal starting with a letter and containing a space — that is
      // prose, not an identifier, a format badge or a separator.
      final hits = lib
          .where((l) => RegExp(r"""Text\(\s*['"][A-Za-z][^'"]*\s[^'"]*['"]""")
              .hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Literal copy passed to Text():',
          hits,
          'add the string to both tables in lib/core/i18n/app_strings.dart '
              'and read it via `context.tr.<key>`.',
        ),
      );
    });

    test('no prose literal is passed to a copy-bearing named parameter', () {
      // `Text()` is the obvious door, not the only one. Every parameter below
      // ends up rendered verbatim, and none of them were being checked — a
      // `GhostButton(label: 'Try again')` or an `AppErrorState(message: …)`
      // would have shipped English onto an Arabic screen with the Text() rule
      // still green.
      //
      // Scoped to the parameters that actually carry sentences — see
      // `_copyParams`. Things like `name:`, `id:` and `key:` take
      // identifiers and would be pure noise.
      const copyParams = _copyParams;
      // A capital or lowercase letter, then a space, then more — prose. An
      // identifier ('server_shell'), a slug ('max-20x'), a format tag ('PDF')
      // or a separator (' · ') has no interior space-plus-word.
      final pattern = RegExp(
        '(${copyParams.join('|')}):'
        r"""\s*['"][A-Za-z][^'"]*\s[^'"]*['"]""",
      );
      final hits = lib
          // The i18n tables ARE the English copy — that is the point of them.
          .where((l) => !l.path.contains('core/i18n/'))
          .where((l) => pattern.hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Literal copy passed to a rendered parameter:',
          hits,
          'add the string to both tables in lib/core/i18n/app_strings.dart '
              'and read it via `context.tr.<key>`.',
        ),
      );
    });

    test('no single-word literal is rendered either', () {
      // Both rules above key on an interior space, which is what makes them
      // safe against identifiers and slugs — and blind to the shortest copy
      // in any UI. `Text('Save')`, `GhostButton(label: 'Retry')` and
      // `AppErrorState(title: 'Offline')` are the labels most likely to be
      // typed inline precisely *because* they are one word, and every one of
      // them would have shipped English onto an Arabic screen with both rules
      // green.
      //
      // Letters only, two or more: that is a word. It deliberately does not
      // match a separator (`'·'`), an interpolation (`'$filesCount'`), a
      // single letter, or anything containing a digit, dash or underscore —
      // those are glyphs, values and identifiers, none of which are copy.
      const copyParams = _copyParams;
      final pattern = RegExp(
        '(Text\\(\\s*|(?:${copyParams.join('|')}):\\s*)'
        r"""['"][A-Za-z]{2,}['"]""",
      );
      final hits = lib
          .where((l) => !l.path.contains('core/i18n/'))
          .where((l) => pattern.hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Single-word literal copy:',
          hits,
          'add the word to both tables in lib/core/i18n/app_strings.dart and '
              'read it via `context.tr.<key>`. If it is genuinely not copy — '
              'a format tag like "PDF", a unit — widen this rule beside the '
              'pattern rather than deleting it.',
        ),
      );
    });
  });

  group('No English sentence is stranded in a view', () {
    test('no multi-word literal in view/widget code outside the i18n tables',
        () {
      // The three rules above key on *where* a literal is passed — into
      // `Text()`, or into one of the named parameters in `_copyParams`. That
      // is precise, and it is only as complete as the list: a sentence handed
      // to a positional argument, to a `TextSpan`, to a custom widget's own
      // parameter name, or built into a local `final` before being rendered
      // walks past all three.
      //
      // This rule comes at it from the other side — *what* the literal looks
      // like rather than where it goes. Two or more English words inside a
      // view or a widget is prose, and prose belongs in `app_strings.dart`.
      //
      // Scoped to `/view/` and `/widgets/`, the only places copy renders.
      // Cubits, services and API clients use English sentences constantly for
      // `AppLogger` output and wire values, and none of that is ever read by a
      // user.
      final hits = _scanLib()
          .where((l) =>
              l.path.contains('/view/') || l.path.contains('/widgets/'))
          .where((l) => !l.path.contains('core/i18n/'))
          // The one file that MUST carry inline English — it renders when the
          // localization scope itself may have died. Exempt here and pinned
          // instead by 'the crash-screen fallback matches its i18n twin',
          // which is a stronger check than this rule could make.
          .where((l) => !l.path.endsWith('shared/widgets/app_error_screen.dart'))
          .where((l) => !_developerFacing.contains((l.path, l.number)))
          .where((l) => _prose.hasMatch(l.text))
          .where((l) => !_prose
              .allMatches(l.text)
              .every((RegExpMatch m) => _allowedNonCopy.contains(m.group(1))))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'English prose literal inside a view:',
          hits,
          'add it to BOTH tables in lib/core/i18n/app_strings.dart and read '
              'it via `context.tr.<key>`. If it is genuinely not copy — a wire '
              'value, a MIME type, a debug label — add it to '
              '`_allowedNonCopy` beside this rule with a note saying why.',
        ),
      );
    });
  });

  group('No screen can trap the user', () {
    test('every screen the router builds offers a way back', () {
      // A pushed route with no app bar has no back button, and on iOS no
      // edge-swipe either — the user is inside a screen with no way out but
      // killing the app. It is the one class of bug where "nothing crashed"
      // and "the app is broken" are the same state.
      //
      // The screen list is read from the ROUTER rather than written here, so
      // a route added tomorrow is covered the day it is added rather than the
      // day someone remembers this file.
      //
      // `AppBar` is the check because Flutter's `automaticallyImplyLeading`
      // renders the back affordance from it whenever the route can pop —
      // which is also why suppressing it is the usual way this breaks.
      final router = File('lib/core/routing/app_router.dart').readAsStringSync();
      final built = RegExp(r'\b([A-Z][A-Za-z]*Screen)\(')
          .allMatches(router)
          .map((m) => m.group(1)!)
          .toSet();

      expect(built, isNotEmpty, reason: 'router parse found no screens');

      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final trapped = <String>[];
      for (final screen in built) {
        if (_ownsItsOwnExit.contains(screen)) continue;
        final file = files.firstWhere(
          (f) => f.readAsStringSync().contains('class $screen extends'),
          orElse: () => File(''),
        );
        if (file.path.isEmpty) continue; // not ours to police
        final src = file.readAsStringSync();
        if (!RegExp(r'AppBar\(|PageScaffold\(').hasMatch(src)) {
          trapped.add('$screen (${file.path.replaceAll(r'\', '/')})');
        }
      }

      expect(
        trapped,
        isEmpty,
        reason: 'These routed screens render no AppBar/PageScaffold, so a user '
            'who opens one cannot get back:\n  ${trapped.join('\n  ')}\n\n'
            'Fix: give the screen an `AppBar` (the back button is automatic), '
            'or add it to `_ownsItsOwnExit` beside this rule with a note '
            'saying which control lets the user leave.',
      );
    });

    test('`go` is only ever used to reach a tab', () {
      // The hole the test above could not see. It checks the SCREEN; this bug
      // was at the CALL SITE.
      //
      // `context.go` REPLACES the location. That is correct for a shell tab —
      // `/chats`, `/vault`, `/account` — because the bottom navigation stays
      // on screen and is itself the way out. It is a trap for anything above
      // the shell: the new route has nothing to pop back to, so its AppBar
      // renders no back button, and being outside the shell there is no
      // bottom bar either.
      //
      // Reported by the user: opening **Saqqar Apps** from the chat's `+`
      // menu used `go` to `/apps`, a top-level route. It destroyed the chat's
      // route and landed on a screen with no exit at all — the only way out
      // was to force-quit the app. `AppsScreen` has an AppBar, so the
      // screen-level rule passed it happily.
      final tabs = {'chatsPath', 'vaultPath', 'accountPath', 'chatPath'};
      final hits = lib
          .where((l) => !l.path.endsWith('core/routing/app_router.dart'))
          .where((l) => RegExp(r'\.go(Named)?\(\s*RouteNames\.').hasMatch(l.text))
          .where((l) {
            final target = RegExp(r'RouteNames\.(\w+)').firstMatch(l.text);
            return target != null && !tabs.contains(target.group(1));
          })
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          '`go` to a non-tab route strands the user:',
          hits,
          'use `context.pushNamed(...)` so the screen gets a back button. '
              '`go` is only safe for a shell tab, where the bottom navigation '
              'is the way out.',
        ),
      );
    });

    test('the lock screen keeps its escape hatch', () {
      // `AppLockScreen` is the one full-screen surface with no app bar, and
      // deliberately so — a back button on a lock defeats the lock. That makes
      // its sign-out button the ONLY way out for someone whose fingerprint
      // stops being recognised. Losing it stops being a UI regression and
      // becomes "the app is bricked until you reinstall".
      final src =
          File('lib/features/security/view/app_lock_screen.dart')
              .readAsStringSync();

      expect(
        src.contains('showSignOutFlow'),
        isTrue,
        reason: 'AppLockScreen must keep a sign-out escape hatch — it has no '
            'back button by design, so this is the only exit for a user who '
            'cannot authenticate.',
      );
    });
  });

  group('setState never returns a value', () {
    test('no arrow-form setState assigns from a call', () {
      // `setState(() => _future = api.list())` returns the value of the
      // assignment, and that value is a `Future`. The framework asserts on
      // exactly that shape, because a closure handing back a Future is nearly
      // always someone awaiting inside `setState`.
      //
      // The assignment itself was fine and the screen reloaded correctly —
      // which is what made it survive: it throws only in debug and profile,
      // and only on the path it guards (returning to the pricing screen from
      // the browser). Once the Sentry bridge was wired it started reporting
      // itself as an app error too. Caught on a real device on 2026-08-09.
      //
      // Narrow on purpose: an arrow that assigns a *literal* or a field
      // (`setState(() => _open = true)`) is idiomatic and returns a bool or a
      // String, which is harmless. Only an assignment whose right-hand side
      // is a CALL can hand back a Future, so only that shape is flagged, and
      // the fix is always the same — use a block body.
      final hits = lib
          .where((l) => RegExp(
                r'setState\(\(\)\s*=>\s*[_a-zA-Z][\w.]*\s*=\s*[^=].*\(',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Arrow setState assigning from a call:',
          hits,
          'give `setState` a block body — `setState(() { x = f(); })` — so '
              'the closure returns void and can never hand back a Future.',
        ),
      );
    });
  });

  group('Sentry keeps the binding it needs', () {
    test('the binding is only ever ensured as SentryWidgetsFlutterBinding',
        () {
      // A Flutter binding is a process-wide singleton: whichever type is
      // instantiated FIRST wins forever. `main` ensures one before
      // `SentryFlutter.init` runs, so ensuring the plain
      // `WidgetsFlutterBinding` there left Sentry's frame-tracking
      // integration with a binding it cannot hook. It disabled itself at
      // boot —
      //   "FramesTrackingIntegration disabled: incompatible binding"
      // — and every slow-frame and frozen-frame metric was silently never
      // collected. Nothing failed; the data just never existed.
      //
      // Seen on a real device on 2026-08-09. The call site looks like
      // ordinary Flutter boilerplate, which is exactly why it needs a guard:
      // `SentryWidgetsFlutterBinding` reads like a typo to anyone tidying
      // imports, and reverting it costs nothing visible.
      final hits = lib
          .where((l) => RegExp(r'(?<!Sentry)WidgetsFlutterBinding\s*\.\s*'
                  r'ensureInitialized')
              .hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Plain WidgetsFlutterBinding.ensureInitialized():',
          hits,
          'use `SentryWidgetsFlutterBinding.ensureInitialized()` — it is a '
              'subclass, so nothing else changes, and it is the only way '
              "Sentry's frame metrics survive boot.",
        ),
      );
    });
  });

  group('The one screen that cannot be localized stays in sync', () {
    test('the crash-screen fallback matches its i18n twin', () {
      // `AppErrorScreen` renders when something threw, and the thing that
      // threw may be the localization scope — so it carries inline English for
      // the case where `AppLocalizations` is not above it. That inline copy is
      // the only user-facing English in the app that no key can replace, which
      // makes it the only user-facing English that can silently disagree with
      // the rest of the product.
      //
      // Its own comment says "The English here must match `crash_screen_*` in
      // app_strings" — a comment cannot enforce that, so this does.
      final source =
          File('lib/shared/widgets/app_error_screen.dart').readAsStringSync();
      final en = AppStrings(const Locale(UiStrings.localeEnglishCode));

      for (final key in ['crash_screen_title', 'crash_screen_body']) {
        final expected = en.lookup(key);
        expect(
          expected,
          isNotEmpty,
          reason: '$key is missing from the English table',
        );
        // The literal is wrapped across source lines, so compare on collapsed
        // whitespace rather than an exact substring.
        final flat = source.replaceAll(RegExp(r"'\s*\n\s*'"), '');
        expect(
          flat.contains(expected),
          isTrue,
          reason: 'app_error_screen.dart no longer contains the English for '
              '$key ("$expected"). The crash screen would show one sentence '
              'when localization survives and a different one when it does '
              'not — update the inline fallback to match.',
        );
      }
    });
  });

  group('Every endpoint is declared in ApiEndpoints', () {
    test('no `/api/…` path is written inline', () {
      // `ApiEndpoints` pins all 76 paths to `/api/v1/`. A path typed at a
      // call site skips that pin, so it keeps hitting the unversioned `/api/`
      // alias and would be the one request that breaks the day `/api/v2/`
      // changes the contract.
      final hits = lib
          .where((l) => !l.path.endsWith('core/network/api_endpoints.dart'))
          .where((l) => RegExp("['\"]/api/").hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'API paths must live in `ApiEndpoints`:',
          hits,
          'add a `static const` to lib/core/network/api_endpoints.dart.',
        ),
      );
    });

    test('no absolute http(s) URL is hardcoded', () {
      // The base URL is a `--dart-define` so a staging build can point
      // somewhere else. A literal `https://saqqaar.com/...` would keep
      // talking to production from a staging build.
      final hits = lib
          .where((l) =>
              !l.path.endsWith('core/network/api_endpoints.dart') &&
              !l.path.endsWith('firebase_options.dart') &&
              !l.path.endsWith('core/constants/ui_strings.dart'))
          .where((l) => RegExp("['\"]https?://").hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Absolute URLs must be centralised:',
          hits,
          'derive it from `ApiEndpoints.baseUrl`, or name it in `UiStrings` '
              'if it is display-only sample text.',
        ),
      );
    });
  });

  group('An absent response body is never defaulted away', () {
    test('no API client substitutes a value for `res.data`', () {
      // `res.data` is null when the transport delivered NO BODY — a proxy
      // that stripped the payload, a gateway answering its own health check,
      // a CDN serving a cached 200 with `Content-Length: 0`. Dio reports
      // complete success, so this never reaches `ErrorInterceptor`; the
      // client alone decides what an absent body means.
      //
      // Twelve of them answered `?? const {}`, which is not a null-safety
      // formality — it manufactures a body the server never sent, and every
      // field below it then reads its own null-tolerant default. What came
      // out was a complete, plausible, entirely invented answer: `/usage/`
      // rendered a paying account as "Free · 0 of 0", `share/` produced a
      // blank link for the OS share sheet, and `account/delete/` reported an
      // irreversible deletion as done. None of them threw, so none of them
      // offered a retry — strictly worse than an error screen, because the
      // user cannot tell the app failed to ask.
      //
      // `requiredBody` / `postJson` / `getJson` in core/network make the
      // absent body a `ParseFailure` → "unexpected response from the
      // server". A body that IS present but empty (`{}`) is a different
      // question and each endpoint still answers it its own way.
      final hits = lib
          .where((l) => l.path.endsWith('_api.dart'))
          .where((l) => RegExp(r'\.data\s*\?\?').hasMatch(l.text))
          // `logout` is the deliberate exception: the caller clears local
          // state regardless of what the server says, so "no body" really
          // does mean "sign out anyway".
          .where((l) => !l.text.contains("['revoked']"))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'An absent response body was defaulted into data:',
          hits,
          'read it through `res.requiredBody` (or `dio.postJson` / '
              '`dio.getJson`) from lib/core/network/response_body.dart, so a '
              'bodiless 200 raises instead of inventing an answer. '
              '`api_hostile_response_test.dart` pins every client against '
              'this.',
        ),
      );
    });
  });

  group('Failure states cannot carry untranslated copy', () {
    test('`DataFailure` exposes no `message` field', () {
      // `DataFailure` used to require a `String message`, which cubits had to
      // author with no `BuildContext` to localize against — so all seven
      // wrote English. It rendered only when `error` was null, which made it
      // a latent trap rather than a visible bug. Keeping the field gone is
      // what forces every failure through `ApiErrorMapper`.
      final source = File('lib/core/state/data_state.dart').readAsStringSync();

      expect(
        RegExp(r'\bfinal\s+String\s+message\b').hasMatch(source),
        isFalse,
        reason: 'DataFailure must not reintroduce a `message` field — the '
            'view localizes `error` through ApiErrorMapper instead.',
      );
    });
  });

  group('A per-conversation setting stays in its conversation', () {
    test('flipping Task prep in an existing chat writes no device default', () {
      // Reported by the user: turning Task prep on in one chat turned it on
      // in every other chat.
      //
      // The read is `conversation.taskPrep ?? TaskPrepCubit.state`, and the
      // backend keeps the column nullable and defaulted to null — so every
      // conversation nobody has flipped yet renders from the device default.
      // `_setTaskPrep` wrote BOTH the PATCH and that default on every flip, so
      // one flip re-rendered all of them.
      //
      // A widget test cannot see this: it would need two chats, two snapshots
      // and a shared preferences store, and it would still only prove the case
      // it happened to set up. The rule is simply that the device default is
      // written on the NEW-chat branch only, which is checkable where it is
      // written.
      final source =
          File('lib/features/chat/view/chat_screen.dart').readAsStringSync();
      final body = RegExp(
        r'void _setTaskPrep\(bool value\) \{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(source)?.group(1);

      expect(body, isNotNull, reason: '_setTaskPrep not found — rename?');

      // Cut out the new-chat branch, then look at what is LEFT. Asking
      // "is there a write inside the branch?" is not the question — there is
      // supposed to be one there. The question is whether any write survives
      // outside it, and the only way to ask that is to remove the legitimate
      // one first.
      //
      // (Written this way after the first attempt — `if (_isNewChat) …
      // TaskPrepCubit.set` anywhere in the body — passed happily against a
      // deliberately reintroduced leak, because the legitimate write inside
      // the branch satisfied it.)
      final newChatBranch = RegExp(
        r'if \(_isNewChat\) \{.*?\n    \}',
        dotAll: true,
      ).firstMatch(body!)?.group(0);

      expect(
        newChatBranch,
        isNotNull,
        reason: '_setTaskPrep no longer branches on `_isNewChat` — this rule '
            'cannot tell the two writes apart any more.',
      );

      final outsideBranch = body.replaceFirst(newChatBranch!, '');

      expect(
        outsideBranch.contains('TaskPrepCubit>().set('),
        isFalse,
        reason: '_setTaskPrep writes the device-wide TaskPrepCubit outside the '
            '`_isNewChat` branch.\n\n'
            'That default is the fallback for every conversation the server '
            'has no value for, so writing it from an existing chat turns the '
            'toggle on in all of them — the bug this rule exists for.\n\n'
            'Fix: PATCH the conversation only. Write the device default just '
            'for a chat that does not exist server-side yet, where there is '
            'nothing to PATCH and it is what the first send carries.',
      );
    });
  });

  group('The iOS minimum is one number in three files', () {
    // Two separate App Store failures came out of these three declarations
    // disagreeing, and **neither one is visible from this machine** — Windows
    // cannot run `flutter build ios` at all, so nothing catches them until
    // App Store Connect has already accepted the binary:
    //
    //   * The key missing from AppFrameworkInfo.plist → hard rejection at
    //     validation, `MinimumOSVersion in
    //     'Runner.app/Frameworks/App.framework' is ''`.
    //   * Any of them below 15.0 → `ITMS-90068: MinimumOSVersion too low`,
    //     emailed after the build reaches TestFlight and shown as a yellow
    //     warning triangle beside it. A warning today; from Spring 2027 App
    //     Store Connect refuses the upload outright.
    //
    // CI is green either way — the archive builds, signs and *uploads* before
    // anything objects — which is exactly why the check lives here instead.
    //
    // The Podfile's `post_install` floor covers a fourth surface (each pod
    // carries its own MinimumOSVersion and Apple validates the lowest in the
    // bundle) but is deliberately not asserted on: it is an implementation
    // shape, not a declaration, and pinning a regex to it would fail on an
    // honest rewrite.
    const floor = 15.0;

    /// Every place the minimum is declared, as `label -> raw value`.
    /// Missing files are reported as such rather than silently skipped —
    /// a rule that passes because it read nothing is worse than no rule.
    Map<String, String> declarations() {
      String read(String path) {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: '$path is missing — this rule cannot check what it cannot '
              'read. If the file moved, update the path here.',
        );
        return file.readAsStringSync();
      }

      final found = <String, String>{};

      final plist = RegExp(
        r'<key>MinimumOSVersion</key>\s*<string>([\d.]+)</string>',
      ).firstMatch(read('ios/Flutter/AppFrameworkInfo.plist'));
      if (plist != null) {
        found['AppFrameworkInfo.plist MinimumOSVersion'] = plist.group(1)!;
      }

      final podfile = RegExp(
        r"^platform :ios, '([\d.]+)'",
        multiLine: true,
      ).firstMatch(read('ios/Podfile'));
      if (podfile != null) found['Podfile platform :ios'] = podfile.group(1)!;

      final pbx = RegExp(
        r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
      ).allMatches(read('ios/Runner.xcodeproj/project.pbxproj'));
      for (final (index, match) in pbx.indexed) {
        found['project.pbxproj IPHONEOS_DEPLOYMENT_TARGET #${index + 1}'] =
            match.group(1)!;
      }

      return found;
    }

    test('every one of them is declared', () {
      final found = declarations();

      expect(
        found.keys,
        contains('AppFrameworkInfo.plist MinimumOSVersion'),
        reason: 'ios/Flutter/AppFrameworkInfo.plist has no MinimumOSVersion.\n\n'
            'The archive still builds, signs and uploads — then App Store '
            "Connect rejects it with `MinimumOSVersion in "
            "'Runner.app/Frameworks/App.framework' is ''`. That is how it was "
            'lost once already: removed as part of an unrelated migration, '
            'and nothing noticed for six weeks.\n\n'
            'Fix: <key>MinimumOSVersion</key><string>$floor</string>.',
      );

      expect(
        found.keys,
        contains('Podfile platform :ios'),
        reason: 'ios/Podfile has no top-level `platform :ios, \'…\'` line. '
            'Without it CocoaPods picks its own default for every pod.',
      );

      expect(
        found.keys.where((k) => k.startsWith('project.pbxproj')),
        isNotEmpty,
        reason: 'No IPHONEOS_DEPLOYMENT_TARGET in project.pbxproj — either the '
            'project stopped declaring one or this rule\'s pattern is stale.',
      );
    });

    test('none is below the floor Apple enforces', () {
      final tooLow = <String, String>{
        for (final entry in declarations().entries)
          if ((double.tryParse(entry.value) ?? 0) < floor)
            entry.key: entry.value,
      };

      expect(
        tooLow,
        isEmpty,
        reason: 'These declare an iOS minimum below $floor:\n'
            '${tooLow.entries.map((e) => '  • ${e.key} = ${e.value}').join('\n')}'
            '\n\nApple emails `ITMS-90068: MinimumOSVersion too low` for the '
            'build and flags it in TestFlight, and refuses the upload entirely '
            'from Spring 2027.\n\n'
            'Raising the floor costs no devices: every iPhone that can run '
            'iOS 13 can run iOS 15 — the 6s is the oldest for both.',
      );
    });

    test('they all agree with each other', () {
      final found = declarations();
      final distinct = found.values.toSet();

      expect(
        distinct.length,
        1,
        reason: 'The iOS minimum is declared ${found.length} times and '
            '${distinct.length} different values came back:\n'
            '${found.entries.map((e) => '  • ${e.key} = ${e.value}').join('\n')}'
            '\n\nApple validates the LOWEST minimum in the bundle, so the '
            'smallest of these is the one that counts — raising only some of '
            'them changes nothing except where the problem is visible.\n\n'
            'The Share Extension is a separate target with its own copy; it '
            'has to move too.',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // The 2026-08-18 token sweep.
  //
  // The rules above named colour, radius, type size, icon size, spacing and
  // motion. A census on 2026-08-18 found the axes they did NOT cover still
  // carrying 640 bare literals: opacity (170), line height (80), letter
  // tracking (54), the dark/light alpha ternary (54), box dimensions (283 in
  // the two-argument form the SizedBox rule deliberately skipped), border
  // widths (29), shadow geometry (20), stroke widths (18), elevations (14)
  // and content max-widths (17).
  //
  // Every one of them is now a token. These rules are what stop the 641st.
  // ─────────────────────────────────────────────────────────────────────────

  group('Opacity is named, not typed', () {
    test('no `alpha:` takes a bare number', () {
      // 170 of these, at 31 distinct values — including `0.2` alongside
      // `0.20` and `0.4` alongside `0.40`, which are the same level written
      // two ways and could therefore never be counted by anyone grepping for
      // one of the spellings.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(r'\balpha:\s*[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in an alpha:',
          hits,
          'use `AppAlphas.a<NN>` from lib/core/theme/app_sizes.dart, or one '
              'of its semantic aliases (`fill`, `border`, `scrim`, `shadow`, '
              '`deemphasis`). If the level has to differ between light and '
              'dark, use `context.alpha(AppAlphaPairs.<name>)` instead — see '
              'the next rule.',
        ),
      );
    });

    test('no brightness ternary picks an opacity inline', () {
      // The rule above cannot see these: `alpha: context.isDark ? 0.55 : 0.9`
      // has no digit directly after `alpha:`. That blind spot is why the
      // first sweep of 170 literals left all 54 of these untouched, and why
      // one role — a translucent panel — ended up written twelve different
      // ways with nothing able to notice.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(
                r'alpha:\s*[\w.]*is(?:Dark|Light)\s*\?',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Inline brightness ternary choosing an opacity:',
          hits,
          'use `context.alpha(AppAlphaPairs.<name>)`. If no existing pair '
              'fits, add one to `AppAlphaPairs` — that class is the census of '
              'how many distinct pairs this app really has, and it only stays '
              'honest if new ones land in it.',
        ),
      );
    });
  });

  group('Type metrics beyond size are named', () {
    test('no `letterSpacing:` takes a bare number', () {
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) =>
              RegExp(r'\bletterSpacing:\s*-?[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a letterSpacing:',
          hits,
          'use `AppLetterSpacing.<role>`. Positive values are for uppercase '
              'labels (the smaller the caps, the wider the tracking); the '
              'negative ones are optical tightening for headings and are '
              'chosen against a specific text-theme role.',
        ),
      );
    });

    test('no TextStyle `height:` takes a bare number', () {
      // Scoped to fractional values. `height:` is Flutter's most overloaded
      // parameter name — a `SizedBox`, a `Container`, a `Divider` and a
      // `TextStyle` all take one — but only line heights are written as a
      // multiple, and every box dimension in this app is now a token, so a
      // bare `1.x` here is a leading value with no other candidate.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(r'\bheight:\s*[0-9]+\.[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare line height:',
          hits,
          'use `AppLineHeights.<role>`. Anything rendering both scripts '
              'needs `reading` or `body` — IBM Plex Sans Arabic has taller '
              'ascenders than Space Grotesk, so a value picked against '
              'English alone clips in Arabic.',
        ),
      );
    });
  });

  group('Strokes, shadows and elevation are named', () {
    test('no `strokeWidth:` takes a bare number', () {
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(r'\bstrokeWidth:\s*[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a strokeWidth:',
          hits,
          'use `AppStrokeWidths.spinner<Weight>`, picked against the '
              '`AppControlSizes` diameter the spinner is drawn at — Flutter '
              'defaults to 4.0, which is far too heavy at the 14–22 px this '
              'app spins at.',
        ),
      );
    });

    test('no border `width:` takes a bare number', () {
      // Balanced rather than line-based: `Border.all(color: x.withValues(…),
      // width: 1)` puts parentheses between the constructor and the number,
      // so a non-greedy `[^()]*` scan silently skips exactly the sites that
      // have any colour computation in them — which is most of them.
      final ctor = RegExp(
        r'\b(?:BorderSide|Border\.all|BorderDirectional|TableBorder\.all)\(',
      );
      final bare = RegExp(r'\bwidth:\s*([0-9][0-9.]*)');
      final hits = <_Line>[];

      for (final file in _scanFiles()) {
        if (file.path.endsWith('core/theme/app_sizes.dart')) continue;
        var from = 0;
        while (true) {
          final m = ctor.firstMatch(file.text.substring(from));
          if (m == null) break;
          final open = from + m.end - 1;
          final close = _matchParen(file.text, open);
          if (close == -1) {
            from = open + 1;
            continue;
          }
          final region = file.text.substring(open + 1, close);
          for (final n in bare.allMatches(region)) {
            final at = open + 1 + n.start;
            hits.add((
              path: file.path,
              number: '\n'.allMatches(file.text.substring(0, at)).length + 1,
              text: '${m.group(0)}… width: ${n.group(1)} …',
            ));
          }
          from = close;
        }
      }

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a border width:',
          hits,
          'use `AppBorderWidths.<role>`. A border stroke is not a spinner '
              'stroke — `AppStrokeWidths` scales with a diameter, these scale '
              'with how much the edge is meant to assert itself.',
        ),
      );
    });

    test('no `thickness:` or `Divider` height is a bare number', () {
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) =>
              RegExp(r'\bthickness:\s*[0-9]').hasMatch(l.text) ||
              RegExp(r'Divider\([^)]*\bheight:\s*[0-9]').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number on a rule:',
          hits,
          'use `AppBorderWidths.hairline`. This app always sets a Divider\'s '
              '`height` and `thickness` to the same value because it wants a '
              'rule with no padding — one name is what keeps the pair from '
              'drifting apart.',
        ),
      );
    });

    test('no shadow geometry is a bare number', () {
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(
                r'\b(?:blurRadius|spreadRadius|sigmaX|sigmaY):\s*[0-9]',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in shadow geometry:',
          hits,
          'use `AppShadowSizes.<role>`. Shadow COLOUR belongs on the theme '
              'extension (it differs per brightness); only the geometry lives '
              'in the size scale, because a surface\'s softness is the same '
              'whether it renders dark or light.',
        ),
      );
    });

    test('no `elevation:` takes a bare number', () {
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_sizes.dart'))
          .where((l) => RegExp(
                r'(?<!scrolledUnder)\belevation:\s*[0-9]',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in an elevation:',
          hits,
          'use `AppElevations.<role>`. The design system is flat — surfaces '
              'are separated by borders and translucency — so `none` is what '
              'almost everything takes, and it is set explicitly because '
              'Material\'s own defaults are not 0.',
        ),
      );
    });
  });

  group('Box dimensions are named, not typed', () {
    // The `SizedBox` gap rule above deliberately stops at the one-argument
    // form and says so: "if this is really a fixed control size, give it both
    // dimensions and name it in `AppControlSizes`." That sentence was an
    // instruction nobody could enforce — 283 two-argument dimensions had
    // accumulated behind it. These rules enforce it.

    test('no width/height pair is a bare number', () {
      final hits = lib
          .where((l) => !l.path.contains('core/theme/'))
          .where((l) => RegExp(
                r'\b(?:width|height):\s*[0-9]+\s*,\s*(?:width|height):\s*[0-9]',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare width/height pair:',
          hits,
          'a sized box is a control dimension. Use `AppBoxSizes` for a '
              'decorative square behind a glyph, `AppControlSizes` for a tap '
              'target, `AppAvatarSizes` for an identity circle, or '
              '`AppSkeletonSizes` for a loading placeholder. For a circle, '
              '`SkeletonBlock.circle(size:)` already exists.',
        ),
      );
    });

    test('no constraint is a bare number', () {
      final hits = lib
          .where((l) => !l.path.contains('core/theme/'))
          .where((l) => RegExp(
                r'\b(?:maxWidth|minWidth|maxHeight|minHeight):\s*[0-9]',
              ).hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a BoxConstraints:',
          hits,
          'a max width is a responsive decision — use `AppLayoutWidths`. A '
              'sheet\'s bounds go in `AppSheetHeights` (as a min/max PAIR, so '
              'nothing can raise the minimum past the maximum). A control\'s '
              'minimum goes in `AppControlSizes`.',
        ),
      );
    });

    test('no `cacheExtent:` is a bare number', () {
      // Six lists, one value, and nothing saying the six were the same
      // decision except that they happened to be equal.
      final hits = lib
          .where((l) => RegExp(r'\bcacheExtent:\s*[0-9]').hasMatch(l.text))
          .where((l) => !l.path.contains('core/theme/'))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare number in a cacheExtent:',
          hits,
          'use `AppScrollTuning.cacheExtent`. A value that is right for one '
              'long list in this app is right for all of them.',
        ),
      );
    });
  });

  group('Absolute colours are named', () {
    test('no bare `Colors.white` / `Colors.black`', () {
      // `Colors.transparent` is deliberately NOT in this rule. It is not a
      // colour decision — it is the absence of one, and it means the same
      // thing at every call site, so naming it would add indirection without
      // adding information. White and black are the opposite: this app has
      // four distinct reasons to reach for them (a foreground on a brand
      // fill, a modal scrim, an image viewer's backdrop, and that backdrop's
      // foreground) which happen to resolve to the same value today.
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_colors.dart'))
          .where((l) => !_brandLockedColours.any(l.path.contains))
          .where((l) =>
              RegExp(r'(?<![A-Za-z.])Colors\.(?:white|black)\b').hasMatch(l.text))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Bare absolute colour:',
          hits,
          'use `AppColors.onBrand` (a label or glyph on a brand fill), '
              '`AppColors.scrimBase` (a modal barrier, tinted by an '
              '`AppAlphas` scrim level), `AppColors.imageBackdrop` or '
              '`AppColors.onImageBackdrop`. `Colors.transparent` is fine and '
              'is not covered by this rule.',
        ),
      );
    });
  });

  group('Responsive boundaries are read from one place', () {
    test('the breakpoint ladder holds no bare widths', () {
      final src =
          File('lib/shared/extensions/responsive_breakpoints.dart').readAsStringSync();
      final ladder = src.substring(src.indexOf('Breakpoint breakpointForWidth'));

      expect(
        RegExp(r'width <= [0-9]').hasMatch(ladder),
        isFalse,
        reason: 'breakpointForWidth compares against a bare number.\n\n'
            'Fix: read the boundary from `BreakpointWidths`. The responsive '
            'test harness sweeps device widths against these tiers, and a '
            'harness that hardcodes its own 340 is testing a boundary the app '
            'may no longer have — reading them from one class means the two '
            'can only ever agree.',
      );
    });

    test('BreakpointWidths actually declares all three', () {
      // Without this, the rule above passes vacuously the moment someone
      // deletes the class and inlines the numbers somewhere else.
      final src =
          File('lib/shared/extensions/responsive_breakpoints.dart').readAsStringSync();
      for (final name in ['tiny', 'compact', 'regular']) {
        expect(
          src,
          contains('static const double $name ='),
          reason: 'BreakpointWidths.$name is missing.',
        );
      }
    });
  });
}
