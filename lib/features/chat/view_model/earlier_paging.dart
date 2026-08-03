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
}) =>
    !isNewChat && hasRenderedMessages && lastAttemptFailed;
