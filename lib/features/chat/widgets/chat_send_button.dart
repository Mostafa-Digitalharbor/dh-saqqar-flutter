import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/theme/app_colors.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Circular gradient send button used inside the composer pill.
///
/// Renders disabled (no gradient, muted color, no tap target) when
/// [onPressed] is null — the composer passes `null` whenever the device is
/// offline so the user can't queue requests that would silently fail.
///
/// When [onStop] is supplied the button morphs into a Stop control (filled
/// square glyph on a warning-tinted fill) the moment the agent starts
/// streaming, mirroring the web's Send → Stop swap. Tapping it cancels the
/// in-flight reply. [onPressed] is ignored while the stop variant is shown.
class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    super.key,
    required this.onPressed,
    this.onStop,
    this.stopping = false,
    this.size = AppControlSizes.sendButton,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onStop;

  /// Optimistic in-flight state — set true the moment the user taps Stop,
  /// cleared once the server confirms the cancel. While true, the button
  /// is non-interactive and shows a small spinner so the user knows the
  /// tap registered even if the cancel takes a beat to propagate. Web
  /// parity for `state.stopping` (chat-v2 line ~919).
  final bool stopping;

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final showStop = onStop != null;
    final disabled = !showStop && onPressed == null;

    if (showStop) {
      // Neutral muted styling — stopping is a regular action, not an
      // error. Warning-colour fill (the previous design) read as "you
      // did something wrong" which was misleading. Muted surface +
      // outlined ring + foreground text-tinted square reads as
      // "interactive control" without alarm semantics.
      return Tooltip(
        message: stopping ? context.tr.stopping : context.tr.stopGeneration,
        child: TappableSurface(
          radius: AppRadius.pillR,
          onTap: stopping
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onStop!();
                },
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: s.surface3,
              border: Border.all(
                color: s.cardBorder,
                width: AppBorderWidths.medium,
              ),
              shape: BoxShape.circle,
            ),
            child: stopping
                ? Padding(
                    padding: EdgeInsets.all(size * 0.28),
                    child: CircularProgressIndicator(
                      strokeWidth: AppStrokeWidths.spinnerHairline,
                      valueColor: AlwaysStoppedAnimation(s.muted),
                    ),
                  )
                : Icon(AppIcons.stop, color: s.text, size: size * 0.38),
          ),
        ),
      );
    }

    return Tooltip(
      message: context.tr.send,
      child: TappableSurface(
        radius: AppRadius.pillR,
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
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
            color: disabled ? s.muted : AppColors.onBrand,
            size: size * 0.43,
          ),
        ),
      ),
    );
  }
}
