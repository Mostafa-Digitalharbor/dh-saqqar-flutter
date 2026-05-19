import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/saqqar_logo.dart';

/// Slot shown beside a chat message to identify the sender.
///
/// User → round 32×32 muted plate with a `user` glyph.
/// Assistant → bare SAQQÂR wordmark (no chrome). [SaqqarLogo] picks the
/// navy-coloured variant on light themes and the white variant on dark
/// themes automatically, so the brand stays legible against whichever
/// surface the chat is sitting on.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.isUser, this.size = 32});

  final bool isUser;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    if (isUser) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: s.surface2,
          border: Border.all(color: s.border),
        ),
        child: Icon(AppIcons.user, size: size * 0.47, color: s.muted),
      );
    }
    // Wordmark — no circle, no background. Height tuned to sit small and
    // tight against the bubble's start edge rather than occupying a full
    // avatar's worth of space.
    return SaqqarLogo(height: size * 0.42);
  }
}
