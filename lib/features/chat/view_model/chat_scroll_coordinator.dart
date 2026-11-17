import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_radius.dart';
import 'chat_reveal_window.dart';
import 'earlier_paging.dart';

/// The slice of `ChatCubit` the transcript's paging needs.
///
/// Narrow on purpose. The coordinator below is a state machine with six
/// interacting latches, and the only reason it was untestable was that
/// exercising it meant standing up a real cubit, a repository, a disk cache
/// and a 1.5 s poll timer to answer questions like "does a failed automatic
/// load stop the next scroll frame from asking again?".
///
/// Four members is the whole dependency. A fake is a dozen lines.
abstract interface class ChatPagingSource {
  /// Whether the server says there is history before the oldest loaded row.
  bool get hasMoreOlder;

  /// Whether the last cubit action left a failure on the state.
  ///
  /// Read straight after an awaited [loadOlder]: the cubit reports paging
  /// failures by emitting rather than throwing, so this is the only signal
  /// that the rows the window is about to reveal never arrived.
  bool get lastLoadFailed;

  Future<void> loadOlder({int? rows});

  Future<void> prefetchOlder({int? rows});
}

/// Where a conversation's lane was left.
///
/// ## Why the window is part of "where"
///
/// A scroll offset is a number of pixels into a rendered list, so it only
/// means anything against the list that produced it. Re-opening a chat
/// rebuilds its lane at [ChatRevealWindow.opening] — 50 rows — and a pixel
/// offset taken 200 rows deep, replayed against that, clamps to the far end
/// of the fresh window. Which is not where the user was, and worse, is the
/// one position that immediately triggers a page.
///
/// Measured on a live 2,917-message chat: leave at 30 August, come back, land
/// on 9 September with a fetch already in flight. So the window travels with
/// the offset, and the lane is rebuilt the size it was before the offset is
/// applied to it.
@immutable
class LanePlace {
  const LanePlace({required this.offset, required this.window});

  /// Pixels into history, or `null` for "was at the newest message".
  ///
  /// The null is meaningful and distinct from having no entry at all:
  /// re-entering a chat you were reading live should land on whatever has
  /// arrived since, not on the pixel the newest message used to occupy.
  final double? offset;

  /// How wide the lane was rendered. Restored first, so the offset lands in
  /// the same list it was measured in.
  final ChatRevealWindow window;
}

/// Everything the chat transcript does with its scroll offset.
///
/// ## Why this is not in the chat screen
///
/// These ~370 lines were fields and methods on `_ChatScreenState`, tangled
/// through it in both directions: six mutable latches near the top of the
/// class, their handlers 900 lines lower, and three of them poked directly
/// from inside `build`. Nothing tested any of it, because reaching the
/// interesting states meant driving a real `ListView` through a real cubit
/// with a real poll timer — so the parts that took the longest to get right
/// (the auto-load hysteresis, the short-viewport fill, and the restore
/// one-shot whose guards were once circular) were held in place by their
/// comments alone.
///
/// Gathered here they are what they always were: a small state machine over
/// a [ScrollController], with the whole of its input surface in the
/// constructor. It notifies when something the screen renders changes —
/// [showScrollDown], [autoLoadEarlierFailed], [window] — and stays silent
/// for the latches nothing draws.
///
/// It owns its [controller] and disposes it, so the screen no longer has a
/// listener to remember to remove.
class ChatScrollCoordinator extends ChangeNotifier {
  ChatScrollCoordinator({
    required this.conversationId,
    required this.isNewChat,
    required int Function() loadedVisibleCount,
    required ChatPagingSource Function() paging,
    required VoidCallback onLoadFailure,
  }) : _loadedVisibleCount = loadedVisibleCount,
       _paging = paging,
       _onLoadFailure = onLoadFailure {
    controller.addListener(_onScrollChanged);
    // Before the first build, so the opening frame renders the lane at the
    // width it had when the user left — which is what makes the saved offset
    // mean anything. See [LanePlace].
    final place = isNewChat ? null : _savedPlaces[conversationId];
    if (place != null) window = place.window;
  }

  /// Which conversation's offset this instance saves and restores.
  final String conversationId;

  /// New chats have no history to page and no offset worth remembering, so
  /// every entry point below short-circuits on it.
  final bool isNewChat;

  /// Count of currently-LOADED visible messages — the whole loaded snapshot,
  /// not the rendered window. The screen owns the memo behind this, because
  /// it is the same filter its message list renders from.
  final int Function() _loadedVisibleCount;

