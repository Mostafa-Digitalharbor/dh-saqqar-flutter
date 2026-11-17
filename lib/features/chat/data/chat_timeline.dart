/// Reshapes the flat message list into the slots the chat list renders.
///
/// Extracted from `_ChatScreenState` so it can be tested without pumping the
/// screen. It is the second of the two places an interactive card can vanish
/// (the first is `message_visibility.dart`): a card folded into a multi-step
/// agent turn ends up inside the COLLAPSED "Saqqar thinking" pill, where the
/// user cannot reach the chips the card exists to offer. Same user-visible
/// outcome as never rendering it — and equally invisible to a widget test
/// that pumps a `MessageRow` on its own.
library;

import 'chat_view_models.dart';
import 'interactive_cards.dart';

/// One renderable slot in the chat list.
sealed class TimelineEntry {
  const TimelineEntry();

  /// First message in this entry — used for date-separator anchoring
  /// (calendar-day boundary against the previous entry).
  ChatMessage get firstMessage;

  /// Last message in this entry — used for the "previous role" check when
  /// the next entry starts a new group.
  ChatMessage get lastMessage;
}

/// A solo bubble — a user message, an interactive card, or a lone assistant
/// reply that had no thinking steps before it.
class SingleMessageEntry extends TimelineEntry {
  const SingleMessageEntry(this.message);

  final ChatMessage message;

  @override
  ChatMessage get firstMessage => message;

  @override
  ChatMessage get lastMessage => message;
}

/// A multi-step agent turn: the intermediate "thinking" messages collapsed
/// into a pill, plus the final reply rendered as a normal bubble below it.
class AgentTurnEntry extends TimelineEntry {
  const AgentTurnEntry({required this.thinkingSteps, required this.finalReply});

  final List<ChatMessage> thinkingSteps;
  final ChatMessage finalReply;

  @override
  ChatMessage get firstMessage =>
      thinkingSteps.isEmpty ? finalReply : thinkingSteps.first;

  @override
  ChatMessage get lastMessage => finalReply;

  /// Wall-clock duration the agent spent on this turn — first thinking step's
  /// `createdAt` → final reply's `createdAt`. Null when either side has no
  /// timestamp (older cached messages) so the pill hides its `· 14s` segment
  /// cleanly, and null for a negative delta rather than rendering "-3s".
  Duration? get duration {
    if (thinkingSteps.isEmpty) return null;
    final start = thinkingSteps.first.createdAt;
    final end = finalReply.createdAt;
    if (start == null || end == null) return null;
    final delta = end.difference(start);
    return delta.isNegative ? null : delta;
  }
}

/// True when [message] carries a card the user is meant to interact with.
///
/// The timeline and the renderer must agree on this exactly: if the timeline
/// thinks a message is ordinary and the renderer thinks it is a card (or the
/// reverse), the card is either buried in a pill or rendered where the layout
/// does not expect it.
bool isInteractiveCardMessage(ChatMessage message) =>
    interactiveCardKind(message.toolPayload) != null;

/// Groups a flat message list into renderable entries.
///
/// Runs of 2+ consecutive assistant messages collapse into one
/// [AgentTurnEntry] (everything before the last becomes thinking steps; the
/// last stays the final reply). Everything else — user messages, lone
/// assistant replies, and **every interactive card** — maps to its own
/// [SingleMessageEntry].
/// A pause long enough that the next assistant message is a new turn rather
/// than more of the same thought.
///
/// Two minutes is well past any real chain of tool calls and well short of a
/// user coming back to a conversation.
const _turnGap = Duration(minutes: 2);

/// Whether [next] belongs to a different turn from [prev].
///
/// **Why this exists.** The grouper used to run on role alone: any stretch of
/// consecutive assistant messages became one "Saqqar thinking" pill, whose
/// header reports the span from the first step to the final reply. That was
/// fine while every assistant message came from the turn just before it.
///
/// The §6 tools broke that assumption — Health Radar, Business Pulse and
/// What-If post their report **into an existing conversation**, hours or days
/// after the last reply. The report got glued to whatever the agent said last
/// and the pill read `Saqqar thinking · 1 steps · 684m 5s`: an eleven-hour
/// think, observed on a real device on 2026-08-09.
///
/// Messages with no timestamp are treated as the same turn — the old
/// behaviour — since there is nothing to measure against.
bool _startsNewTurn(ChatMessage prev, ChatMessage next) {
  final a = prev.createdAt;
  final b = next.createdAt;
  if (a == null || b == null) return false;
  return b.difference(a).abs() >= _turnGap;
}

/// [isRunning] mirrors the web's idle-only rule: while the run is still
/// live, a card message is not pulled out to stand alone — it folds into
/// the ordinary consecutive-assistant grouping like any other thinking
/// step, and only gets promoted to its own slot once the run goes idle.
List<TimelineEntry> buildChatTimeline(
  List<ChatMessage> messages, {
  required bool isRunning,
}) {
  final out = <TimelineEntry>[];
  var i = 0;
  while (i < messages.length) {
    final m = messages[i];
    // A card always stands alone — see the library note above — but only
    // once idle; mid-run it is treated as an ordinary assistant message.
    final isCard = !isRunning && isInteractiveCardMessage(m);
    if (m.role != ChatMessageRole.assistant || isCard) {
      out.add(SingleMessageEntry(m));
      i++;
      continue;
    }
    // Collect a run of consecutive assistant messages, stopping BEFORE any
    // card so it gets its own entry on the next pass — and before any long
    // pause, which means a *different* turn rather than more thinking.
    var j = i;
    while (j < messages.length &&
        messages[j].role == ChatMessageRole.assistant &&
        !(!isRunning && isInteractiveCardMessage(messages[j])) &&
        (j == i || !_startsNewTurn(messages[j - 1], messages[j]))) {
      j++;
    }
    final run = messages.sublist(i, j);
    // The reply is the last row that is actually a REPLY. Trailing agent
    // steps are dropped rather than promoted: a run whose last row is
    // "Applying a change in Odoo" has not answered yet — the agent is still
    // working, the typing row is already saying so, and printing the step as
    // the answer would put words in the agent's mouth. They come back as
    // steps on the next poll, once the real reply lands behind them.
    final replyAt = run.lastIndexWhere((m) => !m.isAgentStep);
    if (replyAt < 0) {
      // Steps only — nothing to attach them to yet.
      i = j;
      continue;
    }
    if (replyAt == 0) {
      out.add(SingleMessageEntry(run.first));
    } else {
      out.add(
        AgentTurnEntry(
          thinkingSteps: run.sublist(0, replyAt),
          finalReply: run[replyAt],
        ),
      );
    }
    i = j;
  }
  return out;
}
