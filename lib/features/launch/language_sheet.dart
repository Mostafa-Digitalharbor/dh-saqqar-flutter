import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../shared/fig/fig.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';

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
          begin: const Offset(0, 0.15),
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
                  style: Fig.t(context, size: 16, color: Fig.inkDeep),
                ),
              ),
            ),
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE1EB).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr.figChooseYourLanguage,
                        style: Fig.t(
                          context,
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.black,
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
