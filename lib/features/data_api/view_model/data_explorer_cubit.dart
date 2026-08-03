import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../vault/data/projects_api.dart';
import '../data/odoo_data_api.dart';
import 'data_explorer_state.dart';

/// Drives the read-only Odoo data explorer (API_MOBILE_NEW_ENDPOINTS.md
/// §4.2). Lists the caller's environments for the picker, then runs any of
/// the seven deterministic operations (count / search / read-group / read /
/// fields / SQL / report-entities) against the selected one — no agent, no
/// LLM cost.
///
/// The request body is user-supplied JSON (see [DataOp.template]), so the
/// screen sends exactly what the user provides and shows exactly what the
/// server returns — no guessed request schema baked in.
class DataExplorerCubit extends Cubit<DataExplorerState> {
  DataExplorerCubit({required ProjectsApi projects, required OdooDataApi data})
      : _projects = projects,
        _data = data,
        super(const DataExplorerState());

  static const _tag = 'DataExplorerCubit';
  static const _encoder = JsonEncoder.withIndent('  ');

  final ProjectsApi _projects;
  final OdooDataApi _data;

  /// Load the environment picker options from the caller's projects.
  Future<void> loadEnvironments() async {
    emit(state.copyWith(loadingEnvs: true, clearEnvError: true));
    try {
      final projects = await _projects.list();
      final envs = <EnvRef>[
        for (final p in projects)
          for (final e in p.environments)
            EnvRef(
              id: e.id,
              label: '${p.name} · ${e.name}',
              readOnly: e.readOnly,
            ),
      ];
      emit(state.copyWith(
        environments: envs,
        loadingEnvs: false,
        selectedEnvId:
            state.selectedEnvId ?? (envs.isNotEmpty ? envs.first.id : null),
      ));
    } catch (e, st) {
      AppLogger.warn(_tag, 'loadEnvironments failed', error: e, stackTrace: st);
      emit(state.copyWith(loadingEnvs: false, envError: e));
    }
  }

  void selectEnv(String id) => emit(state.copyWith(selectedEnvId: id));

  void selectOperation(DataOp op) =>
      emit(state.copyWith(operation: op, clearQueryError: true, result: ''));

  /// Run the current [DataExplorerState.operation] with [bodyText] (JSON) as
  /// the request shape. `report-entities` is a GET, so its object travels as
  /// query parameters — see [DataOp.isGet].
  Future<void> run(String bodyText) async {
    final envId = state.selectedEnvId;
    final op = state.operation;
    if (envId == null || state.running) return;

    Map<String, dynamic> body = const {};
    if (op.needsBody) {
      try {
        final parsed = jsonDecode(bodyText);
        if (parsed is! Map) throw const FormatException('body must be a JSON object');
        body = parsed.cast<String, dynamic>();
      } on FormatException catch (e) {
        emit(state.copyWith(queryError: e, result: ''));
        return;
      }
    }

    emit(state.copyWith(running: true, clearQueryError: true, result: ''));
    try {
      final res = await _dispatch(op, envId, body);
      emit(state.copyWith(running: false, result: _encoder.convert(res)));
    } catch (e, st) {
      AppLogger.warn(_tag, '$op failed', error: e, stackTrace: st);
      emit(state.copyWith(running: false, queryError: e));
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    DataOp op,
    String envId,
    Map<String, dynamic> body,
  ) {
    switch (op) {
      case DataOp.count:
        return _data.count(envId, body);
      case DataOp.search:
        return _data.search(envId, body);
      case DataOp.readGroup:
        return _data.readGroup(envId, body);
      case DataOp.read:
        return _data.read(envId, body);
      case DataOp.fields:
        return _data.fields(envId, body);
      case DataOp.sql:
        return _data.sql(envId, body);
      case DataOp.reportEntities:
        return _data.reportEntities(body);
    }
  }
}
