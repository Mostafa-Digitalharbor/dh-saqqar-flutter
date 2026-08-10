import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Per-user Saqqar feature availability — the `saqqar_features` object on
/// `GET /api/v1/usage/` (web team's response doc, 2026-08-06 §0).
///
/// **This is not [PlanFeatures].** The two are deliberately separate objects
/// on the wire and must not be merged:
///
///   * `windows.features` (→ `PlanFeatures`) is a *billing entitlement* set —
///     `voice`, `postgres`, `github`, `server_shell` — gating paid capability
///     by plan tier.
///   * `saqqar_features` (→ this class) is an *admin toggle* set gating which
///     Saqqar features are switched on for this particular user, independent
///     of what they pay. Most are staff-only during rollout.
///
/// They collide on the word "voice" and mean different things: billing
/// `voice` is the composer mic, `voice_support` here is the support
/// workspace. Keeping them in separate types is what stops one from being
/// read for the other.
///
/// The server enforces every flag regardless of what the client renders — a
/// disabled tool is dropped from the agent's toolset and a direct call is
/// refused — so hiding on `false` is cosmetic correctness, never a security
/// boundary.
@immutable
class SaqqarFeatures extends Equatable {
  const SaqqarFeatures(this.flags);

  /// Nothing has been read yet.
  ///
  /// Distinct from "the server sent an empty object": [known] is `false` here,
  /// which is what lets a gate answer "I don't know" rather than "off". The
  /// app reaches this state on every cold start, because `saqqar_features`
  /// rides on `/api/v1/usage/` and nothing fetches that until a screen asks.
  static const unknown = SaqqarFeatures(null);

  /// Every boolean the server sent, verbatim. `null` until a fetch lands.
  final Map<String, bool>? flags;

  /// Whether any snapshot has been read at all.
  bool get known => flags != null;

  /// Whether the server expressed an opinion about [key].
  bool has(String key) => flags?.containsKey(key) ?? false;

  /// `true` only when the server said so. Unknown and absent both read
  /// `false`, which is why [has] and [known] exist alongside this.
  bool enabled(String key) => flags?[key] ?? false;

  factory SaqqarFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return unknown;
    // Booleans only. A string `"true"` would otherwise be silently readable
    // as a flag the server never actually set.
    return SaqqarFeatures({
      for (final entry in json.entries)
        if (entry.value is bool) entry.key: entry.value as bool,
    });
  }

  // ── Wire keys, verbatim from the web team's response doc §0 ──────────────
  //
  // NOTE: `task_prep`, NOT `task_prep_available`. The longer name is what the
  // HTML feature context calls it; the JSON API ships the short one.
  static const kTaskPrep = 'task_prep';
  static const kPromptBank = 'prompt_bank';
  static const kHealthRadar = 'health_radar';
  static const kWhatIf = 'what_if';
  static const kBusinessPulse = 'business_pulse';
  static const kVoiceSupport = 'voice_support';
  static const kReportBuilder = 'report_builder';
  static const kCollectionNote = 'collection_note';
  static const kVersionAwareness = 'version_awareness';
  static const kModuleManagement = 'module_management';

  @override
  List<Object?> get props => [flags];
}
