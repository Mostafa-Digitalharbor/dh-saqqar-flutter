import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../demo/saqqar_demo_data.dart';
import 'chat_avatar.dart';
import 'message_bubble.dart';
import 'tool_activity_card.dart';

/// Orchestrates layout for one message in the chat list.
///
/// - Tool messages render as a [ToolActivityCard] indented under the assistant.
/// - User / assistant messages render as a [MessageBubble], with the avatar
///   shown only on the first message of a group (consecutive messages from
///   the same sender share a single avatar slot).
class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
  });

  final DemoMessage message;
  final bool isFirstOfGroup;
  final bool isLastOfGroup;

  bool get _isUser => message.role == DemoMessageRole.user;
  bool get _isTool => message.role == DemoMessageRole.tool;

  @override
  Widget build(BuildContext context) {
    if (_isTool) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 42),
        child: ToolActivityCard(message: message),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final factor = constraints.maxWidth < 480 ? 0.86 : 0.78;
        final bubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * factor),
          child: MessageBubble(
            isUser: _isUser,
            message: message,
            showTime: isLastOfGroup,
          ),
        );

        final avatarSlot = SizedBox(
          width: 32,
          child: isFirstOfGroup
              ? ChatAvatar(isUser: _isUser)
              : const SizedBox.shrink(),
        );
        const gap = SizedBox(width: 10);
        final userOnLeft = context.isRtl;

        final children = _isUser
            ? (userOnLeft
                  ? [avatarSlot, gap, bubble]
                  : [bubble, gap, avatarSlot])
            : (context.isRtl
                  ? [bubble, gap, avatarSlot]
                  : [avatarSlot, gap, bubble]);

        return Row(
          mainAxisAlignment: _isUser
              ? (userOnLeft ? MainAxisAlignment.start : MainAxisAlignment.end)
              : (context.isRtl
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: children,
        );
      },
    );
  }
}
