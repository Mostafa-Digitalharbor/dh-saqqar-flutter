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

  group('DeepLinks.actionFor — saqqaar.com Universal / App Links', () {
    DeepLinkAction actionFor(String url) =>
        DeepLinks.actionFor(Uri.parse(url));

    String? navRoute(DeepLinkAction a) =>
        a is DeepLinkNavigate ? a.route : null;

    test('/ → home (chats)', () {
      expect(navRoute(actionFor('https://saqqaar.com/')), '/chats');
    });

    test('bare host with no path → home (chats)', () {
      expect(navRoute(actionFor('https://saqqaar.com')), '/chats');
    });

    test('/new → new conversation', () {
      expect(navRoute(actionFor('https://saqqaar.com/new')), '/chats/new');
    });

    test('/chats/<id> → conversation (same route as saqqar://conversation)', () {
      expect(
        navRoute(actionFor('https://saqqaar.com/chats/abc-123')),
        '/chats/abc-123',
      );
      // The https and custom-scheme links land on the same screen.
      expect(
        navRoute(actionFor('https://saqqaar.com/chats/abc-123')),
        DeepLinks.resolve(Uri.parse('saqqar://conversation/abc-123')),
      );
    });

    test('/chats with no id → chats list', () {
      expect(navRoute(actionFor('https://saqqaar.com/chats')), '/chats');
    });

    test('/share/<token> → shared transcript', () {
      expect(
        navRoute(actionFor('https://saqqaar.com/share/tok-abc')),
        '/share/tok-abc',
      );
    });

    test('query string is ignored for routing', () {
      expect(
        navRoute(actionFor('https://saqqaar.com/chats/abc-123?ref=email')),
        '/chats/abc-123',
      );
    });

    test('unknown path → home (safe default), not an error', () {
      expect(navRoute(actionFor('https://saqqaar.com/blog/post-1')), '/chats');
    });

    test('www. host is accepted', () {
      expect(navRoute(actionFor('https://www.saqqaar.com/new')), '/chats/new');
    });

    group('excluded paths stay in the browser (spec §4)', () {
      for (final path in const [
        '/auth/google/callback',
        '/excel-addin/taskpane',
        '/settings/profile',
        '/admin/users',
        '/static/app.js',
        '/media/logo.png',
        '/privacy',
        '/terms',
        '/support',
        '/refund',
        '/cancellation',
      ]) {
        test('$path → open in browser', () {
          final action = actionFor('https://saqqaar.com$path');
          expect(action, isA<DeepLinkOpenInBrowser>());
          expect(
            (action as DeepLinkOpenInBrowser).uri.path,
            path,
          );
        });
      }

      test('a path that merely starts with an excluded word is NOT excluded',
          () {
        // `/settings-guide` must not be swallowed by the `/settings` prefix.
        expect(
          actionFor('https://saqqaar.com/settings-guide'),
          isA<DeepLinkNavigate>(),
        );
      });
    });

    test('foreign host → ignored (not our domain)', () {
      expect(actionFor('https://example.com/chats/1'), isA<DeepLinkIgnore>());
    });

    test('foreign scheme (Google sign-in callback) → ignored', () {
      expect(
        actionFor('com.googleusercontent.apps.123://oauth'),
        isA<DeepLinkIgnore>(),
      );
    });

    test('saqqar:// custom scheme still routes via actionFor', () {
      expect(
        navRoute(actionFor('saqqar://conversation/abc-123')),
        '/chats/abc-123',
      );
    });

    test('unrecognized saqqar:// link → ignored', () {
      expect(actionFor('saqqar://wat/foo'), isA<DeepLinkIgnore>());
    });
  });
}
