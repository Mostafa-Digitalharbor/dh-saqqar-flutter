import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../data/shared_transcript_models.dart';
import '../data/shares_api.dart';

/// Loads a public, read-only shared transcript for a `/share/<token>` deep
/// link (`GET /api/v1/shares/<token>/`). Emits [DataState] so the screen
/// renders loading / data / error through [DataStateView] with no branching
/// of its own.
///
/// The backend endpoint is public + unauthenticated, so this works whether or
/// not the viewer is signed in — a share link is meant to be opened by people
/// who may not have an account.
class SharedTranscriptCubit extends Cubit<DataState<SharedTranscript>> {
  SharedTranscriptCubit(this._api) : super(const DataIdle());

  static const _tag = 'SharedTranscriptCubit';

  final SharesApi _api;

  /// Fetches the transcript for [token]. Guarded against re-entry so a rapid
  /// rebuild can't fire two in-flight loads.
  Future<void> load(String token) async {
    if (state is DataLoading<SharedTranscript>) return;
    emit(DataLoading<SharedTranscript>(previous: state.dataOrNull));
    try {
      final transcript = await _api.get(token);
      emit(DataSuccess(transcript));
    } catch (e, st) {
      AppLogger.warn(_tag, 'load($token) failed', error: e, stackTrace: st);
      emit(
        DataFailure<SharedTranscript>(
          // Unlocalized fallback only — the canonical user-facing message is
          // resolved by DataStateView via ApiErrorMapper on [error].
          message: 'Failed to load shared transcript',
          error: ApiErrorMapper.toFailure(e),
          previous: state.dataOrNull,
        ),
      );
    }
  }
}
