import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/features/apps/data/app_package_models.dart';
import 'package:saqqar_app/features/apps/data/apps_api.dart';
import 'package:saqqar_app/features/apps/view_model/apps_cubit.dart';

/// In-memory [AppsApi] — never touches Dio. Returns [apps] / [launchId] or
/// throws so both cubit branches are exercised.
class _FakeAppsApi implements AppsApi {
  _FakeAppsApi({this.apps = const [], this.error});

  final List<SaqqarApp> apps;
  final String launchId = 'conv-1';
  final Object? error;
  int listCalls = 0;
  String? lastLaunchedSlug;
  String? lastEnvironmentId;

  @override
  Future<List<SaqqarApp>> list() async {
    listCalls++;
    if (error != null) throw error!;
    return apps;
  }

  @override
  Future<String> launch(String slug, {String? environmentId}) async {
    lastLaunchedSlug = slug;
    lastEnvironmentId = environmentId;
    if (error != null) throw error!;
    return launchId;
  }
}

SaqqarApp _app(String slug) => SaqqarApp(
      slug: slug,
      name: 'ZATCA e-invoicing',
      tagline: 'Onboard Fatoora Phase-2',
      category: 'Compliance · KSA',
      group: 'Finance',
      accent: '#14B8A6',
      iconSvg: '<svg/>',
      envRequired: true,
    );

void main() {
  group('SaqqarApp.fromJson', () {
    test('reads every field the tile renders', () {
      final app = SaqqarApp.fromJson(const {
        'slug': 'zatca',
        'name': 'ZATCA e-invoicing',
        'tagline': 'Onboard Fatoora',
        'category': 'Compliance · KSA',
        'group': 'Finance',
        'accent': '#14B8A6',
        'icon_svg': '<svg/>',
        'env_required': true,
      });
      expect(app.slug, 'zatca');
      expect(app.name, 'ZATCA e-invoicing');
      expect(app.accent, '#14B8A6');
      expect(app.envRequired, isTrue);
    });

    test('defaults missing fields instead of throwing', () {
      final app = SaqqarApp.fromJson(const {'slug': 'x'});
      expect(app.name, '');
      expect(app.envRequired, isFalse);
    });
  });

  group('AppsCubit', () {
    test('starts idle', () {
      final cubit = AppsCubit(_FakeAppsApi());
      addTearDown(cubit.close);
      expect(cubit.state, isA<DataIdle<List<SaqqarApp>>>());
    });

    test('load() emits DataSuccess with the catalogue', () async {
      final cubit = AppsCubit(_FakeAppsApi(apps: [_app('zatca'), _app('wa')]));
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, isA<DataSuccess<List<SaqqarApp>>>());
      expect((cubit.state as DataSuccess<List<SaqqarApp>>).data, hasLength(2));
    });

    test('load() emits DataFailure with a typed error on throw', () async {
      final cubit = AppsCubit(_FakeAppsApi(error: Exception('boom')));
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, isA<DataFailure<List<SaqqarApp>>>());
      expect((cubit.state as DataFailure<List<SaqqarApp>>).error, isNotNull);
    });
  });

  group('AppsApi.launch', () {
    test('omits environment_id when none is passed', () async {
      final api = _FakeAppsApi();
      final id = await api.launch('zatca');
      expect(id, 'conv-1');
      expect(api.lastLaunchedSlug, 'zatca');
      expect(api.lastEnvironmentId, isNull);
    });
  });
}
