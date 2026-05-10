import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  AppGradients._();

  /// Primary CTA — buttons, FABs.
  static const LinearGradient primaryCta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandNavy, AppColors.brandCyan],
  );

  /// Vivid accent — avatars, gradient text only (never large surfaces).
  static const LinearGradient vivid = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandCyan, AppColors.brandPurple],
  );

  /// User chat bubble fill.
  static final LinearGradient userBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandCyan.withValues(alpha: 0.12),
      AppColors.brandPurple.withValues(alpha: 0.08),
    ],
  );

  /// Server-activity bubble fill.
  static final LinearGradient serverActivity = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandPurple.withValues(alpha: 0.06),
      AppColors.brandCyan.withValues(alpha: 0.04),
    ],
  );

  /// Active conversation row fill.
  static final LinearGradient activeRow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandCyan.withValues(alpha: 0.10),
      AppColors.brandPurple.withValues(alpha: 0.10),
    ],
  );
}
