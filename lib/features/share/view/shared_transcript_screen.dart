import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/eyebrow_label.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/responsive_content.dart';

/// Public, read-only view of a shared conversation. Reached via either the
/// in-app push from a "Share link" action or the `saqqar://share/<token>`
/// deep link.
///
/// The full read-only renderer lands in Sprint 3 alongside the chat data
/// fetch (it can reuse `MessageRow` wrapped in a `ReadOnly` modifier). For
/// now this screen is a labelled placeholder so deep links always land
/// somewhere meaningful.
class SharedTranscriptScreen extends StatelessWidget {
  const SharedTranscriptScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.share),
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          tooltip: context.tr.cancel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: AmbientBackground(
        child: Center(
          child: ResponsiveContent(
            maxWidth: 560,
            padding: const EdgeInsets.all(20),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EyebrowLabel('Saqqar'),
                  const SizedBox(height: 8),
                  Text(
                    context.tr.share,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Token: $token',
                    style: context.text.bodySmall?.copyWith(color: s.muted),
                  ),
                  const SizedBox(height: 18),
                  EmptyState(
                    title: context.tr.placeholder,
                    body: context.tr.actionCenterSummaryBody,
                    icon: AppIcons.fileText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
