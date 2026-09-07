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

  /// Every `AppBar` in the app. Four dp taller than Material's default 56 so
  /// an [iconButton]-sized action clears the bar's own padding without the
  /// bar growing under it — at 56 the 44 dp target had 6 dp a side, which is
  /// what made trailing actions look crowded against the title.
  ///
  /// Set once on the theme rather than per screen; it is named here because
  /// it is the one control size that was still a literal, and a bar height
  /// that drifts is a bar that stops lining up with the screens' own
  /// leading padding.
  static const double appBar = 60;

  /// The composer's send button.
  static const double sendButton = 42;

  /// `ColoredIconBox`'s default square.
  static const double iconBox = 38;

  /// One metric tile in an app-pulse card's `Wrap` (Task 1,
  /// MOBILE_TASKS_2026-09.md) — wide enough for a 3-digit `StatTile` value
  /// and its two-line label without `Expanded`, which a `Wrap` cannot give
  /// it: unlike the fixed-column stat rows elsewhere (`stats_line.dart`,
  /// billing), a pulse card's tile count varies per kind and must wrap to a
  /// second line on a narrow phone instead of squeezing every tile into one.
  static const double pulseStatTile = 84;

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

  /// The track thickness of a `LinearProgressIndicator` — the blocking
  /// progress dialog's bar. Set on both the wrapping `SizedBox` and the
  /// indicator's own `minHeight`, which is why it is one name rather than
  /// two literals that could drift apart.
  static const double progressBarThickness = 2.5;

  /// A `LinearProgressIndicator` used as a *meter* rather than as an
  /// indeterminate bar — a run's progress, a plan's quota. Thicker than
  /// [progressBarThickness] because the user is meant to read a value off
  /// it, not just see that something is happening.
  static const double meterThin = 4;
  static const double meterThick = 7;

  /// The minimum height of a dense row's tap target — a filter chip, a
  /// sheet's list row, a ghost button. Below the 44 px [iconButton]
  /// minimum because these are wide targets: the row spans the sheet, so
  /// the finger has far more than 44 px to land in horizontally.
  static const double rowMin = 36;

  /// The minimum height of a standard button.
  static const double buttonMin = 40;

  /// The minimum height of a social sign-in button, which carries a
  /// provider mark beside its label and needs the extra room.
  static const double socialButtonMin = 48;

  /// The minimum box a count badge is allowed to shrink to. Square at
  /// [badgeMin]; [badgeMinWide] is the same badge once it holds two
  /// digits and has to grow along one axis only.
  static const double badgeMin = 16;
  static const double badgeMinWide = 18;

  /// A vertical hairline rule between two inline stats.
  static const double verticalRuleShort = 22;

  /// A vertical hairline rule between two columns of a billing row.
  static const double verticalRule = 34;

  /// A bottom sheet's drag handle. Always this pair — a handle that is
  /// not [dragHandleWidth] × [dragHandleHeight] reads as a divider.
  static const double dragHandleWidth = 64;
  static const double dragHandleHeight = 3;

  // ── One-off control dimensions ─────────────────────────────────────────
  //
  // Each of these belongs to exactly one widget. They are named anyway,
  // because "88" sitting in a `SizedBox` tells the next reader nothing
  // about whether it may be changed, and the comment that explained it
  // was three lines above the number.

  /// A 4 px dot in the voice-support transcript's speaker column.
  static const double dotTiny = 4;

  /// One bar of the voice recorder's live waveform, and the range its
  /// height animates across.
  static const double waveformBarWidth = 3;
  static const double waveformBarMin = 4;
  static const double waveformBarMax = 20;

  /// The waveform strip's own height.
  static const double waveformHeight = 22;

  /// The composer's attachment strip: a [AppBoxSizes.thumbnail] chip, plus
  /// the top inset the remove `×` hangs into, plus slack so nothing clips
  /// against the viewport.
  static const double attachmentStripHeight = 88;

  /// The composer's Task-prep toggle track.
  static const double toggleWidth = 26;
  static const double toggleHeight = 14;

  /// A chat header control's row.
  static const double headerControlHeight = 40;

  /// The avatar slot beside a typing indicator — narrower than a real
  /// avatar so the wordmark hugs the bubble's start edge.
  static const double typingAvatarSlot = 50;

  /// The conversations empty state's CTA, sized so the glow behind it
  /// stays centred on the button rather than the column.
  static const double emptyStateCtaWidth = 220;

  /// The label column of a trial screen's credential row.
  static const double trialLabelWidth = 78;

  /// A `PageScaffold` app bar.
  /// The chat screen's app bar, two pixels taller than [appBarHeight]
  /// because it carries a two-line title (conversation name + status).
  static const double chatToolbarHeight = 64;

  static const double appBarHeight = 62;

  /// The icon slot in a bottom-nav destination — fixed so the label below
  /// it sits on the same baseline whichever glyph is drawn.
  static const double navIconSlot = 24;

  /// The apps screen's pinned horizontal filter strip.
  static const double filterStripHeight = 52;

  /// The typing-dots spinner that replaces a primary button's label.
  static const double buttonSpinnerWidth = 28;
  static const double buttonSpinnerHeight = 18;

  /// A pill-shaped action row inside the project detail sheet.
  static const double pillRowHeight = 36;

  /// An unread-count badge's height. Its width is driven by
  /// [badgeMinWide] plus the digits.
  static const double badgeHeight = 18;

  /// An attachment chip's inline image preview, and the placeholder shown
  /// when that image fails to decode — the same height so a failed load
  /// does not reflow the strip.
  static const double attachmentPreviewHeight = 120;

  /// The splash screen's indeterminate progress track.
  static const double splashProgressWidth = 160;
  static const double splashProgressHeight = 3;
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

  /// No spacing. Not a step on the grid — it is the ABSENCE of one, and
  /// it is named so `titleSpacing: 0` reads as a decision rather than as a
  /// number nobody got round to setting.
  static const double zero = 0;

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

