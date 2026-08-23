// `GET /api/v1/apps/` serves ONE language.
//
// `name`, `tagline` and `category` come back in English whatever the user's
// locale, so the Saqqar Apps grid stayed fully English on an Arabic phone —
// five cards of English inside an otherwise Arabic app.
//
// The fix keys a client string off the app's stable `slug` and falls back to
// the server value, the same rule the report-builder chips use. The two
// properties that matter are both pinned below: a translated app flips with
// the UI language, and an UNTRANSLATED app still renders (in English) rather
// than going blank — which is what a naive `tr.appName(slug)` would do for
// every package the backend adds after this release.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/apps/data/app_package_models.dart';

SaqqarApp _app({
  required String slug,
  String name = 'Server Name',
  String tagline = 'Server tagline',
  String category = 'Server category',
}) =>
    SaqqarApp.fromJson({
      'slug': slug,
      'name': name,
      'tagline': tagline,
      'category': category,
      'group': 'Finance',
      'accent': '#14B8A6',
      'icon_svg': '',
      'env_required': true,
    });

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('a translated app follows the UI language', () {
    test('ZATCA reads Arabic in Arabic', () {
      final app = _app(slug: 'zatca');

      expect(app.displayName(ar), 'الفوترة الإلكترونية (زاتكا)');
      expect(app.displayGroup(ar), 'المالية');
      expect(
        app.displayTagline(ar),
        contains('فاتورة'),
        reason: 'the tagline is the line that sells the card — it must '
            'translate too, not just the title',
      );
    });

    test('ZATCA reads English in English', () {
      final app = _app(slug: 'zatca');

      expect(app.displayName(en), 'ZATCA e-invoicing');
      expect(app.displayGroup(en), 'Finance');
    });

    test('the two locales genuinely differ', () {
      // Guards the copy-paste failure: an Arabic entry that is really the
      // English string passes every "is it non-empty" check.
      final app = _app(slug: 'zatca');

      expect(app.displayName(ar), isNot(app.displayName(en)));
      expect(app.displayTagline(ar), isNot(app.displayTagline(en)));
      expect(app.displayGroup(ar), isNot(app.displayGroup(en)));
    });

    test('the Arabic entries are actually Arabic script', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final app = _app(slug: 'zatca');

      for (final value in [
        app.displayName(ar),
        app.displayTagline(ar),
        app.displayGroup(ar),
      ]) {
        expect(arabic.hasMatch(value), isTrue, reason: value);
      }
    });
  });

  group('an untranslated app still renders', () {
    // The important half. The backend owns this list and can add a package
    // any day; a lookup with no fallback would render an empty card, or the
    // raw key `app_name_whatsapp`, on a screen the user opened to browse.
    test('falls back to the server strings in both locales', () {
      final app = _app(
        slug: 'brand_new_package',
        name: 'Brand New',
        tagline: 'Does a thing',
        category: 'Ops',
      );

      for (final tr in [en, ar]) {
        expect(app.displayName(tr), 'Brand New');
        expect(app.displayTagline(tr), 'Does a thing');
        expect(app.displayCategory(tr), 'Ops');
      }
    });

    test('never leaks the lookup key onto the screen', () {
      final app = _app(slug: 'unknown');

      for (final tr in [en, ar]) {
        expect(app.displayName(tr), isNot(contains('app_name_')));
        expect(app.displayTagline(tr), isNot(contains('app_tagline_')));
      }
    });

    test('an empty slug does not resolve a partial key', () {
      // `app_name_` is a real prefix; a blank slug must not match a stray
      // entry or return the prefix itself.
      final app = _app(slug: '', name: 'Nameless');

      expect(app.displayName(en), 'Nameless');
    });

    test('a server field that is empty stays empty, not the key', () {
      final app = _app(slug: 'nope', name: '', tagline: '', category: '');

      expect(app.displayName(en), isEmpty);
      expect(app.displayCategory(en), isEmpty);
    });
  });

  group('every translated package is complete in both tables', () {
    // A half-translated card — Arabic title over an English tagline — reads
    // as broken rather than as partly done. If a package appears at all,
    // BOTH its keys must exist on both sides.
    const keys = [
      'zatca',
      'zatca_e_invoicing',
      'whatsapp',
      'whatsapp_integration',
      'chart_of_accounts',
      'chart_of_accounts_builder',
      'bank_reconciliation',
      'factory',
      'your_factory',
      'meetings',
      'meeting_notetaker',
    ];

    test('each has a name and a tagline in en AND ar', () {
      for (final key in keys) {
        for (final tr in [en, ar]) {
          for (final prefix in ['app_name_', 'app_tagline_']) {
            expect(
              tr.lookup('$prefix$key'),
              isNotEmpty,
              reason: '$prefix$key missing for ${tr.locale.languageCode}',
            );
          }
        }
      }
    });

    test('the Arabic differs from the English for every package', () {
      for (final key in keys) {
        expect(
          ar.lookup('app_name_$key'),
          isNot(en.lookup('app_name_$key')),
          reason: key,
        );
        expect(
          ar.lookup('app_tagline_$key'),
          isNot(en.lookup('app_tagline_$key')),
          reason: key,
        );
      }
    });
  });

  group('the five live packages resolve by their real names', () {
    // The catalogue is server-owned and the slugs are not published to
    // mobile, so the name-normalized key is what actually matches today.
    // These are the exact `name` values the web renders.
    const live = {
      'ZATCA e-invoicing': 'الفوترة الإلكترونية (زاتكا)',
      'WhatsApp integration': 'تكامل واتساب',
      'Chart of Accounts builder': 'مُنشئ شجرة الحسابات',
      'Bank reconciliation': 'التسوية البنكية',
      'Your factory': 'مصنعك',
    };

    test('each renders Arabic in Arabic whatever the slug is', () {
      live.forEach((englishName, arabicName) {
        // Deliberately a slug we do NOT have a key for — proving the name
        // path carries the translation on its own.
        final app = _app(slug: 'unknown-slug', name: englishName);

        expect(app.displayName(ar), arabicName);
        expect(app.displayName(en), englishName);
      });
    });

    test('each has an Arabic tagline too, not just a title', () {
      for (final englishName in live.keys) {
        final app = _app(
          slug: 'x',
          name: englishName,
          tagline: 'English tagline from the server',
        );

        expect(
          app.displayTagline(ar),
          isNot('English tagline from the server'),
          reason: '$englishName tagline did not translate',
        );
      }
    });
  });

  group('the gallery shows whatever the server sends — no client filter', () {
    // A four-slug allowlist used to live on `SaqqarApp`, because `/apps/`
    // returned a fifth package (`meetings`) the web gallery does not show.
    // It matched web and cost the property that matters more: a genuinely new
    // package would not have appeared on mobile until someone added its key
    // and shipped a release.
    //
    // The endpoint applies the web gallery's own gate as of 2026-08-09, so the
    // filter is gone. These tests are the guard against it coming back — a
    // reinstated allowlist fails the first one.

    test('a package this build has never heard of still reaches the screen',
        () {
      final catalogue = [
        _app(slug: 'zatca', name: 'ZATCA e-invoicing'),
        _app(slug: 'brand-new', name: 'Some Package Shipped Next Month'),
      ];

      // The screen renders `onData`'s list verbatim. Anything that trims it
      // here is a release the backend should not have needed.
      expect(
        [for (final a in catalogue) a.name],
        contains('Some Package Shipped Next Month'),
      );
      expect(catalogue, hasLength(2));
    });

    test('an unknown package renders the server strings, never blank', () {
      // The other half of "no filter": showing it is only safe if it is
      // legible. Untranslated falls through to the server's own English.
      //
      // The example used to be "Meeting Notetaker" — which is now a
      // translated package, so it stopped demonstrating the fallback and
      // started asserting that a package we DO translate comes out English.
      // The name here has to be one nothing could plausibly key on.
      final app = _app(slug: 'brand-new', name: 'Warehouse Slotting Advisor');

      expect(app.displayName(ar), 'Warehouse Slotting Advisor');
      expect(app.displayName(en), 'Warehouse Slotting Advisor');
      expect(app.displayTagline(ar), isNotEmpty);
    });
  });

  group('the live slugs resolve — hyphens and all', () {
    // docs/BACKEND_FIXES_RESPONSE.md §5 records what `/apps/` actually
    // returns: `zatca · whatsapp · chart-of-accounts · bank-reconciliation`.
    // Two of those four are HYPHENATED, and the key builder used to paste the
    // raw slug onto the prefix — producing `app_name_chart-of-accounts`,
    // which matches nothing in a table written entirely in snake_case.
    //
    // The bug was invisible because the display-name path happened to cover
    // for it. That cover is exactly what makes it worth pinning: the day the
    // backend rewords a card, the name key stops matching and the slug key
    // is all that is left.
    const bySlug = {
      'zatca': 'الفوترة الإلكترونية (زاتكا)',
      'whatsapp': 'تكامل واتساب',
      'chart-of-accounts': 'مُنشئ شجرة الحسابات',
      'bank-reconciliation': 'التسوية البنكية',
      'factory': 'مصنعك',
    };

    test('each live slug translates with NO help from the display name', () {
      bySlug.forEach((slug, arabicName) {
        // A server name that keys nothing, so only the slug path can match.
        final app = _app(slug: slug, name: 'Renamed By The Backend');

        expect(app.displayName(ar), arabicName, reason: slug);
        expect(
          app.displayTagline(ar),
          isNot('Server tagline'),
          reason: '$slug tagline fell back to the server value',
        );
      });
    });

    test('and still reads English in English', () {
      for (final slug in bySlug.keys) {
        final app = _app(slug: slug, name: 'Renamed By The Backend');

        expect(app.displayName(en), isNot(app.displayName(ar)), reason: slug);
      }
    });

    test('the slug wins over the display name when both key something', () {
      // Order matters: the slug is the stable id, the name is the guess.
      final app = _app(slug: 'zatca', name: 'Bank reconciliation');

      expect(app.displayName(ar), 'الفوترة الإلكترونية (زاتكا)');
    });
  });

  group('the category chip translates word by word', () {
    // `category` is a COMPOUND label the backend composes from a small
    // vocabulary (`Compliance · KSA`). No `app_category_*` key existed at
    // all before, so this chip was Latin text on every Arabic card whose
    // package carried no group.
    test('a two-word compound comes out fully Arabic', () {
      final app = _app(slug: 'zatca', category: 'Compliance · KSA');

      expect(app.displayCategory(ar), 'الالتزام · السعودية');
      expect(app.displayCategory(en), 'Compliance · KSA');
    });

    test('a pairing nobody has shipped yet still translates', () {
      // The whole point of translating tokens instead of whole strings: the
      // vocabulary is closed, the pairings are not.
      expect(ar.appCategory('Compliance · Egypt'), 'الالتزام · مصر');
      expect(ar.appCategory('Banking · Automation'), 'المصرفية · الأتمتة');
    });

    test('words shared with the group taxonomy are not spelled twice', () {
      // `app_category_finance` deliberately does not exist; the lookup falls
      // through to `app_group_finance`.
      expect(ar.appCategory('Finance'), 'المالية');
      expect(ar.appCategory('Accounting · Setup'), 'المحاسبة · الإعداد');
    });

    test('an unknown word survives as itself, never as a key', () {
      expect(ar.appCategory('Compliance · Neptune'), 'الالتزام · Neptune');
      expect(ar.appCategory('Neptune'), 'Neptune');
      for (final tr in [en, ar]) {
        expect(tr.appCategory('Whatever'), isNot(contains('app_category_')));
      }
    });

    test('other separators are accepted and normalized to ·', () {
      expect(ar.appCategory('Compliance/KSA'), 'الالتزام · السعودية');
      expect(ar.appCategory('Compliance, KSA'), 'الالتزام · السعودية');
    });

    test('empty and whitespace-only stay empty', () {
      expect(ar.appCategory(''), isEmpty);
      expect(ar.appCategory('   '), isEmpty);
      expect(ar.appCategory('·'), '·');
    });
  });

  group('normalizeKey', () {
    test('turns a display name into a stable key', () {
      expect(
        SaqqarApp.normalizeKey('ZATCA e-invoicing'),
        'zatca_e_invoicing',
      );
      expect(
        SaqqarApp.normalizeKey('Chart of Accounts builder'),
        'chart_of_accounts_builder',
      );
    });

    test('collapses runs and trims the ends', () {
      expect(SaqqarApp.normalizeKey('  A -- B  '), 'a_b');
      expect(SaqqarApp.normalizeKey('!!!'), isEmpty);
    });

    test('drops non-Latin script rather than emitting junk', () {
      // An Arabic `name` from a future localized API must not produce a key
      // full of underscores that accidentally collides with another.
      expect(SaqqarApp.normalizeKey('تكامل واتساب'), isEmpty);
    });
  });

  group('the group taxonomy translates by value', () {
    test('the three known groups are Arabic in Arabic', () {
      expect(ar.appGroup('Accounting'), 'المحاسبة');
      expect(ar.appGroup('Finance'), 'المالية');
      expect(ar.appGroup('Integrations'), 'التكاملات');
      expect(ar.appGroupAll, 'الكل');
    });

    test('and English in English', () {
      expect(en.appGroup('Finance'), 'Finance');
      expect(en.appGroupAll, 'All');
    });

    test('an unknown group falls back to the server value', () {
      // A pill labelled `app_group_logistics` would be worse than one
      // labelled "Logistics".
      for (final tr in [en, ar]) {
        expect(tr.appGroup('Logistics'), 'Logistics');
      }
    });

    test('casing and spacing do not break the lookup', () {
      expect(ar.appGroup('FINANCE'), 'المالية');
      expect(ar.appGroup('finance'), 'المالية');
    });

    test('displayGroup on the model matches', () {
      final app = _app(slug: 'x');

      expect(app.displayGroup(ar), 'المالية');
      expect(app.displayGroup(en), 'Finance');
    });
  });
}