  /// Resolved per call rather than held, because the screen reads its cubit
  /// out of the widget tree and that lookup is only valid while mounted.
  final ChatPagingSource Function() _paging;

  /// Called when an awaited page comes back as a failure, so the screen can
  /// turn the cubit's failure into a message in the user's language.
  final VoidCallback _onLoadFailure;

  /// The transcript's controller. Owned here: created with the coordinator,
  /// disposed with it.
  final ScrollController controller = ScrollController();

  /// Where each conversation was left, kept for the process lifetime so
  /// re-opening a chat from the list lands where the user was reading.
  ///
  /// Static, so it survives the `State` being disposed on navigation. That is
  /// the right lifetime: it is a convenience, not persisted state.
  static final Map<String, LanePlace> _savedPlaces = {};

  /// How much of the loaded transcript the lane renders, and how that grows
  /// as the user pages back. The policy lives in [ChatRevealWindow]; this
  /// class only decides *when* to widen it.
  ChatRevealWindow window = const ChatRevealWindow.opening();

  /// Whether the "jump to newest" button should be on screen.
  bool showScrollDown = false;

  /// Set when an automatic load fails. Auto-loading then stands down and the
  /// header falls back to a tap-to-retry pill, so a chat that is offline or
  /// hitting a 500 does not re-request on every scroll frame forever. Cleared
  /// on the next successful load.
  bool autoLoadEarlierFailed = false;

  /// Guards [restoreIfNeeded] so the restore only fires on the first frame
  /// that has real content dimensions.
  bool hasRestoredScroll = false;

  /// Whether the user has taken control of the lane with a real drag.
  ///
  /// Until they do, the chat stays pinned to the newest message — see
  /// [pinToNewestIfUnscrolled]. Set from a drag start rather than from any
  /// scroll activity, because our own corrective `jumpTo`s are scroll
  /// activity too and would hand control away on the frame we opened.
  bool userHasScrolled = false;

  /// Re-entrancy guard for [loadEarlier].
  ///
  /// Scroll notifications arrive on essentially every frame of a drag, so
  /// without this a single upward flick would queue dozens of overlapping
  /// loads. Held until the post-frame follow-up has run, not just until the
  /// await returns — the frame in between is exactly when the list is at its
  /// shortest and would re-trigger.
  bool _loadingEarlier = false;

  /// Whether the scroll-driven trigger is allowed to fire. Cleared on each
  /// automatic load and re-armed only once the user leaves the trigger zone —
  /// see [_onScrollChanged] for why that hysteresis is load-bearing.
  bool _autoLoadArmed = true;

  /// Consecutive [fillViewportIfNotScrollable] passes. Bounded because that
  /// check consults `maxScrollExtent`, which on a lazy list is an estimate:
  /// if it reads zero for a frame after a page lands, the fill would ask for
  /// another. Reset once the list actually scrolls.
  int _viewportFillAttempts = 0;

  /// Stands in for the screen's `mounted` after an await. More accurate than
  /// `mounted` was: this object's life is exactly the window in which its
  /// state is worth mutating.
  bool _disposed = false;

  /// Mirror of the offset worth remembering, kept up to date from the scroll
  /// listener.
  ///
  /// ## Why a mirror rather than reading the position on the way out
  ///
  /// [persistOffset] is called from `dispose`, and **the position is already
  /// gone by then**. Flutter unmounts a subtree children-first, so the
  /// `Scrollable`'s own `State.dispose` — which detaches the position from
  /// this controller — runs before the owning screen's. `hasClients` is
  /// therefore `false` in the screen's `dispose`, and the read this class
  /// used to do there returned nothing, every time.
  ///
  /// Which means the feature the map exists for never worked: no offset was
  /// ever written, so every chat re-opened as though it had never been read.
  /// Nothing surfaced it, because the fallback for "nothing saved" is to
  /// land on the newest message, which is also the sane default.
  ///
  /// A mirror settles it without depending on unmount ordering at all: the
  /// value is computed while the lane is demonstrably alive — one nullable
  /// write per scroll frame — and `dispose` only has to copy it.
  double? _rememberedOffset;

  /// Whether [_rememberedOffset] has been computed from a live position yet.
  ///
  /// Distinct from a null [_rememberedOffset], which is the meaningful "was
  /// at the newest message" sentinel.
  bool _hasRememberedOffset = false;

