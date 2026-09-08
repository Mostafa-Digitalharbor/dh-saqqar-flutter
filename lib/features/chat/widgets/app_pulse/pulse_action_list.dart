import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/auto_direction_text.dart';
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
  /// with no composer (the shared read-only transcript), which hides the
  /// buttons rather than showing dead ones.
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final send = onSend;
    if (actions.isEmpty) {
      // Good news still needs saying: a card that simply stops after its
      // zeros reads like a failed load.
      if (emptyState.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s10),
        child: AutoDirectionText(
          emptyState,
          style: context.text.bodySmall?.copyWith(color: context.saqqar.muted),
        ),
      );
    }
    if (send == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in actions)
          _ActionRow(action: action, onSend: send),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onSend});

  final PulseAction action;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
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
            if (action.title.isNotEmpty)
              AutoDirectionText(
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
                child: AutoDirectionText(
                  action.main,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: s.text),
                ),
              ),
            if (action.cause.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: AutoDirectionText(
                  action.cause,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: s.muted),
                ),
              ),
            const SizedBox(height: AppSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: action.primary
                  ? PrimaryButton(
                      label: action.label,
                      icon: AppIcons.sparkles,
                      minHeight: AppControlSizes.buttonMin,
                      onPressed: () => onSend(action.prompt),
                    )
                  : GhostButton(
                      label: action.label,
                      icon: AppIcons.sparkles,
                      minHeight: AppControlSizes.buttonMin,
                      onPressed: () => onSend(action.prompt),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chip row under the accountant / HR cards — standing questions the
/// card can always ask, with no number of their own, so they render as a
/// wrap of chips rather than as rows.
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
          for (final action in actions)
            GhostButton(
              label: action.label,
              minHeight: AppControlSizes.buttonMin,
              onPressed: () => send(action.prompt),
            ),
        ],
      ),
    );
  }
}

/// The free-text action both counter-driven cards carry: type a document
/// number (accountant) or a job title (HR) and the agent takes it from
/// there. The web puts an input inside the card; so does this.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String promptKey) {
    final ref = _controller.text.trim();
    // An empty box sends nothing — the web focuses the input instead of
    // asking the agent to explain "".
    if (ref.isEmpty) return;
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
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(spec.promptKey),
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
          GhostButton(
            label: tr.lookup(spec.label),
            minHeight: AppControlSizes.buttonMin,
            onPressed: () => _submit(spec.promptKey),
          ),
        ],
      ),
    );
  }
}
