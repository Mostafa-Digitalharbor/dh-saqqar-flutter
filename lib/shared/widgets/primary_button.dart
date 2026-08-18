import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../animations/typing_dots.dart';
import '../extensions/context_extensions.dart';
import 'tappable_surface.dart';

/// Spec §5.2 primary button — navy→cyan gradient, white text.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.minHeight = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s18,
          vertical: AppSpacing.s10,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelWidget = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (context.text.labelLarge ?? const TextStyle()).copyWith(
                color: AppColors.onBrand,
                fontWeight: FontWeight.w600,
              ),
            );

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (loading)
                  // Three-dot pulse matches the chat typing indicator —
                  // feels native to Saqqar rather than the default
                  // Material spinner.
                  const SizedBox(
                    width: AppControlSizes.buttonSpinnerWidth,
                    height: AppControlSizes.buttonSpinnerHeight,
                    child: Center(child: TypingDots(color: AppColors.onBrand)),
                  )
                else if (icon != null)
                  Icon(icon, color: AppColors.onBrand, size: AppIconSizes.regular),
                if (loading || icon != null) const SizedBox(width: AppSpacing.s10),
                if (constraints.hasBoundedWidth)
                  Flexible(child: labelWidget)
                else
                  labelWidget,
              ],
            );
          },
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: TappableSurface(
          onTap: disabled ? null : onPressed,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppGradients.primaryCta,
              borderRadius: AppRadius.buttonR,
            ),
            child: ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
  }
}
