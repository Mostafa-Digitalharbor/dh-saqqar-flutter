import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../data/app_package_models.dart';
import '../data/apps_api.dart';

/// Loads the Saqqar Apps catalogue into a [DataState] the grid renders
/// through [DataStateRefreshableView] — no branching in the view.
///
/// Launch is deliberately NOT modelled here: it's a one-shot action tied to
/// a tile tap that ends in navigation, so the screen owns its own in-flight
/// flag instead of threading a second async state through this cubit.
class AppsCubit extends Cubit<DataState<List<SaqqarApp>>> {
  AppsCubit(this._api) : super(const DataIdle());

  static const _tag = 'AppsCubit';
  final AppsApi _api;

  Future<void> load() async {
    if (state is DataLoading<List<SaqqarApp>>) return;
    emit(DataLoading<List<SaqqarApp>>(previous: state.dataOrNull));
    try {
      final apps = await _api.list();
      emit(DataSuccess(apps));
    } catch (e, st) {
      AppLogger.warn(_tag, 'load() failed', error: e, stackTrace: st);
      emit(
        DataFailure<List<SaqqarApp>>(
          error: ApiErrorMapper.toFailure(e),
          previous: state.dataOrNull,
        ),
      );
    }
  }

  Future<void> refresh() => load();
}
