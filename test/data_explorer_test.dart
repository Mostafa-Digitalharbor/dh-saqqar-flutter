import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';
import 'package:saqqar_app/features/data_api/view_model/data_explorer_cubit.dart';
import 'package:saqqar_app/features/data_api/view_model/data_explorer_state.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';

/// `noSuchMethod` fakes: [ProjectsApi] / [OdooDataApi] have many methods, but
/// the cubit only touches `list` + the seven data ops, so we stub those and
/// let the rest no-op-throw (declaring noSuchMethod suppresses the analyzer's
/// missing-member errors).
class _FakeProjectsApi implements ProjectsApi {
  _FakeProjectsApi(this.projects);
  final List<Project> projects;

  @override
  Future<List<Project>> list() async => projects;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeOdooDataApi implements OdooDataApi {
  String? lastCalled;
  Map<String, dynamic>? lastQuery;

  Future<Map<String, dynamic>> _record(String op, Map<String, dynamic> q) async {
    lastCalled = op;
    lastQuery = q;
    return {'op': op, 'count': 3};
  }

  @override
  Future<Map<String, dynamic>> count(String e, Map<String, dynamic> q) =>
      _record('count', q);
  @override
  Future<Map<String, dynamic>> search(String e, Map<String, dynamic> q) =>
      _record('search', q);
  @override
  Future<Map<String, dynamic>> readGroup(String e, Map<String, dynamic> q) =>
      _record('read-group', q);
  @override
  Future<Map<String, dynamic>> read(String e, Map<String, dynamic> q) =>
      _record('read', q);
  @override
  Future<Map<String, dynamic>> fields(String e, Map<String, dynamic> q) =>
      _record('fields', q);
  @override
  Future<Map<String, dynamic>> sql(String e, Map<String, dynamic> q) =>
      _record('sql', q);
  @override
  Future<Map<String, dynamic>> reportEntities(Map<String, dynamic> q) async {
    lastCalled = 'report-entities';
    lastQuery = q;
    return {'entities': <dynamic>[]};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Environment _env(String id, String name) => Environment(
      id: id,
      name: name,
      slug: name,
      isLive: false,
      readOnly: true,
      autoApprove: false,
      projectId: 'p1',
    );

Project _project() => Project(
      id: 'p1',
      name: 'Acme',
      slug: 'acme',
      environments: [_env('e1', 'prod'), _env('e2', 'staging')],
    );

DataExplorerCubit _cubit(_FakeOdooDataApi data) => DataExplorerCubit(
      projects: _FakeProjectsApi([_project()]),
      data: data,
    );

void main() {
  test('DataOp.count is the default operation', () {
    expect(const DataExplorerState().operation, DataOp.count);
    // Every op takes a JSON object now — report-entities differs only in
    // transport (GET, so the object rides as query parameters).
    expect(DataOp.reportEntities.needsBody, isTrue);
    expect(DataOp.reportEntities.isGet, isTrue);
    expect(DataOp.count.needsBody, isTrue);
    expect(DataOp.count.isGet, isFalse);
  });

  group('loadEnvironments', () {
    test('flattens projects into env refs and auto-selects the first', () async {
      final cubit = _cubit(_FakeOdooDataApi());
      addTearDown(cubit.close);

      await cubit.loadEnvironments();

      expect(cubit.state.loadingEnvs, isFalse);
      expect(cubit.state.environments, hasLength(2));
      expect(cubit.state.environments.first.label, 'Acme · prod');
      expect(cubit.state.selectedEnvId, 'e1');
    });
  });

  group('run', () {
    test('dispatches to the selected op with the parsed JSON body', () async {
      final data = _FakeOdooDataApi();
      final cubit = _cubit(data);
      addTearDown(cubit.close);
      await cubit.loadEnvironments();

      cubit.selectOperation(DataOp.search);
      await cubit.run('{"model": "res.partner", "limit": 5}');

      expect(data.lastCalled, 'search');
      expect(data.lastQuery, {'model': 'res.partner', 'limit': 5});
      expect(cubit.state.result, contains('"op": "search"'));
    });

    // `GET /report-entities/` with no parameters answers
    // `400 conversation_id is required and must belong to you` (verified
    // against production 2026-07-29), so the op used to be the one operation
    // on this screen that could never succeed. It is conversation-scoped, and
    // the explorer only knows about environments — so the id is part of the
    // request the user writes, like every other shape here.
    test('report-entities forwards conversation_id to the GET', () async {
      final data = _FakeOdooDataApi();
      final cubit = _cubit(data);
      addTearDown(cubit.close);
      await cubit.loadEnvironments();

      cubit.selectOperation(DataOp.reportEntities);
      await cubit.run('{"conversation_id": "abc-123"}');

      expect(data.lastCalled, 'report-entities');
      expect(data.lastQuery, {'conversation_id': 'abc-123'});
      expect(cubit.state.result, contains('entities'));
    });

    test('report-entities template names the required parameter', () {
      expect(DataOp.reportEntities.template, contains('conversation_id'));
    });

    test('invalid JSON body yields a FormatException, no call', () async {
      final data = _FakeOdooDataApi();
      final cubit = _cubit(data);
      addTearDown(cubit.close);
      await cubit.loadEnvironments();

      await cubit.run('not json');

      expect(cubit.state.queryError, isA<FormatException>());
      expect(data.lastCalled, isNull);
    });

    test('selectOperation clears the previous result', () async {
      final data = _FakeOdooDataApi();
      final cubit = _cubit(data);
      addTearDown(cubit.close);
      await cubit.loadEnvironments();
      await cubit.run('{"model":"res.partner"}');
      expect(cubit.state.result, isNotEmpty);

      cubit.selectOperation(DataOp.fields);
      expect(cubit.state.result, isEmpty);
      expect(cubit.state.operation, DataOp.fields);
    });
  });
}
