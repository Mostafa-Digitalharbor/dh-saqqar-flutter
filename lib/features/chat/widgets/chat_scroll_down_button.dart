import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/tappable_surface.dart';
import '../../../core/theme/app_colors.dart';

/// Floating chevron button that appears when the chat is scrolled away from
/// the latest message. Fades + slides in/out over 180 ms.
class ChatScrollDownButton extends StatelessWidget {
  const ChatScrollDownButton({
    super.key,
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // `ExcludeSemantics` as well as `IgnorePointer`, and the pair is the
    // point. `IgnorePointer` stops taps; it does not remove the node. A
    // faded-out button is still fully present in the semantics tree, so a
    // screen-reader user swiping through a chat used to land on a control
    // that announced nothing and did nothing — twice as confusing as a
    // missing one, because the focus ring visibly stops on empty space.
    //
    // And when it IS visible it needs a name. This is an icon with no text
    // beside it, which is exactly the case `Semantics(label:)` exists for;
    // `uiautomator` reported it as an unnamed node, which is what a
    // screen reader would have read out too.
    return ExcludeSemantics(
      excluding: !visible,
      child: MergeSemantics(
        child: Semantics(
          label: context.tr.scrollToLatest,
          button: true,
          // `MergeSemantics` + `container` is what collapses the label and the
          // tap onto ONE node. `TappableSurface` wraps an `InkWell`, which
          // publishes its own node carrying the tap action; a bare
          // `Semantics(label:)` above it is a separate PARENT node, and the
          // leaf is the one Android surfaces. A `uiautomator` dump showed
          // exactly that: a clickable 40 dp box at the button's bounds with
          // `content-desc=""` and Android's own `NAF="true"`
          // (Not Accessibility Friendly) flag on it.
          container: true,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: visible
                    ? Offset.zero
                    : const Offset(0, AppSlideFractions.controlDrop),
                duration: AppDurations.fast,
                curve: Curves.easeOutCubic,
                child: TappableSurface(
                  radius: AppRadius.pillR,
                  onTap: onTap,
                  child: Container(
                    width: AppBoxSizes.railButton,
                    height: AppBoxSizes.railButton,
                    decoration: BoxDecoration(
                      color: s.surface.withValues(
                        alpha: context.alpha(AppAlphaPairs.chrome),
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: s.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowDark.withValues(
                            alpha: context.alpha(AppAlphaPairs.glow),
                          ),
                          blurRadius: AppShadowSizes.blurButton,
                          offset: const Offset(0, AppShadowSizes.dropControl),
                        ),
                      ],
                    ),
                    child: Icon(
                      AppIcons.chevronDown,
                      size: AppIconSizes.action,
                      color: s.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
