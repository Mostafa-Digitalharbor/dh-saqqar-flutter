import 'package:flutter/material.dart';

import '../../../shared/extensions/responsive_breakpoints.dart';
import '../data/app_pulse_payloads.dart';
import '../data/chat_view_models.dart';
import '../data/interactive_cards.dart';
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
import '../../../core/theme/app_sizes.dart';

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
          child: bubble,
        );
      },
    );
  }

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
      case InteractiveCardKind.factory:
        final payload = FactoryPulsePayload.parse(message.toolPayload);
        return payload == null ? null : FactoryPulseCard(payload: payload);
      case InteractiveCardKind.inventory:
        final payload = InventoryPulsePayload.parse(message.toolPayload);
        return payload == null ? null : InventoryPulseCard(payload: payload);
      case InteractiveCardKind.finance:
        final payload = FinancePulsePayload.parse(message.toolPayload);
        return payload == null ? null : FinancePulseCard(payload: payload);
      case InteractiveCardKind.purchasing:
        final payload = PurchasingPulsePayload.parse(message.toolPayload);
        return payload == null ? null : PurchasingPulseCard(payload: payload);
      case InteractiveCardKind.accountant:
        final payload = AccountantPulsePayload.parse(message.toolPayload);
        return payload == null ? null : AccountantPulseCard(payload: payload);
      case InteractiveCardKind.hr:
        final payload = HrPulsePayload.parse(message.toolPayload);
        return payload == null ? null : HrPulseCard(payload: payload);
      case InteractiveCardKind.qualityGuard:
        final payload = QualityGuardPulsePayload.parse(message.toolPayload);
        return payload == null ? null : QualityGuardPulseCard(payload: payload);
      case null:
        return null;
    }
  }
}
