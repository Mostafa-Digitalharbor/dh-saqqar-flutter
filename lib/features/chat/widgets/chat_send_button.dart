import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Circular gradient send button used inside the composer pill.
///
/// Renders disabled (no gradient, muted color, no tap target) when
/// [onPressed] is null — the composer passes `null` whenever the device is
/// offline so the user can't queue requests that would silently fail.
class ChatSendButton extends StatelessWidget {
  const ChatSendButton({super.key, required this.onPressed, this.size = 42});

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final s = context.saqqar;
    return Tooltip(
      message: context.tr.send,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillR,
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          borderRadius: AppRadius.pillR,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: disabled ? null : AppGradients.primaryCta,
              color: disabled ? s.surface3 : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.send,
              color: disabled ? s.muted : Colors.white,
              size: size * 0.43,
            ),
          ),
        ),
      ),
    );
  }
}
