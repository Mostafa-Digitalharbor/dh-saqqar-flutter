import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/colored_icon_box.dart';

/// Empty-chat surface — replaces the bare "Start a conversation" headline
/// on 2026-05-17. Hero icon + welcome copy + a 2×2 grid of 4 starter
/// prompts. Tapping a card calls [onSuggestionTap] with the full prompt so
/// the chat screen can seed the composer and focus it.
///
/// Palette accents come from the theme extension (`brandCyan`,
/// `brandPurple`, `success`, `warning`) so light/dark + custom themes stay
/// consistent without hardcoded hex.
class EmptyChatSuggestions extends StatelessWidget {
  const EmptyChatSuggestions({super.key, required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tiles = <_SuggestionData>[
      _SuggestionData(
        icon: AppIcons.database,
        accent: s.brandCyan,
        title: context.tr.suggestExploreTitle,
        subtitle: context.tr.suggestExploreSub,
        prompt: context.tr.suggestExplorePrompt,
      ),
      _SuggestionData(
        icon: AppIcons.fileText,
        accent: s.brandPurple,
        title: context.tr.suggestSummarizeTitle,
        subtitle: context.tr.suggestSummarizeSub,
        prompt: context.tr.suggestSummarizePrompt,
      ),
      _SuggestionData(
        icon: AppIcons.table,
        accent: s.success,
        title: context.tr.suggestReportTitle,
        subtitle: context.tr.suggestReportSub,
        prompt: context.tr.suggestReportPrompt,
      ),
      _SuggestionData(
        icon: AppIcons.terminal,
        accent: s.warning,
        title: context.tr.suggestServerLogsTitle,
        subtitle: context.tr.suggestServerLogsSub,
        prompt: context.tr.suggestServerLogsPrompt,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones; the body never goes wider than 540 px so
        // the grid still reads as a nice 2×2 on tablets / desktop chat.
        const maxWidth = 540.0;
        final width =
            constraints.maxWidth > maxWidth ? maxWidth : constraints.maxWidth;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeroIcon(accent: s.brandCyan),
                  const SizedBox(height: 18),
                  Text(
                    context.tr.emptyChatTitle,
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall?.copyWith(
                      color: s.text,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr.emptyChatBody,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: s.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // 2×2 grid built from two IntrinsicHeight rows instead
                  // of GridView. GridView's fixed childAspectRatio was
                  // squeezing text on small phones; IntrinsicHeight lets
                  // each row grow to match the taller card's natural
                  // content height, and Expanded keeps the two cards in
                  // a row equal width. Adapts to any phone size.
                  _SuggestionGrid(
                    tiles: tiles,
                    onTap: (prompt) {
                      HapticFeedback.selectionClick();
                      onSuggestionTap(prompt);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionData {
  const _SuggestionData({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String prompt;
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.14),
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 1),
      ),
      child: Icon(
        AppIcons.message,
        color: accent,
        size: 26,
      ),
    );
  }
}

/// 2×2 grid: two rows, each `IntrinsicHeight` so the two cards in a
/// row match the taller card's natural height, and `Expanded` so they
/// split the width equally. Cards size to their content (no
/// `childAspectRatio` forcing them into a fixed box), so the title +
/// subtitle text is always fully visible regardless of phone width.
class _SuggestionGrid extends StatelessWidget {
  const _SuggestionGrid({required this.tiles, required this.onTap});

  final List<_SuggestionData> tiles;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowStart = 0; rowStart < tiles.length; rowStart += 2) ...[
          if (rowStart > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SuggestionCard(
                    data: tiles[rowStart],
                    onTap: () => onTap(tiles[rowStart].prompt),
                  ),
                ),
                if (rowStart + 1 < tiles.length) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SuggestionCard(
                      data: tiles[rowStart + 1],
                      onTap: () => onTap(tiles[rowStart + 1].prompt),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.data, required this.onTap});

  final _SuggestionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardR,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: s.cardBg,
            borderRadius: AppRadius.cardR,
            border: Border.all(color: s.cardBorder),
          ),
          // mainAxisSize.min so the card hugs its content. The outer
          // IntrinsicHeight + Expanded in the row gives it equal width
          // and matched height with its sibling — the card itself only
          // commits to height = sum of its children.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ColoredIconBox(
                icon: data.icon,
                color: data.accent,
                size: 28,
                radius: AppRadius.tight,
                iconSize: 16,
                borderAlpha: 0.28,
              ),
              const SizedBox(height: 8),
              Text(
                data.title,
                style: context.text.bodyMedium?.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
