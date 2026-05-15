import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.2 icon button — transparent fill, hairline border, cyan border on press.
///
/// Hits the 44×44 minimum touch target by default.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 18,
    this.bordered = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final disabled = onPressed == null;

    Widget body = Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: AppRadius.buttonR,
        highlightColor: s.brandCyan.withValues(alpha: 0.06),
        splashColor: s.brandCyan.withValues(alpha: 0.10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonR,
            border: bordered ? Border.all(color: s.border) : null,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: disabled ? s.muted : s.text),
        ),
      ),
    );

    if (tooltip != null) {
      body = Tooltip(message: tooltip!, child: body);
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: tooltip ?? '',
      child: Opacity(opacity: disabled ? 0.5 : 1, child: body),
    );
  }
}
