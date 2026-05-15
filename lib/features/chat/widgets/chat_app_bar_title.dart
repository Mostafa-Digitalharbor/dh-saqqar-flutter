import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';

/// AppBar title slot for the chat screen: gradient Saqqar avatar + the
/// conversation title + a subtitle row showing the active credential and
/// an "Auto-approve on" pill when relevant.
///
/// Tapping the row opens the credential picker — that's the primary control
/// users reach for from the header. The auto-approve switch sits in the
/// AppBar actions so it's reachable in one tap.
class ChatAppBarTitle extends StatelessWidget {
  const ChatAppBarTitle({
    super.key,
    required this.conversation,
    required this.activeCredentialLabel,
    required this.autoApprove,
    required this.onCredentialTap,
  });

  final DemoConversation conversation;
  final String activeCredentialLabel;
  final bool autoApprove;
  final VoidCallback onCredentialTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return InkWell(
      onTap: onCredentialTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.vivid,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(AppIcons.sparkles, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: s.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          activeCredentialLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: s.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (autoApprove) ...[
                        const SizedBox(width: 8),
                        _AutoApprovePill(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact "AUTO" pill shown in the title subtitle when auto-approve is on.
/// Spec §6.8 calls for a subtle warning-coloured indicator; the pill stays
/// small enough to ride next to the credential label without crowding.
class _AutoApprovePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: s.warning.withValues(alpha: 0.16),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: s.warning.withValues(alpha: 0.40)),
      ),
      child: Text(
        context.tr.auto.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: s.warning,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
