import 'package:flutter/material.dart';

/// Every corner radius the app draws, named by the role it plays.
///
/// Named by role rather than by size so a re-theme changes one line here
/// instead of a `BorderRadius.circular(10)` grep that cannot tell a tool card
/// from a code block from a header button. `source_invariants_test.dart`
/// enforces that no radius literal is written at a call site.
///
/// The scale below is deliberately not a uniform ramp — it records what the
/// design actually uses. Adding a value means the design gained a surface,
/// not that a developer needed a number.
class AppRadius {
  AppRadius._();

  // ── Structural surfaces ────────────────────────────────────────────────
  /// Square corners. The PDF thumbnail renders inside a parent that
  /// already clips, so rounding it again would double the corner and
  /// leave a hairline of background between the two curves.
  static const double none = 0;

  static const double card = 20;
  static const double button = 12;
  static const double pill = 999;
  static const double input = 14;
  static const double toast = 12;
  static const double modal = 18;
  static const double sheetTop = 28;
  static const double bubble = 16;
  static const double row = 12;

  // ── Nested surfaces ────────────────────────────────────────────────────
  //
  // These sit *inside* an already-rounded surface, so they step down from it:
  // a 10 px plate inside a 20 px card reads as concentric, a second 20 px
  // does not.

  /// Compact panels that carry their own background inside a card — tool
  /// activity rows, header icon buttons, fenced code blocks, the approval
  /// payload plate.
  static const double small = 10;

  /// Chips and inner plates one level deeper still — the suggestion chips,
  /// the credential form's copy plate.
  static const double tight = 8;

  /// The vault's dense metadata chips, where 8 already reads as too round for
  /// the type size.
  static const double micro = 6;

  // ── Component-specific ─────────────────────────────────────────────────
  //
  // One call site each. Named anyway: they are shape decisions the design
  // owns, and a bare literal at the call site is how a re-theme misses one.

  /// The attachment tile's file-type badge.
  static const double badge = 4;

  /// The multi-select checkbox — a hair rounder than a hard square.
  static const double checkbox = 7;

  /// Default for [ColoredIconBox]; between [small] and [button] because the
  /// box is square and reads rounder than a wide surface at the same radius.
  static const double iconBox = 11;

  /// The voice recorder's waveform bars — a stadium cap on a 4 px-wide bar.
  static const double waveformBar = 2;

  /// The home shell's floating nav bar.
  static const double navBar = 22;

  /// The auth screen's hero logo plate.
  static const double heroPlate = 26;

  /// The launch splash's logo plate — one step larger than [heroPlate]; the
  /// splash mark is drawn bigger.
  static const double splashPlate = 28;

  /// The conversation card in the Chats list. Deliberately softer than [row]
  /// so each conversation reads as a distinct card rather than a list row —
  /// design parity with the Chats mock.
  ///
  /// Shares a value with [bubble] today and is named separately anyway: they
  /// are two unrelated design decisions that happen to agree, and collapsing
  /// them would silently re-shape every chat bubble the day the Chats list is
  /// re-styled.
  static const double conversationCard = 16;

  /// The chat composer pill — the rounded box holding the text field and the
  /// action bar.
  static const double composer = 20;

  /// The three rounded corners of a user's chat bubble. See [bubbleCut] for
  /// the fourth.
  static const double bubbleCorner = 14;

  /// The user bubble's signature cut corner — the top-inline-end one. It is a
  /// brand mark, not a radius: it is what makes a Saqqar bubble recognisable
  /// at a glance, which is exactly why it must not drift.
  static const double bubbleCut = 4;

  /// A floating card dialog — the vault's project list and project detail.
  ///
  /// Differs from [modal] (18), which `AppTheme.dialogTheme` applies to every
  /// `AlertDialog`. Both call sites had typed `20` inline with no stated
  /// reason, so the divergence is recorded rather than silently "corrected":
  /// changing it is a design decision, and naming it here is what makes that
  /// decision available to make. `AppCardDialog` is the only consumer.
  static const double cardDialog = 20;

