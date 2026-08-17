// The exact strings the web team handed over, pinned.
//
// `i18n_parity_test` proves the two tables define the same keys and that the
// Arabic side is written in Arabic. It cannot know whether a value is the
// RIGHT copy. These strings were dictated verbatim in
// `docs/WEB_UI_PARITY_GAPS.md` so a user moving between web and mobile reads
// the same words — a well-meaning reword on either side breaks that quietly,
// and only a native speaker comparing two screens would ever notice.
//
// If the web team changes a string, this file is the one place to update, and
// the failure tells the next person that web is the source of truth.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('§1 — tools menu strings, verbatim from the web team', () {
    test('English', () {
      expect(en.toolsTitle, 'Saqqar tools');
      expect(en.toolsUploadFile, 'Upload file');
      expect(en.toolsModesSection, 'Modes');
      expect(en.toolsOdooSection, 'Odoo tools');
      expect(en.toolsConnectSection, 'Connections');
      expect(
        en.toolsReadonlyNote,
        'Tools do not change Odoo without your approval.',
      );
    });

    test('Arabic', () {
      expect(ar.toolsTitle, 'أدوات صقار');
      expect(ar.toolsUploadFile, 'رفع ملف');
      expect(ar.toolsModesSection, 'أوضاع التشغيل');
      expect(ar.toolsOdooSection, 'أدوات Odoo');
      expect(ar.toolsConnectSection, 'الربط والتكاملات');
      expect(
        ar.toolsReadonlyNote,
        'الأدوات لا تغيّر أي شيء في Odoo بدون موافقتك.',
      );
    });
  });

  group('§3 — task-prep strings, verbatim', () {
    test('English', () {
      expect(en.taskPrep, 'Task prep');
      expect(
        en.taskPrepTitle,
        'Saqqar asks quick questions to refine a vague task before building',
      );
      expect(
        en.taskPrepOn,
        'Task prep on. Saqqar will ask a couple of questions to refine vague '
            'tasks.',
      );
      expect(
        en.taskPrepOff,
        'Task prep off. Saqqar builds directly from what you write.',
      );
    });

    test('Arabic', () {
      expect(ar.taskPrep, 'تجهيز المهمة');
      expect(
        ar.taskPrepTitle,
        'صقّار يطرح أسئلة توضيحية مختصرة قبل تنفيذ أي مهمة غير واضحة',
      );
      expect(
        ar.taskPrepOn,
        'تجهيز المهمة مفعّل. صقّار سيطرح أسئلة قصيرة لتوضيح المهام غير '
            'المكتملة.',
      );
      expect(
        ar.taskPrepOff,
        'تجهيز المهمة متوقف. صقّار سيبدأ من النص المكتوب مباشرة.',
      );
    });
  });

  group('§4 — card strings the doc dictated', () {
    test('the clarify "no answer" toast', () {
      // Appendix A.1 gives both sides of this one explicitly.
      expect(en.clarifyNeedsAnswer, 'Pick at least one answer');
      expect(ar.clarifyNeedsAnswer, 'اختر إجابة واحدة على الأقل');
    });

    test('the clarify actions', () {
      expect(en.clarifyBuildSend, 'Build & send');
      expect(en.clarifyPrepareReview, 'Prepare & review');
    });

    test('the suggestion actions', () {
      // Appendix A.3 dictates the Arabic for both.
      expect(en.suggestionApprove, 'Approve & use');
      expect(en.suggestionKeepMine, 'Keep mine');
      expect(ar.suggestionApprove, 'اعتمد الصياغة');
      expect(ar.suggestionKeepMine, 'أبقِ صياغتي');
    });

    test('the composed-answers header matches Appendix A.1', () {
      // The literal prefix of the message the card sends. The agent parses
      // this, so it is a contract, not decoration.
      expect(en.clarifyAnswersHeader, 'Answers to your questions:');
    });
  });

  group('§6 — the tool rows carry no invented prompt text', () {
    // The rows used to send three locally-authored prompts, written against a
    // probe that found no route. The web team then published the real ones
    // (`/radar/run/`, `/pulse/run/`, `/whatif/intro/`), so the wording is no
    // longer the app's to choose and the strings were deleted.
    //
    // This guards the deletion. Leaving them defined-but-unused would be an
    // invitation to wire them back, and re-adding them would mean the app
    // paraphrasing a request the server has an exact endpoint for.
    test('the authored prompt keys are gone from both tables', () {
      for (final tr in [en, ar]) {
        for (final key in [
          'tools_health_radar_prompt',
          'tools_what_if_prompt',
          'tools_business_pulse_prompt',
        ]) {
          expect(
            tr.lookup(key, fallback: ''),
            isEmpty,
            reason: '$key came back — the rows call endpoints now',
          );
        }
      }
    });

    test('the footer promise the prompts used to carry still holds', () {
      // The rows fire on a single tap, and the sheet promises the tools do
      // not change Odoo without approval. That promise now rests on the
      // endpoints being read-only rather than on prompt wording — which is
      // strictly stronger, since the agent can't paraphrase an HTTP call.
      expect(
        en.toolsReadonlyNote,
        'Tools do not change Odoo without your approval.',
      );
      expect(ar.toolsReadonlyNote, isNot(en.toolsReadonlyNote));
    });
  });

  group('no parity string is written and then never shown', () {
    // Copy that exists but is never rendered is worse than missing copy: it
    // reads as "handled" in review, translators keep it alive, and it hides a
    // real gap. `clarifyReadyToReview` was exactly that — the string for
    // "Prepare & review" existed while the button seeded the composer in
    // total silence, so on a phone the tap looked like it did nothing.
    //
    // `i18n_parity_test` cannot catch this: it proves en/ar agree and that
    // referenced keys exist, never that a DEFINED key is referenced.

    /// Getters that may legitimately have no call site yet, and why.
    ///
    /// Empty as of 2026-08-06. `toolsVoiceSupport` sat here while §8 was
    /// blocked on what the row actually did — the web team answered (a
    /// self-service ticket workspace, not telephony), the row and its screen
    /// shipped, and the entry came out. The "stale entries" test below is
    /// what forces that: an allowlist nobody prunes stops being a record of
    /// open work and becomes a place dead copy hides.
    const pending = <String, String>{};

    /// Every getter added for the parity work.
    const parityGetters = [
      'toolsTitle',
      'toolsUploadFile',
      'toolsModesSection',
      'toolsOdooSection',
      'toolsConnectSection',
      'toolsReadonlyNote',
      'toolsPromptBank',
      'toolsHealthRadar',
      'toolsWhatIf',
      'toolsBusinessPulse',
      'toolsMyDatabase',
      'toolsVoiceSupport',
      'taskPrep',
      'taskPrepTitle',
      'taskPrepOn',
      'taskPrepOff',
      'clarifyTitle',
      'clarifySomethingElse',
      'clarifyBuildSend',
      'clarifyPrepareReview',
      'clarifyNeedsAnswer',
      'clarifyAnswersHeader',
      'clarifyReadyToReview',
      'suggestionTitle',
      'suggestionApprove',
      'suggestionKeepMine',
      'reportTitle',
      'reportType',
      'reportPeriod',
      'reportLens',
      'reportFormat',
      'reportRecords',
      'reportPickRecords',
      'reportSearchRecords',
      'reportNoRecords',
      'reportBuild',
      'reportNeedsType',
      'reportRecordsTruncated',
      'reportSelectedCount',
      'emailPreviewTo',
      'emailPreviewCc',
      'emailPreviewBcc',
      'emailPreviewReply',
      // The typed-confirm gate was replaced on 2026-08-17 by a one-tap red
      // button; its five getters went with it.
      'deleteApprovalAction',
      'deleteApprovalRecordsHeader',
      // §11 — batch approvals, once `grouped_count` turned out not to exist.
      'approveAllSimilar',
      'approvalBatchResolved',
      // §6 — the tool rows need a conversation to post their report into.
      'toolsNeedsConversation',
      // §8 — the support workspace.
      'voiceSupportTitle',
      'voiceSupportIntro',
      'voiceSupportHint',
      'voiceSupportSubmit',
      'voiceSupportReply',
      'voiceSupportSteps',
      'voiceSupportQuestions',
      'voiceSupportFileTicket',
      'voiceSupportTicketConfirmTitle',
      'voiceSupportTicketConfirmBody',
      'voiceSupportTicketCreated',
      'voiceSupportEmpty',
    ];

    /// All of `lib/`, minus the file that DEFINES the getters.
    String libSource() {
      final buffer = StringBuffer();
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (file.path.replaceAll(r'\', '/').endsWith('i18n/app_strings.dart')) {
          continue;
        }
        buffer.writeln(file.readAsStringSync());
      }
      return buffer.toString();
    }

    test('every parity string has a call site, or a stated reason', () {
      final source = libSource();

      final orphans = parityGetters
          .where((g) => !pending.containsKey(g))
          .where((g) => !RegExp(r'\.' + g + r'\b').hasMatch(source))
          .toList();

      expect(
        orphans,
        isEmpty,
        reason: 'These strings are defined but never rendered. Either wire '
            'them up, or add them to `pending` above with the reason:\n'
            '${orphans.join('\n')}',
      );
    });

    test('the pending list has no stale entries', () {
      // An entry that outlives its gap silently excuses the next string that
      // lands under that name.
      final source = libSource();

      final wired = pending.keys
          .where((g) => RegExp(r'\.' + g + r'\b').hasMatch(source))
          .toList();

      expect(
        wired,
        isEmpty,
        reason: 'These are now used in lib/, so they are no longer pending — '
            'drop them from the list:\n${wired.join('\n')}',
      );
    });

    test('nothing is left pending', () {
      // A growing pending list would mean parity work is being marked done
      // while its copy sits unrendered. §6 came off it when the three Odoo
      // rows shipped, §8 when the web team answered what the row does and
      // the support workspace shipped. Every parity string now has a call
      // site; a new entry here has to come with a reason that survives
      // review.
      expect(pending, isEmpty);
    });
  });

  group('every new key resolves to real copy in both locales', () {
    // `_t` echoes the key back on a miss, which leaks `tools_title` onto a
    // screen instead of copy. Cheap to assert, and it catches a typo in a
    // getter that no other test would exercise.
    test('no getter returns its own key', () {
      for (final tr in [en, ar]) {
        final values = <String, String>{
          'tools_title': tr.toolsTitle,
          'tools_upload_file': tr.toolsUploadFile,
          'tools_modes_section': tr.toolsModesSection,
          'tools_odoo_section': tr.toolsOdooSection,
          'tools_connect_section': tr.toolsConnectSection,
          'tools_readonly_note': tr.toolsReadonlyNote,
          'tools_prompt_bank': tr.toolsPromptBank,
          'tools_health_radar': tr.toolsHealthRadar,
          'tools_what_if': tr.toolsWhatIf,
          'tools_business_pulse': tr.toolsBusinessPulse,
          'tools_my_database': tr.toolsMyDatabase,
          'tools_voice_support': tr.toolsVoiceSupport,
          'task_prep': tr.taskPrep,
          'task_prep_title': tr.taskPrepTitle,
          'task_prep_on': tr.taskPrepOn,
          'task_prep_off': tr.taskPrepOff,
          'clarify_title': tr.clarifyTitle,
          'clarify_something_else': tr.clarifySomethingElse,
          'clarify_build_send': tr.clarifyBuildSend,
          'clarify_prepare_review': tr.clarifyPrepareReview,
          'clarify_needs_answer': tr.clarifyNeedsAnswer,
          'clarify_answers_header': tr.clarifyAnswersHeader,
          'clarify_ready_to_review': tr.clarifyReadyToReview,
          'suggestion_title': tr.suggestionTitle,
          'suggestion_approve': tr.suggestionApprove,
          'suggestion_keep_mine': tr.suggestionKeepMine,
          'report_title': tr.reportTitle,
          'report_type': tr.reportType,
          'report_period': tr.reportPeriod,
          'report_lens': tr.reportLens,
          'report_format': tr.reportFormat,
          'report_records': tr.reportRecords,
          'report_pick_records': tr.reportPickRecords,
          'report_search_records': tr.reportSearchRecords,
          'report_no_records': tr.reportNoRecords,
          'report_build': tr.reportBuild,
          'report_needs_type': tr.reportNeedsType,
          'email_preview_to': tr.emailPreviewTo,
          'email_preview_cc': tr.emailPreviewCc,
          'delete_approval_action': tr.deleteApprovalAction(12),
        };

        values.forEach((key, value) {
          expect(value, isNotEmpty, reason: key);
          expect(value, isNot(key), reason: '$key echoed its own key back');
        });
      }
    });

    test('interpolated copy leaves no unresolved slot', () {
      for (final tr in [en, ar]) {
        final interpolated = [
          tr.reportRecordsTruncated(7),
          tr.reportSelectedCount(3),
          tr.deleteApprovalAction(6),
          tr.deleteApprovalRecordsHeader(6),
          tr.reportCompose(
            type: 'Sales orders',
            period: 'This month',
            format: 'PDF',
            lens: 'By customer',
            records: 'Acme Co',
          ),
        ];

        for (final value in interpolated) {
          expect(value, isNot(contains('{')), reason: value);
          expect(value, isNot(contains('}')), reason: value);
        }
      }
    });

    test('the report request drops the parts the user did not pick', () {
      // An optional segment left in with an empty value reads as a broken
      // sentence ("- View: ") and gives the agent a field to misparse.
      final minimal = en.reportCompose(
        type: 'Sales orders',
        period: 'This month',
        format: 'PDF',
      );

      expect(minimal, contains('Sales orders'));
      expect(minimal, isNot(contains('View')));
      expect(minimal, isNot(contains('Records')));

      final full = en.reportCompose(
        type: 'Sales orders',
        period: 'This month',
        format: 'PDF',
        lens: 'By customer',
        records: 'Acme Co',
      );

      expect(full, contains('View'));
      expect(full, contains('Acme Co'));
    });
  });
}
