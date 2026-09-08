// Every credential field explains itself, in both languages.
//
// Found in the full web-vs-mobile sweep, and the sweep is the only way it
// could have been found: nothing throws, nothing looks broken, the form just
// renders "Database", "Port", "SSL mode" and twenty-odd other bare labels on a
// phone while the web explains every one of them.
//
// The cause is a branch, not a translation. The server sends `help: ""` on 27
// of its 28 fields and puts the text behind `help_key`, which each client
// resolves in its own table. The app read `help_key_by_auth_type` and `help`
// and skipped `help_key` in between — so the fallback had nothing to fall back
// to, and the eight `help_email_*` strings already in the table were dead.
//
// The fixture is the live schema, captured 2026-09-07 from
// `GET /api/v1/credentials/schemas/`, so this test fails if the server moves
// the text somewhere else again.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';

List<CredentialSchema> _liveSchemas() {
  final raw =
      File('test/fixtures/credential_schemas.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return (decoded['schemas'] as List)
      .cast<Map<String, dynamic>>()
      .map(CredentialSchema.fromJson)
      .toList();
}

void main() {
  final schemas = _liveSchemas();
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  test('the fixture is the real thing', () {
    expect(schemas.map((s) => s.kind.wire), containsAll(<String>[
      'xmlrpc',
      'postgres',
      'server_shell',
      'github',
      'email',
    ]));
    // 28 fields across five kinds. If the server grows one, this number moves
    // and the sweep below covers it automatically.
    expect(
      schemas.fold<int>(0, (n, s) => n + s.fields.length),
      greaterThanOrEqualTo(28),
    );
  });

  test('the schema really does withhold the text', () {
    // The premise of the fix. If the server ever starts sending `help`
    // inline, this fails and the extra branch becomes belt-and-braces rather
    // than load-bearing — worth knowing either way.
    final withLiteralHelp = [
      for (final s in schemas)
        for (final f in s.fields)
          if (f.help.trim().isNotEmpty) '${s.kind.wire}.${f.name}',
    ];

    expect(withLiteralHelp.length, lessThan(5),
        reason: 'the server started shipping help text: $withLiteralHelp');
  });

  test('help_key is parsed off the wire', () {
    final keyed = [
      for (final s in schemas)
        for (final f in s.fields)
          if ((f.helpKey ?? '').isNotEmpty) f.helpKey!,
    ];

    expect(keyed, hasLength(27));
    expect(keyed, contains('help_db'));
    expect(keyed, contains('help_pg_sslmode'));
    expect(keyed, contains('help_shell_private_key'));
  });

  group('every field the server ships has a sentence', () {
    for (final locale in ['en', 'ar']) {
      test('in $locale', () {
        final tr = locale == 'en' ? en : ar;
        final bare = <String>[];

        for (final schema in schemas) {
          for (final field in schema.fields) {
            final byAuth = field.helpKeyByAuthType;
            if (byAuth != null && byAuth.isNotEmpty) {
              // Every non-empty branch must resolve. An empty value is the
              // schema saying "no help here", which is a decision, not a gap.
              for (final entry in byAuth.entries) {
                if (entry.value.isEmpty) continue;
                if (tr.lookup(entry.value).isEmpty) {
                  bare.add('${schema.kind.wire}.${field.name}'
                      '[${entry.key}] -> ${entry.value}');
                }
              }
              continue;
            }
            final key = field.helpKey;
            if (key == null || key.isEmpty) continue;
            if (tr.lookup(key).isEmpty) {
              bare.add('${schema.kind.wire}.${field.name} -> $key');
            }
          }
        }

        expect(bare, isEmpty,
            reason: 'fields with no help in $locale: ${bare.join(', ')}');
      });
    }

    test('and the Arabic is actually Arabic', () {
      // A key that fell back to the English table would pass the check above
      // while leaving an Arabic form half in English.
      final arabic = RegExp(r'[؀-ۿ]');
      final notArabic = <String>[];

      for (final schema in schemas) {
        for (final field in schema.fields) {
          final key = field.helpKey;
          if (key == null || key.isEmpty) continue;
          final text = ar.lookup(key);
          if (text.isNotEmpty && !arabic.hasMatch(text)) {
            notArabic.add('$key: $text');
          }
        }
      }

      expect(notArabic, isEmpty, reason: notArabic.join(' | '));
    });

    test('the email fields name the ports and hosts, like the web', () {
      // These eight were the app's own wording rather than the web's, and
      // said less: "Defaults to 993" never mentions that 587 is the STARTTLS
      // port, and neither host line gave the `imap.gmail.com` example that
      // tells someone what shape of value to type. Someone connecting a
      // mailbox from a phone has no other source for those numbers.
      expect(en.lookup('help_email_imap_port'), contains('993'));
      expect(en.lookup('help_email_smtp_port'), contains('465'));
      expect(en.lookup('help_email_smtp_port'), contains('587'));
      expect(en.lookup('help_email_smtp_security'), contains('STARTTLS'));
      expect(en.lookup('help_email_imap_host'), contains('imap.gmail.com'));
      expect(en.lookup('help_email_smtp_host'), contains('smtp.gmail.com'));

      expect(ar.lookup('help_email_imap_port'), contains('993'));
      expect(ar.lookup('help_email_smtp_port'), contains('587'));
      expect(ar.lookup('help_email_smtp_security'), contains('STARTTLS'));
      expect(ar.lookup('help_email_imap_host'), contains('imap.gmail.com'));
    });

    test('and the two languages are not the same string', () {
      // The cheapest way to leave a field untranslated is to copy the English
      // into the Arabic table.
      for (final schema in schemas) {
        for (final field in schema.fields) {
          final key = field.helpKey;
          if (key == null || key.isEmpty) continue;
          final e = en.lookup(key);
          final a = ar.lookup(key);
          if (e.isEmpty || a.isEmpty) continue;
          expect(a, isNot(e), reason: key);
        }
      }
    });
  });
}
