import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../push/data/devices_api.dart' show DevicePlatform;
import '../data/app_update_api.dart';
import '../data/app_update_status.dart';
import '../data/play_update_service.dart';
import 'app_update_state.dart';

/// Owns "should this build still be running, and is a newer one waiting?".
///
/// Two independent sources, because they know different things:
///
///  * **Our backend** (`/api/v1/app/version/`) owns the *floor* — which builds
///    the API still supports. Nothing else can know that.
///  * **Play** owns the *ceiling* on Android — what is genuinely installable
///    on this device right now, including whether a staged rollout has reached
///    it. It is also the only one that can install without leaving the app.
///
/// Neither is required. With only the backend you get both gates and a store
/// link; with only Play you get the nudge and an in-place install; with
/// neither, nothing happens at all and the app behaves exactly as it did
/// before this feature existed.
///
/// [currentBuild] and [platform] are injected rather than read here —
/// `currentBuild` comes from the `PackageInfo` call `main()` already makes for
/// Sentry's release tag — so the whole decision table is testable without a
/// device.
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit({
    required AppUpdateApi api,
    required SharedPreferences prefs,
    required this.currentBuild,
    required this.platform,
    PlayUpdateService? play,
    this.minRecheckInterval = const Duration(hours: 6),
  })  : _api = api,
        _prefs = prefs,
        _play = play,
        super(const AppUpdateState());

  final AppUpdateApi _api;
  final SharedPreferences _prefs;

  /// Null on iOS and in tests that do not care about Play. Non-null implies
  /// Android — `main.dart` is the only place that decides that, so nothing
  /// here has to re-derive the platform.
  final PlayUpdateService? _play;

  /// Raw `CFBundleVersion` / `versionCode` string, exactly as the platform
  /// reports it. Deliberately not pre-parsed — see [AppUpdateDecision.forBuild]
  /// for why an unparseable value must not become `0`.
  final String currentBuild;

  final DevicePlatform platform;

  /// Floor on how often [check] hits the network. `resumed` fires on every app
  /// switch, and the answer changes at most once per release; without this the
  /// gate would out-poll the chat surface.
  final Duration minRecheckInterval;

  static const String _dismissedBuildKey = 'saqqar.app_update.dismissed_build';

  bool _inFlight = false;

  /// Monotonic, so it cannot be fooled by the user changing the device clock
  /// (or by a timezone shift) into either hammering the endpoint or never
  /// re-checking again. Started only after a check completes.
  final Stopwatch _sinceLastCheck = Stopwatch();

  /// Ask both sources. Safe to call on boot and on every resume.
  Future<void> check({bool force = false}) async {
    if (_inFlight) return;
    // Once blocking, there is nothing left to learn: the only escape is an
    // update, and installing one restarts the process. Continuing to poll from
    // behind the wall would be a retry loop nobody can see.
    if (state.isBlocking) return;
    if (!force &&
        _sinceLastCheck.isRunning &&
        _sinceLastCheck.elapsed < minRecheckInterval) {
      return;
    }

    _inFlight = true;
    try {
      final status = await _api.fetch(platform);
      final play = await _play?.check();
      if (isClosed) return;
      // Built first, then asked for its own `targetBuild`, so "which build is
      // being offered" has exactly ONE definition. Spelling the fallback out a
      // second time here is how the state's `> 0` guard got skipped and a
      // Play-only dismissal keyed onto `0`.
      final next = AppUpdateState(
        decision: _resolve(status, play),
        status: status,
        play: play,
      );
      final target = next.targetBuild;
      emit(
        next.copyWith(
          // A dismissal is scoped to the build it was made about. Tapping
          // "later" on 1.2.5 must not also silence 1.2.6 — otherwise the first
          // "later" a user ever taps mutes the nudge permanently.
          dismissed: next.decision == AppUpdateDecision.optional &&
              target != null &&
              _prefs.getInt(_dismissedBuildKey) == target,
        ),
      );
    } finally {
      _inFlight = false;
      _sinceLastCheck
        ..reset()
        ..start();
    }
  }

  /// Merges the two sources.
  ///
  /// Blocking is the backend's call ALONE. Play has no concept of a supported
  /// floor — it only ever says "something newer exists" — so promoting its
  /// answer to a block would wall users out for an ordinary release.
  ///
  /// In the other direction Play is trusted over silence: it can see a build
  /// the backend has not been told about yet, and on a device where
  /// `/api/v1/app/version/` is still a 404 it is the only voice in the room.
  AppUpdateDecision _resolve(AppUpdateStatus? status, PlayUpdateInfo? play) {
    final fromBackend = AppUpdateDecision.forBuild(status, currentBuild);
    if (fromBackend == AppUpdateDecision.required) {
      return AppUpdateDecision.required;
    }
    if (fromBackend == AppUpdateDecision.optional) {
      return AppUpdateDecision.optional;
    }
    // `installable`, not merely "available": Play reporting an update it has
    // no permitted flow for, on a build the backend is happy with, leaves us
    // nothing to offer but a store link the user did not ask for.
    if (play != null && play.installable) return AppUpdateDecision.optional;
    return AppUpdateDecision.none;
  }

  /// Installs without leaving the app, if Play can.
  ///
  /// Returns `false` when there is no in-place route — no Play service (iOS),
  /// no permitted flow, or the user backed out of Google's sheet — which is
  /// the caller's signal to fall back to the store listing.
  ///
  /// Immediate vs flexible is not a preference, it is the gate's severity:
  /// a blocked build gets Google's own blocking updater because the app is
  /// unusable until it lands, and everything else downloads in the background
  /// so the user keeps working.
  Future<bool> launchInPlaceUpdate() async {
    final play = _play;
    final info = state.play;
    if (play == null || info == null || !info.installable) return false;
    if (state.isBlocking && info.immediateAllowed) return play.runImmediate();
    if (info.flexibleAllowed) return play.runFlexible();
    // Blocked, but the console only permits the flexible flow. Still better
    // than a store bounce: it downloads and restarts into the new build.
    return play.runImmediate();
  }

  /// "Later" on the optional nudge. Persists which build was dismissed so the
  /// answer survives a restart but expires the moment a newer build ships.
  Future<void> dismiss() async {
    final target = state.targetBuild;
    if (target == null || state.decision != AppUpdateDecision.optional) return;
    await _prefs.setInt(_dismissedBuildKey, target);
    if (isClosed) return;
    emit(state.copyWith(dismissed: true));
  }
}
