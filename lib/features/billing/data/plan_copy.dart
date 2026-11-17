import 'package:flutter/widgets.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_strings.dart';

/// Arabic for the plan copy `GET /api/v1/plans/` sends in English.
///
/// **This is no longer a mirror of the website's wording.** As of the backend
/// deploy on 2026-08-09 the endpoint carries `tagline`, `features_intro`,
/// `features_text`, `price_note` and `most_popular`, rendered from the same
/// server module the web pricing page renders from — so *what* each tier says
/// now comes down the wire, and a wording change on the website reaches the
/// app with no release. The slug-keyed table of English strings this file used
/// to hold is gone.
///
/// **What is left, and why.** The endpoint is English-only, by design: the web
/// pricing page is served in English and translated **in the browser**, via a
/// static English→Arabic map keyed by the English text (`public-i18n.js`).
/// There is no server-side Arabic source to read — the English *is* the
/// source. So this file is the mobile half of exactly that mechanism, keyed
/// the same way. It is parity with the web, not a workaround for it.
///
/// **What that buys.** A bullet the backend adds tomorrow renders immediately
/// in English on both locales, and picks up Arabic whenever a translation is
/// added here — never blank, never stale, and never a reason to hold a
/// release. A bullet whose English wording is *edited* server-side falls back
/// to that new English until it is translated, which is the honest failure:
/// the reader sees the current claim in the wrong language rather than the
/// previous claim in the right one.
///
/// The durable fix is server-side: `Accept-Language: ar` on `/plans/`, which
/// the backend has offered. When it ships, [translate] collapses to returning
/// its argument and this table is deleted.
class PlanCopy {
  PlanCopy._();

  // ── Tier names ──────────────────────────────────────────────────────
  //
  // Keyed by SLUG rather than by English text, unlike everything else here.
  // The backend confirmed on 2026-08-09 that the tier `name` values stay
  // English on both the database and the API — permanently — and that the
  // five slugs are stable identifiers. That makes the set closed and the key
  // stable, which is the one situation where a slug table cannot go stale.
  //
  // Note `max-5x` is "Solo" and `max-20x` is "Business": the slug and the
  // display name have nothing to do with each other, which is precisely why
  // the name has to be looked up rather than derived.
  static const Map<String, String> _nameKeyBySlug = {
    'free': 'plan_copy_free_name',
    'starter': 'plan_copy_starter_name',
    'max-5x': 'plan_copy_solo_name',
    'pro': 'plan_copy_pro_name',
    'max-20x': 'plan_copy_business_name',
  };

  /// The tier's name in the reader's language, falling back to whatever the
  /// server sent.
  ///
  /// **Use this at every site that renders a plan name.** The wire `name` is
  /// English-only — `plan_name` on the usage snapshot and `name` on a plan row
  /// both come back "Professional" — so an Arabic account read English in the
  /// account badge, the profile hero and the pricing card alike, on a website
  /// whose own Arabic page says "الاحترافي". Going through one helper is what
  /// keeps those three from drifting apart again.
  ///
  /// A tier this file has never heard of renders the server's own name. An
  /// under-described new tier beats an invented one.
  static String nameFor(
    AppStrings tr, {
    required String slug,
    required String fallback,
  }) {
    final key = _nameKeyBySlug[slug];
    if (key != null) return tr.lookup(key, fallback: fallback);
    // Unknown slug: the name may still be one we know by its English text
    // (a slug rename would land here), so try that before giving up.
    return translate(tr, fallback);
  }

  // ── Descriptive copy, keyed by the server's English ─────────────────

  /// [english] rendered in the reader's language, or [english] itself when
  /// there is no translation for it.
  ///
  /// Never returns blank for non-blank input: an untranslated bullet shows in
  /// English rather than vanishing, because a tier silently missing one of
  /// its selling points is worse than a tier that mixes languages.
  static String translate(AppStrings tr, String? english) {
    final source = english?.trim() ?? '';
    if (source.isEmpty) return '';
    final key = _keyByEnglish[_norm(source)];
    if (key == null) return source;
    return tr.lookup(key, fallback: source);
  }

  /// Case- and whitespace-insensitive. Punctuation is deliberately *kept*:
  /// "Everything in Solo, plus:" ends in a colon that is part of the sentence,
  /// and stripping it would let two different strings collide.
  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Every key whose English value is a string the server can send.
  ///
  /// The English side of these entries must stay **byte-identical to what
  /// `/plans/` returns** — that is what the lookup keys on. `plan_copy_test`
  /// pins them against a captured live payload so an edit to either side
  /// fails a test rather than silently reverting a tier to English.
  static const List<String> _translatableKeys = [
    // free
    'plan_copy_free_name',
    'plan_copy_free_tagline',
    'plan_copy_free_price_note',
    'plan_copy_free_f1',
    'plan_copy_free_f2',
    'plan_copy_free_f3',
    'plan_copy_free_f4',
    'plan_copy_free_f5',
    'plan_copy_free_f6',
    'plan_copy_free_f7',
    // starter
    'plan_copy_starter_name',
    'plan_copy_starter_tagline',
    'plan_copy_starter_inherits',
    'plan_copy_starter_f1',
    'plan_copy_starter_f2',
    // max-5x (Solo)
    'plan_copy_solo_name',
    'plan_copy_solo_tagline',
    'plan_copy_solo_inherits',
    'plan_copy_solo_f1',
    'plan_copy_solo_f2',
    'plan_copy_solo_f3',
    'plan_copy_solo_f4',
    'plan_copy_solo_f5',
    // pro (Professional)
    'plan_copy_pro_name',
    'plan_copy_pro_tagline',
    'plan_copy_pro_inherits',
    'plan_copy_pro_f1',
    'plan_copy_pro_f2',
    'plan_copy_pro_f3',
    'plan_copy_pro_f4',
    // max-20x (Business)
    'plan_copy_business_name',
    'plan_copy_business_tagline',
    'plan_copy_business_inherits',
    'plan_copy_business_f1',
    'plan_copy_business_f2',
    'plan_copy_business_f3',
    'plan_copy_business_f4',
    'plan_copy_business_f5',
  ];

  /// English text → i18n key, built once from the English table itself.
  ///
  /// Derived rather than written out, so the English half of every entry
  /// exists in exactly one place. Writing the strings here as well would
  /// create the failure this whole file is meant to remove: two copies of the
  /// same sentence, one of which is edited.
  ///
  /// Two tiers legitimately share a bullet ("Priority support"); the later key
  /// wins and both translate identically, which `plan_copy_test` pins.
  static final Map<String, String> _keyByEnglish = {
    for (final key in _translatableKeys)
      if (_englishStrings.lookup(key).isNotEmpty)
        _norm(_englishStrings.lookup(key)): key,
  };

  static final AppStrings _englishStrings = AppStrings(
    const Locale(UiStrings.localeEnglishCode),
  );

  /// Every key this file references, for the test that pins them against the
  /// i18n tables. A missing key renders as the server's English — silently,
  /// because [translate] falls back rather than leaking the identifier — so
  /// the guard has to be a test, not a runtime check.
  @visibleForTesting
  static List<String> get allKeys => [
    ..._translatableKeys,
    ..._nameKeyBySlug.values,
  ];

  /// The slugs whose names are localized, for the same test.
  @visibleForTesting
  static List<String> get knownSlugs => _nameKeyBySlug.keys.toList();

  /// The English strings this file can translate, for the test that compares
  /// them against a captured `/plans/` payload.
  @visibleForTesting
  static List<String> get translatableEnglish => [
    for (final key in _translatableKeys) _englishStrings.lookup(key),
  ];
}
