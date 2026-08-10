import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/interactive_cards.dart';
import 'interactive_card_shell.dart';

/// §4c — the cleaner-prompt card
/// (`tool_payload.kind == prompt_suggestion`).
///
/// Shows Saqqar's tidier version of the user's request in an EDITABLE field.
/// "Approve & use" sends whatever is in the field at that moment (edits
/// included); "Keep mine" dismisses the card without sending anything.
///
/// Distinct from [ChatSuggestionStrip] / [EmptyChatSuggestions], which are
/// starter prompts for an empty chat — those seed a conversation, this one
/// rewrites a request the user already made.
class PromptSuggestionCard extends StatefulWidget {
  const PromptSuggestionCard({
    super.key,
    required this.payload,
    required this.onSend,
  });

  final PromptSuggestionPayload payload;
  final ValueChanged<String> onSend;

  @override
  State<PromptSuggestionCard> createState() => _PromptSuggestionCardState();
}

class _PromptSuggestionCardState extends State<PromptSuggestionCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.payload.improved);

  /// "Keep mine" hides the card for this session. Deliberately local: the
  /// server has no "dismissed" state for a suggestion, and writing one into
  /// the message would misreport what the user actually did.
  bool _dismissed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final tr = context.tr;
    final s = context.saqqar;

    return InteractiveCardShell(
      icon: AppIcons.sparkles,
      title: tr.suggestionTitle,
      children: [
        if (widget.payload.note.isNotEmpty) ...[
          Text(
            widget.payload.note,
            style: context.text.bodySmall?.copyWith(
              color: s.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
        ],
        AppTextField(
          controller: _controller,
          minLines: 3,
          maxLines: 8,
          // Rebuild so "Approve & use" disables the moment the user clears
          // the field — sending an empty message would just waste a turn.
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: tr.suggestionKeepMine,
                icon: AppIcons.close,
                onPressed: () => setState(() => _dismissed = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: tr.suggestionApprove,
                icon: AppIcons.check,
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : () => widget.onSend(_controller.text.trim()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
