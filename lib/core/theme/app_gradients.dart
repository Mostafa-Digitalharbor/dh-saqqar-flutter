import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

class AppGradients {
  AppGradients._();

  /// Primary CTA — buttons, FABs. The Figma redesign's blue, the same one
  /// `FigButton` draws, so a button on a screen that has not been redrawn
  /// matches one on a screen that has.
  static const LinearGradient primaryCta = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.figBlueTop, AppColors.figBlueBottom],
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
      AppColors.brandCyan.withValues(alpha: AppAlphas.a12),
      AppColors.brandPurple.withValues(alpha: AppAlphas.a08),
    ],
  );

  /// Server-activity bubble fill.
  static final LinearGradient serverActivity = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandPurple.withValues(alpha: AppAlphas.a06),
      AppColors.brandCyan.withValues(alpha: AppAlphas.a04),
    ],
  );

  /// Active conversation row fill.
  static final LinearGradient activeRow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandCyan.withValues(alpha: AppAlphas.a10),
      AppColors.brandPurple.withValues(alpha: AppAlphas.a10),
    ],
  );
}
