import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Round 32×32 avatar used on each message row.
///
/// User → muted surface plate with a `user` glyph.
/// Assistant → vivid cyan→purple gradient with a `sparkles` glyph.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.isUser, this.size = 32});

  final bool isUser;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser ? null : AppGradients.vivid,
        color: isUser ? s.surface2 : null,
        border: Border.all(
          color: isUser ? s.border : Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Icon(
        isUser ? AppIcons.user : AppIcons.sparkles,
        size: size * 0.47,
        color: isUser ? s.muted : Colors.white,
      ),
    );
  }
}
