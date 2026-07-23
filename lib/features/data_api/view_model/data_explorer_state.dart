import 'package:equatable/equatable.dart';

/// The read-only Odoo operations the explorer can run
/// (API_MOBILE_NEW_ENDPOINTS.md §4.2). Each maps to one endpoint.
enum DataOp {
  count,
  search,
  readGroup,
  read,
  fields,
  sql,
  reportEntities;

  /// `report-entities` is a bodyless GET; every other op POSTs a JSON body.
  bool get needsBody => this != DataOp.reportEntities;

  /// Odoo-ORM operation name shown in the picker. These are the backend's own
  /// vocabulary (technical terms), so they stay English in both locales — same
  /// convention as the rest of `UiStrings`.
  String get label => switch (this) {
        DataOp.count => 'count',
        DataOp.search => 'search',
        DataOp.readGroup => 'read-group',
        DataOp.read => 'read',
        DataOp.fields => 'fields',
        DataOp.sql => 'sql',
        DataOp.reportEntities => 'report-entities',
      };

  /// A starter request body shown when the op is picked. Guidance only —
  /// the user edits it; the exact keys should be confirmed against
  /// `odoo_agent/views_data_api.py`.
  String get template {
    switch (this) {
      case DataOp.count:
        return '{\n  "model": "res.partner",\n  "domain": []\n}';
      case DataOp.search:
        return '{\n  "model": "res.partner",\n  "domain": [],\n  "fields": ["id", "name"],\n  "limit": 20\n}';
      case DataOp.readGroup:
        return '{\n  "model": "res.partner",\n  "domain": [],\n  "groupby": ["country_id"],\n  "fields": ["id"]\n}';
      case DataOp.read:
        return '{\n  "model": "res.partner",\n  "ids": [1],\n  "fields": ["id", "name"]\n}';
      case DataOp.fields:
        return '{\n  "model": "res.partner"\n}';
      case DataOp.sql:
        return '{\n  "query": "SELECT id, name FROM res_partner LIMIT 5"\n}';
      case DataOp.reportEntities:
        return '';
    }
  }
}

/// One selectable environment for the picker — the bound env's id plus a
/// human label (`Project · Env`).
class EnvRef extends Equatable {
  const EnvRef({required this.id, required this.label, required this.readOnly});

  final String id;
  final String label;
  final bool readOnly;

  @override
  List<Object?> get props => [id, label, readOnly];
}

/// State for the read-only Odoo data explorer (§4.2).
class DataExplorerState extends Equatable {
  const DataExplorerState({
    this.environments = const [],
    this.loadingEnvs = true,
    this.selectedEnvId,
    this.operation = DataOp.count,
    this.running = false,
    this.result = '',
    this.envError,
    this.queryError,
  });

  final List<EnvRef> environments;
  final bool loadingEnvs;
  final String? selectedEnvId;
  final DataOp operation;

  /// A query is in flight.
  final bool running;

  /// Last query result, pretty-printed JSON.
  final String result;

  /// Failure loading the environment list (view maps via ApiErrorMapper).
  final Object? envError;

  /// Failure of the last query. A [FormatException] means the body wasn't
  /// valid JSON; anything else is a request failure.
  final Object? queryError;

  DataExplorerState copyWith({
    List<EnvRef>? environments,
    bool? loadingEnvs,
    String? selectedEnvId,
    DataOp? operation,
    bool? running,
    String? result,
    Object? envError,
    Object? queryError,
    bool clearEnvError = false,
    bool clearQueryError = false,
  }) {
    return DataExplorerState(
      environments: environments ?? this.environments,
      loadingEnvs: loadingEnvs ?? this.loadingEnvs,
      selectedEnvId: selectedEnvId ?? this.selectedEnvId,
      operation: operation ?? this.operation,
      running: running ?? this.running,
      result: result ?? this.result,
      envError: clearEnvError ? null : (envError ?? this.envError),
      queryError: clearQueryError ? null : (queryError ?? this.queryError),
    );
  }

  @override
  List<Object?> get props => [
        environments,
        loadingEnvs,
        selectedEnvId,
        operation,
        running,
        result,
        envError,
        queryError,
      ];
}
