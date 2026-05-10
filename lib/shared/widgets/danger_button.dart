import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.2 danger button — soft red fill + red text + red border.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.minHeight = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final disabled = onPressed == null;
    final fill = s.danger.withValues(alpha: 0.10);
    final border = s.danger.withValues(alpha: 0.40);

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: AppRadius.buttonR,
          highlightColor: s.danger.withValues(alpha: 0.10),
          splashColor: s.danger.withValues(alpha: 0.18),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: AppRadius.buttonR,
                border: Border.all(color: border),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final labelWidget = Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: (context.text.labelLarge ?? const TextStyle())
                        .copyWith(color: s.danger, fontWeight: FontWeight.w600),
                  );

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: s.danger),
                        const SizedBox(width: 10),
                      ],
                      if (constraints.hasBoundedWidth)
                        Flexible(child: labelWidget)
                      else
                        labelWidget,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
