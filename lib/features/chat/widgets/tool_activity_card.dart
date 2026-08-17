import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/code_plate.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Inline collapsible card representing a tool call (Odoo XML-RPC, SQL, shell,
/// GitHub). Collapsed by default — header shows the tool name + timestamp;
/// tapping reveals the monospace payload on the code plate.
class ToolActivityCard extends StatefulWidget {
  const ToolActivityCard({super.key, required this.message});

  final DemoMessage message;

  @override
  State<ToolActivityCard> createState() => _ToolActivityCardState();
}

class _ToolActivityCardState extends State<ToolActivityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tool = widget.message.toolName ?? context.tr.roleTool;

    return TappableSurface(
      radius: AppRadius.smallR,
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: AppDurations.expand,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s10,
          AppSpacing.s7,
          AppSpacing.s8,
          AppSpacing.s7,
        ),
        decoration: BoxDecoration(
          color: s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.86),
          borderRadius: AppRadius.smallR,
          border: Border.all(color: s.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.bolt, size: AppIconSizes.meta, color: s.muted),
                const SizedBox(width: AppSpacing.s6),
                Flexible(
                  child: Text(
                    tool,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: AppFontSizes.caption,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.message.time,
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontSize: AppFontSizes.chipLabel,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AppDurations.expand,
                  child: Icon(
                    AppIcons.chevronDown,
                    size: AppIconSizes.dense,
                    color: s.muted,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.s8),
              CodePlate(text: widget.message.content, accent: s.brandCyan),
            ],
          ],
        ),
      ),
    );
  }
}
