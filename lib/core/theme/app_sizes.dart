/// Every type size and icon size the app draws, named by the role it plays.
///
/// The third file in the same family as `AppColors`, `AppRadius` and
/// `AppDurations`, and it exists for the same reason they do: a number typed
/// at a call site is invisible to the design. It does not move when the scale
/// is re-tuned, it cannot be found by anyone grepping the token, and — the
/// part that actually reaches users — it cannot say whether *this* 10 is the
/// same decision as the 10 two widgets over, or a coincidence.
///
/// That is not hypothetical here. An audit on 2026-08-17 found 77 raw
/// `fontSize:` and 139 raw icon `size:` literals across 36 and 61 files. Below
/// `labelSmall` alone the type had drifted into **six** different sizes — 9,
/// 10, 10.5, 11, 11.5 and 12.5 — with no way to tell which badge was meant to
/// match which. Chips rendered a size apart from their neighbours on the same
/// row, and the icon ramp had filled in nearly every integer from 9 to 22,
/// which is what a scale looks like when nobody is choosing from one.
///
/// Neither ramp below is uniform, and that is deliberate: like [AppRadius],
/// these record what the design actually uses. Adding a value should mean the
/// design gained a surface, not that somebody needed a number.
///
/// `source_invariants_test.dart` enforces that no size literal is written at a
/// call site, so the choice keeps happening here.
library;

/// Type sizes.
///
/// The first stop for any screen is the `TextTheme` — `context.text.bodyMedium`
/// and friends — which is built from the ramp at the bottom of this class. A
/// screen that reaches for a named style never touches a number at all.
///
/// The rest exist for the second stop: the call sites that take a theme style
/// and nudge its size, `labelSmall?.copyWith(fontSize: …)`. Those nudges are
/// legitimate — a status pill really is smaller than a caption — but before
/// this class they were bare literals, which is how six sizes appeared below
/// `labelSmall` without anyone deciding on six.
class AppFontSizes {
  AppFontSizes._();

  // ── Micro scale ────────────────────────────────────────────────────────
  //
  // Everything here sits BELOW `labelSmall` (11). This is the band where the
  // drift was worst, because the differences are too small to notice one at a
  // time and very obvious once two land side by side.

  /// Uppercase status caps and count badges — the smallest type in the app.
  /// The chat header's RUNNING/AUTO chips, the artifact tile's kind badge,
  /// the attachment type stamp, the unread count bubble.
  static const double microCaps = 9;

  /// Chip and badge labels. The most-typed size in the app before this class
  /// existed, at 22 call sites.
  static const double chipLabel = 10;

  /// A dense meta line — the message footer's "You · 14:32", the command
  /// palette's section header.
  static const double metaLine = 10.5;

  /// Caption and secondary label. Same value as the theme's `labelSmall`,
  /// named separately because it is also reached for as an *override* on a
  /// larger style.
  static const double caption = 11;

  /// The secondary text inside a pill — the thinking pill's step count and
  /// duration, an empty-suggestion card's subtitle.
  static const double pillLabel = 11.5;

  /// Footnote and code plate. Same value as the theme's `labelMedium`.
  static const double footnote = 12;

  /// The primary text inside a pill — the thinking pill's title, a
  /// suggestion strip's label.
  static const double pillTitle = 12.5;

  // ── Body scale ─────────────────────────────────────────────────────────

  /// Compact body copy. Same value as the theme's `bodySmall`.
  static const double dense = 13;

  /// A suggestion card's title — one step above [dense] because it sits
  /// directly above [pillLabel] copy and needs to out-rank it.
  static const double cardTitle = 13.5;

  /// Body copy. Same value as the theme's `bodyMedium` / `labelLarge`.
  static const double body = 14;

  /// Sustained reading: the composer's input and rendered markdown body.
  /// Deliberately a step above [body] — this is the text a user reads for
  /// minutes rather than glances at.
  static const double reading = 15;

  // ── Avatar initials ────────────────────────────────────────────────────
  //
  // A letter inside a circle, not copy. It scales with the circle rather than
  // with the type ramp, which is why it is named apart from the headings that
  // happen to share its value.

  /// The conversation card's avatar.
  static const double avatarInitial = 18;

  /// The account screen's profile hero.
  static const double avatarInitialLarge = 24;