  /// How close to the top of the transcript the user has to get before the
  /// next page starts loading, in logical pixels.
  ///
  /// Deliberately not zero: firing at the very top means the user watches a
  /// spinner. Firing ~600 px early means the rows are usually already in
  /// place by the time they get there, which is what makes the paging feel
  /// like it is not happening at all. Comfortably inside the list's 1500 px
  /// `cacheExtent`, so the revealed rows are built off-screen too.
  static const double autoLoadEarlierThreshold = 600;

  /// Distance into history, in logical pixels, past which the "jump to
  /// newest" button appears — about one screenful on a phone.
  static const double _scrollDownThreshold = 240;

  /// How close to the newest message still counts as "was reading the latest
  /// reply" when saving an offset.
  static const double _atNewestSlack = 32;

  /// The offset of the newest message.
  ///
  /// Zero, because the list is `reverse: true`. Named rather than written as
  /// a bare `0` at four call sites: in a forward list this was
  /// `position.maxScrollExtent`, which is an ESTIMATE while rows below the
  /// viewport are still unbuilt — animating to it landed short on a long
  /// transcript and needed a second pass. The reversed list has no such
  /// problem, and the name is what says so.
  static const double _newestOffset = 0;

  /// Ceiling on [fillViewportIfNotScrollable]. Raised from 3: a page is raw
  /// rows, and the visible yield per page can be low enough (see
  /// `ChatCubit._olderPageSize`) that three passes still left a lane too
  /// short to scroll — and therefore unable to ask for more.
  static const int _maxViewportFillAttempts = 6;

  /// Console tag for the upward-paging machinery. One tag so a tester can
  /// `logcat | grep ChatScroll` and see the whole decision chain.
  static const String _tag = 'ChatScroll';

  /// The live position, or `null` when the lane is not attached or has not
  /// been laid out yet.
  ///
  /// Every entry point below begins here. `hasClients` alone is not enough:
  /// a controller can be attached for a frame before its position has
  /// content dimensions, and reading `extentBefore` there throws. Six call
  /// sites used to repeat the pair of checks by hand.
  ScrollPosition? get _position {
    if (!controller.hasClients) return null;
    final position = controller.position;
    return position.hasContentDimensions ? position : null;
  }

  // ── Offset persistence ────────────────────────────────────────────────

  /// Snapshots the current scroll state so the next time the user opens this
  /// conversation we can land them where they were instead of at the bottom.
  /// Stores `null` when they were at the latest message — see [_savedOffsets]
  /// for why.
  void persistOffset() {
    if (isNewChat) return;
    // Prefer a live read; fall back to the mirror when the position has
    // already been torn down, which is the case on the `dispose` path.
    _sampleOffset();
    if (!_hasRememberedOffset) return;
    _savedPlaces[conversationId] = LanePlace(
      offset: _rememberedOffset,
      window: window,
    );
  }

  /// Recomputes [_rememberedOffset] if the lane is still attached.
  ///
  /// `reverse: true` puts the newest message at offset 0, so "was the user
  /// reading the latest reply?" is a question about `extentBefore` — how far
  /// back toward the newest they still are. Storing `null` for that case is
  /// what makes re-entry land on whatever has arrived since, rather than on
  /// a stale pixel offset that a newly arrived reply has already moved.
  void _sampleOffset() {
    final position = _position;
    if (position == null) return;
    _hasRememberedOffset = true;
    _rememberedOffset = position.extentBefore < _atNewestSlack
        ? null
        : position.pixels;
  }

