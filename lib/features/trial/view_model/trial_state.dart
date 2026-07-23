import 'package:equatable/equatable.dart';

import '../../../core/state/data_state.dart';
import '../data/trial_models.dart';

/// State for the trial screen: the current trial [status] as a [DataState]
/// plus a transient [submitting] flag for the request round-trip.
///
/// Keeping `submitting` out of [DataState] lets the screen show the request
/// form's inline spinner without disturbing whatever status is on screen
/// (e.g. `none` while the POST is in flight).
class TrialScreenState extends Equatable {
  const TrialScreenState({
    this.status = const DataIdle<TrialInfo>(),
    this.submitting = false,
    this.submitError,
  });

  final DataState<TrialInfo> status;
  final bool submitting;

  /// Raw error from the last failed [TrialCubit.submit]; the view maps it to
  /// a localized message via `ApiErrorMapper`. Cleared on the next attempt.
  final Object? submitError;

  TrialScreenState copyWith({
    DataState<TrialInfo>? status,
    bool? submitting,
    Object? submitError,
    bool clearSubmitError = false,
  }) {
    return TrialScreenState(
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  @override
  List<Object?> get props => [status, submitting, submitError];
}
