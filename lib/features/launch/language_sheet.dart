import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../shared/fig/fig.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/fig_metrics.dart';

/// First-launch "Choose Your Language" card, shown over the blurred splash.
/// Returns the chosen language code. Hindi and Chinese are listed as in the
/// design but have no translation yet, so callers fall back to English.
Future<String?> showLanguageSheet(BuildContext context) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: AppDurations.routeIn,
    pageBuilder: (ctx, _, __) => const _LanguageSheet(),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(
          begin: FigOffsets.oU0U0U15,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    Widget option(String label, String code, {double opacity = 1}) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(code),
          child: Opacity(
            opacity: opacity,
            child: SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  label,
                  style: Fig.t(context, size: AppFontSizes.reading, color: Fig.inkDeep),
                ),
              ),
            ),
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: FigMetrics.sigma14, sigmaY: FigMetrics.sigma14),
          child: ColoredBox(color: AppColors.figBlack.withValues(alpha: AppAlphas.a12)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s30),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s18, AppSpacing.s16, AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.figCFFDCE1EB.withValues(alpha: AppAlphas.a94),
                    borderRadius: BorderRadius.circular(AppRadius.sheetTop),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr.figChooseYourLanguage,
                        style: Fig.t(
                          context,
                          size: AppFontSizes.body,
                          weight: FontWeight.w700,
                          color: AppColors.figBlack,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      option('English', 'en'),
                      option('العربية', 'ar'),
                      option('हिन्दी', 'hi'),
                      option('中文 - Zhōngwén', 'zh', opacity: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