  // ── Rendered markdown ──────────────────────────────────────────────────
  //
  // Agent replies carry their own heading hierarchy, which has to stay
  // legible inside a chat bubble — so it is a compressed ramp of its own
  // rather than the screen-level `headline*` styles.

  static const double markdownH3 = 16;
  static const double markdownH2 = 17;
  static const double markdownH1 = 19;

  /// The crash screen's title. It renders when the app is already broken —
  /// possibly with no theme above it — so it names its own size rather than
  /// reading one from a `TextTheme` that may not exist.
  static const double crashTitle = 20;

  // ── The TextTheme ramp ─────────────────────────────────────────────────
  //
  // The sizes `AppTypography.scale` is built from (spec §2.2). Named here so
  // this file is the single home for "how big is text", rather than the ramp
  // living as literals in one file and every override as literals everywhere
  // else — which is the split that let the two drift apart.

  static const double displayLarge = 28;
  static const double displayMedium = 28;
  static const double displaySmall = 24;

  static const double headlineLarge = 22;
  static const double headlineMedium = 20;
  static const double headlineSmall = 18;

  static const double titleLarge = 16;
  static const double titleMedium = 15;
  static const double titleSmall = 14;

  static const double bodyLarge = 16;
  static const double bodyMedium = 14;
  static const double bodySmall = 13;

  static const double labelLarge = 14;
  static const double labelMedium = 12;
  static const double labelSmall = 11;

  /// Monospace plates — code blocks, inline code, command output.
  static const double mono = 12;
}

/// Icon sizes.
///
/// Grouped by what the glyph is *doing* rather than by how big it is, because
/// that is the question a call site is actually answering: is this a mark
/// inside a chip, the icon on a button, or the whole content of an empty
/// state?
class AppIconSizes {
  AppIconSizes._();

  // ── Marks inside another element ───────────────────────────────────────
  //
  // These are never tapped and never stand alone — they qualify the thing
  // they sit inside, so they are sized against its text rather than against
  // the touch grid.

  /// The lock stamped onto a project card's avatar.
  static const double overlay = 9;

  /// A meta glyph on a message footer or a detail row.
  static const double metaTight = 11;

  /// The meta-dot row's glyph and a chip's leading mark.
  static const double meta = 12;

  /// Dense list rows and suggestion chips.
  static const double dense = 13;

  /// Compact composer controls and inline label marks.
  static const double compact = 14;

  /// Inline warnings and banner marks.
  static const double inline = 15;

  // ── Standard UI glyphs ─────────────────────────────────────────────────

  /// The small inline icon: account link rows, plan feature ticks, chat
  /// header controls.
  static const double small = 16;

  /// The trial screen's muted list mark.
  static const double listMark = 17;

  /// The app's default inline icon, and its most common size at 33 call
  /// sites. When there is no reason to pick another, this is the one.
  static const double regular = 18;

  /// The page scaffold's notification bell — a hair larger than [regular]
  /// because it carries an unread dot that would otherwise crowd it.
  static const double bell = 19;

  /// Toolbar, dialog and drawer actions. Also the `AppBar` icon theme's size,
  /// so an explicit action icon matches the ones Flutter renders for free.
  static const double action = 20;

  /// The Apple mark on the social sign-in button. Fixed against Google's
  /// mark beside it, which is drawn by a painter at its own brand size.
  static const double socialLogo = 21;

  /// The home shell's nav bar, the voice button, and the global icon theme.
  static const double navBar = 22;

  /// The back chevron, and the rail drawer's section marks.
  static const double back = 24;

  // ── Feature glyphs: the icon IS the content ────────────────────────────
  //
  // Nothing below is decoration. Each one is the largest thing on its
  // surface and carries the meaning on its own, which is why the ramp gets
  // coarse here — these are never side by side, so near-neighbours would be
  // a distinction nobody can see.

  /// An attachment tile's file mark, and the empty-suggestion card.
  static const double tile = 26;

  /// The larger attachment previews.
  static const double tileLarge = 28;

  /// The crash screen's mark.
  static const double crash = 30;

  /// Empty states and dialog headers.
  static const double emptyState = 32;

  /// The approval and interactive card headers.
  static const double cardHeader = 34;

  /// The apps screen's server mark and the chat artifact tile.
  static const double feature = 44;

  /// A confirm dialog's hero glyph.
  static const double dialogHero = 46;

