import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The server's xmlrpc credential schema names the secret field `secret`
/// (fixture: `test/fixtures/credential_schemas.json`). The two hand-built
/// "connect Odoo" forms once sent `password` instead, and the backend answered
/// every attempt with 400 "Provide URL, database, username, and either a
/// password or an API key." — so no Odoo environment could be connected from
/// them. Pinning the keys to the fixture keeps the hand-built payloads in step
/// with the schema.
void main() {
  final schema = jsonDecode(
    File('test/fixtures/credential_schemas.json').readAsStringSync(),
  );
  final xmlrpc = _fieldNames(schema);

  const builders = [
    'lib/features/setup/setup_screens.dart',
    'lib/features/chat/widgets/chat_context_environment.dart',
  ];

  test('the fixture still names the xmlrpc fields these forms rely on', () {
    expect(xmlrpc, containsAll(['url', 'db', 'username', 'secret', 'auth_type']));
  });

  for (final path in builders) {
    test('$path sends the schema-named secret, not "password"', () {
      final src = File(path).readAsStringSync();
      final start = src.indexOf('CredentialKind.xmlrpc');
      expect(start, isNonNegative, reason: 'no xmlrpc upsert found');
      final payload = src.substring(start, start + 400);
      for (final key in ['url', 'db', 'username', 'secret', 'auth_type']) {
        expect(payload, contains("'$key':"), reason: 'missing "$key"');
      }
      expect(payload, isNot(contains("'password':")));
    });
  }
}

/// Field names of the `xmlrpc` schema, wherever the fixture nests them.
Set<String> _fieldNames(Object? node) {
  final out = <String>{};
  void walk(Object? n, bool inXmlrpc) {
    if (n is Map) {
      final isX = inXmlrpc || n['kind'] == 'xmlrpc';
      final fields = n['fields'];
      if (isX && fields is List) {
        for (final f in fields) {
          if (f is Map && f['name'] is String) out.add(f['name'] as String);
        }
      }
      n.forEach((k, v) => walk(v, isX || k == 'xmlrpc'));
    } else if (n is List) {
      for (final v in n) {
        walk(v, inXmlrpc);
      }
    }
  }

  walk(node, false);
  return out;
}
