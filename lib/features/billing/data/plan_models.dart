import 'package:flutter/foundation.dart';

/// One usage window (day / week / month) from `conversation.plan`. Values are
/// in Saqqar-Token (ST) — an opaque cost-weighted credit. Caps are
/// admin-editable; NEVER hardcode them, always read [cap] from the server.
@immutable
class UsageWindow {
  const UsageWindow({
    required this.used,
    required this.cap,
    required this.pct,
    required this.remaining,
  });

  final int used;
  final int cap;

  /// Server-computed percentage (0–100+). Use this rather than recomputing
  /// from used/cap so mobile matches web exactly (rounding included).
  final int pct;
  final int remaining;

  /// Fraction in [0,1] for progress bars — clamped so an over-limit window
  /// renders full rather than overflowing.
  double get fraction => cap <= 0 ? 0 : (used / cap).clamp(0.0, 1.0);

  /// ≥80% but not yet over — drives the amber near-limit banner.
  bool get nearLimit => pct >= 80 && pct < 100;

  /// At or over the cap — the agent won't run.
  bool get exceeded => remaining <= 0 || pct >= 100;

  factory UsageWindow.fromJson(Map<String, dynamic> json) {
    return UsageWindow(
      used: (json['used'] as num?)?.toInt() ?? 0,
      cap: (json['cap'] as num?)?.toInt() ?? 0,
      pct: (json['pct'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Per-plan feature gates from `plan.features`. A `false` flag means the tool
/// is locked on the caller's plan (the server 403s if called anyway).
@immutable
class PlanFeatures {
  const PlanFeatures({
    this.voice = false,
    this.postgres = false,
    this.github = false,
    this.serverShell = false,
  });

  final bool voice;
  final bool postgres;
  final bool github;
  final bool serverShell;

  /// Generic lookup by wire key — lets callers gate on a server-named
  /// feature without a hardcoded field reference.
  bool enabled(String key) => switch (key) {
        'voice' => voice,
        'postgres' => postgres,
        'github' => github,
        'server_shell' => serverShell,
        _ => false,
      };

  factory PlanFeatures.fromJson(Map<String, dynamic> json) {
    return PlanFeatures(
      voice: json['voice'] as bool? ?? false,
      postgres: json['postgres'] as bool? ?? false,
      github: json['github'] as bool? ?? false,
      serverShell: json['server_shell'] as bool? ?? false,
    );
  }
}

/// The `conversation.plan` object — plan identity, the three usage windows,
/// and feature gates. Surfaced app-wide via `PlanCubit` so the account
/// screen, chat banners, and feature gating all read one source of truth.
@immutable
class PlanSnapshot {
  const PlanSnapshot({
    required this.slug,
    required this.name,
    required this.exempt,
    required this.day,
    required this.week,
    required this.month,
    required this.features,
  });

  /// Plan slug — `free | pro | max-5x | max-20x`.
  final String slug;

  /// Display name — `Free | Pro | Max | Max 20×`.
  final String name;

  /// Staff/superuser bypass — when `true`, all caps are ignored and every
  /// feature shows regardless of [features].
  final bool exempt;

  final UsageWindow day;
  final UsageWindow week;
  final UsageWindow month;
  final PlanFeatures features;

  bool get isFree => slug == 'free';

  /// `true` when a paid badge should show next to the user (web shows the
  /// badge for any non-free plan).
  bool get showBadge => !isFree && name.isNotEmpty;

  /// Whether a feature is available to this account — `exempt` always wins.
  bool feature(String key) => exempt || features.enabled(key);

  /// The most-constrained window that is near its limit (≥80%, <100%), or
  /// `null` when nothing is near. Day takes precedence (resets soonest).
  UsageWindow? get nearLimitWindow {
    for (final w in [day, week, month]) {
      if (w.nearLimit) return w;
    }
    return null;
  }

  factory PlanSnapshot.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) =>
        (json[key] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlanSnapshot(
      slug: json['plan'] as String? ?? 'free',
      name: json['plan_name'] as String? ?? '',
      exempt: json['exempt'] as bool? ?? false,
      day: UsageWindow.fromJson(sub('day')),
      week: UsageWindow.fromJson(sub('week')),
      month: UsageWindow.fromJson(sub('month')),
      features: PlanFeatures.fromJson(sub('features')),
    );
  }
}

/// Identifies which usage window was exceeded on a blocked send.
enum QuotaWindow {
  day('day'),
  week('week'),
  month('month');

  const QuotaWindow(this.wire);
  final String wire;

  static QuotaWindow? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final w in QuotaWindow.values) {
      if (w.wire == value) return w;
    }
    return null;
  }
}
