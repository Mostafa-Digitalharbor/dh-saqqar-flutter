import 'package:flutter/material.dart';

import '../../../shared/extensions/responsive_breakpoints.dart';
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
        // Spec §8 — user clamps to 88 %, agent clamps to 96 %. On
        // the `compact` tier (≤400 px) the 88 % cap leaves user
        // messages with so little width that URLs and Arabic phrases
        // wrap one-or-two-words-per-line; relax to 94 % below the
        // breakpoint so the bubble breathes. Neither side renders an
        // avatar — the agent's gradient wordmark identifies itself
        // inside the message body, and the user avatar was retired on
        // 2026-05-17 (alignment + cyan fill already say "this is you").
        final tier = breakpointForWidth(constraints.maxWidth);
        final userFactor = tier.isCompactOrBelow ? 0.94 : 0.88;
        final factor = _isUser ? userFactor : 0.96;
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