/// Stroke thickness for the arc of a `CircularProgressIndicator`.
///
/// Paired with [AppControlSizes]' spinner diameters: the arc has to thicken
/// as the circle grows or a large spinner reads as a hairline ring. Flutter
/// defaults to 4.0, which is far too heavy at the 14–22 px this app spins
/// at, so every call site overrode it — with five different numbers.
class AppStrokeWidths {
  AppStrokeWidths._();

  /// Inside the composer's send button, the smallest spinner that replaces
  /// a glyph rather than a label.
  static const double spinnerHairline = 1.8;

  /// Inside a button or chip whose label the spinner replaces.
  static const double spinnerThin = 2;

  /// The voice button's recording ring.
  static const double spinnerSnug = 2.2;

  /// The default: full-surface and row-level loading states.
  static const double spinnerRegular = 2.4;

  /// The two hero spinners — an app launching, a trial provisioning.
  static const double spinnerThick = 2.6;
}

/// Material `elevation` values.
///
/// The design system is flat: surfaces are separated by borders and
/// translucency, not by drop shadows, so [none] is what almost everything
/// takes and the two non-zero values below are the deliberate exceptions.
class AppElevations {
  AppElevations._();

  /// Flat. App bars, sheets, dialogs, toasts, buttons — the default
  /// everywhere, set explicitly because Material's own defaults are not 0.
  static const double none = 0;

  /// The composer's send affordance — just enough to lift it off the
  /// input row it sits on.
  static const double raised = 1;

  /// Popup menus.
  static const double menu = 6;

  /// Navigation drawers, which slide over content and need a real edge.
  static const double drawer = 8;
}

/// `BoxShadow` geometry — blur and spread radii.
///
/// Shadow *colour* lives on the theme extension (it differs per brightness);
/// only the geometry is here, because a shadow's softness is a fixed
/// property of the surface class regardless of whether it is rendered dark
/// or light.
class AppShadowSizes {
  AppShadowSizes._();

  /// The inner highlight along a glass card's top edge.
  static const double blurHairline = 3;

  /// A brand-coloured glow behind a small round control — the voice
  /// button's record halo, the composer's focus ring at rest.
  static const double blurGlow = 6;

  /// A tab bar's own shadow onto the content behind it.
  static const double blurSubtle = 8;

  /// The scroll-to-bottom button.
  static const double blurButton = 14;

  /// The conversations empty state's pulsing halo, at rest.
  static const double blurPulseBase = 18;

  /// The new-conversation FAB.
  static const double blurFab = 22;

  /// The most common card shadow — glass cards, toasts, the home shell's
  /// nav bar.
  static const double blurCard = 24;

  /// A bottom sheet.
  static const double blurSheet = 28;

  /// A modal dialog, and the splash screen's logo halo.
  static const double blurModal = 30;

  /// The deepest shadow in the app — a full-screen modal over content.
  static const double blurDeep = 36;

  /// The Gaussian sigma a `GlassCard`'s `BackdropFilter` blurs the content
  /// behind it by. Not a `BoxShadow` radius — this one blurs what is
  /// *underneath* the surface rather than casting a shadow from it.
  static const double glassBlurSigma = 14;

  // ── Drop distance ──────────────────────────────────────────────────────
  //
  // How far below a surface its shadow falls — the `dy` of a `BoxShadow`'s
  // `Offset`. This is shadow geometry exactly like `blurRadius` above, and it
  // was the one part of it with no named scale: the guard that keeps shadows
  // off bare numbers spells out `blurRadius`, `spreadRadius`, `sigmaX` and
  // `sigmaY`, so `offset:` slipped past it and eleven call sites accumulated.
  //
  // These are a ladder of drops rather than one drop per `blur*` role,
  // because the app does not actually pair them one-to-one: `blurModal`
  // casts at both [dropFab] and [dropModal], and `blurCard` at both
  // [dropCard] and [dropFab]. Naming them after the blur would have meant
  // either a lie in the doc or a silent change to four surfaces' shadows, so
  // they are named for the depth they read as. If the pairing is ever
  // regularised, that is a design decision to make deliberately — not a
  // side effect of giving these numbers names.

  /// Barely displaced — an inner edge highlight sitting on its own surface.
  static const double dropHairline = 1;

  /// A small round control: the scroll-to-bottom button's shadow.
  static const double dropControl = 6;

  /// The most common drop — glass cards, toasts, raised sheets.
  static const double dropCard = 8;

  /// A floating surface: the new-conversation FAB, the home shell's nav bar.
  static const double dropFab = 10;

  /// The splash logo's halo.
  static const double dropHalo = 14;

  /// The deepest drop in the app — a full-screen modal over content.
  static const double dropDeep = 16;

  /// Spread on a focus ring at rest.
  static const double spreadHairline = 0.5;

  /// Spread on a tab bar's shadow, and the empty state's halo at rest.
  static const double spreadThin = 1;

  // ── Animated ranges ────────────────────────────────────────────────────
  //
  // Added to the resting value above as an animation drives `t` from 0 → 1.
  // Named separately from the base so a glow's *travel* can be tuned
  // without moving where it starts.

  /// How far [blurGlow] grows as the composer takes focus.
  static const double blurGlowRange = 6;

  /// How far [spreadHairline] grows as the composer takes focus.
  static const double spreadGlowRange = 1.5;

  /// How far [blurPulseBase] grows across the empty state's pulse.
  static const double blurPulseRange = 10;

  /// How far [spreadThin] grows across the empty state's pulse.
  static const double spreadPulseRange = 2;
}

/// Stroke widths for borders and rules.
///
/// Distinct from [AppStrokeWidths], which is the arc of a spinner: these are
/// *edges* — the line around a card, the rule between two rows, the ring
/// around a selected avatar. A spinner's stroke scales with its diameter; a
/// border's does not, it scales with how much the edge is meant to assert
/// itself.
///
/// `Divider` is included here even though its `height` is nominally a layout
/// dimension: this app always sets `height` and `thickness` to the same
/// value, because it wants a rule with no padding around it. Naming them
/// once is what keeps the pair from drifting.
class AppBorderWidths {
  AppBorderWidths._();

