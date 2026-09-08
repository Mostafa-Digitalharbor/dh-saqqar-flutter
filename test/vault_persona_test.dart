// Which credential tabs the vault shows, and whether it remembers.
//
// Found in the full web-vs-mobile sweep. The web's user persona lists
// `["xmlrpc", "email"]`; the app listed only `xmlrpc`, so someone in the
// default view had no route to the Email form at all — the kind shipped, and
// nothing led to it. The choice was also not persisted, so a developer who
// flipped the switch to reach Postgres had to flip it again every visit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/vault_persona_service.dart';
import 'package:saqqar_app/features/vault/widgets/environment_detail_sheet.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('what the user view offers', () {
    test('Odoo and Email, exactly as the web lists them', () {
      // ENV_PERSONA_KINDS.user on the web. Connecting a mailbox is an
      // end-user task; hiding it behind "I'm a developer" made a shipped
      // feature unreachable for the people it was built for.
      const userKinds = EnvironmentDetailSheet.userKinds;

      expect(userKinds, contains(CredentialKind.email));
      // And still not the three technical ones — the simple view has to stay
      // simple or it is not a persona, it is just the same list.
      expect(userKinds, isNot(contains(CredentialKind.postgres)));
      expect(userKinds, isNot(contains(CredentialKind.serverShell)));
      expect(userKinds, isNot(contains(CredentialKind.github)));
    });

    test('the developer view is still everything', () {
      expect(EnvironmentDetailSheet.developerKinds, hasLength(5));
      expect(
        EnvironmentDetailSheet.developerKinds,
        containsAll(const [
          CredentialKind.xmlrpc,
          CredentialKind.postgres,
          CredentialKind.serverShell,
          CredentialKind.github,
          CredentialKind.email,
        ]),
      );
    });
  });

  group('remembering the choice', () {
    test('a never-opened environment starts in the user view', () {
      // The web's default. Someone who has never expressed a preference gets
      // the two tabs, not five.
      expect(VaultPersonaService(prefs).isDeveloper('env-1'), isFalse);
    });

    test('the flip survives closing the sheet', () async {
      final service = VaultPersonaService(prefs);

      await service.setDeveloper('env-1', developer: true);

      // A fresh instance, as if the sheet were reopened.
      expect(VaultPersonaService(prefs).isDeveloper('env-1'), isTrue);
    });

    test('and is per environment, not global', () async {
      // Production may be someone else's Odoo-only environment while staging
      // is the one they SSH into. One shared flag would fight them on both.
      final service = VaultPersonaService(prefs);

      await service.setDeveloper('env-dev', developer: true);

      expect(service.isDeveloper('env-dev'), isTrue);
      expect(service.isDeveloper('env-prod'), isFalse);
    });

    test('flipping back is remembered too', () async {
      final service = VaultPersonaService(prefs);

      await service.setDeveloper('env-1', developer: true);
      await service.setDeveloper('env-1', developer: false);

      expect(VaultPersonaService(prefs).isDeveloper('env-1'), isFalse);
    });
  });

  group('what the Odoo tab is called', () {
    testWidgets('an invitation in the user view, the protocol for developers',
        (tester) async {
      // Web parity: `kindTabLabel` renames xmlrpc to "Connect Odoo" for the
      // user persona only.
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        final tr = AppStrings(locale);
        expect(tr.connectOdoo, isNotEmpty);
        // The two names are genuinely different — if they collided the
        // persona rename would be invisible and the branch pointless.
        expect(tr.connectOdoo, isNot(tr.lookup('credKindXmlrpc')));
      }
      expect(
        AppStrings(const Locale('ar')).connectOdoo,
        isNot(AppStrings(const Locale('en')).connectOdoo),
      );
    });
  });
}
