import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/animations/floating_bob.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/primary_button.dart';

/// Friendly empty state for the Conversations list — vivid Saqqar mark,
/// inviting headline, supporting copy, and a primary "Start a conversation"
/// CTA that opens a fresh chat.
///
/// More welcoming than the generic [EmptyState] shell because this is the
/// first thing a brand-new user sees if no demo data is preloaded.
class ConversationsEmptyState extends StatelessWidget {
  const ConversationsEmptyState({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          FloatingBob(
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.vivid,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(AppIcons.chats, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            context.tr.askSaqqarAnything,
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.tr.workspaceSummaryBody,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: s.muted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 220,
            child: PrimaryButton(
              label: context.tr.newConversation,
              icon: AppIcons.plus,
              expand: true,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}
