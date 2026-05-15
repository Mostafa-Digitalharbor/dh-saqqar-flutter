import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/animations/floating_bob.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'chat_suggestion_tile.dart';

/// First-run welcome state for an empty chat — Saqqar avatar, headline, the
/// active-credential pill, and three starter prompts seeded from i18n.
class ChatWelcome extends StatelessWidget {
  const ChatWelcome({
    super.key,
    required this.onSuggestion,
    required this.onPickCredential,
    required this.activeCredentialLabel,
  });

  final ValueChanged<String> onSuggestion;
  final VoidCallback onPickCredential;
  final String activeCredentialLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final suggestions = <ChatSuggestion>[
      ChatSuggestion(
        icon: AppIcons.database,
        text: context.tr.suggestUserCount,
        accent: s.brandCyan,
      ),
      ChatSuggestion(
        icon: AppIcons.fileDown,
        text: context.tr.suggestExportUsers,
        accent: s.success,
      ),
      ChatSuggestion(
        icon: AppIcons.terminal,
        text: context.tr.suggestTailLog,
        accent: s.brandPurple,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Center(
          child: FloatingBob(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.vivid,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(
                AppIcons.sparkles,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr.startConversation,
          textAlign: TextAlign.center,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr.liveAccessNote,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: s.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onPickCredential,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: s.brandCyan.withValues(alpha: 0.10),
                  border: Border.all(
                    color: s.brandCyan.withValues(alpha: 0.30),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.key, size: 14, color: s.brandCyan),
                    const SizedBox(width: 8),
                    Text(
                      activeCredentialLabel,
                      style: context.text.labelMedium?.copyWith(
                        color: s.brandCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(AppIcons.chevronDown, size: 14, color: s.brandCyan),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in suggestions)
                ChatSuggestionTile(
                  suggestion: suggestion,
                  onTap: () => onSuggestion(suggestion.text),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