  /// Thinner than a hairline — the skeleton block's edge, which only has to
  /// suggest a recessed corner, not draw one.
  static const double subHairline = 0.6;

  /// The default border, and every divider's thickness. Anything that just
  /// needs an edge uses this.
  static const double hairline = 1;

  /// An input or button that has taken focus, and the send button at rest.
  static const double medium = 1.4;

  /// An avatar's ring where it overlaps the surface behind it, sized so the
  /// ring reads as a cut-out rather than a stroke.
  static const double thick = 1.5;

  /// A selection ring — a chosen conversation, a selected project.
  static const double ring = 2;

  /// The ring on an avatar with unread activity, one step up from [ring] so
  /// it survives against the avatar's own fill.
  static const double ringThick = 2.5;

  /// A vertical accent bar — a markdown blockquote's start edge, an
  /// unread conversation's leading stripe, a dialog's gradient hairline.
  static const double accentBar = 3;
}

/// Letter tracking, in logical pixels.
///
/// Tracking in this app is not decorative — it is what makes an uppercase
/// micro-label legible. Small caps set at 9–11 px close up into a solid
/// block without it, so every eyebrow, status pill and section header
/// carries a positive value, and the amount scales *inversely* with the
/// font size: the smaller the caps, the wider the tracking.
///
/// Before this class these were 54 bare literals across 36 files, spread
/// over fifteen distinct values. Nobody chose fifteen — they accumulated
/// one screen at a time, and two labels that were meant to match (the chat
/// app bar's status and the tools sheet's header) only agreed by accident.
/// They are preserved rather than collapsed because merging them is a
/// visual change; naming them makes the spread visible so the next person
/// can collapse it deliberately.
class AppLetterSpacing {
  AppLetterSpacing._();

  /// No tracking. The explicit default on the text theme's headings and on
  /// [AppTypography.eyebrow] / [AppTypography.statusPill], which set their
  /// tracking at the call site instead.
  static const double none = 0;

  /// Barely-there tracking on a meta dot's separator line.
  static const double hairline = 0.1;

  /// Sentence-case labels that sit under a heading — the nav bar's tab
  /// captions, a message bubble's meta line, a tool card's status.
  static const double tight = 0.2;

  /// Sentence-case labels on a coloured ground, where the fill eats a
  /// little of the counters — the swipe-to-archive backgrounds.
  static const double snug = 0.3;

  /// The workhorse label tracking: attachment chips, sheet headers, the
  /// notifications inbox.
  static const double label = 0.4;

  /// Wordmark and hero-caption tracking — the logo lockup, the profile
  /// hero, a shared transcript's byline.
  static const double wide = 0.5;

  /// Uppercase labels at body size — the auth screen's legal line, a
  /// conversation card's badge.
  static const double caps = 0.6;

  /// Uppercase labels at caption size — the chat app bar's status, an
  /// artifact tile's format badge, the tools sheet header.
  static const double capsWide = 0.8;

  /// Uppercase micro-caps at 10–11 px — artifact pills, date separators,
  /// the environment multi-select header.
  static const double microCaps = 1.0;

  /// Micro-caps at 10 px inside a drawer or detail sheet, where the
  /// surrounding surface is denser.
  static const double microCapsWide = 1.2;

  /// The widest tracking in the app — 9 px section headers inside the
  /// vault's project sheets.
  static const double microCapsWidest = 1.4;

  // ── Optical tightening ─────────────────────────────────────────────────
  //
  // Headings run the ramp the other way: the larger the type, the more air
  // there already is between the letters, so the tracking goes *negative*
  // to close it back up. The four values below are picked against the
  // text-theme role they sit on — pairing one with a different size is what
  // makes a heading look loose or cramped.

  /// `titleSmall` (14 px) — an approval card's title, an interactive
  /// card's header.
  static const double title = -0.1;

  /// `titleLarge` / `titleMedium` (15–16 px) — the app bar title, dialog
  /// headings, sheet headers. The most common of the four.
  static const double heading = -0.2;

  /// `headlineSmall` (18 px) — an empty chat's title.
  static const double displaySmall = -0.3;

  /// `headlineMedium` (20 px) — the conversations empty state, the largest
  /// heading the app sets.
  static const double display = -0.4;
}

/// Text line height, as a multiple of the font size (Flutter's
/// `TextStyle.height`).
///
/// The ramp is deliberately steep at the top: display type is set nearly
/// flush so a two-line screen title does not open a gap that reads as two
/// separate headings, while running prose sits at [body] so Arabic
/// diacritics and English descenders both clear.
///
/// Arabic is the reason the lower half of this ramp exists at all. IBM Plex
/// Sans Arabic carries taller ascenders than Space Grotesk, so a value
/// chosen against English alone clips in Arabic — anything rendering both
/// scripts uses [reading] or [body], never [flush].
class AppLineHeights {
  AppLineHeights._();

  /// Flush — no leading at all. Single-line lockups only (the wordmark, a
  /// one-line hero count) where a second line is impossible by
  /// construction.
  static const double flush = 1.0;

  /// Two-line display type — a conversation card's title, a stat tile's
  /// value, a page scaffold's heading.
  static const double displayTight = 1.1;

  /// Display type that may wrap to a second line in Arabic — the profile
  /// hero's name, the chat app bar's title.
  static const double display = 1.15;

  /// Headings and multi-line button labels.
  static const double heading = 1.2;

  /// Headings on a dense surface, where the extra quarter-line separates
  /// the title from the subtitle beneath it.
  static const double headingLoose = 1.25;

  /// A tool sheet's one-line description.
  static const double snug = 1.3;

  /// Secondary copy under a heading — captions, helper text.
  static const double label = 1.35;

  /// Dense list subtitles and metadata lines.
  static const double compact = 1.4;

  /// Long-form secondary copy — `bodySmall`, markdown paragraphs, the
  /// monospace plate.
  static const double reading = 1.45;

  /// Running prose — `bodyLarge` / `bodyMedium`, chat messages, anything
  /// the user actually reads a paragraph of.
  static const double body = 1.5;

