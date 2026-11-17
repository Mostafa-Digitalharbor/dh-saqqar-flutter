/// Paging policy for the chat's "load older messages as you scroll up"
/// behaviour.
///
/// This is deliberately a pure function rather than a few `if`s inside
/// `_ChatScreenState`. The behaviour it encodes is driven by a scroll handler
/// that fires on every frame of a drag, and its two failure modes are both
/// silent and both bad:
///
///   * fire too eagerly → the same page is requested dozens of times per
///     gesture, or the list loads history forever the moment a chat opens;
///   * fire too timidly → the user hits the top of the transcript and nothing
///     happens, with no button left to press.
///
/// Neither is visible in a screenshot and neither reproduces reliably by
/// hand, so the decision is separated from the widget and pinned by
/// `test/earlier_paging_test.dart`.
library;

/// What the chat should do when the user approaches the start of the loaded
/// transcript.
enum EarlierPageAction {
  /// Do nothing — either there is nothing older, or a guard is holding.
  none,

  /// Older messages are already in memory and just aren't rendered yet.
  /// Widen the render window; no network call.
  revealBuffered,

  /// The render window has caught up with everything loaded. Ask the server
  /// for more before widening.
  fetchOlder,
}

/// Decides whether to page in older messages, and how.
///
/// [automatic] distinguishes the scroll-driven call from an explicit user tap
/// on the retry affordance. Only the automatic path is subject to
/// [scrollRestored] and [lastAttemptFailed] — a deliberate tap should work
/// even when auto-loading has stood down, since that tap is the user telling
/// us to try again.
///
/// [shownCount] is how many visible messages are currently rendered;
/// [loadedCount] is how many the cubit holds. When rendering has caught up
/// with what's loaded, the only way forward is the network.
EarlierPageAction decideEarlierPage({
  required bool automatic,
  required bool alreadyLoading,
  required bool scrollRestored,
  required bool lastAttemptFailed,
  required int shownCount,
  required int loadedCount,
  required bool hasMoreOlder,
}) {
  // A load is in flight. Its own completion re-evaluates.
  if (alreadyLoading) return EarlierPageAction.none;

  if (automatic) {
    // Opening a chat sits at offset 0 for a frame or two before the one-shot
    // restore jumps to the latest message. That transient looks exactly like
    // "the user has scrolled to the top", so without this every chat open
    // would eagerly page in history nobody asked for.
    if (!scrollRestored) return EarlierPageAction.none;
    // Auto-loading stands down after an error instead of re-requesting a
    // failing endpoint on every scroll frame. The user gets a retry
    // affordance, and a successful retry clears the latch.
    if (lastAttemptFailed) return EarlierPageAction.none;
  }

  // Still holding rows we haven't drawn — cheapest possible page.
  if (shownCount < loadedCount) return EarlierPageAction.revealBuffered;

  // Everything loaded is on screen. Either the server has more, or this is
  // genuinely the start of the conversation and we must stop: returning
  // anything else here is what turns "scrolled to the top" into an infinite
  // request loop.
  return hasMoreOlder ? EarlierPageAction.fetchOlder : EarlierPageAction.none;
}

