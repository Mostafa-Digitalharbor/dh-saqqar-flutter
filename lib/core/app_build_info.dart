/// The build this process is running, read once from `PackageInfo` in
/// `main()`.
///
/// A holder rather than a `PackageInfo.fromPlatform()` call at each use site:
/// that call crosses a platform channel, and the two consumers need the value
/// in places where an async gap is awkward — `AppUpdateCubit` is constructed
/// synchronously inside a `BlocProvider`, and the auth screen's badge would
/// otherwise flicker through a `FutureBuilder` on every rebuild.
///
/// Empty when the read failed. Every consumer treats that as "unknown" rather
/// than substituting a value — see `AppUpdateDecision.forBuild` for why a
/// missing build number must never resolve to `0`.
class AppBuildInfo {
  AppBuildInfo._();

  /// Semver, e.g. `1.2.6`.
  static String version = '';

  /// Platform build code, e.g. `203`. Raw, exactly as the platform reports
  /// it — iOS `CFBundleVersion` is free-form and is not always an integer.
  static String buildNumber = '';

  /// `1.2.6 (203)`, or just the version when the build code is unknown, or
  /// empty when neither was read.
  ///
  /// Shown on the sign-in screen so a tester can see at a glance which build
  /// a device is actually running. That is the whole point of a staged
  /// rollout: "did the update land?" should be answerable by looking, not by
  /// digging through Android's app-info screen.
  static String get label {
    if (version.isEmpty) return '';
    if (buildNumber.isEmpty) return version;
    return '$version ($buildNumber)';
  }
}