  /// The loosest leading in the app — the voice-support screen's
  /// transcript, which is read aloud as often as it is read on screen and
  /// needs the extra air to stay scannable mid-sentence.
  static const double loose = 1.6;
}

/// Opacity levels, as the `alpha` passed to `Color.withValues`.
///
/// ## Why this exists
///
/// Almost no colour in this app is used at full strength. The palette is a
/// handful of brand hues, and every tinted fill, every border on a coloured
/// surface, every scrim and every de-emphasised label is one of those hues
/// at some fraction. That made opacity the single largest source of bare
/// numbers in the codebase: 170 literals across 72 files, at 31 distinct
/// values — including 0.2 and 0.20, and 0.4 and 0.40, which are the same
/// level written two ways and were therefore invisible to any grep that
/// tried to count them.
///
/// ## The bands
///
/// The values are not arbitrary; they cluster by what they are *for*, and
/// the bands barely overlap:
///
/// | Band            | Range       | What it does                        |
/// |-----------------|-------------|-------------------------------------|
/// | Gradient wash   | 0 – 0.08    | A hue bled into a background        |
/// | Tinted fill     | 0.05 – 0.20 | The body of a chip, icon box, card  |
/// | Border          | 0.22 – 0.45 | The edge of a tinted surface        |
/// | Scrim           | 0.25 / 0.55 | A modal barrier over content        |
/// | De-emphasis     | 0.60 – 0.85 | Secondary text, a disabled glyph    |
/// | Chrome          | 0.88 – 0.98 | A nav bar over scrolling content    |
///
/// ## Why the names carry the number
///
/// Forty levels cannot be given orderable adjectives — nobody can say
/// whether "faint" sits above or below "subtle". So the step scale below
/// keeps the value in the name, exactly as [AppSpacing] does for the same
/// reason, and the semantic aliases at the bottom name the handful of
/// levels that carry a real role. Reach for an alias when one fits; fall
/// back to the step when it does not.
///
/// For a level that has to differ between light and dark mode, use
/// [AppAlphaPairs] — never an inline isDark ternary.
class AppAlphas {
  AppAlphas._();

  // ── The step scale ─────────────────────────────────────────────────────

  /// Fully transparent — the far end of a fading gradient.
  static const double a0 = 0;

  static const double a04 = 0.04;
  static const double a05 = 0.05;
  static const double a06 = 0.06;
  static const double a07 = 0.07;
  static const double a08 = 0.08;
  static const double a09 = 0.09;
  static const double a10 = 0.10;
  static const double a12 = 0.12;
  static const double a14 = 0.14;
  static const double a16 = 0.16;
  static const double a18 = 0.18;
  static const double a20 = 0.20;
  static const double a22 = 0.22;
  static const double a25 = 0.25;
  static const double a26 = 0.26;
  static const double a28 = 0.28;
  static const double a30 = 0.30;
  static const double a32 = 0.32;
  static const double a34 = 0.34;
  static const double a35 = 0.35;
  static const double a36 = 0.36;
  static const double a40 = 0.40;
  static const double a45 = 0.45;
  static const double a50 = 0.50;
  static const double a55 = 0.55;
  static const double a60 = 0.60;
  static const double a62 = 0.62;
  static const double a65 = 0.65;
  static const double a70 = 0.70;
  static const double a75 = 0.75;
  static const double a80 = 0.80;
  static const double a82 = 0.82;
  static const double a85 = 0.85;
  static const double a86 = 0.86;
  static const double a88 = 0.88;
  static const double a90 = 0.90;
  static const double a92 = 0.92;
  static const double a94 = 0.94;
  static const double a95 = 0.95;
  static const double a96 = 0.96;
  static const double a98 = 0.98;

  // ── Semantic aliases ───────────────────────────────────────────────────
  //
  // Aliases onto the steps above, never separate literals, so the two can
  // never disagree about what a "fill" is worth.

  /// A brand hue bled into a background gradient.
  static const double wash = a06;

  /// The lightest tinted fill — a skeleton block, a hover ground.
  static const double fillFaint = a08;

  /// The workhorse tinted fill: chips, icon boxes, tinted cards.
  static const double fill = a12;

  /// A tinted fill that has to hold its own against a busy surface.
  static const double fillStrong = a18;

  /// The edge of a tinted surface.
  static const double border = a30;

  /// The edge of a tinted surface that carries state — a selected chip, a
  /// destructive confirmation.
  static const double borderStrong = a45;

  /// The barrier behind a small confirmation dialog, which should still
  /// show the screen it interrupted.
  static const double scrimLight = a25;

  /// The barrier behind a full modal.
  static const double scrim = a55;

  /// A drop shadow's colour.
  static const double shadow = a35;

  /// Secondary text and disabled glyphs — present, but clearly not the
  /// thing you are meant to read first.
  static const double deemphasis = a70;
}

/// A dark/light pair of opacity levels.
///
/// Resolve with `context.alpha(pair)` (see `context_extensions.dart`), not
/// by reading [dark] / [light] at the call site — the point of the type is
/// that the brightness check happens in exactly one place.
class AlphaPair {
  const AlphaPair({required this.dark, required this.light});

  /// The level used when the app is in dark mode.
  final double dark;

  /// The level used when the app is in light mode.
  final double light;

  double resolve({required bool isDark}) => isDark ? dark : light;

  @override
  bool operator ==(Object other) =>
      other is AlphaPair && other.dark == dark && other.light == light;

  @override
  int get hashCode => Object.hash(dark, light);
}

