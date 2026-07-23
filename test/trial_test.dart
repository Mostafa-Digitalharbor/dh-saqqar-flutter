import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/trial/data/trial_api.dart';
import 'package:saqqar_app/features/trial/data/trial_models.dart';
import 'package:saqqar_app/features/trial/view_model/trial_cubit.dart';

/// In-memory [TrialApi]. [statusInfo] is returned by both request() and
/// status() so a test controls exactly which trial state the cubit sees.
class _FakeTrialApi implements TrialApi {
  _FakeTrialApi({required this.statusInfo, this.error});

  TrialInfo statusInfo;
  final Object? error;
  TrialRequest? lastRequest;

  @override
  Future<TrialInfo> request(TrialRequest req) async {
    lastRequest = req;
    if (error != null) throw error!;
    return statusInfo;
  }

  @override
  Future<TrialInfo> status() async {
    if (error != null) throw error!;
    return statusInfo;
  }
}

void main() {
  group('TrialState.fromWire', () {
    test('maps known statuses', () {
      expect(TrialState.fromWire('none'), TrialState.none);
      expect(TrialState.fromWire('pending'), TrialState.pending);
      expect(TrialState.fromWire('provisioning'), TrialState.provisioning);
      expect(TrialState.fromWire('ready'), TrialState.ready);
      expect(TrialState.fromWire('failed'), TrialState.failed);
    });

    test('an unknown status is terminal (not in progress)', () {
      expect(TrialState.fromWire('weird'), TrialState.unknown);
      expect(TrialState.unknown.isInProgress, isFalse);
    });

    test('only pending / provisioning count as in progress', () {
      expect(TrialState.pending.isInProgress, isTrue);
      expect(TrialState.provisioning.isInProgress, isTrue);
      expect(TrialState.ready.isInProgress, isFalse);
      expect(TrialState.failed.isInProgress, isFalse);
    });
  });

  group('TrialInfo.fromJson', () {
    test('carries credentials when ready', () {
      final info = TrialInfo.fromJson(const {
        'status': 'ready',
        'ready': true,
        'url': 'https://acme.odoo.com',
        'db': 'acme-main',
        'login': 'admin',
        'password': 'secret',
      });
      expect(info.state, TrialState.ready);
      expect(info.hasCredentials, isTrue);
      expect(info.password, 'secret');
    });

    test('none state has no credentials', () {
      final info = TrialInfo.fromJson(const {'status': 'none', 'ready': false});
      expect(info.state, TrialState.none);
      expect(info.hasCredentials, isFalse);
    });
  });

  group('TrialRequest.toJson', () {
    test('always includes company_name and omits blank optionals', () {
      final body = const TrialRequest(
        companyName: '  Acme Co  ',
        workEmail: '',
        phone: '   ',
      ).toJson();
      expect(body['company_name'], 'Acme Co'); // trimmed
      expect(body.containsKey('work_email'), isFalse);
      expect(body.containsKey('phone'), isFalse);
    });

    test('includes optionals that carry a value', () {
      final body = const TrialRequest(
        companyName: 'Acme',
        workEmail: 'a@acme.com',
        phone: '+9665',
      ).toJson();
      expect(body['work_email'], 'a@acme.com');
      expect(body['phone'], '+9665');
    });
  });

  group('TrialCubit', () {
    test('loadStatus() adopts the fetched status', () async {
      final api = _FakeTrialApi(
        statusInfo: const TrialInfo(state: TrialState.none, ready: false),
      );
      final cubit = TrialCubit(api);
      addTearDown(cubit.close);

      await cubit.loadStatus();

      expect(cubit.state.status, isA<DataSuccess<TrialInfo>>());
      expect(cubit.state.status.dataOrNull?.state, TrialState.none);
    });

    test('submit() adopts the returned trial and clears submitting', () async {
      final api = _FakeTrialApi(
        statusInfo: const TrialInfo(
          state: TrialState.ready,
          ready: true,
          url: 'https://acme.odoo.com',
          login: 'admin',
          password: 'p',
        ),
      );
      final cubit = TrialCubit(api);
      addTearDown(cubit.close);

      await cubit.submit(const TrialRequest(companyName: 'Acme'));

      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.status.dataOrNull?.state, TrialState.ready);
      expect(api.lastRequest?.companyName, 'Acme');
    });

    test('submit() records the error and stops submitting on failure',
        () async {
      final api = _FakeTrialApi(
        statusInfo: const TrialInfo(state: TrialState.none, ready: false),
        error: Exception('boom'),
      );
      final cubit = TrialCubit(api);
      addTearDown(cubit.close);

      await cubit.submit(const TrialRequest(companyName: 'Acme'));

      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.submitError, isNotNull);
    });
  });
}
