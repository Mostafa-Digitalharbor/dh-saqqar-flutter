import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/accent_banner.dart';
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
    final tr = context.tr;
    return AccentBanner(
      color: context.saqqar.brandCyan,
      icon: AppIcons.database,
      title: tr.envHintTitle,
      body: tr.envHintBody,
      action: PrimaryButton(
        label: tr.envHintUseMyDatabase,
        icon: AppIcons.database,
        minHeight: AppControlSizes.buttonMin,
        loading: busy,
        onPressed: busy ? null : onUseMyDatabase,
      ),
    );
  }
}
