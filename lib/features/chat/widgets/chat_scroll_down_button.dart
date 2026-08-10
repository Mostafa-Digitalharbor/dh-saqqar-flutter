import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';

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
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.pillR,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.pillR,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.surface.withValues(
                    alpha: context.isDark ? 0.94 : 0.98,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: s.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF020617,
                      ).withValues(alpha: context.isDark ? 0.30 : 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(AppIcons.chevronDown, size: 20, color: s.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