  /// Jumps to the last-seen offset for this conversation (or to the latest
  /// message when there is nothing saved / the user left while pinned to
  /// bottom). One-shot: guarded by [hasRestoredScroll] so it only fires on
  /// the first frame after messages render — every subsequent poll / state
  /// emit is a no-op.
  void restoreIfNeeded() {
    if (hasRestoredScroll || isNewChat) return;
    final position = _position;
    if (position == null) return;
    if (position.maxScrollExtent <= 0) {
      // Nothing to restore on a lane that does not scroll — so the restore is
      // trivially DONE, and saying so matters. [loadEarlier] refuses to run
      // until this flag is set, and [fillViewportIfNotScrollable] only fires
      // when the lane cannot scroll. Returning early here made those two
      // guards circular: a short lane could not auto-load, so it stayed
      // short, so it never auto-loaded. Reproduced on a live 1,282-message
      // conversation whose most recent page was almost entirely `tool` rows —
      // the chat rendered ONE bubble and would not page back.
      hasRestoredScroll = true;
      return;
    }
    hasRestoredScroll = true;
    final saved = _savedPlaces[conversationId]?.offset;
    if (saved == null) {
      // The newest message — offset 0, because the list is `reverse: true`.
      //
      // This branch used to read `jumpTo(position.maxScrollExtent)`, which
      // was correct for the forward list it was written against and is the
      // exact opposite here: in a reversed lane `maxScrollExtent` is the
      // OLDEST loaded message. So the "nothing saved, so show them the
      // latest" path was throwing the reader to the far end of history.
      //
      // It was invisible because [pinToNewestIfUnscrolled] runs immediately
      // after in the same post-frame callback and snapped the lane back to 0
      // before anything was painted. What did survive was the cost: the jump
      // notified the scroll listener from `extentAfter == 0`, which fired an
      // automatic `loadEarlier` — so every chat open pulled a page of history
      // nobody asked for, on a guard ([hasRestoredScroll]) that had just been
      // set to `true` two lines above and so could not stop it.
      //
      // A reversed lane already rests at 0, hence the equality check: a
      // `jumpTo` to where we already are still notifies.
      if (position.pixels.abs() >= 1.0) controller.jumpTo(_newestOffset);
      return;
    }
    controller.jumpTo(saved.clamp(0.0, position.maxScrollExtent));
  }

  // ── Scroll handling ───────────────────────────────────────────────────

  void _onScrollChanged() {
    final position = _position;
    if (position == null) return;
    // Keep the "where were they reading" mirror current. The only place this
    // can be sampled from a live position is here — see [_rememberedOffset].
    _sampleOffset();
    // ── Everything below reads `extentBefore` / `extentAfter` ───────────
    //
    // The list is `reverse: true`, so offset 0 is the NEWEST message and
    // `extentBefore` is the distance back toward it. That makes the two
    // questions this handler asks read the same way they would in a forward
    // list, just against the other end:
    //
    //   * `extentBefore` — how far the user has travelled INTO history.
    //   * `extentAfter`  — how much loaded history is still ahead of them.
    //
    // Show the jump button once they are more than ~one screenful into
    // history.
    final shouldShow = position.extentBefore > _scrollDownThreshold;
    if (shouldShow != showScrollDown) {
      showScrollDown = shouldShow;
      notifyListeners();
    }

    // Infinite scroll into history: running out of loaded rows AHEAD pulls
    // the next page automatically. `extentAfter` is clamped at 0, so an
    // overscroll bounce at the far end reads as 0 rather than going negative
    // and skipping the check.
    //
    // Hysteresis, not a bare threshold. The trigger re-arms only once the
    // user has moved back out of the zone, which is the ordinary job of not
    // firing twice for one gesture.
    if (position.extentAfter > autoLoadEarlierThreshold * 2) {
      _autoLoadArmed = true;
      _viewportFillAttempts = 0;
    }
    if (_autoLoadArmed && position.extentAfter <= autoLoadEarlierThreshold) {
      _autoLoadArmed = false;
      unawaited(loadEarlier(auto: true));
    }

    // Top up the bank on approach, not only after a page lands.
    //
    // Refilling solely from the reveal has a hole: during one long
    // uninterrupted scroll the reveals are what drain the bank, and if a
    // reveal is itself waiting on a fetch, nothing asks for the page after
    // it. Watching the approach instead means the request goes out while the
    // user is still on their way. Cheap enough for a scroll frame — two
    // reads, and it no-ops while a page is in flight.
    if (position.extentAfter <= autoLoadEarlierThreshold * 4) {
      topUpPrefetch();
    }
  }

  /// Re-arms the automatic trigger because the user just asked again.
  ///
  /// The `extentAfter` rule in [_onScrollChanged] re-arms by *position*, and
  /// position alone has a dead end: once the list is resting at the far end
  /// of loaded history, it can never climb back over the re-arm line, so the
  /// latch stays down and further upward swipes do nothing at all. Verified
  /// on a live 816-message chat — the transcript stopped paging with "Load
  /// earlier messages" still showing, and six more swipes produced a
  /// pixel-identical screen.
  ///
  /// A drag start is the other half of the signal. It cannot run away the way
  /// a position-based re-arm inside the trigger zone would, because it fires
  /// once per gesture rather than once per scroll frame, and [_loadingEarlier]
  /// still collapses anything that overlaps an in-flight page.
  ///
  /// Deliberately does not notify: nothing in the tree is built from either
  /// flag, and a rebuild on the first frame of every drag would be a
  /// scroll-time cost for no visual change.
  void noteUserDrag() {
    _autoLoadArmed = true;
    // The user is driving now; stop holding the lane at the newest message.
    userHasScrolled = true;
  }

