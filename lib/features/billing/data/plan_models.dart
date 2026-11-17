import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// One usage window (day / week / month) from `conversation.plan`. Values are
/// in Saqqar-Token (ST) — an opaque cost-weighted credit. Caps are
/// admin-editable; NEVER hardcode them, always read [cap] from the server.
@immutable
class UsageWindow extends Equatable {
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

  @override
  List<Object?> get props => [used, cap, pct, remaining];
}

/// Per-plan feature gates from `plan.features`. A `false` flag means the tool
/// is locked on the caller's plan (the server 403s if called anyway).
@immutable
class PlanFeatures extends Equatable {
  const PlanFeatures({
    this.voice = false,
    this.postgres = false,
    this.github = false,
    this.serverShell = false,
    this.flags = const {},
  });

  final bool voice;
  final bool postgres;
  final bool github;
  final bool serverShell;

  /// EVERY boolean the server sent under `plan.features`, verbatim.
  ///
  /// The four typed fields above are the flags the app has shipped UI for.
  /// The web gates several more rows off its own feature context
  /// (`prompt_bank`, `health_radar`, `what_if`, `business_pulse`,
  /// `voice_support`, `task_prep_available`) which the mobile snapshot does
  /// not carry yet. Keeping the raw map means the day the backend adds one,
  /// [enabled] / [has] resolve it with no client release — and until then
  /// [has] can tell "the server said false" apart from "the server never
  /// mentioned it", which is the difference between hiding a locked control
  /// and hiding a working one.
  final Map<String, bool> flags;

  /// Generic lookup by wire key — lets callers gate on a server-named
  /// feature without a hardcoded field reference. Unknown keys are `false`.
  bool enabled(String key) => switch (key) {
    'voice' => voice,
    'postgres' => postgres,
    'github' => github,
    'server_shell' => serverShell,
    _ => flags[key] ?? false,
  };

  /// Whether the server expressed an opinion about [key] at all.
  bool has(String key) => flags.containsKey(key);

  factory PlanFeatures.fromJson(Map<String, dynamic> json) {
    return PlanFeatures(
      voice: json['voice'] as bool? ?? false,
      postgres: json['postgres'] as bool? ?? false,
      github: json['github'] as bool? ?? false,
      serverShell: json['server_shell'] as bool? ?? false,
      // Booleans only: a non-bool value would make `enabled` lie about a
      // flag it can't actually evaluate.
      flags: {
        for (final entry in json.entries)
          if (entry.value is bool) entry.key: entry.value as bool,
      },
    );
  }

  @override
  List<Object?> get props => [voice, postgres, github, serverShell, flags];
}

/// The `conversation.plan` object — plan identity, the three usage windows,
/// and feature gates. Surfaced app-wide via `PlanCubit` so the account
/// screen, chat banners, and feature gating all read one source of truth.
@immutable
class PlanSnapshot extends Equatable {
  const PlanSnapshot({
    required this.slug,
    required this.name,
    required this.exempt,
    required this.day,
    required this.week,
    required this.month,
    required this.features,
    this.status = '',
    this.cycle = '',
    this.expiresAt,
    this.tokenBalance = 0,
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

  /// Subscription state — `active` | `trialing` | `canceled` | `past_due`.
  /// Empty when the server didn't send one (free / never-paid accounts, and
  /// the chat-snapshot shape, which carries no subscription fields).
  final String status;

  /// `monthly` | `annual`, or empty when unknown.
  final String cycle;

  /// When the current paid period ends / renews.
  ///
  /// **Not a cut-off.** Saqqar billing is prepaid: entitlement is
  /// [tokenBalance] plus the window caps, so nothing stops working on this
  /// date. `null` for free or never-paid accounts — render "Renews on …" only
  /// when it's present, never a countdown to a lockout that doesn't happen.
  final DateTime? expiresAt;

  /// Prepaid balance in ST. This, not [expiresAt], is what buys access.
  final int tokenBalance;

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
      status: json['status'] as String? ?? '',
      cycle: json['cycle'] as String? ?? '',
      expiresAt: _parseDate(json['expires_at']),
      tokenBalance: (json['token_balance'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

  @override
  List<Object?> get props => [
    slug,
    name,
    exempt,
    day,
    week,
    month,
    features,
    status,
    cycle,
    expiresAt,
    tokenBalance,
  ];
}

/// Why a send is blocked: a usage window that will roll over, or a token
/// balance that will not.
///
/// [balance] is not a window at all, which is exactly why it was missing.
/// `fromWire` returned null for it, so a user who had simply run out of
/// tokens got no banner and a live composer — they typed, sent, and watched
/// it fail, with nothing on screen saying why. The web has always named this
/// case ("You're out of tokens.") and locked the composer for it.
enum QuotaWindow {
  day('day'),
  week('week'),
  month('month'),
  balance('balance');

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
