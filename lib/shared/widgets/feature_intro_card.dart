import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';
import '../extensions/context_extensions.dart';
import '../../core/theme/app_radius.dart';

/// Hero card used at the top of each main screen (Conversations, Vault, etc.).
/// Subtle cyan→purple gradient overlay to feel premium.
class FeatureIntroCard extends StatelessWidget {
  const FeatureIntroCard({
    super.key,
    required this.title,
    required this.body,
    this.pills = const [],
    this.action,
  });

  final String title;
  final String body;
  final List<Widget> pills;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Stack(
      children: [
        // Glow tint behind the card.
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    s.brandCyan.withValues(alpha: context.isDark ? 0.10 : 0.06),
                    s.brandPurple.withValues(
                      alpha: context.isDark ? 0.06 : 0.04,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: s.surface.withValues(alpha: context.isDark ? 0.55 : 0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: s.brandCyan.withValues(alpha: context.isDark ? 0.16 : 0.10),
            ),
            boxShadow: context.isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620 && action != null;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pills.isNotEmpty) ...[
                    Wrap(spacing: 8, runSpacing: 8, children: pills),
                    const SizedBox(height: 14),
                  ],
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [s.text, s.text],
                    ).createShader(bounds),
                    child: Text(
                      title,
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                        letterSpacing: -0.2,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: context.text.bodyMedium?.copyWith(
                      color: s.muted,
                      height: 1.55,
                    ),
                  ),
                ],
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      action!,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: action!,
                  ),
                ],
              );
            },
          ),
        ),
        // Decorative gradient corner stripe (top-right).
        Positioned.directional(
          textDirection: Directionality.of(context),
          end: 16,
          top: 16,
          child: IgnorePointer(
            child: Container(
              width: 38,
              height: 4,
              decoration: const BoxDecoration(
                gradient: AppGradients.primaryCta,
                borderRadius: AppRadius.pillR,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
