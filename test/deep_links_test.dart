import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/routing/deep_links.dart';

void main() {
  group('DeepLinks.resolve', () {
    test('parses saqqar://conversation/<id>', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://conversation/abc-123')),
        '/chats/abc-123',
      );
    });

    test('parses saqqar://approval/<id>?conversation=<cid>', () {
      expect(
        DeepLinks.resolve(
          Uri.parse('saqqar://approval/apr-1024?conversation=3abf67f5'),
        ),
        '/chats/3abf67f5?approval=apr-1024',
      );
    });

    test('rejects saqqar://approval/<id> with no conversation query', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://approval/apr-1024')),
        isNull,
      );
    });

    test('parses saqqar://credential/add with kind query', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://credential/add?kind=xmlrpc')),
        '/vault/add?kind=xmlrpc',
      );
    });

    test('parses saqqar://credential/add with no query', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://credential/add')),
        '/vault/add',
      );
    });

    test('parses saqqar://share/<token>', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://share/tok-abc')),
        '/share/tok-abc',
      );
    });

    test('rejects unknown host', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://wat/foo')),
        isNull,
      );
    });

    test('rejects wrong scheme', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/foo')),
        isNull,
      );
    });

    test('rejects missing id segment', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://conversation/')),
        isNull,
      );
    });
  });
}
