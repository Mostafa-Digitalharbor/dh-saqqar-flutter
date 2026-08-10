import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/code_plate.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../../core/theme/app_radius.dart';

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

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.smallR,
      child: InkWell(
        borderRadius: AppRadius.smallR,
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: AppDurations.expand,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
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
                  Icon(AppIcons.bolt, size: 12, color: s.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tool,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.message.time,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppDurations.expand,
                    child: Icon(
                      AppIcons.chevronDown,
                      size: 13,
                      color: s.muted,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                CodePlate(text: widget.message.content, accent: s.brandCyan),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
