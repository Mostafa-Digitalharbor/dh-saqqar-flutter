import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import 'accent_card_chrome.dart';
import '../../../shared/widgets/tappable_surface.dart';

/// Shared chrome for the three in-chat interactive cards (clarify, report
/// builder, prompt suggestion) so they read as one family rather than three
/// unrelated widgets that happen to sit in the message lane.
///
/// Cyan start-side stripe — the mirror of the amber stripe an approval card
/// wears. Amber says "a decision with consequences is waiting"; cyan says
/// "Saqqar needs input before it starts", which is the whole point of these.
class InteractiveCardShell extends StatelessWidget {
  const InteractiveCardShell({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return AccentCardChrome(
      accent: s.brandCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColoredIconBox(
                icon: icon,
                color: s.brandCyan,
                size: AppIconSizes.cardHeader,
                radius: AppRadius.small,
                iconSize: AppIconSizes.boxGlyphCard,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: s.text,
                    letterSpacing: AppLetterSpacing.title,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          ...children,
        ],
      ),
    );
  }
}

/// Single-select chip used by the clarify + report cards.
///
/// A `Wrap` of these, not a horizontal strip: the options are server-authored
/// sentences ("This quarter", "كل العملاء النشطين") of wildly different
/// widths, and a strip would push half of them off-screen with no affordance
/// saying so.
class CardChoiceChip extends StatelessWidget {
  const CardChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TappableSurface(
      radius: AppRadius.pillR,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDurations.control,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? s.brandCyan.withValues(alpha: AppAlphas.a16)
              : s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.panelCard)),
          borderRadius: AppRadius.pillR,
          border: Border.all(
            color: selected
                ? s.brandCyan.withValues(alpha: AppAlphas.a55)
                : s.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: selected ? s.brandCyan : s.text,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Small group heading inside a card ("Period", "Which customers?").
class CardFieldLabel extends StatelessWidget {
  const CardFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(
          color: context.saqqar.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