  /// The full-screen error state's mark — the largest glyph in the app,
  /// because it is the only thing on the screen.
  static const double errorHero = 56;

  // ── Glyphs inside a ColoredIconBox ─────────────────────────────────────
  //
  // `ColoredIconBox` draws a filled square with a glyph centred in it, and
  // that glyph is sized against the BOX — roughly half its width — rather
  // than against the text beside it. Naming them as their own sub-scale is
  // what keeps the pair in step: a box that grows without its glyph growing
  // reads as a misprint, and the two are set at different call sites.
  //
  // The ramp records one real inconsistency rather than hiding it: a 44 px
  // box carries a 22 glyph on the apps screen and a 20 on the chat artifact
  // tile. Both are preserved here because changing either is a visual
  // decision, not a refactor — but they are now two named constants a
  // designer can see, instead of two numbers nobody could compare.

  /// Inside the attachment chip's 28 px box.
  static const double boxGlyphSmall = 14;

  /// Inside a 28–32 px box — the empty-suggestion card, the rename dialog,
  /// the update nudge.
  static const double boxGlyphCompact = 16;

  /// Inside the 34 px box on an approval / interactive card header.
  static const double boxGlyphCard = 17;

  /// Inside the devices screen's platform box.
  static const double boxGlyphDevice = 19;

  /// Inside the chat artifact tile's 44 px box.
  static const double boxGlyphTile = 20;

  /// Inside a 44–46 px hero box — the apps screen, and every confirm dialog.
  static const double boxGlyphLarge = 22;

  /// Inside the full-screen error state's 56 px box.
  static const double boxGlyphHero = 26;
}

/// Fixed control diameters — the surfaces a finger lands on, and the
/// indicators that sit inside them.
///
/// These reach the user as *tap targets*, not as decoration, which is why
/// they are named apart from [AppIconSizes]: the glyph inside a button and the
/// button itself move for different reasons, and the one that matters for
/// accessibility is the button.
class AppControlSizes {
  AppControlSizes._();

  /// `AppIconButton`'s tap target. 44 is Apple's documented minimum, and the
  /// whole reason this is a fixed square rather than padding around an
  /// [AppIconSizes.regular] glyph.
  static const double iconButton = 44;

  /// The composer's send button.
  static const double sendButton = 42;

  /// `ColoredIconBox`'s default square.
  static const double iconBox = 38;

  // ── Progress spinners ──────────────────────────────────────────────────
  //
  // A `CircularProgressIndicator` has no intrinsic size — it fills whatever
  // box it is given — so every one of these is a `SizedBox` around it, and
  // every one was a pair of bare numbers.
  //
  // The ramp is denser than it should be: seven sizes for one control, across
  // ten files, at 14 / 15 / 16 / 18 / 20 / 22 / 34. Nobody chose seven. They
  // are preserved rather than collapsed because merging them is a visual
  // change, but they are named so the next person can see the spread at a
  // glance instead of having to grep for it.

  /// Inside a dense form row — the credential form's per-field check.
  static const double spinnerDense = 14;

  /// Inside a compact icon button — the billing history download.
  static const double spinnerTiny = 15;

  /// The inline spinner that replaces a button's label mid-request.
  static const double spinnerInline = 16;

  /// Inside a standard row action — the report builder.
  static const double spinnerSmall = 18;

  /// Inside a list row — the devices screen.
  static const double spinnerRow = 20;

  /// The most common one: an attachment upload, the voice button, a share
  /// destination, a credential test.
  static const double spinnerMedium = 22;

  /// A full-surface loading spinner.
  static const double spinner = 32;

  /// The trial screen's provisioning spinner — the only thing on its card.
  static const double spinnerHero = 34;

  /// The rounded square behind an empty state's glyph, in the chat rail's
  /// tabs. Sized against the glyph rather than a tap target — nothing here is
  /// tappable.
  static const double emptyGlyphBox = 56;

  /// A status dot — the pulse indicator and the typing animation's dots.
  static const double dot = 6;

  /// The unread/meta dot on a conversation row, a step down from [dot]
  /// because it sits inside a line of 11 px type rather than beside a label.
  static const double dotSmall = 5;

  /// The typing indicator inside a chat row, a step up from [dot] so it
  /// reads as motion at bubble scale.
  static const double dotLarge = 7;
}

