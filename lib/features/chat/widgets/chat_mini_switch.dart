import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';

/// Tiny 28×16 toggle track used inside [AutoApproveSwitch].
///
/// Tints the track with the supplied [color] when [value] is on, otherwise
/// fades to the theme's `surface3` token. Animates the thumb across the
/// track with a 180 ms ease-out-cubic curve.
class ChatMiniSwitch extends StatelessWidget {
  const ChatMiniSwitch({
    super.key,
    required this.value,
    required this.color,
    this.trackWidth = 28,
    this.trackHeight = 16,
  });

  final bool value;
  final Color color;
  final double trackWidth;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: trackWidth,
      height: trackHeight,
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.85) : context.saqqar.surface3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: trackHeight - 4,
            height: trackHeight - 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
