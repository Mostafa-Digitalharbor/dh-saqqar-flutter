import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';

/// Spec §5.8 — round avatar with vivid brand gradient + first-letter glyph.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.username, this.size = 32});

  final String username;
  final double size;

  String get _initial {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.vivid,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
