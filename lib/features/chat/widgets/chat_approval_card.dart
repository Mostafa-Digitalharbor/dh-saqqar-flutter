import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';

/// Approval card shown inside the chat "Pending approvals" sheet.
/// Neutral surface + 4 px amber start-side stripe + Reject / Approve actions.
class ChatApprovalCard extends StatelessWidget {
  const ChatApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final DemoApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.cardBorder),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: s.warning,
                borderRadius: const BorderRadiusDirectional.horizontal(
                  start: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: s.warning.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        AppIcons.shieldAlert,
                        color: s.warning,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        approval.title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: s.text,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    MiniChip(approval.risk, color: s.warning),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  approval.prompt,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in approval.payload.entries)
                      MiniChip(context.tr.keyValue(entry.key, entry.value)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: context.tr.reject,
                        icon: AppIcons.close,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onReject();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: context.tr.approve,
                        icon: AppIcons.check,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onApprove();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
