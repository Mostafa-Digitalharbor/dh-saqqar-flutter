import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../data/trial_api.dart';
import '../data/trial_models.dart';
import 'trial_state.dart';

/// Drives the managed-trial screen: loads status on open, submits a request,
/// and polls `/trial/status/` every 5 s while provisioning is in progress
/// (per the doc's polling guidance). Stops polling on `ready` / `failed` /
/// `none` and on [close].
///
/// SECURITY: the `ready` payload carries live admin credentials. They flow
/// through [TrialInfo] into the widget tree and are never written to
/// [AppLogger] / Sentry — the log lines below deliberately record only the
/// state name, never the credential fields.
class TrialCubit extends Cubit<TrialScreenState> {
  TrialCubit(this._api) : super(const TrialScreenState());

  static const _tag = 'TrialCubit';
  static const _pollInterval = Duration(seconds: 5);

  final TrialApi _api;
  Timer? _poll;

  /// Initial status fetch on screen open. Calling `/status/` also nudges
  /// provisioning server-side, so this doubles as "resume where we left off".
  Future<void> loadStatus() async {
    if (state.status is DataLoading<TrialInfo>) return;
    emit(
      state.copyWith(
        status: DataLoading<TrialInfo>(previous: state.status.dataOrNull),
      ),
    );
    await _fetchStatus();
  }

  /// Submit a trial request. On success, adopt the returned info and start
  /// polling if it's still provisioning.
  Future<void> submit(TrialRequest req) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, clearSubmitError: true));
    try {
      final info = await _api.request(req);
      emit(state.copyWith(status: DataSuccess(info), submitting: false));
      AppLogger.info(_tag, 'trial requested → ${info.state.name}');
      _syncPolling(info);
    } catch (e, st) {
      AppLogger.warn(_tag, 'submit failed', error: e, stackTrace: st);
      emit(state.copyWith(submitting: false, submitError: e));
    }
  }

  /// Single status poll, shared by [loadStatus] and the periodic timer.
  Future<void> _fetchStatus() async {
    try {
      final info = await _api.status();
      if (isClosed) return;
      emit(state.copyWith(status: DataSuccess(info)));
      AppLogger.info(_tag, 'trial status → ${info.state.name}');
      _syncPolling(info);
    } catch (e, st) {
      if (isClosed) return;
      AppLogger.warn(_tag, 'status fetch failed', error: e, stackTrace: st);
      // Keep any status already on screen; a transient poll failure must not
      // blank a provisioning card. Only surface a full error when we have
      // nothing to show yet.
      final prev = state.status.dataOrNull;
      if (prev == null) {
        emit(
          state.copyWith(
            status: DataFailure<TrialInfo>(error: ApiErrorMapper.toFailure(e)),
          ),
        );
      }
      // On a poll failure with existing data, leave the timer running — the
      // next tick may recover.
    }
  }

  /// Start/stop the periodic poll to match the trial's progress.
  void _syncPolling(TrialInfo info) {
    if (info.state.isInProgress) {
      _poll ??= Timer.periodic(_pollInterval, (_) => _fetchStatus());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
