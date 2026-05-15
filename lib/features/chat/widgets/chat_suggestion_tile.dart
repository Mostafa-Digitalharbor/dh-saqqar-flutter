import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';

/// Plain data record for a single suggestion (icon + text + accent color).
class ChatSuggestion {
  const ChatSuggestion({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;
}

/// Tappable card shown on the chat welcome state offering a starter prompt.
/// Tapping seeds the composer with [ChatSuggestion.text].
class ChatSuggestionTile extends StatelessWidget {
  const ChatSuggestionTile({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  final ChatSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Compact pill — replaces the older full-width tile so the welcome state
    // reads as "tap a starter" instead of "pick from a menu". Three pills wrap
    // happily in a [Wrap], and the visual weight stops competing with the
    // hero avatar above.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: suggestion.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: suggestion.accent.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(suggestion.icon, size: 14, color: suggestion.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  suggestion.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: suggestion.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
