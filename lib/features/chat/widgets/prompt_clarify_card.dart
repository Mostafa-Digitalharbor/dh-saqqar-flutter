import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/interactive_cards.dart';
import 'interactive_card_shell.dart';
import '../../../core/theme/app_sizes.dart';

/// §4a — the clarifying-questions card (`tool_payload.kind == prompt_clarify`).
///
/// Saqqar asks 1–3 short questions before building a vague task; the user
/// answers them **inside the conversation** and the card composes the reply.
/// Without this the same payload rendered as a raw JSON blob with nothing to
/// tap — which made Task prep (§3) actively worse than leaving it off.
class PromptClarifyCard extends StatefulWidget {
  const PromptClarifyCard({
    super.key,
    required this.payload,
    required this.onSend,
    required this.onSeed,
  });

  final PromptClarifyPayload payload;

  /// "Build & send" — composes the answers and sends them as a message.
  final ValueChanged<String> onSend;

  /// "Prepare & review" — composes the same text but drops it in the composer
  /// so the user can read it, edit it, and send when they're ready.
  ///
  /// The web routes this to a server-side review path that mobile has no
  /// endpoint for; seeding the composer is the honest local equivalent —
  /// nothing is sent until the user commits. Flagged to the web team.
  final ValueChanged<String> onSeed;

  @override
  State<PromptClarifyCard> createState() => _PromptClarifyCardState();
}

class _PromptClarifyCardState extends State<PromptClarifyCard> {
  /// Chip index chosen per question — null for "none picked".
  late final List<int?> _picked;

  /// Free-text answers, one controller per question. Kept alive for the
  /// card's whole life so the user doesn't lose typing when another question
  /// rebuilds the row.
  late final List<TextEditingController> _typed;

  @override
  void initState() {
    super.initState();
    // Smart defaults come pre-selected — the payload's `default` index. The
    // parser already dropped out-of-range values, so this can't highlight a
    // chip that doesn't exist.
    _picked = [for (final q in widget.payload.questions) q.defaultIndex];
    _typed = [
      for (var i = 0; i < widget.payload.questions.length; i++)
        TextEditingController(),
    ];
  }

  @override
  void dispose() {
    for (final c in _typed) {
      c.dispose();
    }
    super.dispose();
  }

  /// The answer for question [i]: free text wins when the user typed
  /// something, otherwise the chip they tapped.
  String? _answerAt(int i) {
    final typed = _typed[i].text.trim();
    if (typed.isNotEmpty) return typed;
    final chip = _picked[i];
    if (chip == null) return null;
    return widget.payload.questions[i].options[chip];
  }

  /// `"Answers to your questions:\n- <question> <answer>\n…"` — answers only.
  /// The original request is already a message above, so repeating it would
  /// just make the agent re-read it.
  String? _compose(BuildContext context) {
    final lines = <String>[];
    for (var i = 0; i < widget.payload.questions.length; i++) {
      final answer = _answerAt(i);
      if (answer == null) continue;
      lines.add('- ${widget.payload.questions[i].question} $answer');
    }
    if (lines.isEmpty) return null;
    return '${context.tr.clarifyAnswersHeader}\n${lines.join('\n')}';
  }

  void _submit(BuildContext context, {required bool send}) {
    final composed = _compose(context);
    if (composed == null) {
      AppToast.show(
        context,
        message: context.tr.clarifyNeedsAnswer,
        variant: ToastVariant.info,
      );
      return;
    }
    if (send) {
      widget.onSend(composed);
    } else {
      widget.onSeed(composed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final questions = widget.payload.questions;

    return InteractiveCardShell(
      icon: AppIcons.lightbulb,
      title: tr.clarifyTitle,
      children: [
        if (widget.payload.intro.isNotEmpty) ...[
          Text(
            widget.payload.intro,
            style: context.text.bodyMedium?.copyWith(
              color: s.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        for (var i = 0; i < questions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s14),
          CardFieldLabel(questions[i].question),
          if (questions[i].options.isNotEmpty)
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (var o = 0; o < questions[i].options.length; o++)
                  CardChoiceChip(
                    label: questions[i].options[o],
                    selected: _picked[i] == o && _typed[i].text.trim().isEmpty,
                    onTap: () => setState(() {
                      // Tapping a chip clears that question's free text, and
                      // vice-versa (see the listener below) — one answer per
                      // question, never two competing ones.
                      _typed[i].clear();
                      _picked[i] = _picked[i] == o ? null : o;
                    }),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.s8),
          AppTextField(
            controller: _typed[i],
            hint: tr.clarifySomethingElse,
            onChanged: (value) => setState(() {
              if (value.trim().isNotEmpty) _picked[i] = null;
            }),
          ),
        ],
        const SizedBox(height: AppSpacing.s14),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: tr.clarifyPrepareReview,
                icon: AppIcons.edit,
                onPressed: () => _submit(context, send: false),
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: PrimaryButton(
                label: tr.clarifyBuildSend,
                icon: AppIcons.send,
                onPressed: () => _submit(context, send: true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
