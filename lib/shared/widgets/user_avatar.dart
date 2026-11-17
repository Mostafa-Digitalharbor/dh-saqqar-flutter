import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_sizes.dart';

/// Spec §5.8 — round avatar with vivid brand gradient + first-letter glyph.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.username,
    this.size = AppAvatarSizes.small,
  });

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
        border: Border.all(
          color: AppColors.onBrand.withValues(alpha: AppAlphas.a16),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: AppColors.onBrand,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