/// Where the lane should settle after a page lands, if it should move at all.
///
/// Returns the scroll offset to ease to, or `null` to leave the lane alone.
///
/// ## The bug this exists for
///
/// Reported by the user: flinging quickly to the top of a long chat parks you
/// against the edge with older messages still unloaded, and the only way
/// forward is to scroll down and back up again. That is not a gesture anyone
/// discovers, and resting against a dead edge reads as the app being stuck.
///
/// A fling outruns the fetch. By the time the page lands the user is already
/// at `extentBefore == 0`, and the row the correction wanted to re-anchor
/// against has been culled by the lazy list — so no correction is applied and
/// the list does not move at all. Nothing about the screen changes, which is
/// exactly what "it froze" looks like.
///
/// Easing down off the edge answers all of it: the freshly revealed rows end
/// up above the reader where they can scroll into them, the movement says the
/// list is alive, and the resulting scroll notification re-arms the load
/// trigger that had latched off.
///
/// ## It must never land at the end of the conversation
///
/// The first version clamped the target to `maxScrollExtent`, and that is a
/// trap: whenever the rendered transcript was shorter than the bump — which is
/// often, since a page reveals a bounded number of rows — the clamp resolved to
/// the very bottom and threw the user out of the history they were reading and
/// back to the newest message. Reported immediately: *"sometimes it takes me
/// all the way down to the end of the chat, and that's not acceptable."*
///
/// So the ceiling is `maxScrollExtent - viewportDimension`: a full screen of
/// content always stays below the landing point, which makes "you are still in
/// history" a property of the arithmetic rather than a hope. When even that
/// much room does not exist the lane is simply not long enough to strand
/// anyone, and the nudge stands down.
///
/// ## Distance
///
/// A fraction of the viewport, not a pixel constant — it should read as *a few
/// messages* on any screen, and message heights vary far too much to count
/// rows. It deliberately does NOT have to clear the auto-load trigger:
/// the trigger is latched off after firing, and only a fresh finger-down drag
/// re-arms it, so landing inside the trigger zone cannot re-fire anything.
///
/// ## The other guard
///
/// [hasMoreToReveal] false means this is the true start of the conversation.
/// Nudging there would shove the user away from the first message they scrolled
/// up to read, to uncover nothing — the same rudeness in the other direction.
double? topEdgeNudgeTarget({
  required double pixels,
  required double extentBefore,
  required double maxScrollExtent,
  required double viewportDimension,
  required bool hasMoreToReveal,
  required double slack,
  required double bumpFraction,
}) {
  // Not pinned: a correction landed, or the user simply is not at the edge.
  if (extentBefore > slack) return null;
  if (!hasMoreToReveal) return null;
  // A fling that hits the top leaves the lane in OVERSCROLL, so `pixels` is
  // negative — measured at −2, −49, −62, −72 and −77 px on a real device. The
  // bump is measured from the resting edge rather than from wherever the
  // bounce happened to be sampled, or an identical gesture travels a different
  // distance each time.
  final from = pixels < 0 ? 0.0 : pixels;
  // Keep a whole screen of transcript below the landing point, so the nudge
  // can never double as "jump to the newest message".
  final ceiling = maxScrollExtent - viewportDimension;
  if (ceiling <= from + 0.5) return null;
  final target = from + viewportDimension * bumpFraction;
  return target > ceiling ? ceiling : target;
}

// A `prependGrowthTarget` used to live here — "hold the viewport still by
// however much `maxScrollExtent` grew", as a fallback for when the row-anchored
// correction cannot be measured. It was removed on 2026-08-12 because the
// premise is false, and measuring it on a real signed-in device is what showed
// that.
//
// The premise was that rows are only added above, so growth in
// `maxScrollExtent` IS the height inserted above. But `ListView.builder`
// **estimates** its total extent from the children it has actually built, and
// that estimate is revised — in both directions — as more rows are laid out.
// Over one burst of fast flings on a long chat it read:
//
//   3617 → 7251 → 5494 → 9404 → 19802 → 12332 → 12125 → 26240 → 28428
//        → 19293 → 37380 → 29506 → 181096
//
// It shrinks as often as it grows. There is no way to separate "content was
// inserted above" from "the list re-guessed its own height", so the correction
// was applying re-estimation noise as a scroll offset. On the last step it
// computed a jump of **152,048 px** and threw the reader to the end of the
// conversation — the exact symptom reported ("sometimes it takes me all the way
// down to the end of the chat").
//
// The same capture showed the precise, row-anchored correction firing **zero**
// times under a fast fling: the anchor row is always culled by then. So the
// honest position is that there is no correction available in that case, and
// pretending otherwise is worse than admitting it. `topEdgeNudgeTarget` handles
// it instead — bounded by construction, and it cannot invent a number like that
// because it never reads a metric it does not trust.

/// Whether the retry affordance belongs at the head of the lane.
///
/// The answer is "only when a page actually failed", and the reason it lives
/// here rather than as an inline `&&` in the widget is that it has been got
/// wrong twice and is invisible in a screenshot of the working case.
///
/// It used to be shown whenever older history existed. On any long chat that
/// put "Load earlier messages" permanently at the top of the lane — an
/// invitation to trigger something the app was already doing automatically,
/// which users reasonably read as *the transcript stops here*. Paging is
/// automatic and pages ahead now, so the only moment there is anything for the
/// user to do is after a failure, when auto-loading has stood down rather than
/// hammer a failing endpoint.
///
/// [hasRenderedMessages] keeps it off an empty lane, where a retry pill would
/// be the only thing on screen.
bool showEarlierRetry({
  required bool isNewChat,
  required bool hasRenderedMessages,
  required bool lastAttemptFailed,
}) => !isNewChat && hasRenderedMessages && lastAttemptFailed;
