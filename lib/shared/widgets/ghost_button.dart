import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Visual tone of a [GhostButton]. `neutral` keeps the standard hairline +
/// text color; `danger` swaps in the red border + red text used for delete /
/// sign-out actions. Replaces the old separate `DangerButton`.
enum GhostButtonTone { neutral, danger }

/// Spec §5.2 ghost button — transparent fill, hairline border. The [tone]
/// param recolours border + text + ink for destructive contexts.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.minHeight = 48,
    this.tone = GhostButtonTone.neutral,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double minHeight;
  final GhostButtonTone tone;

  /// When true, replaces the leading [icon] with an inline spinner and
  /// disables the tap target. Use for cubit-bound submit buttons (see
  /// [AsyncSubmitButton.ghost]) so the user gets immediate feedback that
  /// the action is in flight.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final disabled = onPressed == null || loading;
    final isDanger = tone == GhostButtonTone.danger;

    final fg = isDanger ? s.danger : s.text;
    final accent = isDanger ? s.danger : s.brandCyan;
    final fillColor = isDanger
        ? s.danger.withValues(alpha: 0.10)
        : s.surface2.withValues(alpha: context.isDark ? 0.45 : 0.55);
    final borderColor = isDanger
        ? s.danger.withValues(alpha: 0.40)
        : s.cardBorder;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.buttonR,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: AppRadius.buttonR,
            highlightColor: accent.withValues(alpha: 0.06),
            splashColor: accent.withValues(alpha: 0.10),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: AppRadius.buttonR,
                  border: Border.all(color: borderColor),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final labelWidget = Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: (context.text.labelLarge ?? const TextStyle())
                          .copyWith(color: fg, fontWeight: FontWeight.w600),
                    );

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        if (loading) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(fg),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else if (icon != null) ...[
                          Icon(icon, size: 18, color: fg),
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
      ),
    );
  }
}
