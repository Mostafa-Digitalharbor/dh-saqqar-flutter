import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/tappable_surface.dart';

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
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.3),
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
                    color: const Color(
                      0xFF020617,
                    ).withValues(alpha: context.alpha(AppAlphaPairs.glow)),
                    blurRadius: AppShadowSizes.blurButton,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(AppIcons.chevronDown, size: AppIconSizes.action, color: s.text),
            ),
          ),
        ),
      ),
    );
  }
}
