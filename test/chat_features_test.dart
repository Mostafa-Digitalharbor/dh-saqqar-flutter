// docs/WEB_UI_PARITY_WEB_RESPONSE.md §0 — the feature-flag contract, as the
// backend actually shipped it on 2026-08-06.
//
// The first version of this file tested the wrong object. Mobile assumed the
// six Saqqar flags would appear under `plan.features` — the billing
// entitlement bag — "with no client release". They did not: they ship as a
// separate top-level `saqqar_features` on `GET /api/v1/usage/`, and the task
// flag is `task_prep`, not `task_prep_available`.
//
// That miss was silent in the worst way. Reading the wrong bag makes every
// flag come back ABSENT, and the old optimistic defaults rendered absent as
// "show it" — so an account the server has these features switched OFF for
// would have been shown all three tool rows. This file pins both halves: the
// source object, and the default each gate picks for "not known yet".

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/chat/data/chat_features.dart';

PlanSnapshot _plan({
  Map<String, dynamic> features = const {},
  bool exempt = false,
}) =>
    PlanSnapshot.fromJson({
      'plan': 'pro',
      'plan_name': 'Pro',
      'exempt': exempt,
      'features': features,
    });

SaqqarFeatures _flags(Map<String, dynamic> json) =>
    SaqqarFeatures.fromJson(json);

