import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Centered/left-aligned Saqqar mark + name + tagline used on the auth
/// screens (`compact: true` on phones, otherwise the wider hero layout).
///
/// The mark inside the gradient ring is the same `saqqar-icon-foreground`
/// asset rendered on the launch splash — keeps the brand consistent across
/// the very first surfaces a new user sees (splash → auth).
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final ringSize = compact ? 68.0 : 80.0;
    // Logo inset 4 px from the ring so the foreground glyph reads as
    // "sitting inside" the gradient halo rather than crowding the edge.
    final logoSize = ringSize - 18;

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: ringSize,
          height: ringSize,
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
          child: Image.asset(
            'assets/img/saqqar-icon-foreground.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
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