  /// Reveals the previous step of messages.
  ///
  /// Called automatically as the user scrolls toward the top ([auto] true),
  /// and from the header pill when a previous automatic attempt failed.
  ///
  /// Two-tier so it is instant AND reliable:
  ///   * If the loaded snapshot still has older messages we have not shown
  ///     yet, just grow the render window — instant, no network.
  ///   * Otherwise (window has caught up to everything loaded) pull more from
  ///     the server, then reveal the next step.
  Future<void> loadEarlier({bool auto = false}) async {
    if (isNewChat) return;

    final paging = _paging();
    final loadedBefore = _loadedVisibleCount();
    final shownBefore = window.shownOf(loadedBefore);
    // Every guard lives in `decideEarlierPage` so the scroll handler can call
    // this on any frame without the caller having to know the rules — see
    // that function for why they are kept out of the widget.
    final action = decideEarlierPage(
      automatic: auto,
      alreadyLoading: _loadingEarlier,
      scrollRestored: hasRestoredScroll,
      lastAttemptFailed: autoLoadEarlierFailed,
      shownCount: shownBefore,
      loadedCount: loadedBefore,
      hasMoreOlder: paging.hasMoreOlder,
    );
    // "Sometimes it does not load" is a decision taken from state that no
    // longer exists by the time anyone can ask about it.
    AppLogger.debug(
      _tag,
      'earlier? auto=$auto armed=$_autoLoadArmed loading=$_loadingEarlier '
      'shown=$shownBefore loaded=$loadedBefore '
      'more=${paging.hasMoreOlder} failed=$autoLoadEarlierFailed '
      '=> ${action.name}',
    );
    if (action == EarlierPageAction.none) return;

    _loadingEarlier = true;

    if (action == EarlierPageAction.fetchOlder) {
      await paging.loadOlder(rows: window.nextStep);
      if (_disposed) return;
      // Surface a failed fetch instead of silently widening the window over
      // messages that never arrived.
      if (paging.lastLoadFailed) {
        // Latch on ANY failure, including a manual retry. If a failed retry
        // cleared the flag the header would drop back to its spinner state
        // and the user would be left watching a load that is not running,
        // with no way to ask again.
        _loadingEarlier = false;
        autoLoadEarlierFailed = true;
        notifyListeners();
        _onLoadFailure();
        return;
      }
    }

    autoLoadEarlierFailed = false;

    // Reveal immediately — no measuring, no waiting for the scroll to settle.
    //
    // This is the payoff from `reverse: true` on the list. Older rows land at
    // HIGH indices, which is off-screen in the direction the user is already
    // travelling, so widening the window moves nothing they can see. Every
    // row currently on screen keeps the exact pixel it occupied.
    //
    // What this replaces: sample an anchor row's Y, wait for the momentum to
    // decay (a `jumpTo` mid-drag cancels the gesture), widen, re-measure the
    // anchor, `jumpTo` the difference — and, because a fast fling culls the
    // anchor row before any of that can run, a bounded "nudge" as a fallback
    // for the correction that could not be made. Five steps and two failure
    // modes, all of them to answer a question a reversed list never asks.
    window = window.revealedFrom(shownBefore);
    notifyListeners();
    _loadingEarlier = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      fillViewportIfNotScrollable();
      topUpPrefetch();
    });
  }

  /// Keeps roughly one page of un-rendered history in hand at all times.
  ///
  /// The cubit cannot decide this for itself: it knows how much is loaded but
  /// not how much has been revealed, and "loaded" alone would either fetch
  /// forever or never. This class holds both numbers, so it owns the decision
  /// and the cubit just does as it is told.
  ///
  /// Cheap to call on every reveal — `prefetchOlder` is a no-op while a page
  /// is in flight or once the start of the conversation is reached, so this
  /// settles by itself.
  void topUpPrefetch() {
    if (isNewChat) return;
    final paging = _paging();
    if (!paging.hasMoreOlder) return;
    if (!window.needsPrefetch(_loadedVisibleCount())) return;
    unawaited(paging.prefetchOlder(rows: window.nextStep));
  }

  /// Pulls another page when the rendered window does not fill the viewport.
  ///
  /// Ten short messages on a tall phone produce a list that cannot scroll —
  /// and a list that cannot scroll never emits a scroll notification, so
  /// [_onScrollChanged] would never fire and the user would be stranded with
  /// no way to reach older history. Terminates because each pass either grows
  /// the content (making it scrollable) or exhausts `hasMoreOlder`, which
  /// makes [loadEarlier] return immediately.
  void fillViewportIfNotScrollable() {
    final position = _position;
    if (position == null) return;
    if (position.maxScrollExtent > 0) return;
    if (_viewportFillAttempts >= _maxViewportFillAttempts) return;
    _viewportFillAttempts++;
    // Bypasses the `_autoLoadArmed` latch on purpose: a list that cannot
    // scroll emits no scroll notifications, so nothing would ever re-arm it.
    _autoLoadArmed = true;
    unawaited(loadEarlier(auto: true));
  }

  /// Holds the lane on the newest message while rows are still arriving.
  ///
  /// Nearly a no-op now, and kept for the one case that survives the flip to
  /// a reversed list. A reversed list RESTS at offset 0, so a chat opens on
  /// its newest message with no scrolling at all — the forward list needed a
  /// post-frame `jumpTo(maxScrollExtent)` here because `maxScrollExtent` grew
  /// as unbuilt rows below the viewport were laid out, and each growth left
  /// the user one screenful short of where they asked to be.
  ///
  /// What remains: a rebuild triggered while the list is at a tiny non-zero
  /// offset — a bounce settling, or a row above resizing as its markdown
  /// finishes laying out — can leave the lane a few pixels off the newest
  /// message. Snapping those back is invisible and keeps "I have not
  /// scrolled" meaning exactly what it says.
  ///
  /// Skipped when there is a saved offset: returning to a chat you had
  /// scrolled back through should land where you left it.
  void pinToNewestIfUnscrolled() {
    if (userHasScrolled || isNewChat) return;
    if (_savedPlaces[conversationId]?.offset != null) return;
    final position = _position;
    if (position == null) return;
    if (position.pixels.abs() < 1.0) return;
    controller.jumpTo(_newestOffset);
  }

  /// The post-frame work the transcript needs after any build that has rows.
  ///
  /// Called from `build` with the frame's row count. Was three separate
  /// post-frame calls and a `firstPass` local inlined in the message list,
  /// which is how the ordering between them — restore, then fill, then pin —
  /// ended up being documented in three places and enforced in none.
  void settleAfterBuild({required bool hasContent}) {
    if (!hasContent) return;
    if (hasRestoredScroll && userHasScrolled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final firstPass = !hasRestoredScroll;
      restoreIfNeeded();
      // And immediately check whether the lane is even long enough to
      // scroll. Without this the fill only ever ran as a follow-up to a page
      // the user had already triggered — so a chat that opened SHORT (a
      // recent window that is mostly `tool` rows renders as one or two
      // bubbles) had no scroll to give and no page to follow, and simply sat
      // there. Verified against a live 1,282-message conversation.
      if (firstPass) fillViewportIfNotScrollable();
      // The restore above is a one-shot against an estimated extent; this
      // keeps the lane on the newest message until the user drags.
      pinToNewestIfUnscrolled();
    });
  }

  // ── Jump to newest ────────────────────────────────────────────────────

  /// Animates to the newest message. The "jump to newest" button.
  void scrollToNewest() {
    if (!controller.hasClients) return;
    controller.animateTo(
      _newestOffset,
      duration: AppDurations.scrollToEnd,
      curve: Curves.easeOutQuart,
    );
  }

  /// Animates to the newest message once the frame that added a row has been
  /// laid out. Used after the user sends, where the row does not exist yet at
  /// the moment the send handler runs.
  void scrollToNewestSoft() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (!controller.hasClients) return;
      controller.animateTo(
        _newestOffset,
        duration: AppDurations.scrollToEndSoft,
        curve: Curves.easeOutQuart,
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // Save on the way out, while the position is still attached.
    persistOffset();
    controller
      ..removeListener(_onScrollChanged)
      ..dispose();
    super.dispose();
  }

  /// Drops every remembered place.
  ///
  /// Test-only: [_savedPlaces] is static and therefore leaks between test
  /// cases in one process, where a stale offset for `conv-1` would decide the
  /// outcome of an unrelated restore test.
  @visibleForTesting
  static void resetSavedOffsets() => _savedPlaces.clear();
}
