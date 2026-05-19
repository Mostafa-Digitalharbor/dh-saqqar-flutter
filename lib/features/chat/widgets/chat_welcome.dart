import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Empty-chat welcome surface — kept deliberately bare on 2026-05-17:
/// just the centred "Start a conversation" headline, nothing else. The
/// previous logo + tagline + credential pill + suggestion chips were
/// removed at user request — the composer below is the only call to
/// action the empty state needs.
///
/// The callback params are retained for API compat with [chat_screen]
/// (it still passes them) but currently unused inside the build.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          context.tr.startConversation,
          textAlign: TextAlign.center,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
