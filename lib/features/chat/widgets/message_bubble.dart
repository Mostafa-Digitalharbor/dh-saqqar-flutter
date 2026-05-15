import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../demo/saqqar_demo_data.dart';
import 'artifact_pill.dart';
import 'attachment_chip.dart';
import 'chat_markdown.dart';

/// A single message bubble. Handles user/assistant styling, optional tool
/// label, attachments, long-press to copy, and time shown only on the last
/// message of a group.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isUser,
    required this.message,
    required this.showTime,
  });

  final bool isUser;
  final DemoMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _copyMessage(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              gradient: isUser ? AppGradients.userBubble : null,
              color: isUser ? null : s.surface2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUser ? s.brandCyan.withValues(alpha: 0.38) : s.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.toolName != null && !isUser) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.bolt, size: 11, color: s.muted),
                      const SizedBox(width: 4),
                      Text(
                        message.toolName!,
                        style: context.text.labelSmall?.copyWith(
                          color: s.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                ChatMarkdown(data: message.content, isUser: isUser),
                for (final attachment in message.attachments) ...[
                  const SizedBox(height: 8),
                  if (attachment.isAgentGenerated)
                    ArtifactPill(
                      attachment: attachment,
                      onOpen: () {
                        // Caller wires share-sheet / new-tab open here. The
                        // chat screen forwards the tap to AppToast in the
                        // demo build.
                      },
                    )
                  else
                    AttachmentChip(attachment: attachment),
                ],
              ],
            ),
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              message.time,
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: context.tr.copiedToClipboard,
      variant: ToastVariant.success,
    );
  }
}
