// The Figma company card shared by the chat's company picker and the
// Connections page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/vault/data/project_models.dart';
import 'package:saqqar_app/features/vault/widgets/fig_company_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _prod = Environment(
  id: 'e1',
  name: 'Production',
  slug: 'prod',
  isLive: true,
  readOnly: false,
  autoApprove: false,
  projectId: 'p1',
  hasXmlrpc: true,
);
const _stage = Environment(
  id: 'e2',
  name: 'Staging',
  slug: 'stage',
  isLive: false,
  readOnly: true,
  autoApprove: false,
  projectId: 'p1',
);
const _project = Project(
  id: 'p1',
  name: 'Company1',
  slug: 'company1',
  environments: [_prod, _stage],
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(const Locale('en')),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppStrings.supported,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

FigCompanyCard _card({
  bool open = true,
  bool pickable = false,
  String? selected,
  VoidCallback? onToggle,
  VoidCallback? onRename,
  VoidCallback? onDelete,
  ValueChanged<Environment>? onEnvTap,
  VoidCallback? onAdd,
}) => FigCompanyCard(
  project: _project,
  open: open,
  pickable: pickable,
  selectedEnvId: selected,
  onToggle: onToggle ?? () {},
  onRename: onRename ?? () {},
  onDelete: onDelete ?? () {},
  onEnvTap: onEnvTap ?? (_) {},
  onAddEnvironment: onAdd ?? () {},
);

void main() {
  testWidgets('closed: shows the name and hides the environments', (t) async {
    await t.pumpWidget(_host(_card(open: false)));
    expect(find.text('Company1'), findsOneWidget);
    expect(find.text('Production'), findsNothing);
  });

  testWidgets('open: lists the environments and the add link', (t) async {
    await t.pumpWidget(_host(_card()));
    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Staging'), findsOneWidget);
    expect(find.text('Add environment'), findsOneWidget);
  });

  testWidgets('header, edit and delete each fire their own callback', (
    t,
  ) async {
    final calls = <String>[];
    await t.pumpWidget(
      _host(
        _card(
          open: false,
          onToggle: () => calls.add('toggle'),
          onRename: () => calls.add('rename'),
          onDelete: () => calls.add('delete'),
        ),
      ),
    );
    await t.tap(find.byIcon(LucideIcons.pencil));
    await t.tap(find.byIcon(LucideIcons.trash2));
    await t.tap(find.text('Company1'));
    expect(calls, ['rename', 'delete', 'toggle']);
  });

  testWidgets('a row reports the environment it was tapped on', (t) async {
    Environment? tapped;
    await t.pumpWidget(_host(_card(onEnvTap: (e) => tapped = e)));
    await t.tap(find.text('Staging'));
    expect(tapped, _stage);
  });

  testWidgets('pickable marks only the current environment', (t) async {
    await t.pumpWidget(_host(_card(pickable: true, selected: 'e1')));
    expect(find.text('Current'), findsOneWidget);
    // Plain rows carry a chevron instead of a radio.
    await t.pumpWidget(_host(_card()));
    expect(find.text('Current'), findsNothing);
  });

  testWidgets('add environment link fires its callback', (t) async {
    var added = false;
    await t.pumpWidget(_host(_card(onAdd: () => added = true)));
    await t.tap(find.text('Add environment'));
    expect(added, isTrue);
  });

  testWidgets('add company pill fires its callback', (t) async {
    var added = false;
    await t.pumpWidget(_host(FigAddCompanyButton(onTap: () => added = true)));
    await t.tap(find.byType(FigAddCompanyButton));
    expect(added, isTrue);
  });
}
