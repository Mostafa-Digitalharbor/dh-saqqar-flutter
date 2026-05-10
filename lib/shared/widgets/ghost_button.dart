import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.2 ghost button — transparent fill, hairline border, cyan on press.
class GhostButton extends StatelessWidget {
  const GhostButton({
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

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonR,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: AppRadius.buttonR,
          highlightColor: s.brandCyan.withValues(alpha: 0.06),
          splashColor: s.brandCyan.withValues(alpha: 0.10),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: s.surface2.withValues(
                  alpha: context.isDark ? 0.45 : 0.55,
                ),
                borderRadius: AppRadius.buttonR,
                border: Border.all(color: s.cardBorder),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final labelWidget = Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: (context.text.labelLarge ?? const TextStyle())
                        .copyWith(color: s.text, fontWeight: FontWeight.w600),
                  );

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: s.text),
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
