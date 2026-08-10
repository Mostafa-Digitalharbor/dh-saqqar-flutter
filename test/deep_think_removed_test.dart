// docs/WEB_UI_PARITY_GAPS.md §2 — deep think is gone, and has to stay gone.
//
// A widget test only proves the screens it pumps carry no toggle. This scans
// the whole tree, because the failure mode is a *re-add*: someone restores a
// deep-think control on one surface (or a `deep_think` key in one request
// body) and nothing else in the suite notices.
//
// The removal was a strip-UI-and-wiring, keep-the-model-tolerant job, so the
// one surviving mention is `Conversation.deepThink` — the server still
// serializes the key and a stricter model would fail the snapshot parse.
// That file is the single allowance below; widening it is the decision this
// test exists to force someone to make on purpose.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ONLY file allowed to mention deep-think, and why.
const _allowed = {
  'lib/features/conversations/data/conversation_models.dart':
      'parse-and-ignore: the server still sends `deep_think`',
};

typedef _Hit = ({String path, int number, String text});

/// Every non-comment, non-import line under `lib/`.
///
/// Comments are stripped for the same reason `source_invariants_test` strips
/// them: the removal is *explained* in a dozen doc comments ("deep think used
/// to sit here…") and a naive grep would flag every explanation.
List<_Hit> _scanLib() {
  final out = <_Hit>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (_allowed.keys.any(path.endsWith)) continue;

    var inBlockComment = false;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (inBlockComment) {
        if (trimmed.contains('*/')) inBlockComment = false;
        continue;
      }
      if (trimmed.startsWith('/*')) {
        if (!trimmed.contains('*/')) inBlockComment = true;
        continue;
      }
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
      if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
        continue;
      }
      out.add((path: path, number: i + 1, text: lines[i]));
    }
  }
  return out;
}

void main() {
  final lib = _scanLib();

  test('no deep-think identifier survives outside the tolerant model', () {
    final pattern = RegExp(r'deepThink|deep_think', caseSensitive: false);
    final hits = lib.where((l) => pattern.hasMatch(l.text)).toList();

    expect(
      hits,
      isEmpty,
      reason: 'Deep think was removed with the web toggle (§2). These lines '
          'bring it back:\n'
          '${hits.map((h) => '  ${h.path}:${h.number}\n      '
              '${h.text.trim()}').join('\n')}\n\n'
          'The backend escalates hard tasks to the stronger model on its own '
          '— a client-side toggle now only fights it. If a NEW reason to '
          'mention the key exists, add the file to `_allowed` above with the '
          'reason.',
    );
  });

  test('the deep-think cubit file is deleted, not just unreferenced', () {
    expect(
      File('lib/features/chat/view_model/deep_think_cubit.dart').existsSync(),
      isFalse,
      reason: 'an unreferenced cubit is a re-add waiting to happen',
    );
  });

  test('its persisted preference key is gone too', () {
    // `saqqar.deepThink` in SharedPreferences would keep a dead value alive
    // across upgrades and confuse anyone reading a device dump.
    final uiStrings =
        File('lib/core/constants/ui_strings.dart').readAsStringSync();

    expect(uiStrings.contains('saqqar.deepThink'), isFalse);
    expect(
      uiStrings.contains('saqqar.taskPrep'),
      isTrue,
      reason: 'the replacement preference key (§3)',
    );
  });

  test('the i18n tables carry task-prep copy and no deep-think copy', () {
    final strings = File('lib/core/i18n/app_strings.dart').readAsStringSync();

    expect(strings.contains("'deep_think'"), isFalse);
    expect(strings.contains("'deep_think_title'"), isFalse);
    // Both tables — `i18n_parity_test` proves the pairing, this proves the
    // keys exist at all.
    expect("'task_prep':".allMatches(strings).length, 2);
    expect("'task_prep_title':".allMatches(strings).length, 2);
  });

  test('the allowlist has no stale entries', () {
    // An allowance that outlives its file silently covers whatever lands at
    // that path next.
    for (final path in _allowed.keys) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '`$path` is allowlisted but no longer exists — drop it.',
      );
    }
  });
}
