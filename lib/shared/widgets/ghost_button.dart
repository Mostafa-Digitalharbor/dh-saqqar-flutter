import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';
import 'tappable_surface.dart';

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
        ? s.danger.withValues(alpha: AppAlphas.a10)
        : s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.splashFill));
    final borderColor = isDanger
        ? s.danger.withValues(alpha: AppAlphas.a40)
        : s.cardBorder;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: TappableSurface(
          onTap: disabled ? null : onPressed,
          splashColor: accent.withValues(alpha: AppAlphas.a10),
          highlightColor: accent.withValues(alpha: AppAlphas.a06),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
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
                          width: AppControlSizes.spinnerInline,
                          height: AppControlSizes.spinnerInline,
                          child: CircularProgressIndicator(
                            strokeWidth: AppStrokeWidths.spinnerThin,
                            valueColor: AlwaysStoppedAnimation(fg),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s10),
                      ] else if (icon != null) ...[
                        Icon(icon, size: AppIconSizes.regular, color: fg),
                        const SizedBox(width: AppSpacing.s10),
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
