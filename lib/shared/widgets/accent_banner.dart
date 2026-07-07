import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// Accent-tinted inline banner: a leading icon, a bold accent title, a body
/// line, and an optional start-aligned action below. The recurring "call-out
/// above the composer" shape (env hint, plan/quota warnings) — one home so
/// every banner shares the exact margin/padding/tint recipe.
class AccentBanner extends StatelessWidget {
  const AccentBanner({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  /// Accent driving the tinted fill (10%), hairline border (35%), icon, and
  /// title colour. Callers pass a semantic tone (cyan hint, amber near-limit,
  /// danger exceeded) — it is NOT the app's fixed brand accent.
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  /// Optional CTA rendered start-aligned beneath the text (e.g. an upgrade
  /// or "use my database" button). Omitted → the banner is text-only.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: context.text.bodySmall?.copyWith(color: s.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: action!,
            ),
          ],
        ],
      ),
    );
  }
}
