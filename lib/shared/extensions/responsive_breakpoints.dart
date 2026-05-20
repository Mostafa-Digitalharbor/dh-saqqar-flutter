import 'package:flutter/widgets.dart';

/// Width-based breakpoints for the Saqqar mobile shell.
///
/// Treat each tier as a layout intent rather than a precise device match:
///
///   * [Breakpoint.tiny]    — small phones (≤340 px). iPhone SE 1st gen,
///                            Galaxy A01, older Androids. Two-column rows
///                            should stack; AppBar actions should be
///                            icon-only; messaging bubbles get up to 94 %
///                            of the row to keep Arabic phrases readable.
///   * [Breakpoint.compact] — mainstream phones (341–400 px). Pixel 5/6,
///                            iPhone 13 mini, most Androids in portrait.
///                            Default layout target.
///   * [Breakpoint.regular] — large phones / fold-inner (401–600 px).
///                            iPhone Pro Max, Galaxy S Ultra. Room for
///                            an extra inline action or a wider message
///                            cap.
///   * [Breakpoint.wide]    — tablets / fold-outer (>600 px). Side-by-
///                            side panels, larger insets, max-width
///                            caps on forms / dialogs.
///
/// Boundaries were chosen from the Material 3 window-size class table
/// (compact ≤ 600 px) plus an internal "tiny" tier we need because the
/// 320–340 px slice of Android still ships in volume.
enum Breakpoint {
  tiny,
  compact,
  regular,
  wide;

  bool get isTinyOrBelow => this == Breakpoint.tiny;
  bool get isCompactOrBelow =>
      this == Breakpoint.tiny || this == Breakpoint.compact;
  bool get isRegularOrAbove =>
      this == Breakpoint.regular || this == Breakpoint.wide;
  bool get isWide => this == Breakpoint.wide;
}

/// Resolves a [Breakpoint] from a raw width (logical pixels).
///
/// Boundaries chosen to match the doc above; kept as a top-level
/// function so widgets that already have the width in hand (e.g.
/// inside a `LayoutBuilder`) can resolve without spinning up a
/// `MediaQuery` lookup.
Breakpoint breakpointForWidth(double width) {
  if (width <= 340) return Breakpoint.tiny;
  if (width <= 400) return Breakpoint.compact;
  if (width <= 600) return Breakpoint.regular;
  return Breakpoint.wide;
}

/// `context.breakpoint` and friends — pulls width from `MediaQuery`
/// and resolves it to a [Breakpoint]. Widgets inside a `LayoutBuilder`
/// should prefer [breakpointForWidth] on the constraint width instead
/// (the surrounding chrome may be narrower than the device's screen).
extension ResponsiveBreakpointsX on BuildContext {
  /// Current breakpoint based on the device window width. Triggers
  /// a rebuild when the window resizes (foldable open/close, rotation,
  /// split-screen drag).
  Breakpoint get breakpoint =>
      breakpointForWidth(MediaQuery.sizeOf(this).width);

  /// True on phones at or below 340 px wide — the layout-collapsing
  /// tier where two-column rows should stack and inline actions get
  /// hidden behind a menu.
  bool get isTinyScreen => breakpoint == Breakpoint.tiny;

  /// True on phones at or below 400 px wide (covers tiny + compact).
  /// Use this when you want a single switch for "everything that's a
  /// phone in portrait" vs. anything roomier.
  bool get isCompactScreen => breakpoint.isCompactOrBelow;
}
