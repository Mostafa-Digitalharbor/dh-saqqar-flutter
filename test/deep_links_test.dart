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

    test('rejects missing id segment', () {
      expect(
        DeepLinks.resolve(Uri.parse('saqqar://conversation/')),
        isNull,
      );
    });

    test('rejects an unrelated scheme/host entirely', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://example.com/foo')),
        isNull,
      );
    });
  });

  group('DeepLinks.resolve — https://saqqaar.com universal links', () {
    test('root path opens Home', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/')),
        '/chats',
      );
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com')),
        '/chats',
      );
    });

    test('/new opens a new conversation', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/new')),
        '/chats/new',
      );
    });

    test('/chats/<id> opens that conversation', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/chats/abc-123')),
        '/chats/abc-123',
      );
    });

    test('/chats with no id falls back to Home', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/chats')),
        '/chats',
      );
    });

    test('/share/<token> opens the shared transcript', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/share/tok-abc')),
        '/share/tok-abc',
      );
    });

    test('unrecognized path falls back to Home', () {
      expect(
        DeepLinks.resolve(Uri.parse('https://saqqaar.com/foo')),
        '/chats',
      );
    });

    test('browser-only prefixes are not routed', () {
      for (final path in [
        '/auth/callback',
        '/excel-addin/manifest.xml',
        '/settings/profile',
        '/admin/dashboard',
        '/static/app.js',
        '/media/logo.png',
      ]) {
        expect(
          DeepLinks.resolve(Uri.parse('https://saqqaar.com$path')),
          isNull,
          reason: '$path should not open the app',
        );
      }
    });

    test('exact browser-only pages are not routed', () {
      for (final path in [
        '/privacy',
        '/terms',
        '/support',
        '/refund',
        '/cancellation',
      ]) {
        expect(
          DeepLinks.resolve(Uri.parse('https://saqqaar.com$path')),
          isNull,
          reason: '$path should not open the app',
        );
      }
    });

    test('http (non-https) saqqaar.com is not handled', () {
      expect(
        DeepLinks.resolve(Uri.parse('http://saqqaar.com/new')),
        isNull,
      );
    });
  });
}