/// Opacity levels that differ between light and dark mode.
///
/// ## Why a pair type rather than two constants
///
/// A translucent surface cannot use one alpha in both themes. Over a
/// near-black background 55 % reads as a panel; over white the same 55 %
/// reads as a smudge, and it takes ~90 % to look like the same material.
/// So every glass surface in the app carried its own inline
/// "isDark ? 0.55 : 0.9" ternary — 54 of them across 46 files.
///
/// ## The drift this exposed
///
/// Those 54 ternaries spelled **29 distinct pairs**, and 31 of the 54 were
/// the same thing: a translucent panel over content. That one role was
/// written twelve different ways — 0.50/0.85 ten times, then 0.55/0.92,
/// 0.55/0.90 and 0.55/0.86 three times each, 0.55/0.85, 0.62/0.92,
/// 0.62/0.88 and 0.45/0.85 twice each, and 0.65/0.92, 0.62/0.95,
/// 0.62/0.86 and 0.55/0.82 once each.
///
/// That is not twelve decisions. It is one decision made twelve times by
/// people who could not see the other eleven. Nothing could have caught
/// it: a ternary is invisible to a grep for an alpha followed by a digit,
/// which is exactly why [AppAlphas]' own sweep of 170 literals missed
/// every one of these.
///
/// The values are **preserved, not collapsed** — merging them is a visual
/// change and belongs in a deliberate design pass, not in a rename. Naming
/// them is what makes that pass a one-file edit instead of an audit. This
/// is the same call [AppControlSizes] made for its seven spinner sizes.
class AppAlphaPairs {
  AppAlphaPairs._();

  // ── Translucent panels (31 of the 54 sites) ────────────────────────────

  /// The most common panel by a wide margin: a sheet row, a drawer item, a
  /// detail-sheet section.
  static const panel = AlphaPair(dark: AppAlphas.a50, light: AppAlphas.a85);

  /// A ghost button's ground, and the auth screen's card.
  static const panelSoft =
      AlphaPair(dark: AppAlphas.a45, light: AppAlphas.a85);

  /// The auth header's action bar.
  static const panelMuted =
      AlphaPair(dark: AppAlphas.a55, light: AppAlphas.a82);

  /// A suggestion strip, a conversations list row.
  static const panelPlain =
      AlphaPair(dark: AppAlphas.a55, light: AppAlphas.a85);

  /// A filter pill, a tool activity card, a message-bubble skeleton.
  static const panelDense =
      AlphaPair(dark: AppAlphas.a55, light: AppAlphas.a86);

  /// An email preview, an interactive card shell, the voice-support card.
  static const panelCard =
      AlphaPair(dark: AppAlphas.a55, light: AppAlphas.a90);

  /// A chat header control, a run-progress card, a date separator's chip.
  static const panelSheet =
      AlphaPair(dark: AppAlphas.a55, light: AppAlphas.a92);

  /// The search-and-filters bar.
  static const panelStrong =
      AlphaPair(dark: AppAlphas.a62, light: AppAlphas.a86);

  /// A conversation-card / credential-row skeleton's ground.
  static const panelSkeleton =
      AlphaPair(dark: AppAlphas.a62, light: AppAlphas.a88);

  /// An accent card's chrome, and a project-card skeleton.
  static const panelOpaque =
      AlphaPair(dark: AppAlphas.a62, light: AppAlphas.a92);

  /// The chat header's own background.
  static const panelHeader =
      AlphaPair(dark: AppAlphas.a62, light: AppAlphas.a95);

  /// A chat date separator's rule.
  static const panelSeparator =
      AlphaPair(dark: AppAlphas.a65, light: AppAlphas.a92);

  // ── Near-opaque chrome ─────────────────────────────────────────────────

  /// The bottom nav bar and the scroll-to-bottom button — chrome that sits
  /// over scrolling content and must stay legible against any of it.
  static const chrome = AlphaPair(dark: AppAlphas.a94, light: AppAlphas.a98);

  /// A screen's app bar.
  static const appBar = AlphaPair(dark: AppAlphas.a88, light: AppAlphas.a96);

  // ── Brand / status tints ───────────────────────────────────────────────
  //
  // These run the opposite way to the panels: the tint is *stronger* in
  // dark mode, because a 10 % cyan wash that reads clearly on white
  // disappears entirely on near-black.

  /// An offline/online banner, a profile hero's ring, a quoted message.
  static const tint = AlphaPair(dark: AppAlphas.a18, light: AppAlphas.a10);

  /// A profile hero's avatar ground.
  static const tintAvatar =
      AlphaPair(dark: AppAlphas.a18, light: AppAlphas.a16);

  /// A selected filter pill.
  static const tintPill = AlphaPair(dark: AppAlphas.a16, light: AppAlphas.a12);

  /// The update-available nudge banner.
  static const tintBanner =
      AlphaPair(dark: AppAlphas.a16, light: AppAlphas.a09);

  /// The active bottom-nav destination.
  static const tintNav = AlphaPair(dark: AppAlphas.a14, light: AppAlphas.a10);

  /// A thinking pill's accent ground.
  static const tintFaint =
      AlphaPair(dark: AppAlphas.a10, light: AppAlphas.a08);

  /// An artifact pill's ground.
  static const tintFaintest =
      AlphaPair(dark: AppAlphas.a10, light: AppAlphas.a06);

  // ── Glows and shadows ──────────────────────────────────────────────────

  /// The scroll-to-bottom button's drop shadow.
  static const glow = AlphaPair(dark: AppAlphas.a30, light: AppAlphas.a10);

  /// The bottom nav bar's shadow onto the content behind it.
  static const glowNav = AlphaPair(dark: AppAlphas.a32, light: AppAlphas.a06);

  /// The splash screen's logo halo.
  static const splashShadow =
      AlphaPair(dark: AppAlphas.a35, light: AppAlphas.a05);

  // ── Inputs ─────────────────────────────────────────────────────────────

  /// A text field's fill at rest.
  static const field = AlphaPair(dark: AppAlphas.a20, light: AppAlphas.a14);

  /// A text field's fill once focused.
  static const fieldFocused =
      AlphaPair(dark: AppAlphas.a22, light: AppAlphas.a16);

  // ── Splash ─────────────────────────────────────────────────────────────

  /// The splash wordmark's plate.
  static const splashFill =
      AlphaPair(dark: AppAlphas.a45, light: AppAlphas.a55);

  /// The splash plate's border.
  static const splashBorder =
      AlphaPair(dark: AppAlphas.a80, light: AppAlphas.a90);
}

