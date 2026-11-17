import 'package:flutter/foundation.dart';

/// How much of a loaded transcript the chat lane renders, and how that grows
/// as the user scrolls back through it.
///
/// **Why this is an object.** The rule is four numbers and three derivations
/// — an opening size, a step that doubles, a cap on the doubling, a prefetch
/// margin that tracks the step, and the slice itself. All of it used to live
/// as three `static const`s, two mutable fields and two getters scattered
/// among the forty-odd members of `_ChatScreenState`, with the slice
/// arithmetic (`all.sublist(all.length - limit)`) written out a third time at
/// the render site. Nothing there was wrong; it just could not be read in one
/// place, or exercised without pumping a chat screen.
///
/// It is pure and immutable, so the whole policy can be reasoned about — and
/// tested — as arithmetic, which is all it is.
///
/// **What the numbers mean**
///
/// The opening window is deliberately larger than the step. A chat used to
/// open on ten messages, which on a transcript where most rows are `tool`
/// rows is a screen and a bit: the user is already at the top and paging
/// before they have read anything. Opening on [openingRows] means the first
/// screenful is history, not a starting pistol. Growing it is cheap —
/// `ListView.builder` only builds what is near the viewport, so a wider
/// window costs the timeline pass over the extra rows and no extra layout.
///
/// A fixed step is wrong at both ends of a long transcript, and the two ends
/// want opposite things. Near the newest message the user is reading; a small
/// step is enough, and a large one is layout work for rows they will never
/// look at. Ten reveals deep they have stopped reading and started *looking
/// for* something, and a small step makes them do it fifty rows at a time. So
/// the step follows what the gesture means: 50, then 100, 200, 400 — someone
/// who keeps scrolling is telling us they want to go further.
///
/// [maxStepRows] caps the doubling. Past it the timeline pass — which IS
/// linear in the window — starts to cost more per reveal than the reveal
/// saves, and 400 rows is already several minutes of reading.
@immutable
class ChatRevealWindow {
  const ChatRevealWindow._({required this.limit, required this.revealCount});

  /// A freshly-opened chat: one wide window, nothing revealed yet.
  const ChatRevealWindow.opening() : limit = openingRows, revealCount = 0;

  /// Rows shown when a chat opens.
  static const int openingRows = 50;

  /// The first reveal's size. Every reveal after it doubles, up to
  /// [maxStepRows].
  static const int initialStepRows = 50;

  /// Ceiling on the doubling.
  static const int maxStepRows = 400;

  /// How many visible messages the lane currently renders. Display-only —
  /// the cubit holds every loaded message; this just windows them.
  final int limit;

  /// How many reveals have happened, which is what the step doubles on.
  final int revealCount;

  /// The size of the next reveal: 50, 100, 200, 400, 400, …
  int get nextStep {
    final step = initialStepRows * (1 << revealCount);
    return step > maxStepRows ? maxStepRows : step;
  }

  /// Refill the bank once fewer than this many loaded-but-unrevealed
  /// messages remain.
  ///
  /// Tracks the step rather than sitting at a fixed number, because the step
  /// no longer sits at one either. The rule is "keep the NEXT reveal in hand,
  /// twice over": a page takes seconds to arrive, and at one reveal of
  /// headroom a user scrolling briskly drains the bank faster than a single
  /// in-flight request refills it — the lane stops, which is the whole
  /// failure this exists to prevent. At two, the next request starts while
  /// there is still a reveal left to read, so the wait is spent reading.
  int get prefetchHeadroom => nextStep * 2;

  /// How many rows are actually on screen given [loadedCount] loaded ones.
  ///
  /// The window can be wider than the transcript — it opens at 50 rows over
  /// a chat that may hold three — so the honest answer is the smaller of the
  /// two. This is the number a reveal grows FROM: growing from [limit] when
  /// only three rows exist would jump the window to 53 and reveal nothing.
  int shownOf(int loadedCount) => loadedCount < limit ? loadedCount : limit;

  /// The rendered slice of [all]: its most recent [limit] entries.
  List<T> slice<T>(List<T> all) =>
      all.length <= limit ? all : all.sublist(all.length - limit);

  /// Whether another page should be pulled, given how much is loaded.
  bool needsPrefetch(int loadedCount) => loadedCount - limit < prefetchHeadroom;

  /// The window after one reveal, grown from what is currently on screen.
  ///
  /// Takes the shown count rather than reading [limit], for the reason
  /// [shownOf] gives: a window wider than the transcript must not compound.
  ChatRevealWindow revealedFrom(int shownCount) => ChatRevealWindow._(
    limit: shownCount + nextStep,
    revealCount: revealCount + 1,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatRevealWindow &&
      other.limit == limit &&
      other.revealCount == revealCount;

  @override
  int get hashCode => Object.hash(limit, revealCount);

  @override
  String toString() =>
      'ChatRevealWindow(limit: $limit, revealCount: $revealCount)';
}
