import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Centered/left-aligned Saqqar mark + name + tagline used on the auth
/// screens (`compact: true` on phones, otherwise the wider hero layout).
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 68 : 80,
          height: compact ? 68 : 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.vivid,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: s.brandCyan.withValues(alpha: 0.32),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Icon(
            AppIcons.logoMark,
            color: Colors.white,
            size: compact ? 30 : 36,
          ),
        ),
        SizedBox(height: compact ? 18 : 24),
        Text(
          context.tr.appName,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: context.text.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr.appTagline,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: context.text.bodyMedium?.copyWith(
            color: s.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