/// Maximum content widths — the caps that stop a layout from stretching
/// edge-to-edge on a tablet or a foldable's outer screen.
///
/// These are the other half of the responsive story from `Breakpoint` and
/// `BreakpointWidths`: a breakpoint says *which* layout to build, a cap
/// says how wide that layout is allowed to get once it is built. A screen
/// with neither will look correct on a phone and wrong on anything larger —
/// a 1200 px-wide line of body text is unreadable no matter how well the
/// breakpoints are chosen.
///
/// Every value here was a bare literal at a `ConstrainedBox` or
/// `ResponsiveContent` call site. The chat's reading column appeared six
/// times and its chrome three, which is exactly the kind of repetition that
/// drifts: one of the six moving to 780 would have gone unnoticed.
class AppLayoutWidths {
  AppLayoutWidths._();

  /// A truncating title inside the chat app bar — capped so a long
  /// conversation name cannot push the bar's actions off the row.
  static const double titleCap = 220;

  /// An attachment chip's label, and the rename dialog's field.
  static const double chipCap = 360;

  /// A toast. Narrow enough that it still reads as an overlay on a tablet
  /// rather than a full-width banner.
  static const double toast = 420;

  /// The auth screen's card — the sign-in form never widens past a
  /// comfortable single-column form.
  static const double authCard = 440;

  /// The crash / fatal-error screen's card.
  static const double errorCard = 480;

  /// A shared transcript's header block.
  static const double transcriptHeader = 560;

  /// A shared transcript's message column.
  static const double transcript = 720;

  /// **The chat's reading column.** Every message, card and separator is
  /// capped to this so a line of Arabic or English prose stays inside a
  /// comfortable measure on a tablet. The most-used cap in the app.
  static const double chatColumn = 760;

  /// The default cap for a standard screen's content — `ResponsiveContent`
  /// and `SaqqarScreen` both centre on this.
  static const double screen = 920;

  /// The chat's *chrome* — composer, header controls, suggestion strip.
  /// Deliberately wider than [chatColumn] so the composer and the header
  /// frame the message column rather than lining up flush with it.
  static const double chatShell = 980;

  /// The sidebar/rail drawer's absolute width cap — paired with
  /// [AppFractions.drawer] (a `min(86% of screen, this)` cap) so the drawer
  /// reads as a slide-in panel on a tablet instead of covering the screen.
  static const double drawerCap = 320;
}

/// Square surfaces that are not tap targets and not avatars.
///
/// Three classes divide this space and the split is deliberate:
///
///   * [AppControlSizes] — a surface a finger lands on. Sized by
///     accessibility minimums, never by the glyph inside it.
///   * [AppAvatarSizes] — a person or a project's identity circle.
///   * **This class** — the tinted rounded square *behind* a glyph, a
///     thumbnail, a status badge, a hero mark. Sized by the artwork it
///     frames, so it moves when the glyph does.
///
/// Every value here was a `width: N, height: N` pair at a `Container`, and
/// the pairs are the reason it needs naming: [sheetRow] appeared five times
/// across five different sheets, each as two separate literals, so a
/// mismatched pair — a 34 x 36 box — was a single typo away and nothing
/// would have caught it.
class AppBoxSizes {
  AppBoxSizes._();

  /// A bare status dot inside a pill or a scaffold's header.
  static const double dot = 8;

  /// A recording indicator, and the composer's inline state dot.
  static const double dotLarge = 10;

  /// A tiny count badge on a project card.
  static const double badge = 12;

  /// A conversation row's presence dot, sized to sit on the avatar's edge.
  static const double presenceDot = 13;

  /// A mini glyph box inside a dense card row.
  static const double glyphMini = 16;

  /// A small icon slot — a stats divider's neighbour, a social provider's
  /// mark, a composer affordance.
  static const double glyphSmall = 22;

  /// A checkbox / radio square in a multi-select sheet.
  static const double selector = 24;

  /// A composer action's tinted ground.
  static const double composerAction = 26;

  /// A compact icon box — an account link row, a chat command row.
  static const double glyphCompact = 30;

  /// A share destination's app mark.
  static const double destinationMark = 32;

  /// **The standard sheet-row icon box.** Attachment source, tools,
  /// conversation actions, message actions, account card header — five
  /// sheets, one size.
  static const double sheetRow = 34;

  /// A header control's ground, one step up from [sheetRow] so it holds
  /// against a busier bar.
  static const double headerControl = 36;

  /// A drawer's rail button and the scroll-to-bottom affordance.
  static const double railButton = 40;

  /// A project card's leading tile.
  static const double cardTile = 42;

  /// A conversation avatar's outer ring — the avatar plus its border.
  static const double avatarRing = 46;

  /// A project card's hero tile.
  static const double cardTileLarge = 48;

  /// An empty-chat suggestion's glyph ground.
  static const double suggestionGlyph = 54;

  /// The attachment viewer's file-kind mark.
  static const double fileKind = 56;

  /// The profile hero's avatar, inside its ring.
  static const double profileAvatar = 58;

  /// The crash screen's glyph ground.
  static const double errorGlyph = 64;

  /// The profile hero's avatar ring — [profileAvatar] plus its border.
  static const double profileAvatarRing = 68;

  /// An attachment thumbnail — the image preview, the PDF first page, and
  /// the generic file mark all render at this size so a mixed strip lines
  /// up.
  static const double thumbnail = 72;

  /// A hero mark on a full-screen state — update required, app lock, the
  /// conversations empty state.
  static const double hero = 76;
}

/// The logo lockup's rendered height.
///
/// `SaqqarLogo` takes a height and derives its width from the artwork's
/// aspect ratio, so this is the only dimension any call site sets — and it
/// was a different bare number at each of the seven places the lockup
/// appears. The mark reads as the same brand only if the sizes form a
/// deliberate ramp rather than seven independent guesses.
class AppLogoSizes {
  AppLogoSizes._();

  /// Inline in an assistant message's byline.
  static const double inline = 14;

  /// Inside a conversation row's avatar slot.
  static const double avatar = 15;

