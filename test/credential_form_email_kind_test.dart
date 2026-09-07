// The "Email (IMAP/SMTP)" credential kind (2026-09-07) was the one gap found
// comparing the vault's "I'm a developer" mode against web: mobile's
// `CredentialKind` enum only had xmlrpc/postgres/server_shell/github, so a
// schema response tagged `kind: "email"` from `GET /credentials/schemas/`
// silently mis-resolved to the xmlrpc schema (`CredentialSchema.fromJson`'s
// `?? CredentialKind.xmlrpc` fallback) and had no tab to render it under.
//
// This pins the fix with the *exact* schema the live backend returns for
// this kind (captured 2026-09-07), so a future backend reshuffle of this
// schema fails a test here rather than silently mis-rendering on a phone.
// It specifically exercises the two things new to this kind:
//   * field names with no `label_key` from the server (imap_host, imap_port,
//     smtp_host, smtp_port, smtp_security) resolving through the form's
//     name-based fallback instead of falling back to the raw English label.
//   * a select option (`ssl`) the form has never had to translate before.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/state/data_state.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';
import 'package:saqqar_app/features/vault/data/vault_repository.dart';
import 'package:saqqar_app/features/vault/view_model/vault_cubit.dart';
import 'package:saqqar_app/features/vault/view_model/vault_state.dart';
import 'package:saqqar_app/features/vault/widgets/credential_form.dart';

/// Verbatim `GET /api/v1/credentials/schemas/` entry for `kind: "email"`,
/// captured live against saqqaar.com on 2026-09-07.
final _emailSchemaJson = <String, dynamic>{
  'kind': 'email',
  'label': 'Email (IMAP/SMTP)',
  'fields': [
    {
      'name': 'email',
      'label': 'Email',
      'type': 'text',
      'required': true,
      'label_key': 'fieldEmailAddress',
      'help_key': 'help_email_address',
    },
    {
      'name': 'auth_type',
      'label': 'Auth Type',
      'type': 'select',
      'required': true,
      'options': ['password', 'oauth2'],
      'default': 'password',
      'label_key': 'authType',
      'help_key': 'help_email_auth_type',
    },
    {
      'name': 'password',
      'label': 'Password',
      'type': 'password',
      'required': true,
      'label_key': 'fieldEmailPassword',
      'help_key': 'help_email_password',
    },
    {
      'name': 'imap_host',
      'label': 'Imap Host',
      'type': 'text',
      'required': true,
      'help_key': 'help_email_imap_host',
    },
    {
      'name': 'imap_port',
      'label': 'Imap Port',
      'type': 'number',
      'placeholder': '993',
      'required': false,
      'help_key': 'help_email_imap_port',
    },
    {
      'name': 'smtp_host',
      'label': 'Smtp Host',
      'type': 'text',
      'required': true,
      'help_key': 'help_email_smtp_host',
    },
    {
      'name': 'smtp_port',
      'label': 'Smtp Port',
      'type': 'number',
      'placeholder': '465',
      'required': false,
      'help_key': 'help_email_smtp_port',
    },
    {
      'name': 'smtp_security',
      'label': 'Smtp Security',
      'type': 'select',
      'required': false,
      'options': ['ssl', 'starttls'],
      'default': 'ssl',
      'help_key': 'help_email_smtp_security',
    },
  ],
};

class _SeededVaultCubit extends VaultCubit {
  _SeededVaultCubit()
      : super(
          repository: VaultRepository(
            projectsApi: ProjectsApi(Dio()),
            credentialsApi: CredentialsApi(Dio()),
          ),
        );

  @override
  VaultState get state => VaultState(
        data: DataSuccess(VaultData(
          projects: const [],
          schemas: [CredentialSchema.fromJson(_emailSchemaJson)],
          // Present-but-empty: tells the form "no saved credential yet",
          // not "still loading" — same distinction `credsLoaded` makes.
          credentialsByEnv: const {'env-1': []},
        )),
      );
}

Future<void> _pump(WidgetTester tester, {required Locale locale}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<VaultCubit>(create: (_) => _SeededVaultCubit()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        theme: AppTheme.light(locale),
        home: Scaffold(
          body: Provider<CredentialsApi>.value(
            value: CredentialsApi(Dio()),
            child: const CredentialForm(
              envId: 'env-1',
              kind: CredentialKind.email,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CredentialForm — email (IMAP/SMTP) kind', () {
    testWidgets('resolves every field label in English', (tester) async {
      await _pump(tester, locale: const Locale('en'));

      // Text/password fields render their label via the shared `EyebrowLabel`
      // (uppercased); the two selects render theirs through Material's own
      // `InputDecoration.labelText` (as-typed case) — matching each field's
      // real widget, not guessing one casing for all of them.
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('PASSWORD / APP-PASSWORD'), findsOneWidget);
      // The five fields with no server-provided `label_key` — this is the
      // exact fallback path the missing kind used to have no entry for.
      expect(find.text('IMAP HOST'), findsOneWidget);
      expect(find.text('IMAP PORT'), findsOneWidget);
      expect(find.text('SMTP HOST'), findsOneWidget);
      expect(find.text('SMTP PORT'), findsOneWidget);
      expect(find.text('SMTP Security'), findsOneWidget);
    });

    testWidgets('resolves every field label in Arabic', (tester) async {
      await _pump(tester, locale: const Locale('ar'));

      expect(find.text('عنوان البريد الإلكتروني'), findsOneWidget);
      expect(find.text('نوع المصادقة'), findsOneWidget);
      expect(find.text('كلمة المرور / كلمة مرور التطبيق'), findsOneWidget);
      expect(find.text('مضيف IMAP'), findsOneWidget);
      expect(find.text('منفذ IMAP'), findsOneWidget);
      expect(find.text('مضيف SMTP'), findsOneWidget);
      expect(find.text('منفذ SMTP'), findsOneWidget);
      expect(find.text('تأمين SMTP'), findsOneWidget);
    });

    testWidgets('the smtp_security default renders as translated SSL, not '
        'the raw wire value', (tester) async {
      await _pump(tester, locale: const Locale('en'));
      // The dropdown's closed state shows the resolved option text.
      expect(find.text('SSL'), findsOneWidget);
      expect(find.text('ssl'), findsNothing);
    });

    testWidgets('never crashes and needs no scroll clamp for its longest '
        'locale', (tester) async {
      // A regression guard, not a layout audit — the full responsive sweep
      // (widget_conformance_provided_test.dart) owns overflow coverage for
      // CredentialForm across the device/locale/text-scale matrix.
      await _pump(tester, locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
    });
  });
}