/// Every gap and every inset the app lays out with.
///
/// ## Why this has two naming schemes
///
/// The seven t-shirt names at the bottom — [xs] … [xxxl] — are the **published
/// design scale**. They are what `design/export/tokens.json` ships to Figma as
/// `space/xs` … `space/xxxl`, and renaming or re-valuing one changes what the
/// designers see. They describe a 4 px grid: 4, 8, 12, 16, 20, 24, 32.
///
/// The `s`-prefixed steps are what the **code** uses, because a census on
/// 2026-08-17 found the app does not lay out on that grid. Of 1,127 spacing
/// literals, only 48% landed on a published step. The three most-used values in
/// the entire app — 14 (158 uses), 10 (125) and 6 (105) — have no name on the
/// 4 px scale at all, and 14 alone is used more often than 16 or 12.
///
/// So the two schemes record two different true things, and collapsing them
/// would mean lying about one of them: snapping 14 → 16 is a visual redesign
/// nobody asked for, and pretending the published scale covers the app is how
/// a design system stops describing the product. Naming both makes the gap
/// **visible and measurable** rather than leaving it as 1,127 anonymous
/// numbers — and closing it is now a designer's decision with a number
/// attached, not a refactor.
///
/// ## Reading the scale
///
/// `AppSpacing.s14` is 14 logical pixels. The name encodes the step because
/// spacing is the one axis where that is honest: unlike a colour or a radius,
/// the *value* is the meaning — a 14 px gap is not "the card gap", it is 14,
/// and the same 14 separates an icon from a label in one place and two rows in
/// another. Role names here would be fiction.
///
/// What the scale buys instead is a **closed set**. Off-grid values cannot be
/// added casually, they are all listed in one place, and
/// `source_invariants_test.dart` refuses a bare number at a call site.
class AppSpacing {
  AppSpacing._();

  // ── The 2 px grid the app actually lays out on ─────────────────────────

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s26 = 26;
  static const double s28 = 28;
  static const double s30 = 30;
  static const double s32 = 32;
  static const double s34 = 34;
  static const double s36 = 36;

  // ── Large gaps ─────────────────────────────────────────────────────────
  //
  // Coarser steps, because at this size a 2 px difference is not a decision
  // anyone can see. These are section breaks and scroll-tail padding, not
  // the space between two controls.

  static const double s42 = 42;
  static const double s48 = 48;
  static const double s52 = 52;
  static const double s56 = 56;
  static const double s64 = 64;
  static const double s80 = 80;

  // ── Off-grid ───────────────────────────────────────────────────────────
  //
  // Odd values, 42 uses in total. Every one of them is drift rather than a
  // decision: nothing in the design calls for a 3 px gap next to a 4 px one,
  // and at these sizes the difference is invisible — which is exactly why
  // they survived.
  //
  // They are named rather than left as literals so the guard can be absolute
  // and so this list stays an accurate inventory. Treat a new entry here as a
  // bug: the fix is to round to the neighbouring even step, and the only
  // reason that has not been done already is that it is a visual change and
  // therefore a designer's call, not a refactor's.

  static const double s1 = 1;
  static const double s3 = 3;
  static const double s5 = 5;
  static const double s7 = 7;
  static const double s9 = 9;
  static const double s11 = 11;
  static const double s13 = 13;
  static const double s15 = 15;
  static const double s19 = 19;

  // ── The published design scale ─────────────────────────────────────────
  //
  // Exported to Figma by `test/support/figma_tokens.dart` as `space/*`. Kept
  // as aliases onto the step scale so the two can never disagree about what
  // `space/md` is worth — before this they were separate literals, and the
  // export was the only thing in the repo that read them.

  static const double xs = s4;
  static const double sm = s8;
  static const double md = s12;
  static const double lg = s16;
  static const double xl = s20;
  static const double xxl = s24;
  static const double xxxl = s32;
}

/// Avatar diameters.
///
/// Separate from [AppIconSizes] because an avatar is a *surface* — it has a
/// fill, a border and a letter inside it — not a glyph. Sizing it from the
/// icon ramp would tie the two together, and they move for different reasons.
class AppAvatarSizes {
  AppAvatarSizes._();

  /// [UserAvatar]'s default, and the size every real screen renders it at.
  static const double small = 32;

  /// The storybook's medium sample.
  static const double medium = 48;

  /// The storybook's large sample.
  static const double large = 64;
}