  /// A screen's app bar when the lockup replaces the title outright — the
  /// `SaqqarLogo` default, and therefore the size any call site that does
  /// not name one gets.
  static const double navBar = 22;

  /// A drawer header.
  static const double drawer = 24;

  /// A screen's app bar.
  static const double appBar = 27;

  /// A full-screen state's header — app lock, update required.
  static const double screen = 34;

  /// The auth screen's hero lockup, the largest the mark is drawn.
  static const double hero = 40;
}

/// Min / max heights for the sheets and dialogs that size themselves
/// against their content.
///
/// A sheet with no minimum collapses to its content and reads as a popup;
/// one with no maximum grows past the screen and traps its own scroll. Both
/// bounds have to be set, which is why they are named in pairs here — the
/// pairs used to be four bare numbers in two files and there was nothing to
/// stop a `minHeight` from being raised past its `maxHeight`.
class AppSheetHeights {
  AppSheetHeights._();

  /// The projects list sheet.
  static const double projectsListMin = 380;
  static const double projectsListMax = 560;

  /// The project detail sheet, which carries more rows than the list.
  static const double projectDetailMin = 420;
  static const double projectDetailMax = 640;

  /// An approval card's collapsible payload — the JSON diff the user is
  /// being asked to approve. Capped so a large payload scrolls inside the
  /// card instead of pushing the Approve button off screen.
  static const double approvalPayloadMax = 132;

  /// A report builder's record list.
  static const double reportRecordsMax = 220;

  /// An attachment chip's expanded image preview.
  static const double attachmentPreviewMax = 240;

  /// An artifact details sheet's body.
  static const double artifactDetailsMax = 340;
}

/// The shapes a loading skeleton draws.
///
/// A skeleton is a lie about content that has not arrived yet, and the lie
/// only works if the shapes match what will replace them: a 14 px bar where
/// a title will land, an 11 px bar where a subtitle will. Get the ramp
/// wrong and the screen visibly reflows the moment real data arrives, which
/// is worse than showing nothing.
///
/// That is why these are named rather than left as bare numbers next to the
/// real ones: [titleLine] has to track `AppFontSizes.body`, and nothing
/// links them except this comment and a person remembering to change both.
class AppSkeletonSizes {
  AppSkeletonSizes._();

  // ── Line heights ───────────────────────────────────────────────────────

  /// A meta chip's bar — a timestamp, a count.
  static const double chipLine = 10;

  /// A subtitle or preview bar.
  static const double subtitleLine = 11;

  /// A body bar inside a card.
  static const double bodyLine = 12;

  /// A dense secondary bar in the vault's project rows.
  static const double denseLine = 13;

  /// A title bar. `SkeletonBlock`'s default, and the one that has to stay
  /// in step with `AppFontSizes.body`.
  static const double titleLine = 14;

  /// A tag bar in the credential rows.
  static const double tagLine = 16;

  /// A square action placeholder in a project card's header.
  static const double actionSquare = 18;

  // ── Widths ─────────────────────────────────────────────────────────────

  /// A short meta chip.
  static const double chipShort = 50;

  /// A meta chip.
  static const double chip = 70;

  /// A wide meta chip.
  static const double chipWide = 80;

  /// A short subtitle.
  static const double subtitleShort = 90;

  /// A subtitle.
  static const double subtitle = 110;

  /// A title.
  static const double title = 140;

  /// A long title.
  static const double titleLong = 160;

  /// A short preview line.
  static const double previewShort = 180;

  /// A preview line.
  static const double preview = 200;

  /// A full-width preview line.
  static const double previewLong = 220;

  // ── Squares ────────────────────────────────────────────────────────────

  /// A project card's leading tile placeholder.
  static const double tile = 30;

  /// A message bubble's avatar placeholder.
  static const double avatarSmall = 32;

  /// A project card's icon placeholder.
  static const double tileLarge = 34;

  /// A conversation row's / credential row's avatar placeholder.
  static const double avatar = 44;

  // ── Card heights ───────────────────────────────────────────────────────

  /// The account screen's short (button-height) card placeholder.
  static const double cardShort = 48;

  /// A standard card placeholder.
  static const double card = 140;

  /// A taller card placeholder.
  static const double cardTall = 160;

  /// The account screen's tallest card placeholder.
  static const double cardHero = 220;

  /// Below this a `_SkeletonCard` cannot fit its three-bar layout and
  /// renders a single fill block instead.
  static const double cardCompactCutoff = 80;

  // ── Chat bubbles ───────────────────────────────────────────────────────
  //
  // Six placeholder bubbles alternating user / assistant, at varying
  // widths so the list reads like a real conversation in shape rather
  // than a stack of identical rectangles.

  static const double bubbleShort = 180;
  static const double bubbleMedium = 200;
  static const double bubbleRegular = 220;
  static const double bubbleWide = 240;
  static const double bubbleWider = 260;
  static const double bubbleWidest = 280;
}

/// Scroll-performance tuning.
///
/// Not a design token — nothing here reaches the user as a visual. It is
/// here because the alternative is a bare `1500` repeated in six list
/// builders, where the only thing telling the next reader that all six are
/// the *same* decision is that they happen to be equal.
class AppScrollTuning {
  AppScrollTuning._();

  /// How far beyond the viewport a list keeps children alive, in logical
  /// pixels.
  ///
  /// Flutter's default is 250 — roughly one row — which means a fast flick
  /// rebuilds every row it passes and a scroll back up rebuilds them all
  /// again. 1500 is about six rows in either direction: enough that an
  /// ordinary flick lands on already-built children, and small enough that
  /// a long conversation does not hold its whole history in the tree.
  ///
  /// Applied to every long list in the app — the chat timeline, the
  /// conversations list, both drawers, the projects sheet — because a
  /// value that is right for one of them is right for all of them.
  static const double cacheExtent = 1500;
}

/// Fractions of the screen (or of a parent) that a sheet or a row occupies.
///
/// Kept apart from the pixel scales because they do not behave like sizes:
/// 0.7 means "seven tenths of whatever this lands in", so it cannot be
/// re-tuned against a device width and it does not belong on a grid.
class AppFractions {
  AppFractions._();

