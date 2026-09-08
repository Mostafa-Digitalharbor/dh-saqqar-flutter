import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/responsive_breakpoints.dart';
import '../data/app_pulse_payloads.dart';
import '../data/chat_view_models.dart';
import '../data/interactive_cards.dart';
import '../data/pulse_actions.dart';
import '../../../core/theme/app_sizes.dart';
import 'continue_run_button.dart';
import 'app_pulse/accountant_pulse_card.dart';
import 'app_pulse/factory_pulse_card.dart';
import 'app_pulse/finance_pulse_card.dart';
import 'app_pulse/hr_pulse_card.dart';
import 'app_pulse/inventory_pulse_card.dart';
import 'app_pulse/purchasing_pulse_card.dart';
import 'app_pulse/quality_guard_pulse_card.dart';
import 'message_bubble.dart';
import 'prompt_clarify_card.dart';
import 'prompt_suggestion_card.dart';
import 'report_builder_card.dart';
import 'tool_activity_card.dart';

/// Orchestrates layout for one message in the chat list.
///
/// - A message whose `tool_payload.kind` names an INTERACTIVE card renders
///   that card, so the user can choose options inside the conversation. This
///   branch runs first and deliberately outranks the tool-role branch below:
///   the generic [ToolActivityCard] would otherwise swallow the payload and
///   show a monospace JSON blob with nothing to tap.
/// - Other tool messages render as a [ToolActivityCard] indented under the
///   assistant.
/// - User / assistant messages render as a [MessageBubble], with the avatar
///   shown only on the first message of a group (consecutive messages from
///   the same sender share a single avatar slot).
class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
    required this.isRunning,
    this.isLatestAssistant = false,
    this.onCardSend,
    this.onCardSeed,
    this.entityLoader,
  });

  final ChatMessage message;
  final bool isFirstOfGroup;
  final bool isLastOfGroup;

  /// Web parity (idle-only cards): while the run is still live, the three
  /// "compose a follow-up" kinds (`promptClarify`/`reportBuilder`/
  /// `promptSuggestion`) fall through to ordinary rendering instead of a
  /// card — mid-run they are just another step, not something to act on
  /// yet. The read-only app-pulse dashboards are unaffected: those come
  /// from a different doc (MOBILE_TASKS_2026-09.md) with no such rule.
  final bool isRunning;

  /// Whether this is the newest assistant reply in the conversation.
  ///
  /// Gates the Continue button below. The web keeps the same rule so a run
  /// that was continued long ago does not leave a stale button halfway up
  /// the transcript, offering to resume something already finished.
  final bool isLatestAssistant;

  /// An interactive card composed a follow-up and wants it SENT.
  final ValueChanged<String>? onCardSend;

  /// An interactive card composed a follow-up and wants it dropped in the
  /// composer for the user to review before sending.
  final ValueChanged<String>? onCardSeed;

  /// Backs the report card's record multi-select. Null hides that section.
  final ReportEntityLoader? entityLoader;

  bool get _isUser => message.role == ChatMessageRole.user;
  bool get _isTool => message.role == ChatMessageRole.tool;

  /// The interactive card this message carries, if any.
  ///
  /// Static so the chat timeline can ask the same question before grouping
  /// messages — a card folded into a "thinking steps" run would be
  /// unreachable, which is the same bug as not rendering it at all.
  static InteractiveCardKind? interactiveKindOf(ChatMessage message) =>
      interactiveCardKind(message.toolPayload);

  @override
  Widget build(BuildContext context) {
    final card = _buildInteractiveCard(context);
    if (card != null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.s8,
          top: AppSpacing.s4,
          bottom: AppSpacing.s4,
        ),
        child: card,
      );
    }

    if (_isTool) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.s42),
        child: ToolActivityCard(message: message),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Spec §8 — user clamps to 88 %, agent clamps to 96 %. On
        // the `compact` tier (≤400 px) the 88 % cap leaves user
        // messages with so little width that URLs and Arabic phrases
        // wrap one-or-two-words-per-line; relax to 94 % below the
        // breakpoint so the bubble breathes. Neither side renders an
        // avatar — the agent's gradient wordmark identifies itself
        // inside the message body, and the user avatar was retired on
        // 2026-05-17 (alignment + cyan fill already say "this is you").
        final tier = breakpointForWidth(constraints.maxWidth);
        final userFactor = tier.isCompactOrBelow ? 0.94 : 0.88;
        final factor = _isUser ? userFactor : 0.96;
        final bubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * factor),
          child: MessageBubble(
            isUser: _isUser,
            message: message,
            showTime: isLastOfGroup,
          ),
        );

        return Align(
          alignment: _isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: _canContinue
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bubble,
                    const SizedBox(height: AppSpacing.s8),
                    ContinueRunButton(
                      onPressed: () =>
                          onCardSend!.call(context.tr.continueRunMessage),
                    ),
                  ],
                )
              : bubble,
        );
      },
    );
  }

  /// Whether to offer the one-tap Continue under this reply.
  ///
  /// The server sets `tool_payload.continue_available` when a run stops
  /// because it hit the agent's ceiling on tool rounds — it has said so and
  /// is waiting, which is a different state from the silent stop the resume
  /// banner covers. Without this the only way forward on mobile was to type
  /// "carry on" and hope the agent understood; the button sends the exact
  /// sentence the web sends.
  ///
  /// Three conditions, all the web's: only the newest reply (an old one
  /// would offer to continue something already finished), only while nothing
  /// is running, and only with a handler to send through.
  bool get _canContinue =>
      isLatestAssistant &&
      !isRunning &&
      !_isUser &&
      onCardSend != null &&
      message.toolPayload?['continue_available'] == true;

  /// Mirrors the web's `kind` dispatch in `renderMessages`.
  ///
  /// Returns null — falling through to the ordinary message paths — whenever
  /// the payload can't actually be answered (no questions, no suggestion text,
  /// no report types) or, for the three "compose a follow-up" kinds, when the
  /// screen wired no send handler. A card the user cannot act on is worse
  /// than a plain message.
  ///
  /// The app-pulse kinds (Task 1, MOBILE_TASKS_2026-09.md) are read-only
  /// dashboards — nothing they render composes a message — so they need no
  /// `onCardSend` and render even on a surface that never wires one (e.g. the
  /// shared read-only transcript view).
  Widget? _buildInteractiveCard(BuildContext context) {
    switch (interactiveCardKind(message.toolPayload)) {
      case InteractiveCardKind.promptClarify:
        if (isRunning) return null;
        final send = onCardSend;
        if (send == null) return null;
        final payload = PromptClarifyPayload.parse(message.toolPayload);
        if (payload == null) return null;
        return PromptClarifyCard(
          payload: payload,
          onSend: send,
          onSeed: onCardSeed ?? send,
        );
      case InteractiveCardKind.reportBuilder:
        if (isRunning) return null;
        final send = onCardSend;
        if (send == null) return null;
        final payload = ReportBuilderPayload.parse(message.toolPayload);
        if (payload == null) return null;
        return ReportBuilderCard(
          payload: payload,
          onSend: send,
          entityLoader: entityLoader,
        );
      case InteractiveCardKind.promptSuggestion:
        if (isRunning) return null;
        final send = onCardSend;
        if (send == null) return null;
        final payload = PromptSuggestionPayload.parse(message.toolPayload);
        if (payload == null) return null;
        return PromptSuggestionCard(payload: payload, onSend: send);
      // The pulse cards render with or without a composer behind them: the
      // numbers are worth reading on a read-only surface too. What the
      // composer adds is the action rows — `onCardSend` is what the buttons
      // send through, so a surface that wires none gets the card without
      // them rather than with dead buttons.
      case InteractiveCardKind.factory:
        final payload = FactoryPulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : FactoryPulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.factory),
                onSend: onCardSend,
              );
      case InteractiveCardKind.inventory:
        final payload = InventoryPulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : InventoryPulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.inventory),
                deepActions:
                    _deepActions(context, InteractiveCardKind.inventory),
                onSend: onCardSend,
              );
      case InteractiveCardKind.finance:
        final payload = FinancePulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : FinancePulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.finance),
                onSend: onCardSend,
              );
      case InteractiveCardKind.purchasing:
        final payload = PurchasingPulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : PurchasingPulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.purchasing),
                onSend: onCardSend,
              );
      case InteractiveCardKind.accountant:
        final payload = AccountantPulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : AccountantPulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.accountant),
                deepActions:
                    _deepActions(context, InteractiveCardKind.accountant),
                onSend: onCardSend,
              );
      case InteractiveCardKind.hr:
        final payload = HrPulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : HrPulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.hr),
                deepActions: _deepActions(context, InteractiveCardKind.hr),
                onSend: onCardSend,
              );
      case InteractiveCardKind.qualityGuard:
        final payload = QualityGuardPulsePayload.parse(message.toolPayload);
        return payload == null
            ? null
            : QualityGuardPulseCard(
                payload: payload,
                actions: _actions(context, InteractiveCardKind.qualityGuard),
                onSend: onCardSend,
              );
      case null:
        return null;
    }
  }

  /// The card's action rows, built from the same `tool_payload` the card
  /// renders. Empty when the payload has nothing to act on.
  List<PulseAction> _actions(BuildContext context, InteractiveCardKind kind) =>
      pulseActions(kind, message.toolPayload, context.tr);

  /// The accountant / HR / inventory chip row — standing questions with no
  /// number.
  List<PulseAction> _deepActions(
    BuildContext context,
    InteractiveCardKind kind,
  ) =>
      pulseDeepActions(kind, message.toolPayload, context.tr);
}
