import 'package:equatable/equatable.dart';

/// What the backend says about the build the user is currently running.
///
/// Two numbers, deliberately separate:
///
///  * [minSupportedBuild] — the floor. Anything below it is a build the
///    backend no longer wants talking to it (a broken contract, a leaked
///    token format, a payload shape that was removed). Blocking.
///  * [latestBuild] — the newest build actually installable from that
///    platform's store. Anything below it is merely stale. Suggestible.
///
/// Store-driven auto-update takes 1–7 days to reach a device, which is the
/// whole reason this exists: it lets a fix reach users in hours instead, by
/// telling them a build is waiting rather than waiting for the OS to notice.
class AppUpdateStatus extends Equatable {
  const AppUpdateStatus({
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.latestVersion,
    required this.storeUrl,
  });

  final int minSupportedBuild;
  final int latestBuild;

  /// Human-readable semver of [latestBuild] (e.g. `1.2.5`), shown in copy.
  final String latestVersion;

  /// Deep link to this platform's store listing. Comes from the wire on
  /// purpose — hardcoding a Play/App Store URL would (a) trip the
  /// "no absolute http(s) URL" source invariant and (b) mean a bundle-id or
  /// listing change could only be fixed by shipping the very update the
  /// user is being sent to fetch.
  final String storeUrl;

  /// `true` when [currentBuild] is below the supported floor.
  ///
  /// Three ways this deliberately answers "no" even though the raw numbers
  /// say otherwise — each is a misconfiguration that would otherwise brick
  /// every install on the platform, with no recovery path inside the app:
  ///
  ///  * **No store URL.** Blocking is only legitimate if the user can act on
  ///    it. A full-screen wall with no button is a dead end, so an absent
  ///    link downgrades the whole thing to "no opinion".
  ///  * **A floor above the ceiling.** `min_supported_build > latest_build`
  ///    demands a build that exists on no store, so literally no user could
  ///    ever satisfy it. That is a typo in a backend config, not a policy.
  ///  * **An unreadable local build.** See [AppUpdateDecision.forBuild].
  ///
  /// The bias is fail-open throughout. A missed block costs one stale
  /// client; a wrongly-enforced one costs every client at once and can only
  /// be undone from the server the blocked app is refusing to trust.
  bool blocks(int currentBuild) {
    if (storeUrl.isEmpty) return false;
    if (minSupportedBuild > latestBuild) return false;
    return currentBuild < minSupportedBuild;
  }

  /// `true` when a newer build exists but the current one still works.
  bool suggests(int currentBuild) =>
      storeUrl.isNotEmpty && currentBuild < latestBuild;

  /// Reads the wire shape. Every field is optional on the wire and every
  /// absence collapses to a value that cannot trigger a gate — a body the
  /// server sent but we only half-understood must never lock anyone out.
  factory AppUpdateStatus.fromJson(Map<String, dynamic> json) {
    return AppUpdateStatus(
      minSupportedBuild: _asInt(json['min_supported_build']) ?? 0,
      latestBuild: _asInt(json['latest_build']) ?? 0,
      latestVersion: (json['latest_version'] as String?)?.trim() ?? '',
      storeUrl: (json['store_url'] as String?)?.trim() ?? '',
    );
  }

  @override
  List<Object?> get props => [
    minSupportedBuild,
    latestBuild,
    latestVersion,
    storeUrl,
  ];
}

/// What the app should do about [AppUpdateStatus] for this specific install.
enum AppUpdateDecision {
  /// Nothing to say — up to date, endpoint absent, or anything unreadable.
  none,

  /// A newer build exists. Dismissible nudge.
  optional,

  /// This build is below the supported floor. Blocking.
  required;

  /// Resolves a decision from a status and the raw `buildNumber` string that
  /// `PackageInfo.fromPlatform()` hands back.
  ///
  /// That string is NOT reliably an integer. It is whatever the platform put
  /// in `CFBundleVersion` / `versionCode`, which on iOS is free-form and can
  /// legitimately read `1.2.5` or be empty on a simulator build. Parsing it
  /// with a bare `int.parse` throws; parsing with `int.tryParse(...) ?? 0`
  /// is worse — it silently reports build 0, which is below every
  /// conceivable floor, so **every user on that platform** would be shown
  /// the blocking wall. Unreadable therefore means [none].
  static AppUpdateDecision forBuild(AppUpdateStatus? status, String rawBuild) {
    if (status == null) return AppUpdateDecision.none;
    final current = int.tryParse(rawBuild.trim());
    if (current == null) return AppUpdateDecision.none;
    if (status.blocks(current)) return AppUpdateDecision.required;
    if (status.suggests(current)) return AppUpdateDecision.optional;
    return AppUpdateDecision.none;
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