void main() {
  group('SaqqarFeatures parses the wire object', () {
    test('separates "said false" from "never said"', () {
      final f = _flags(const {'what_if': false});

      expect(f.has('what_if'), isTrue);
      expect(f.has('health_radar'), isFalse);
      // Both read `false` through `enabled` — which is exactly why `has`
      // has to exist as well.
      expect(f.enabled('what_if'), isFalse);
      expect(f.enabled('health_radar'), isFalse);
    });

    test('a missing object is UNKNOWN, not empty', () {
      // A server that predates the deploy sends no `saqqar_features` at all.
      // Reading that as "an empty set of flags" would be indistinguishable
      // from "every feature is off", and the optimistic gates would silently
      // pick the wrong branch.
      expect(SaqqarFeatures.fromJson(null).known, isFalse);
      expect(_flags(const {}).known, isTrue);
      expect(SaqqarFeatures.unknown.known, isFalse);
    });

    test('a non-boolean value is not treated as a flag', () {
      final f = _flags(const {'health_radar': 'yes'});

      expect(f.has('health_radar'), isFalse);
      expect(f.enabled('health_radar'), isFalse);
    });

    test('carries flags the app has no gate for yet', () {
      // `report_builder`, `collection_note`, `version_awareness` and
      // `module_management` arrived in the same object. Nothing reads them
      // today; the raw map means they resolve without a model change.
      final f = _flags(const {'report_builder': true, 'brand_new': true});

      expect(f.enabled('report_builder'), isTrue);
      expect(f.enabled('brand_new'), isTrue);
    });

    test('the wire key is task_prep, NOT task_prep_available', () {
      // The long name is what the web's HTML feature context calls it. The
      // JSON API ships the short one, and reading the long one would leave
      // the toggle permanently on its "unknown" default.
      expect(SaqqarFeatures.kTaskPrep, 'task_prep');
    });
  });

  group('the flags come from saqqar_features, never from plan.features', () {
    test('a same-named key under plan.features does NOT enable a row', () {
      // The two objects genuinely collide: billing has `voice`, availability
      // has `voice_support`. If a gate ever read the billing bag again, this
      // is the shape that would catch it.
      final f = ChatFeatures(
        _plan(features: {'health_radar': true, 'what_if': true}),
        SaqqarFeatures.unknown,
      );

      expect(f.healthRadar, isFalse);
      expect(f.whatIf, isFalse);
    });

    test('the same key under saqqar_features DOES enable it', () {
      final f = ChatFeatures(
        _plan(),
        _flags(const {'health_radar': true, 'what_if': true}),
      );

      expect(f.healthRadar, isTrue);
      expect(f.whatIf, isTrue);
    });
  });

  group('task prep is optimistic', () {
    test('shown before any /usage/ fetch has landed', () {
      // `saqqar_features` rides on `/api/v1/usage/` alone, so this is the
      // state on every cold start. The backend reports task_prep on for all
      // accounts, so the optimistic default and the real value agree — the
      // default only has to cover the pre-fetch window.
      expect(const ChatFeatures(null).taskPrepAvailable, isTrue);
      expect(ChatFeatures(_plan()).taskPrepAvailable, isTrue);
    });

    test('shown when the server explicitly enables it', () {
      expect(
        ChatFeatures(_plan(), _flags(const {'task_prep': true}))
            .taskPrepAvailable,
        isTrue,
      );
    });

    test('hidden ONLY on an explicit false', () {
      expect(
        ChatFeatures(_plan(), _flags(const {'task_prep': false}))
            .taskPrepAvailable,
        isFalse,
      );
    });

    test('an exempt account keeps it whatever the flags say', () {
      expect(
        ChatFeatures(
          _plan(exempt: true),
          _flags(const {'task_prep': false}),
        ).taskPrepAvailable,
        isTrue,
      );
    });
  });

  group('the Odoo tool rows are STRICT (§6)', () {
    // The backend's own instruction: "Everything else strict (absent OR
    // `false` ⇒ hide) is exactly right." An earlier build had these
    // optimistic on the theory that a row sending a chat prompt cannot
    // dead-end. Two things killed that: the rows call real endpoints now,
    // and a disabled tool is dropped from the agent's toolset anyway — so
    // the optimistic branch produced rows that answer "I can't do that".
    test('hidden before any fetch has landed', () {
      for (final f in [const ChatFeatures(null), ChatFeatures(_plan())]) {
        expect(f.healthRadar, isFalse);
        expect(f.whatIf, isFalse);
        expect(f.businessPulse, isFalse);
      }
    });

    test('hidden on an explicit false', () {
      final f = ChatFeatures(
        _plan(),
        _flags(const {
          'health_radar': false,
          'what_if': false,
          'business_pulse': false,
        }),
      );

      expect(f.healthRadar, isFalse);
      expect(f.whatIf, isFalse);
      expect(f.businessPulse, isFalse);
    });

    test('shown only on an explicit true', () {
      final f = ChatFeatures(
        _plan(),
        _flags(const {
          'health_radar': true,
          'what_if': true,
          'business_pulse': true,
        }),
      );

      expect(f.healthRadar, isTrue);
      expect(f.whatIf, isTrue);
      expect(f.businessPulse, isTrue);
    });

    test('the production default for a non-staff account hides all three', () {
      // Verbatim from the backend's sample response: these are staff-only in
      // the flag table during rollout, so a normal account really does get
      // three `false`s today. If this test ever flips, the flags rolled out
      // — nothing in the client needs to change for that.
      final f = ChatFeatures(
        _plan(),
        _flags(const {
          'voice_support': false,
          'task_prep': true,
          'prompt_bank': true,
          'business_pulse': false,
          'health_radar': false,
          'what_if': false,
        }),
      );

      expect(f.healthRadar, isFalse);
      expect(f.whatIf, isFalse);
      expect(f.businessPulse, isFalse);
      expect(f.voiceSupport, isFalse);
      // …while the two that ARE on for everyone stay visible.
      expect(f.taskPrepAvailable, isTrue);
      expect(f.promptBank, isTrue);
    });

    test('they gate independently of one another', () {
      final f = ChatFeatures(
        _plan(),
        _flags(const {'health_radar': false, 'what_if': true}),
      );

      expect(f.healthRadar, isFalse);
      expect(f.whatIf, isTrue);
      expect(f.businessPulse, isFalse);
    });

    test('an exempt account keeps them whatever the flags say', () {
      final f = ChatFeatures(
        _plan(exempt: true),
        _flags(const {'health_radar': false, 'what_if': false}),
      );

      expect(f.healthRadar, isTrue);
      expect(f.whatIf, isTrue);
    });
  });

  group('prompt bank stays optimistic', () {
    test('shown before any fetch, because it calls no server', () {
      // Client-side only — the app's own starter prompts. There is no
      // request for a server to refuse, so the dead-row risk that makes the
      // other rows strict does not apply.
      expect(const ChatFeatures(null).promptBank, isTrue);
      expect(ChatFeatures(_plan()).promptBank, isTrue);
    });

    test('hidden ONLY on an explicit false', () {
      expect(
        ChatFeatures(_plan(), _flags(const {'prompt_bank': false})).promptBank,
        isFalse,
      );
    });
  });

  group('voice support: availability and TTS are different flags (§8)', () {
    test('the row is strict', () {
      expect(const ChatFeatures(null).voiceSupport, isFalse);
      expect(ChatFeatures(_plan()).voiceSupport, isFalse);
      expect(
        ChatFeatures(_plan(), _flags(const {'voice_support': true}))
            .voiceSupport,
        isTrue,
      );
    });

    test('billing `voice` is NOT voice_support', () {
      // `voice` gates the composer mic and lives in the billing bag;
      // `voice_support` gates the support workspace and lives in the
      // availability bag. An account with the mic must not get the row.
      final f = ChatFeatures(_plan(features: {'voice': true}));

      expect(f.voiceSupport, isFalse);
      expect(f.voiceSupportTts, isTrue);
    });

    test('the workspace can be available while TTS is not', () {
      // The documented Free-plan shape: the row shows, but
      // `/voice-support/tts/` 403s. That is why the app renders the written
      // reply and offers no speak button.
      final f = ChatFeatures(
        _plan(features: {'voice': false}),
        _flags(const {'voice_support': true}),
      );

      expect(f.voiceSupport, isTrue);
      expect(f.voiceSupportTts, isFalse);
    });
  });
}
