import 'package:flutter/material.dart';

import '../../core/theme/app_sizes.dart';

/// A flexible title paired with a trailing accessory that must never push
/// the title off the row — the header line shared by the conversations
/// list, the chat sidebar, the notifications inbox and the vault's
/// environment rows.
///
/// ## Why this exists
///
/// Four surfaces had independently written the same `Row`:
///
/// ```dart
/// Row(children: [
///   Expanded(child: Text(title, maxLines: 1, overflow: ellipsis)),
///   const SizedBox(width: 8),
///   Text(relativeTime),   // ← or a status pill; either way, unbounded
/// ])
/// ```
///
/// and all four carried the same latent overflow. A `Row` lays out its
/// *non-flexible* children first, with an **unbounded** main-axis
/// constraint, and only then divides what is left among the flexible ones.
/// So the bare trailing child takes whatever width it wants; `Expanded`
/// gets the remainder — which clamps at zero. Once the accessory is wider
/// than the lane, the title collapses to nothing *and* the row still
/// overflows.
///
/// Both variants were reproduced by `responsive_sweep_test` at 320 px ×
/// 1.3× text: a conversation card's timestamp measured 187 px inside a
/// 173 px lane, and every row of a project's environment list overflowed
/// on its status pill.
///
/// Note that `mainAxisSize: MainAxisSize.min` on the accessory does **not**
/// prevent this. It stops the accessory's own `Row` from *expanding*; it
/// does nothing to stop a child from exceeding the incoming constraint. The
/// accessory must additionally be willing to shrink — see [trailing].
///
/// ## The fix
///
/// [trailing] is capped at [trailingMaxFraction] of the row before it is
/// laid out, so it can never starve the title. The title stays `Expanded`,
/// which means it still reclaims the slack whenever the accessory is short
/// ("now", "IDLE") — the reason this is a width *cap* and not a second flex
/// child. Two `Flexible`s splitting the row proportionally would truncate
/// the title early and leave dead space beside a short accessory.
///
/// When the incoming width is unbounded (an intrinsic-sizing pass, a
/// horizontal scroller) there is no fraction to take, so the cap is skipped
/// and the accessory keeps its natural width.
class TitleTrailingRow extends StatelessWidget {
  const TitleTrailingRow({
    super.key,
    required this.title,
    required this.trailing,
    this.leading = const [],
    this.gap = AppSpacing.s8,
    this.trailingMaxFraction = AppFractions.trailingHalf,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// Trailing-timestamp convenience — the most common case by far. Builds a
  /// single-line, ellipsizing [Text] so each call site doesn't restate the
  /// same three overflow flags.
  TitleTrailingRow.stamp({
    super.key,
    required this.title,
    required String stamp,
    TextStyle? stampStyle,
    this.leading = const [],
    this.gap = AppSpacing.s8,
    this.trailingMaxFraction = AppFractions.trailingHalf,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  }) : trailing = Text(
          stamp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: stampStyle,
        );

  /// The flexible leading content. Usually a single-line `Text`, but the
  /// chat sidebar passes a whole `Column` (title + preview) — anything that
  /// is happy being handed a tight width works.
  final Widget title;

  /// The trailing accessory: a timestamp, a status pill, a count badge.
  ///
  /// It is handed a *bounded* maximum width, so it must be able to shrink
  /// into it — a `Text` needs `overflow: ellipsis`, and a pill needs its
  /// label wrapped in `Flexible`. The cap guarantees the row never
  /// overflows; making the accessory shrinkable is what keeps it from
  /// clipping its own content at the cap.
  final Widget trailing;

  /// Fixed-size widgets placed before [title] — e.g. the conversation
  /// card's pin icon. They are laid out at their natural size, so keep them
  /// small and bounded.
  final List<Widget> leading;

  /// Horizontal space between [title] and [trailing].
  final double gap;

  /// Hard ceiling on the accessory's width, as a fraction of the row. The
  /// default leaves the title a clear majority of the lane at every
  /// breakpoint while still fitting "Yesterday" / "منذ 5 دقائق" unclipped.
  final double trailingMaxFraction;

  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            ...leading,
            Expanded(child: title),
            SizedBox(width: gap),
            if (constraints.maxWidth.isFinite)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * trailingMaxFraction,
                ),
                child: trailing,
              )
            else
              trailing,
          ],
        );
      },
    );
  }
}
