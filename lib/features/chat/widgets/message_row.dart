import 'package:flutter/material.dart';

import '../../demo/saqqar_demo_data.dart';
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
        // Spec §8 — user clamps to 88 %, agent clamps to 96 %. Neither
        // side renders an avatar anymore: the agent identifies itself
        // via the gradient wordmark in its message body, and the user
        // avatar was retired on 2026-05-17 (redundant — the bubble's
        // alignment + cyan fill already say "this is you").
        final factor = _isUser ? 0.88 : 0.96;
        final bubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * factor),
          child: MessageBubble(
            isUser: _isUser,
            message: message,
            showTime: isLastOfGroup,
          ),
        );

        return Align(
          alignment: _isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: bubble,
        );
      },
    );
  }
}