  /// The projects list sheet's share of the screen height, before its
  /// `AppSheetHeights` bounds clamp it.
  static const double projectsListSheet = 0.6;

  /// The project detail sheet's share, likewise clamped.
  static const double projectDetailSheet = 0.7;

  /// A `DraggableScrollableSheet`'s resting, minimum and maximum extents —
  /// the chat's in-conversation search.
  static const double searchSheetInitial = 0.7;
  static const double searchSheetMin = 0.4;
  static const double searchSheetMax = 0.92;

  /// The sidebar/rail drawer's share of screen width, before
  /// [AppLayoutWidths.drawerCap] clamps it on a wide screen.
  static const double drawer = 0.86;

  /// A `TitleTrailingRow`'s default trailing share — just under half, so a
  /// title always keeps the larger half of the row.
  static const double trailingHalf = 0.45;

  /// The most of a `TitleTrailingRow` a trailing widget may claim before
  /// the title starts truncating instead.
  static const double trailingMax = 0.6;

  /// A bottom sheet's share of the screen height — the chat sheets, the
  /// conversation actions sheet.
  static const double sheet = 0.85;

  /// The environment detail sheet, which is taller than the rest.
  static const double sheetTall = 0.92;

  /// The splash wordmark's share of the screen width, and the tagline's.
  static const double splashWordmark = 0.82;
  static const double splashTagline = 0.60;

  /// The radius of the ambient background's radial gradient, as a fraction
  /// of the shorter side.
  static const double ambientGlowRadius = 0.7;
}

/// How far a widget travels as it animates into place.
///
/// Distance, not duration — `AppDurations` says how long a transition takes,
/// this says how much ground it covers. Kept out of [AppSpacing] because a
/// travel distance is not a gap: nothing is laid out at these values, they
/// only exist between the first frame of an entrance and its last, and
/// re-tuning one has no effect on the resting layout.
///
/// Small on purpose. Every entrance in this app is a *rise* — content slides
/// up a few dp as it fades in — so the whole scale is a choice between
/// "barely" and "noticeably", and a third value would be a distinction the
/// eye cannot make.
class AppMotionTravel {
  AppMotionTravel._();

  /// A card rising into a list it is joining mid-scroll — approval cards
  /// arriving on a poll tick. Shorter than [rise] so a card that appears
  /// beside settled content does not out-move it.
  static const double riseTight = 6;

  /// The default entrance travel: content rises into place rather than
  /// leaping there.
  static const double rise = 8;
}

/// How far a transition slides, as a fraction of the moving widget's own
/// size.
///
/// Separate from [AppMotionTravel] because the unit is different, and the
/// difference is the whole reason both exist: `SlideTransition` and
/// `AnimatedSlide` multiply their `Offset` by the child's size, so `0.3` on a
/// 44 dp button travels 13 dp while the same `0.3` on a full-screen route
/// travels the height of the phone. Reading one of these as dp — or a dp
/// value as one of these — is a silent 100× error, so they do not share a
/// class and cannot be mixed up by autocomplete.
///
/// The values are small on purpose. Every one of them pairs with a fade, and
/// a slide that runs alongside a fade only needs enough travel to give the
/// fade a direction; more reads as the screen lurching.
class AppSlideFractions {
  AppSlideFractions._();

  /// A tab swap inside the home shell — the shallowest motion in the app,
  /// because the two screens are siblings and neither is "deeper".
  static const double tabRise = 0.025;

  /// A detail route pushing in from the trailing edge. Applied on the x
  /// axis, and negated in RTL so "deeper in" is always the direction the
  /// user reads towards.
  static const double detailPush = 0.06;

  /// The scroll-to-bottom button dropping out of view. Larger than the
  /// route values because it is a single small control: the same fraction
  /// that would throw a whole screen around barely moves a 44 dp circle.
  static const double controlDrop = 0.3;
}

/// `ScaleTransition`/`Transform.scale` start values, as a fraction of the
/// widget's resting size. Grouped the same way [AppSlideFractions] groups
/// its axis — one class per animation currency, so a scale ratio and a slide
/// fraction can never be swapped by autocomplete.
class AppScaleFractions {
  AppScaleFractions._();

  /// A pushed route's start scale in the shared scale+fade page transition —
  /// close enough to 1 that it reads as "arriving", not as a zoom.
  static const double routePush = 0.98;
}

/// Tuning specific to [LaunchSplashScreen]'s one-off entrance sequence.
///
/// Kept separate from [AppMotionTravel]/[AppScaleFractions] (which are
/// reused across many entrances) because these values belong to a single,
/// bespoke, once-per-launch animation rather than a shared motion currency —
/// a future second caller should get its own named value here rather than
/// bending the splash's own tuning to fit.
class AppSplashMotion {
  AppSplashMotion._();

  /// The wordmark's zoom-in start scale — "tiny → full size" per the
  /// screen's own doc comment.
  static const double logoScaleStart = 0.25;

  /// The framing card's gentler settle-in start scale — barely off 1 so the
  /// card never "pops" the way the logo deliberately does.
  static const double cardScaleStart = 0.94;

  /// End point (on the entrance timeline) of the wordmark's fade-in curve —
  /// it finishes fading in well before the scale/slide settle.
  static const double fadeIntervalEnd = 0.35;

  /// Start point (on the entrance timeline) of the wordmark's slide-in
  /// curve — begins after the fade so the slide reads as a second beat.
  static const double slideIntervalStart = 0.55;
}

/// [TypingDots] tuning, expressed relative to its own `dotSize` rather than
/// as absolute dp — the indicator is reused at more than one [dotSize], so
/// the gap and the bounce height need to scale with it rather than being
/// pinned to whichever size the first caller happened to use.
class AppTypingDotsMotion {
  AppTypingDotsMotion._();

  /// Gap between dots, as a fraction of `dotSize`.
  static const double gapRatio = 0.7;

  /// Peak hop height in `bounce` mode, as a fraction of `dotSize`.
  static const double bounceRatio = 0.8;
}
