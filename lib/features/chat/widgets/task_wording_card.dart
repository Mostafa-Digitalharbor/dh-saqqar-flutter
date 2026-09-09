import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/glass_card.dart';

/// The structured task prompt, docked above the composer for review.
///
/// The web's `task-prompt-dock`: a heading that says where the text came
/// from, the draft in an **editable** box, and two ways out — put it in the
/// composer, or run it now. Editable is the point; the draft is the server's
/// best guess at a task the user has only half-described, and the review step
/// is what stops a wrong guess from being executed.
///
/// Saved past prompts are deliberately not listed here. They reach the server
/// as ranking signal for the draft and never appear on screen — the web made
/// the same call, and a card that also listed eight old tasks would bury the
/// one thing the user asked for.
class TaskWordingCard extends StatefulWidget {
  const TaskWordingCard({
    super.key,
    required this.draft,
    required this.loading,
    required this.onUse,
    required this.onRun,
    required this.onClose,
  });

  /// The server's structured rewrite, or the raw query when it produced
  /// none — never empty while [loading] is false.
  final String draft;

  /// The round trip is slow (an LLM writes the draft), so the card opens
  /// immediately in this state rather than after a silent wait.
  final bool loading;

  /// Both receive the CURRENT text of the box, not [draft] — the user is
  /// expected to edit it, and sending the original would silently discard
  /// what they just typed.
  final ValueChanged<String> onUse;
  final ValueChanged<String> onRun;

  final VoidCallback onClose;

  @override
  State<TaskWordingCard> createState() => _TaskWordingCardState();
}

class _TaskWordingCardState extends State<TaskWordingCard> {
  late final TextEditingController _draft;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.draft);
  }

  @override
  void didUpdateWidget(TaskWordingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The draft arrives after the card is already on screen. Adopt it when
    // the server's text changes, but never overwrite edits the user has
    // made since — hence the comparison against the OLD draft rather than
    // the current field contents.
    if (widget.draft != oldWidget.draft && _draft.text == oldWidget.draft) {
      _draft.text = widget.draft;
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  String get _text => _draft.text.trim();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final busy = widget.loading;

    return GlassCard.flat(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s12,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIcons.fileText,
                color: s.brandCyan,
                size: AppIconSizes.regular,
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.promptBankTitle,
                      style: context.text.labelLarge?.copyWith(
                        color: s.brandCyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      tr.promptCardIntro,
                      style: context.text.bodySmall?.copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.close, size: AppIconSizes.regular),
                color: s.muted,
                tooltip: tr.close,
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          if (busy)
            Row(
              children: [
                SizedBox(
                  width: AppControlSizes.spinnerDense,
                  height: AppControlSizes.spinnerDense,
                  child: CircularProgressIndicator(
                    strokeWidth: AppStrokeWidths.spinnerThin,
                    color: s.brandCyan,
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                Text(
                  tr.promptPreparing,
                  style: context.text.bodySmall?.copyWith(color: s.muted),
                ),
              ],
            )
          else
            AppTextField(
              label: tr.promptBankDraftTitle,
              controller: _draft,
              // The web's `rows="6"`. Taller than this and the card plus an
              // open keyboard leaves the transcript no room at all.
              maxLines: 6,
              minLines: 3,
              keyboardType: TextInputType.multiline,
            ),
          const SizedBox(height: AppSpacing.s10),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              PrimaryButton(
                label: tr.promptUseDraft,
                minHeight: AppControlSizes.buttonMin,
                onPressed:
                    busy ? null : () => widget.onUse(_text),
              ),
              PrimaryButton(
                label: tr.promptRunNow,
                icon: AppIcons.send,
                minHeight: AppControlSizes.buttonMin,
                onPressed:
                    busy ? null : () => widget.onRun(_text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
