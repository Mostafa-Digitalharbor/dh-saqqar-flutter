import 'package:flutter/foundation.dart';

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