  // ── Convenience BorderRadius constants ─────────────────────────────────
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonR = BorderRadius.all(Radius.circular(button));
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius inputR = BorderRadius.all(Radius.circular(input));
  static const BorderRadius toastR = BorderRadius.all(Radius.circular(toast));
  static const BorderRadius modalR = BorderRadius.all(Radius.circular(modal));
  static const BorderRadius bubbleR = BorderRadius.all(Radius.circular(bubble));
  static const BorderRadius rowR = BorderRadius.all(Radius.circular(row));
  static const BorderRadius smallR = BorderRadius.all(Radius.circular(small));
  static const BorderRadius tightR = BorderRadius.all(Radius.circular(tight));
  static const BorderRadius microR = BorderRadius.all(Radius.circular(micro));
  static const BorderRadius badgeR = BorderRadius.all(Radius.circular(badge));
  static const BorderRadius checkboxR = BorderRadius.all(
    Radius.circular(checkbox),
  );
  static const BorderRadius waveformBarR = BorderRadius.all(
    Radius.circular(waveformBar),
  );
  static const BorderRadius navBarR = BorderRadius.all(Radius.circular(navBar));
  static const BorderRadius heroPlateR = BorderRadius.all(
    Radius.circular(heroPlate),
  );
  static const BorderRadius splashPlateR = BorderRadius.all(
    Radius.circular(splashPlate),
  );

  static const BorderRadius sheetTopR = BorderRadius.only(
    topLeft: Radius.circular(sheetTop),
    topRight: Radius.circular(sheetTop),
  );

  static const BorderRadius conversationCardR = BorderRadius.all(
    Radius.circular(conversationCard),
  );
  static const BorderRadius composerR = BorderRadius.all(
    Radius.circular(composer),
  );
  static const BorderRadius cardDialogR = BorderRadius.all(
    Radius.circular(cardDialog),
  );

  /// The user chat bubble, cut corner and all.
  ///
  /// Directional so the cut lands on the *inline* end — top-right in English,
  /// top-left in Arabic. A `BorderRadius` here would put the cut on the wrong
  /// corner in RTL, which is the whole reason the shape is declared once
  /// instead of re-typed per surface: `message_bubble.dart` and
  /// `shared_transcript_screen.dart` had both spelled these four corners out
  /// by hand, comment included, so the brand mark was maintained in two
  /// places and the shared transcript was one edit away from disagreeing with
  /// the chat it was a transcript of.
  static const BorderRadiusDirectional userBubbleR =
      BorderRadiusDirectional.only(
        topStart: Radius.circular(bubbleCorner),
        topEnd: Radius.circular(bubbleCut),
        bottomStart: Radius.circular(bubbleCorner),
        bottomEnd: Radius.circular(bubbleCorner),
      );

  /// The 4 px accent rail down the inline-start edge of a chat card, rounded
  /// to sit flush inside the card's own [bubble] corner.
  ///
  /// Shared by the approval card (warning) and the interactive card shell
  /// (cyan) — see `AccentRail`, which owns the whole strip.
  static const BorderRadiusDirectional accentRailR =
      BorderRadiusDirectional.horizontal(start: Radius.circular(bubble));
}

class AppDurations {
  AppDurations._();

  /// The app's micro-transition: a control changing state in place — a chevron
  /// rotating, a panel cross-fading, a button sliding in or out.
  ///
  /// Named because it was written out twelve times across six files, which
  /// makes it a design decision maintained by search-and-replace. Anything
  /// with its own reason to be slower or faster keeps its own literal —
  /// naming those after this one would be a false claim that they move
  /// together.
  static const Duration fast = Duration(milliseconds: 180);

  // Animation timings from §12 of the spec.
  static const Duration cardIn = Duration(milliseconds: 220);
  static const Duration menuIn = Duration(milliseconds: 150);
  static const Duration toastIn = Duration(milliseconds: 250);
  static const Duration listFadeIn = Duration(milliseconds: 400);
  static const Duration pulseDot = Duration(seconds: 2);
  static const Duration scanLine = Duration(milliseconds: 2600);
  static const Duration cursorBlink = Duration(milliseconds: 900);
  static const Duration thinkingDots = Duration(seconds: 1);
  static const Duration themeTransition = Duration(milliseconds: 300);

