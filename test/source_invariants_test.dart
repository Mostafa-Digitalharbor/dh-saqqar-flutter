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
    test('no `Color(0x…)` literal outside the theme', () {
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
      final hits = lib
          .where((l) => !l.path.contains('core/theme/'))
          .where((l) => RegExp(r'Color\(0x').hasMatch(l.text))
          .where((l) => !_brandLockedColours.any(l.path.endsWith))
          .toList();

      expect(
        hits,
        isEmpty,
        reason: _report(
          'Hex colour outside the theme:',
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
      final hits = lib
          .where((l) => !l.path.endsWith('core/theme/app_radius.dart'))
          .where((l) => RegExp(r'BorderRadius\.circular\(\s*[0-9]')
              .hasMatch(l.text))
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
}
