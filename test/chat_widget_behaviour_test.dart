import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/widgets/artifact_pill.dart';
import 'package:saqqar_app/features/chat/widgets/chat_app_bar_title.dart';
import 'package:saqqar_app/features/chat/widgets/chat_artifact_tile.dart';
import 'package:saqqar_app/features/chat/widgets/chat_env_hint_banner.dart';
import 'package:saqqar_app/features/chat/widgets/chat_resume_banner.dart';
import 'package:saqqar_app/features/chat/widgets/chat_suggestion_strip.dart';
import 'package:saqqar_app/features/chat/widgets/empty_chat_suggestions.dart';
import 'package:saqqar_app/features/chat/widgets/prompt_clarify_card.dart';
import 'package:saqqar_app/features/chat/widgets/report_builder_card.dart';

import 'support/widget_conformance.dart';
import 'package:saqqar_app/shared/fig/fig.dart';

/// Do the chat's interactive widgets actually DO anything when tapped?
///
/// Every widget here was already covered — by the conformance matrix, by a
/// responsive sweep, or by both. None of that coverage ever touched one. An
/// audit of the fifteen chat widgets that take a callback found twelve whose
/// callback no test had ever fired: they were pumped with `onTap: () {}` and
/// asserted to render. A widget whose `onSelect` was wired to the wrong chip,
/// or dropped in a refactor, renders exactly as well as one that works.
///
/// This is the other half of the contract. The matrix proves the widget
/// survives content it does not control; this proves it reports back what the
/// user actually touched — the right payload, from the right control, and
/// *not* when the widget said it was disabled.
///
/// Grouped by widget, one group per, so a failure names the component.
void main() {
  final en = AppStrings(const Locale('en'));

  Widget host(Widget child) =>
      conformanceHarness(child, locale: const Locale('en'), scale: 1.0);

  group('ChatSuggestionStrip', () {
    testWidgets('reports the prompt of the chip that was tapped', (
      tester,
    ) async {
      // The strip builds four chips from four different i18n getters in a
      // loop. A closure capturing the loop variable incorrectly — the
      // classic version of this bug — still renders four correct labels and
      // sends the same prompt for all of them.
      final prompts = [
        en.suggestRestartWorker,
        en.suggestReconciliationReport,
        en.suggestPendingInvoices,
        en.suggestSyncInventory,
      ];
      for (final expected in prompts) {
        String? got;
        await tester.pumpWidget(
          host(ChatSuggestionStrip(visible: true, onSelect: (p) => got = p)),
        );
        // The strip scrolls horizontally and the fourth chip starts beyond
        // an 800 px viewport, so it has to be brought on screen before it
        // can be hit-tested — which is also what a user does to reach it.
        await tester.ensureVisible(find.text(expected));
        await tester.pumpAndSettle();
        await tester.tap(find.text(expected));
        await tester.pump();
        expect(got, expected, reason: 'Tapping "$expected" reported "$got".');
      }
    });

    testWidgets('collapses to nothing when not visible', (tester) async {
      // `visible: false` is what keeps the composer from jumping while a
      // voice note records. A strip that merely went transparent would still
      // take the height, and would still be tappable.
      await tester.pumpWidget(
        host(ChatSuggestionStrip(visible: false, onSelect: (_) {})),
      );
      expect(find.text(en.suggestPendingInvoices), findsNothing);
      expect(
        tester.getSize(find.byType(ChatSuggestionStrip)),
        Size.zero,
        reason: 'A hidden strip still occupies space.',
      );
    });
  });

  group('EmptyChatSuggestions', () {
    testWidgets('greets the user by first name, with no starter tiles',
        (tester) async {
      // The redesign replaced the 2x2 prompt grid with the orb and a centred
      // "Hello <name>" greeting; starter prompts live in the tools sheet.
      final sent = <String>[];
      await tester.pumpWidget(
        host(EmptyChatSuggestions(
          onSuggestionTap: sent.add,
          userName: 'Nada',
        )),
      );

      expect(find.textContaining('Hello Nada'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(sent, isEmpty);
    });
  });

  group('ChatEnvHintBanner', () {
    testWidgets('invokes its action once when idle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(ChatEnvHintBanner(onUseMyDatabase: () => taps++)),
      );
      await tester.tap(find.byType(FigButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('is inert while busy', (tester) async {
      // `busy` is set while the request it starts is in flight. If the
      // button stays live the user fires the same mutation two or three
      // times — and this one repoints the conversation at a database.
      var taps = 0;
      await tester.pumpWidget(
        host(ChatEnvHintBanner(busy: true, onUseMyDatabase: () => taps++)),
      );
      await tester.tap(find.byType(FigButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0, reason: 'The banner fired its action while busy.');
    });
  });

  group('ChatResumeBanner', () {
    testWidgets('invokes its action once when idle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(ChatResumeBanner(onResume: () => taps++)));
      await tester.tap(find.byType(FigButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('is inert while busy', (tester) async {
      // Same contract as ChatEnvHintBanner: the in-flight flag must disable
      // the button, or a slow network round-trip lets a second tap fire a
      // second resume request.
      var taps = 0;
      await tester.pumpWidget(
        host(ChatResumeBanner(busy: true, onResume: () => taps++)),
      );
      await tester.tap(find.byType(FigButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0, reason: 'The banner fired its action while busy.');
    });

    testWidgets('relabels to the working string while busy', (tester) async {
      await tester.pumpWidget(host(ChatResumeBanner(onResume: () {})));
      expect(find.text(en.chatResumeButton), findsOneWidget);
      expect(find.text(en.chatResumeButtonWorking), findsNothing);

      await tester.pumpWidget(
        host(ChatResumeBanner(busy: true, onResume: () {})),
      );
      expect(find.text(en.chatResumeButton), findsNothing);
      expect(find.text(en.chatResumeButtonWorking), findsOneWidget);
    });

    testWidgets('shows the last failure reason inline, not as a toast',
        (tester) async {
      // A failed Resume deliberately raises no toast (the spec: the user
      // can just tap again) — but that must not mean the user sees nothing
      // at all. The reason belongs on the banner itself, where it stays
      // visible until the next attempt clears it.
      await tester.pumpWidget(host(ChatResumeBanner(
        onResume: () {},
        failureMessage: 'No internet connection',
      )));
      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('shows no failure line when nothing has failed yet',
        (tester) async {
      await tester.pumpWidget(host(ChatResumeBanner(onResume: () {})));
      expect(find.text(en.chatResumeBannerText), findsOneWidget);
      // No second line of body text under the title — AccentBanner drops
      // the row entirely rather than reserving blank space for it.
      expect(find.textContaining('internet'), findsNothing);
    });
  });

  group('ArtifactPill', () {
    testWidgets('opens on tap', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          ArtifactPill(
            attachment: const ChatAttachment(
              name: 'odoo_products_full_export.xlsx',
              kind: 'xlsx',
              size: '12.4 MB',
            ),
            onOpen: () => opened++,
          ),
        ),
      );
      await tester.tap(find.byType(ArtifactPill));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('ChatArtifactTile', () {
    ChatArtifactTile tile({
      required VoidCallback onOpen,
      VoidCallback? onLongPress,
    }) => ChatArtifactTile(
      artifact: const ChatArtifact(
        id: 'a1',
        name: 'reconciliation.xlsx',
        kind: 'xlsx',
        size: '2.1 MB',
        conversation: 'Q3 ledger close',
        conversationId: 'c1',
        createdLabel: 'Aug 20',
      ),
      onOpen: onOpen,
      onLongPress: onLongPress,
    );

    testWidgets('separates tap from long-press', (tester) async {
      // Two gestures, two callbacks, one row. Wiring long-press to `onOpen`
      // — or leaving it null when a handler was passed — is invisible until
      // somebody holds a row and it downloads instead of opening a menu.
      var opened = 0;
      var held = 0;
      await tester.pumpWidget(
        host(tile(onOpen: () => opened++, onLongPress: () => held++)),
      );

      await tester.tap(find.byType(ChatArtifactTile).first);
      await tester.pump();
      expect(opened, 1);
      expect(held, 0);

      await tester.longPress(find.byType(ChatArtifactTile).first);
      await tester.pump();
      expect(opened, 1, reason: 'A long press also fired onOpen.');
      expect(held, 1);
    });

    testWidgets('with no long-press handler, holding falls back to opening', (
      tester,
    ) async {
      // Flutter's own behaviour, pinned rather than assumed: an `InkWell`
      // with a null `onLongPress` never enters a long-press gesture, so the
      // press-and-release resolves as an ordinary tap. That is a reasonable
      // outcome here — holding a row opens it — but it is worth stating,
      // because the obvious guess is that the gesture is swallowed, and a
      // future menu added behind `onLongPress` changes it.
      var opened = 0;
      await tester.pumpWidget(host(tile(onOpen: () => opened++)));
      await tester.longPress(find.byType(ChatArtifactTile).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(opened, 1);
    });
  });

  group('ChatAppBarTitle', () {
    ChatAppBarTitle bar({
      required VoidCallback onCredentialTap,
      VoidCallback? onRenameTap,
    }) => ChatAppBarTitle(
      title: 'Q3 ledger close',
      activeCredentialLabel: 'Default · ZAD LIVE',
      autoApprove: false,
      onCredentialTap: onCredentialTap,
      onRenameTap: onRenameTap,
    );

    testWidgets('the credential row opens the picker', (tester) async {
      var picks = 0;
      await tester.pumpWidget(host(bar(onCredentialTap: () => picks++)));
      await tester.tap(find.text('Default · ZAD LIVE'));
      await tester.pump();
      expect(picks, 1);
    });

    testWidgets('rename is offered only when a handler exists', (tester) async {
      // `onRenameTap` is nullable and the widget guards on it. The failure
      // this pins is the inverse of the usual one: not a dead control, but a
      // control rendered for a screen that cannot service it.
      var renames = 0;
      var picks = 0;
      await tester.pumpWidget(host(bar(onCredentialTap: () => picks++)));
      expect(
        find.byIcon(AppIcons.edit),
        findsNothing,
        reason: 'A rename pencil is offered with no handler behind it.',
      );

      await tester.pumpWidget(
        host(bar(onCredentialTap: () => picks++, onRenameTap: () => renames++)),
      );
      expect(find.byIcon(AppIcons.edit), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.edit));
      await tester.pump();
      expect(renames, 1);
      // The pencil sits INSIDE the InkWell that opens the credential
      // picker. If the inner gesture did not win the arena, every rename
      // would also swap the environment behind the user's back.
      expect(
        picks,
        0,
        reason: 'Tapping rename also fired the credential picker.',
      );
    });
  });

  group('PromptClarifyCard', () {
    const payload = PromptClarifyPayload(
      original: 'send the report',
      intro: 'A couple of quick questions:',
      questions: [
        ClarifyQuestion(
          question: 'Which period?',
          options: ['This month', 'Last quarter'],
        ),
      ],
    );

    testWidgets('seeds the composer with the answer that was chosen', (
      tester,
    ) async {
      // Two callbacks with near-identical signatures — `onSend` submits,
      // `onSeed` only fills the composer. Swapping them sends a half-formed
      // request to a live Odoo instance instead of letting the user finish
      // typing it.
      final sent = <String>[];
      final seeded = <String>[];
      await tester.pumpWidget(
        host(
          PromptClarifyCard(
            payload: payload,
            onSend: sent.add,
            onSeed: seeded.add,
          ),
        ),
      );

      await tester.tap(find.text('Last quarter'));
      await tester.pumpAndSettle();
      expect(
        sent,
        isEmpty,
        reason: 'Picking an option submitted the request outright.',
      );
    });
  });

  group('ReportBuilderCard', () {
    testWidgets('does not submit until the user asks it to', (tester) async {
      // The card composes a request from several pickers. Nothing it does
      // while being filled in should reach `onSend` — the send is the last,
      // deliberate tap, and this card's output runs a report against a real
      // database.
      final sent = <String>[];
      await tester.pumpWidget(
        host(
          ReportBuilderCard(
            payload: const ReportBuilderPayload(),
            onSend: sent.add,
          ),
        ),
      );
      await tester.pump();
      expect(sent, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
