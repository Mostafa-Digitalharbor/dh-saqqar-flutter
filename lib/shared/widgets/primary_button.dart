import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelWidget = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (context.text.labelLarge ?? const TextStyle()).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            );

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, color: Colors.white, size: 18),
                if ((loading || icon != null)) const SizedBox(width: 10),
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

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: AppRadius.buttonR,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppGradients.primaryCta,
              borderRadius: AppRadius.buttonR,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
