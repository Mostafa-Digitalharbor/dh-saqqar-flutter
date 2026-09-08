import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/ghost_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';

/// The action rows under an app-pulse card's numbers — "Customer collection ·
/// 13 invoices · [Start collection]".
///
/// This is the half of the card the phone was missing: the web has rendered
/// these rows since the apps shipped, and each button hands the agent a
/// prompt and lets it work. Reading the same numbers with no way to act on
/// them was the gap the team reported.
///
/// Tapping sends immediately — the prompts are all read-only investigations
/// ("show…", "review…", "suggest… without executing"), and anything the
/// agent then wants to write still stops at an approval card. That is the
/// web's behaviour too: `sendMessage(row.prompt)`.
class PulseActionList extends StatelessWidget {
  const PulseActionList({
    super.key,
    required this.actions,
    required this.onSend,
    this.emptyState = '',
  });

  final List<PulseAction> actions;

  /// Shown in place of the rows when the payload earns none — the web's
  /// own "looks calm in the current read" line. Empty string renders
  /// nothing, which is what the counter-driven cards want.
  final String emptyState;

  /// Sends the row's prompt as the next user message. Null on a surface
  /// with no composer (the shared read-only transcript), where the rows
  /// still render — the reading is worth having — but without buttons,
  /// rather than showing dead ones.
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      // Good news still needs saying: a card that simply stops after its
      // zeros reads like a failed load.
      if (emptyState.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s10),
        child: Text(
          emptyState,
          style: context.text.bodySmall?.copyWith(color: context.saqqar.muted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in actions)
          _ActionRow(action: action, onSend: onSend),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onSend});

  final PulseAction action;

  /// Null on a read-only surface — the row then renders its reading with no
  /// buttons under it.
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final send = onSend;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s10),
        decoration: BoxDecoration(
          color: s.surface2.withValues(alpha: AppAlphas.a06),
          borderRadius: AppRadius.smallR,
          border: Border.all(color: s.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ambient direction, not per-string detection: these three are
            // this client's own translated copy with a short data fragment
            // spliced in (an order code, a customer, a product name), and
            // `dir=auto` on a mixed string picks the wrong base direction —
            // "7 days waiting on «كيس جامبو»" came out reading backwards on
            // an English phone. The web sets one direction for the whole
            // card from the UI language and this matches it. The exception
            // stays [AutoDirectionText]: `notes` and `priorities`, which the
            // server writes in Arabic whatever the phone's language is.
            if (action.title.isNotEmpty)
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (action.main.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: Text(
                  action.main,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: s.text),
                ),
              ),
            if (action.cause.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: Text(
                  action.cause,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: s.muted),
                ),
              ),
            // A row can carry more than one button — the factory's at-risk
            // orders offer both a delivery promise and a shortage cover. A
            // [Wrap] rather than a [Row] so the second one drops to its own
            // line on a narrow phone or at a large text scale instead of
            // overflowing.
            if (send != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final button in action.buttons)
                    button.primary
                        ? PrimaryButton(
                            label: button.label,
                            icon: AppIcons.sparkles,
                            minHeight: AppControlSizes.buttonMin,
                            onPressed: () => send(button.prompt),
                          )
                        : GhostButton(
                            label: button.label,
                            icon: AppIcons.sparkles,
                            minHeight: AppControlSizes.buttonMin,
                            onPressed: () => send(button.prompt),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chip row under the accountant / HR / inventory cards — standing
/// questions the card can always ask, with no number of their own, so they
/// render as a wrap of chips rather than as rows.
class PulseDeepActionChips extends StatelessWidget {
  const PulseDeepActionChips({
    super.key,
    required this.actions,
    required this.onSend,
  });

  final List<PulseAction> actions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final send = onSend;
    if (actions.isEmpty || send == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s10),
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          // The lead chip is filled, the rest ghosts — the web's own rule
          // (`d.primary ? "fc-btn--primary"`). It is what makes "Track
          // shipments" the obvious first tap on the inventory card.
          for (final action in actions)
            action.primary
                ? PrimaryButton(
                    label: action.label,
                    minHeight: AppControlSizes.buttonMin,
                    onPressed: () => send(action.prompt),
                  )
                : GhostButton(
                    label: action.label,
                    minHeight: AppControlSizes.buttonMin,
                    onPressed: () => send(action.prompt),
                  ),
        ],
      ),
    );
  }
}

/// The free-text action three cards carry: type a document number
/// (accountant), a job title (HR), or a shipment / order / customer to
/// follow (inventory), and the agent takes it from there. The web puts an
/// input inside the card; so does this.
///
/// The inventory one is the "tracking banner" the review asked for: on the
/// web it sits under the chips as `.ac-explain`, and its reference is
/// something the card cannot know in advance — a transfer number, the order
/// behind it, or the customer waiting on it — which is why it is a box to
/// type in rather than one more button.
class PulseFreeTextAction extends StatefulWidget {
  const PulseFreeTextAction({
    super.key,
    required this.kind,
    required this.onSend,
  });

  final InteractiveCardKind kind;
  final ValueChanged<String>? onSend;

  @override
  State<PulseFreeTextAction> createState() => _PulseFreeTextActionState();
}

class _PulseFreeTextActionState extends State<PulseFreeTextAction> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String promptKey, String? emptyPromptKey) {
    final ref = _controller.text.trim();
    if (ref.isEmpty) {
      // Nothing typed. The tracker still has a question to ask — "everything
      // on the move" — so it asks it. The accountant's and HR's boxes do
      // not: "explain ''" is not a question, so they put the cursor in the
      // box instead, which is the web's `input.focus()`.
      if (emptyPromptKey == null) {
        _focus.requestFocus();
        return;
      }
      widget.onSend?.call(context.tr.lookup(emptyPromptKey));
      return;
    }
    _controller.clear();
    widget.onSend?.call(context.tr.format(promptKey, {'ref': ref}));
  }

  @override
  Widget build(BuildContext context) {
    final spec = pulseFreeTextAction(widget.kind);
    if (spec == null || widget.onSend == null) return const SizedBox.shrink();
    final s = context.saqqar;
    final tr = context.tr;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) =>
                  _submit(spec.promptKey, spec.emptyPromptKey),
              style: context.text.bodySmall?.copyWith(color: s.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: tr.lookup(spec.hint),
                hintStyle: context.text.bodySmall?.copyWith(color: s.muted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s8,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smallR,
                  borderSide: BorderSide(color: s.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smallR,
                  borderSide: BorderSide(color: s.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          // Filled, as on the web (`fc-btn--primary ac-explain-btn`): it is
          // the only thing to press once something has been typed.
          PrimaryButton(
            label: tr.lookup(spec.label),
            minHeight: AppControlSizes.buttonMin,
            onPressed: () => _submit(spec.promptKey, spec.emptyPromptKey),
          ),
        ],
      ),
    );
  }
}
