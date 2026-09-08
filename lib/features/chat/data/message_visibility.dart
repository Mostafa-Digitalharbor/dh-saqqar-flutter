/// Which server messages the chat stream shows the user.
///
/// Extracted from `_ChatScreenState` so it can be tested without pumping the
/// whole screen — which is how a real defect hid: the filter drops every
/// `tool`-role row and every empty-content assistant row, and
/// `docs/WEB_UI_PARITY_GAPS.md` Appendix A puts the interactive-card payload
/// on exactly those ("the server sends these as `message.tool_payload` on an
/// assistant/tool message"). Widget tests that pump a `MessageRow` directly
/// bypass this filter entirely, so all three cards passed their tests while
/// being unreachable in the running app.
///
/// The rest of the predicate is unchanged: it drops the agent's internal
/// plumbing — tool outputs, empty tool-call invocations, system-injected
/// user payloads, and `[agent-control]` directives.
library;

import '../../conversations/data/conversation_models.dart';
import 'interactive_cards.dart';

/// Single-word approval acks ("approve" / "rejected" …). These come from
/// tapping an inline approval card, not from anyone typing.
const _approvalKeywords = {
  'approve',
  'approved',
  'reject',
  'rejected',
  'accept',
  'accepted',
  'deny',
  'denied',
};

/// True when [m] belongs in the conversation the user reads.
///
/// Shared by the render path and the paging math so the two can never
/// disagree about what counts as a visible message.
///
/// [isRunning] mirrors the web's idle-only rule for interactive cards
/// (`prompt_clarify` / `prompt_suggestion` / `report_builder`): the web only
/// promotes a `tool_payload.kind` message to a card once the run has gone
/// idle — mid-run it is just another step. Passing `isRunning: true` here
/// stops the card carve-out below from force-keeping an otherwise-empty
/// tool/assistant row visible, so it instead falls through to the ordinary
/// empty-content rule and collapses into the ordinary "thinking" grouping,
/// exactly like any other intermediate step.
bool isVisibleMessage(Message m, {required bool isRunning}) {
  // An interactive card IS the message — it outranks every rule below.
  //
  // Both of the next two rules would otherwise eat it: the payload rides on
  // a `tool` row in some deployments, and on an assistant row whose `content`
  // is empty in others (the payload is the content). `hasRenderable…` rather
  // than a bare `kind` check, so a malformed card still gets dropped instead
  // of rendering as an empty bubble.
  if (!isRunning && hasRenderableInteractiveCard(m.toolPayload)) return true;

  // An agent STEP is kept, but it is not a bubble — see [isAgentStepMessage].
  // The timeline folds it into the "Saqqar thinking · N steps" pill, which is
  // where the web puts the same rows. Dropping it here is what made a write
  // vanish without trace: the transcript read "add a product" → "done", with
  // no sign that an approval had been granted or that anything had run.
  if (isAgentStepMessage(m)) return true;

  if (m.role == MessageRole.tool) return false;
  if (m.role == MessageRole.assistant && m.content.trim().isEmpty) {
    return false;
  }
  if (m.role == MessageRole.user && isSystemUserPayload(m.content)) {
    return false;
  }
  if (isAgentControlPayload(m.content)) return false;
  return true;
}

/// Heuristic for "this user message wasn't actually typed by the user — it's
/// a system-injected payload (approval ack, button-tap echo, raw JSON
/// envelope) that leaked into the conversation as a `user` row server-side".
/// The server doesn't mark these distinctly, so we sniff the content.
///
/// Tight on purpose — only obvious payloads. Anything that looks like real
/// prose passes through, including short replies like "تمام" or "yes".
bool isSystemUserPayload(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return true;
  if (_approvalKeywords.contains(trimmed.toLowerCase())) return true;
  // JSON-shaped payload — a raw envelope the server persisted as a user
  // message. Real users don't type JSON.
  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    return true;
  }
  return false;
}

/// Detects the server-side "approval granted, now go execute" directives the
/// agent receives after a user accepts an approval. They carry the literal
/// `[agent-control]` marker and start with `Approval '<id>' …`, so we match
/// either signal — the marker is authoritative, the prefix a cheap early-exit.
bool isAgentControlPayload(String content) {
  if (content.isEmpty) return false;
  if (content.contains('[agent-control]')) return true;
  final trimmed = content.trimLeft();
  if (trimmed.startsWith("Approval '") && trimmed.contains('is approved')) {
    return true;
  }
  return false;
}

/// A row that records something the agent DID, rather than something it said.
///
/// The backend narrates a run as pairs: an assistant row carrying
/// `tool_payload.tool_calls` and no text, then a `tool` row with the call's
/// result. Only the second is kept. The pair describes one action, so keeping
/// both would print every step twice; and the assistant half has no content
/// at all, which is why the web — which does keep both — renders a blank line
/// above each of its steps.
///
/// A `tool_name` is required, not incidental: it is what the label is looked
/// up from, so a tool row without one has nothing readable to become and is
/// still dropped rather than shown as raw JSON.
bool isAgentStepMessage(Message m) =>
    m.role == MessageRole.tool && (m.toolName ?? '').trim().isNotEmpty;
