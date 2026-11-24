import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/fig_metrics.dart';
import '../fig/fig.dart';

/// A full-screen wall: "the app is not usable right now, and here is the one
/// thing to do about it."
///
/// Two screens are this shape — the app lock and the forced-update wall — and
/// they should be, because a user meeting either is being stopped, and the
/// same shape is how they recognise that. They were also two copies of the
/// same layout, which is a different matter: the scroll treatment below is
/// hard-won, and a fix applied to one copy would have silently left the other
/// broken.
///
/// **Why it scrolls.** The column is around 360 dp tall. That fits any
/// portrait phone and does NOT fit a landscape one (~320 dp of viewport), and
/// nothing pins these screens to portrait — so a returning user who rotated
/// their phone hit a RenderFlex overflow on the very first surface they saw.
/// `minHeight: constraints.maxHeight` keeps `MainAxisAlignment.center`
/// behaving exactly as it did wherever there is room; past that the content
/// scrolls instead of clipping. The same arithmetic covers 1.4× text scale in
/// portrait, where the subtitle wraps to three lines.
///
/// **Why [Material] is opaque.** Nothing behind a wall may ever be visible —
/// including the app-switcher snapshot, which both platforms take of the
/// top-most layer.
class BlockingWall extends StatelessWidget {
  const BlockingWall({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.footnote,
  });

  /// Drawn inside the tinted circle above the title.
  final IconData icon;

  final String title;
  final String body;

  /// An extra dim line under [body] — the update wall names the version it
  /// wants. Null or empty renders nothing rather than reserving a gap.
  final String? footnote;

  /// The way out, primary first. The lock screen adds a sign-out escape
  /// hatch below its unlock button; the update wall deliberately has none,
  /// because signing out does not make an unsupported build supported.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Fig.pageGrey,
      child: LayoutBuilder(
        builder: (context, outer) {
          final wall = SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                child: ConstrainedBox(
                  // Floor the column at the viewport height so the actions sit at
                  // the bottom — but only when there IS a viewport height. Under
                  // an unbounded parent (a measuring pass, a scrollable that
                  // hands down infinity) `minHeight: infinity` is not a tall
                  // column, it is a layout assertion. Falling back to zero gives
                  // the natural height, which is the one answer that cannot
                  // crash.
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.s64),
                      Container(
                        width: AppBoxSizes.hero,
                        height: AppBoxSizes.hero,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.figWhite.withValues(
                            alpha: AppAlphas.a12,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.figWhite.withValues(
                              alpha: AppAlphas.a30,
                            ),
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: AppIconSizes.emptyState,
                          color: AppColors.figWhite,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      Text(
                        title,
                        style: Fig.t(
                          context,
                          size: FigMetrics.fontFig32,
                          color: AppColors.figWhite,
                          height: FigMetrics.lhFig117,
                          letterSpacing: AppLetterSpacing.heading,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      Text(
                        body,
                        style:
                            Fig.t(
                              context,
                              size: AppFontSizes.dense,
                              color: AppColors.figWhite,
                              height: AppLineHeights.snug,
                            ).copyWith(
                              shadows: const [
                                Shadow(
                                  color: Fig.shadowInk,
                                  blurRadius: FigMetrics.blur6,
                                ),
                              ],
                            ),
                      ),
                      if (footnote != null && footnote!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s6),
                        Text(
                          footnote!,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.caption,
                            color: AppColors.figWhite,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s64),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.s10),
                        actions[i],
                      ],
                      const SizedBox(height: AppSpacing.s24),
                    ],
                  ),
                ),
              ),
            ),
          );
          // The backdrop needs a bounded height; under an unbounded parent
          // (a measuring pass) the wall still lays out, just without it.
          return outer.hasBoundedHeight ? FigBackdrop(child: wall) : wall;
        },
      ),
    );
  }
}
