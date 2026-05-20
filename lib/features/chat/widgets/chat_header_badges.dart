import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/text_scale_lock.dart';
import '../../demo/saqqar_demo_data.dart';

/// Brief §4.1 — compact env-badges strip rendered under the chat AppBar
/// on mobile, replacing the project / environment dropdowns. Renders
/// the project name as plain text and the environment's flags as small
/// status chips (`LIVE`, `READ-ONLY`, `AUTO-APPROVE`).
///
/// The whole strip is tappable — fires [onTap] (the chat screen routes
/// it to the environment picker sheet so the user still has a one-tap
/// path to switch envs).
class ChatHeaderBadges extends StatelessWidget {
  const ChatHeaderBadges({
    super.key,
    required this.project,
    required this.environment,
    required this.onTap,
  });

  /// Active project — null when the user hasn't picked one yet.
  final DemoProject? project;

  /// Active environment — null when the user hasn't picked one yet.
  final DemoEnvironment? environment;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final hasSelection = project != null && environment != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: s.surface,
            border: Border(bottom: BorderSide(color: s.cardBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              // Status dot — cyan when an env is selected, muted when
              // the user hasn't picked yet.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasSelection ? s.brandCyan : s.muted,
                  boxShadow: hasSelection
                      ? [
                          BoxShadow(
                            color: s.brandCyan.withValues(alpha: 0.45),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Project/env label + optional badges share an Expanded
              // Wrap so the badges flow onto a second visual line on
              // narrow phones (320–360 px) instead of pushing the
              // chevron off-screen or truncating the env name to a few
              // letters. Chevron stays anchored to the trailing edge.
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        hasSelection
                            ? '${project!.name} · ${environment!.name}'
                            : context.tr.pickProjectFirst,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium?.copyWith(
                          color: hasSelection ? s.text : s.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (environment != null) ...[
                      if (environment!.isLive)
                        _Badge(label: 'LIVE', color: s.warning),
                      if (environment!.readOnly)
                        _Badge(label: 'READ-ONLY', color: s.muted),
                      if (environment!.autoApprove)
                        _Badge(label: 'AUTO', color: s.brandCyan),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(AppIcons.chevronDown, size: 14, color: s.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextScaleLock(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: AppRadius.pillR,
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