  // ── Roles that had drifted back to literals ─────────────────────────
  //
  // `cardIn` (220 ms) alone was re-typed at ten call sites across nine
  // files, and 160/200/280 each at two or more. That is the same failure
  // the radius tokens above were extracted to stop: a re-theme has to grep
  // for numbers, and a number cannot say whether this 200 is a control
  // settling or a card arriving — so half of them get changed and half
  // don't. Each name below is the *role*, never the size.
  //
  // Deliberately NOT here: request timeouts, poll cadences and prefetch
  // gaps. Those are already named `static const` beside the code that owns
  // them, and they are policy, not motion — they don't move when the design
  // system re-times its animations, and pulling them into a shared class
  // would imply that they do.

  /// A control settling in place — a chip filling, a row highlighting.
  /// Faster than [cardIn]: nothing is entering, only changing.
  static const Duration control = Duration(milliseconds: 160);

  /// A panel expanding or collapsing to its content height.
  static const Duration expand = Duration(milliseconds: 200);

  /// A sheet or overlay sliding in — the longest of the entrances, because
  /// it travels the furthest.
  static const Duration sheetIn = Duration(milliseconds: 280);

  /// The page-to-page route transition, and its faster reverse. Popping
  /// reads as instant when it matches the push, so it is deliberately
  /// shorter — the destination is already familiar.
  static const Duration routeIn = Duration(milliseconds: 260);
  static const Duration routeOut = Duration(milliseconds: 200);

  /// One breath of the "agent is working" pulse — the app-bar pill and the
  /// tab-bar dot, which sit on screen together and must breathe in step.
  static const Duration agentPulse = Duration(milliseconds: 1400);

  /// A widget cross-fading to a different child in place.
  static const Duration switcherIn = Duration(milliseconds: 240);

  /// The shimmer sweep across a skeleton placeholder.
  static const Duration skeletonSweep = Duration(milliseconds: 1200);

  /// How long a toast stays on screen. Errors get longer because they carry
  /// something the user has to act on, and often a retry action to reach.
  ///
  /// Both live here rather than inside `AppToast` because callers override
  /// the dwell — `pricing_screen` had re-typed the 5 s, so the error dwell
  /// was already maintained in two places.
  static const Duration toastDwell = Duration(seconds: 3);

  /// Longest the launch splash waits for the session check.
  static const Duration splashMax = Duration(seconds: 4);
  static const Duration toastDwellError = Duration(seconds: 5);

  // ── One-per-surface timings ─────────────────────────────────────────
  //
  // Each of these is used once. They are named anyway, for the same reason
  // the radii are: the next person to re-time the app needs to know which
  // number belongs to which motion without opening every file, and a
  // comment beside a literal is only visible to whoever is already in that
  // file. Naming them does NOT claim they move together — they are listed
  // apart from the shared roles above precisely so that stays clear.

  /// Chat jumping to the newest message on demand. Longer than [cardIn]:
  /// it travels the whole viewport and needs to read as a journey, not a
  /// cut, or the user cannot tell whether the list moved or reloaded.
  static const Duration scrollToEnd = Duration(milliseconds: 420);

  /// The same trip taken automatically after a new message lands. Shorter,
  /// because the user did not ask for it and should not be made to wait.
  static const Duration scrollToEndSoft = Duration(milliseconds: 360);

  /// Conversations returning to the top of the list. Longer than the motion
  /// baseline so the trip registers before the new rows take attention.
  static const Duration scrollToTop = Duration(milliseconds: 380);

  /// A slow in-out breath: the composer's idle pulse and the typing dots.
  static const Duration breathe = Duration(milliseconds: 1100);

  /// The empty Conversations screen's glow. The slowest loop in the app —
  /// it marks a resting state, so anything quicker reads as activity.
  static const Duration breathingGlow = Duration(milliseconds: 2200);

  /// The mic button's pulse while a voice note is recording.
  static const Duration recordingPulse = Duration(milliseconds: 900);

  /// One waveform bar re-heighting. Near-instant on purpose: the bars track
  /// live amplitude, so any easing at all would smear the level.
  static const Duration waveformBar = Duration(milliseconds: 80);

  /// The splash wordmark's zoom-in. It starts at ~25 % of final size, which
  /// needs room to grow or the entrance feels rushed.
  static const Duration splashEntrance = Duration(milliseconds: 1600);
}
