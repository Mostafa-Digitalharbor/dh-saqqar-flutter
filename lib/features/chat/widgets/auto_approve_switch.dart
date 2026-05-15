import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'chat_mini_switch.dart';

/// Compact pill toggle controlling whether destructive actions auto-approve
/// without asking for consent. Pairs an icon + label + [ChatMiniSwitch].
class AutoApproveSwitch extends StatelessWidget {
  const AutoApproveSwitch({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr.autoApproveSubtitle,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 34,
            padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 4, 0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: value ? 0.14 : 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.26)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.shieldCheck, size: 13, color: color),
                const SizedBox(width: 6),
                Text(
                  context.tr.autoApprove,
                  style: context.text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                ChatMiniSwitch(value: value, color: color),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
