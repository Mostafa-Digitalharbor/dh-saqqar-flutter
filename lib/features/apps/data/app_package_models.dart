import 'package:flutter/foundation.dart';

import '../../../core/i18n/app_strings.dart';

/// One guided implementation package from `GET /api/v1/apps/`
/// (API_MOBILE_NEW_ENDPOINTS.md §1).
///
/// Launching a package spins up a package-tagged conversation the agent
/// drives with its normal tools — there is no per-app backend. Every field
/// shown in the UI comes straight from this object (name, tagline,
/// category, accent); nothing is fabricated client-side.
@immutable
class SaqqarApp {
  const SaqqarApp({
    required this.slug,
    required this.name,
    required this.tagline,
    required this.category,
    required this.group,
    required this.accent,
    required this.iconSvg,
    required this.envRequired,
  });

  /// Stable id — used in the launch call.
  final String slug;
  final String name;
  final String tagline;

  /// Short chip label (e.g. `Compliance · KSA`).
  final String category;

  /// Filter taxonomy: `Accounting` · `Finance` · `Integrations`.
  final String group;

  /// Hex tint (e.g. `#14B8A6`) supplied by the server. Parsed defensively
  /// by the view via [accentColor]; a malformed value falls back to the
  /// brand accent rather than throwing.
  final String accent;

  /// Inline 24×24 SVG markup. NOT rendered yet — the app bundles no SVG
  /// package, so the tile shows a group-mapped icon tinted with [accent]
  /// instead. Kept on the model so a later flutter_svg pass can show the
  /// exact server icon without a backend change.
  final String iconSvg;

  /// When `true`, the task needs a bound Odoo environment. Surfaced as a
  /// tile hint; binding still happens in-chat (the agent asks) so launch
  /// never blocks on it.
  final bool envRequired;

  // ── Localization ────────────────────────────────────────────────────
  //
  // `GET /api/v1/apps/` serves ONE language: `name`, `tagline` and
  // `category` come back in English whatever the user's locale, so the whole
  // grid stayed English on an Arabic phone.
  //
  // These resolve a client string keyed by the app's stable `slug` and fall
  // back to the server value — the same rule the report-builder chips use
  // (`rbType_<key>` → server `label`). Two properties follow from that:
  //
  //   * An app the backend adds tomorrow still renders, in English, with no
  //     mobile release. It is never blank.
  //   * A translated app renders in the user's language on both tables,
  //     because `lookup` falls through `ar` → `en` → the server string.
  //
  // The durable fix is server-side (`name_ar`/`tagline_ar`, or honouring
  // `Accept-Language`); this is what makes the Arabic build correct today
  // without inventing a contract. When the backend localizes, delete the
  // `app_*_<slug>` keys and these three getters collapse to the raw fields.

  /// Lookup keys for this package, most stable first.
  ///
  /// The `slug` is the right key and is tried first. The normalized English
  /// name is a second chance, because the catalogue is server-owned and the
  /// slugs are not published anywhere the mobile side can read — keying only
  /// on a slug we had to guess would silently fall back to English and look
  /// exactly like no translation at all.
  ///
  /// Both are checked, so a translation lands whichever key matches, and a
  /// package with neither still renders the server's own strings.
  ///
  /// The slug is **normalized**, not used raw. The live catalogue sends
  /// `chart-of-accounts` and `bank-reconciliation` — hyphens — while every
  /// key in `app_strings.dart` is snake_case, so the raw form built
  /// `app_name_chart-of-accounts` and matched nothing on either table. That
  /// left the slug path dead for two of the four live packages: they only
  /// ever translated by display name, and would have gone back to English
  /// the first time the backend reworded a card.
  List<String> _keys(String prefix) {
    final bySlug = normalizeKey(slug);
    final byName = normalizeKey(name);
    return [
      if (bySlug.isNotEmpty) '$prefix$bySlug',
      if (byName.isNotEmpty && byName != bySlug) '$prefix$byName',
    ];
  }

  /// `ZATCA e-invoicing` → `zatca_e_invoicing`. Lowercased, every run of
  /// non-alphanumerics collapsed to one underscore, ends trimmed.
  ///
  /// Delegates to [AppStrings.taxonomyKey] so the package keys and the
  /// group/category keys cannot normalize differently — they used to be two
  /// copies of the same regex pair, and only one of them trimmed its ends.
  static String normalizeKey(String value) => AppStrings.taxonomyKey(value);

  String _resolve(AppStrings tr, String prefix, String fallback) {
    for (final key in _keys(prefix)) {
      final hit = tr.lookup(key);
      if (hit.isNotEmpty) return hit;
    }
    return fallback;
  }

  String displayName(AppStrings tr) => _resolve(tr, 'app_name_', name);

  String displayTagline(AppStrings tr) => _resolve(tr, 'app_tagline_', tagline);

  /// The short chip label (`Compliance · KSA`).
  ///
  /// Translated **word by word** by [AppStrings.appCategory], which is what
  /// makes an unseen pairing like `Compliance · Egypt` come out Arabic
  /// without a release. Falling straight through to the server's English
  /// (what this used to do, since no `app_category_*` key existed for any
  /// package) left the chip Latin on every Arabic card that had no group to
  /// show instead.
  ///
  /// Deliberately **not** keyed per package the way [displayName] is. The
  /// `app_category_*` table is a shared vocabulary, so a per-package lookup
  /// would collide with it: the `meetings` package would have resolved
  /// `app_category_meetings` — the word "Meetings" — and rendered that
  /// instead of its own category, whatever the server actually sent.
  String displayCategory(AppStrings tr) => tr.appCategory(category);

  /// The taxonomy chip the web shows on each card (`FINANCE`,
  /// `INTEGRATIONS`, `ACCOUNTING`) and the value its filter pills key off.
  /// A closed set, so it translates by value rather than per package.
  String displayGroup(AppStrings tr) =>
      tr.lookup('app_group_${normalizeKey(group)}', fallback: group);

  // ── Which packages mobile shows: all of them ────────────────────────
  //
  // A four-slug ALLOWLIST used to sit here. `GET /api/v1/apps/` was returning
  // a fifth package (`meetings`) that the web gallery does not show — it is a
  // direct-launch app that opens an internal web route, gated behind staff and
  // a configured integration, and mobile has no surface for it. Filtering it
  // out client-side matched web, and cost the property that matters more: a
  // genuinely new package would not have appeared on mobile until someone
  // added its key here and shipped a release.
  //
  // The endpoint became authoritative on 2026-08-09 — it now applies the web
  // gallery's own visibility gate and omits direct-launch apps server-side —
  // so the list is rendered whole. `POST /apps/{slug}/launch/` returns 404 for
  // a filtered slug, so there is no second path to one either.
  //
  // Nothing replaces this. That is the point: the grid is whatever the server
  // says it is.

  factory SaqqarApp.fromJson(Map<String, dynamic> json) {
    return SaqqarApp(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      category: json['category'] as String? ?? '',
      group: json['group'] as String? ?? '',
      accent: json['accent'] as String? ?? '',
      iconSvg: json['icon_svg'] as String? ?? '',
      envRequired: json['env_required'] as bool? ?? false,
    );
  }
}
