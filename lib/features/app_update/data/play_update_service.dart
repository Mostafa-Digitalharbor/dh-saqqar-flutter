import 'package:equatable/equatable.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../../core/logging/app_logger.dart';

/// What Play itself says is installable right now.
///
/// Distinct from `AppUpdateStatus`, which is what *our* backend says. The two
/// answer different questions and neither replaces the other:
///
///  * Play knows what is genuinely on the store for this device, today,
///    including a staged rollout this user has not been included in. It has
///    no idea which builds the API still supports.
///  * The backend knows the supported floor. It has no idea whether the build
///    it is recommending has actually reached this user's country/device yet.
class PlayUpdateInfo extends Equatable {
  const PlayUpdateInfo({
    required this.availableVersionCode,
    required this.immediateAllowed,
    required this.flexibleAllowed,
  });

  /// The `versionCode` Play would install. Used as the dismissal key so
  /// "later" expires the moment a newer build ships.
  final int availableVersionCode;

  /// Google's blocking full-screen updater. Only used for a build the backend
  /// has declared unsupported.
  final bool immediateAllowed;

  /// Background download + "restart to update". The default.
  final bool flexibleAllowed;

  /// An update Play can actually install. `updateAvailable` with neither flow
  /// permitted is a real state (the developer disabled both in the console)
  /// and is worth nothing to us — the store listing is the only route left.
  bool get installable => immediateAllowed || flexibleAllowed;

  @override
  List<Object?> get props => [
    availableVersionCode,
    immediateAllowed,
    flexibleAllowed,
  ];
}

/// Thin wrapper over Play's In-App Update API.
///
/// Constructed ONLY on Android (see `main.dart`) — the plugin has no iOS
/// implementation and Apple ships no equivalent, so the iOS path is the store
/// listing and always was.
///
/// Every method swallows its failures. `checkForUpdate` throws on any install
/// Play does not recognise as its own — a sideloaded APK, an emulator image,
/// a `flutter run` build, an internal-track tester whose account is not on the
/// tester list — and every one of those is a normal developer/QA situation,
/// not a bug. A throw here must degrade to "use the store link", never to a
/// crash on the first frame.
class PlayUpdateService {
  const PlayUpdateService();

  static const _tag = 'PlayUpdateService';

  /// What Play has, or `null` when it has nothing to offer or could not say.
  Future<PlayUpdateInfo?> check() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return null;
      }
      final code = info.availableVersionCode;
      if (code == null) return null;
      return PlayUpdateInfo(
        availableVersionCode: code,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        _tag,
        'Play update check unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Google's blocking updater. Returns `false` if the user backed out or Play
  /// refused, so the caller can fall back to the store listing.
  Future<bool> runImmediate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } catch (error, stackTrace) {
      AppLogger.warn(
        _tag,
        'immediate update failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Background download, then install. The returned future completes when the
  /// DOWNLOAD finishes, not the install — `completeFlexibleUpdate` is what
  /// actually swaps the binary and restarts the app, so both calls belong
  /// together and neither is useful alone.
  Future<bool> runFlexible() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return false;
      await InAppUpdate.completeFlexibleUpdate();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        _tag,
        'flexible update failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
