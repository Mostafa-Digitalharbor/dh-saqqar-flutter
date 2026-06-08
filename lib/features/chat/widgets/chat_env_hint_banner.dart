import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/primary_button.dart';

/// Env-hint banner (Gap H) — shown above the composer when the conversation
/// has no environment bound (`conversation.needs_environment == true`). The
/// "Use My Database" button ensures a default project + production env exists
/// (server-side), binds it to the conversation, and prompts for credentials
/// if the new env can't connect to Odoo yet.
///
/// Purely presentational: the chat screen owns the async work and passes a
/// [busy] flag so the button shows a spinner while the round-trip is in
/// flight.
class ChatEnvHintBanner extends StatelessWidget {
  const ChatEnvHintBanner({
    super.key,
    required this.onUseMyDatabase,
    this.busy = false,
  });

  final VoidCallback onUseMyDatabase;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final color = s.brandCyan;

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
              Icon(AppIcons.database, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.envHintTitle,
                      style: context.text.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr.envHintBody,
                      style: context.text.bodySmall?.copyWith(color: s.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PrimaryButton(
              label: tr.envHintUseMyDatabase,
              icon: AppIcons.database,
              minHeight: 40,
              loading: busy,
              onPressed: busy ? null : onUseMyDatabase,
            ),
          ),
        ],
      ),
    );
  }
}
