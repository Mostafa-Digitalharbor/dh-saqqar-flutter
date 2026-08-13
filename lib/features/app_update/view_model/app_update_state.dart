import 'package:equatable/equatable.dart';

import '../data/app_update_status.dart';
import '../data/play_update_service.dart';

/// What the update gate should currently render.
///
/// [Equatable] so an idle re-check that returns the same numbers emits an
/// identical state and rebuilds nothing — the same reason the API models are
/// value types. The gate wraps the whole router, so a spurious rebuild here is
/// a spurious rebuild of every screen.
class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.decision = AppUpdateDecision.none,
    this.status,
    this.play,
    this.dismissed = false,
  });

  final AppUpdateDecision decision;

  /// What our backend said, kept so the UI can name the version the user is
  /// being sent to fetch and open the right store URL. Null until
  /// `/api/v1/app/version/` exists.
  final AppUpdateStatus? status;

  /// What Play said. Android only, and independent of [status] — on a device
  /// where the backend endpoint is still a 404 this is the ONLY source, which
  /// is what makes the Android half of the feature work today.
  final PlayUpdateInfo? play;

  /// The user tapped "later" for this exact [targetBuild]. Never set for
  /// [AppUpdateDecision.required] — a blocking gate has no dismiss affordance.
  final bool dismissed;

  /// The blocking wall is showing.
  bool get isBlocking => decision == AppUpdateDecision.required;

  /// The dismissible nudge should be visible.
  bool get showsNudge => decision == AppUpdateDecision.optional && !dismissed;

  /// Play can install this without leaving the app.
  bool get canUpdateInPlace => play?.installable ?? false;

  /// The build being offered, whichever source named it.
  ///
  /// The backend wins when both spoke: it is the one that knows *why* an
  /// update matters, and its number is the one the copy quotes. Play's is the
  /// fallback so a dismissal still keys onto something real when the endpoint
  /// is a 404.
  ///
  /// `> 0`, not just non-null. `AppUpdateStatus.fromJson` collapses a missing
  /// or unreadable `latest_build` to `0` — deliberately, so a half-understood
  /// body cannot gate anyone — and a plain `??` treats that zero as an answer.
  /// It would then shadow Play's real version code, and the dismissal would
  /// key on `0` forever: one "later" would mute every future release on
  /// Android. Covered by `a zero latest_build does not shadow Play's code`.
  int? get targetBuild {
    final fromBackend = status?.latestBuild;
    if (fromBackend != null && fromBackend > 0) return fromBackend;
    return play?.availableVersionCode;
  }

  AppUpdateState copyWith({
    AppUpdateDecision? decision,
    AppUpdateStatus? status,
    PlayUpdateInfo? play,
    bool? dismissed,
  }) {
    return AppUpdateState(
      decision: decision ?? this.decision,
      status: status ?? this.status,
      play: play ?? this.play,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  @override
  List<Object?> get props => [decision, status, play, dismissed];
}
