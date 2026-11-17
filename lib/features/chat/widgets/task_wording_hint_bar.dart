import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/accent_banner.dart';
import '../../../shared/widgets/primary_button.dart';

/// "This looks like a long task. Want me to structure it before sending?"
///
/// Appears above the composer once the typed text passes the web's ten-word
/// bar, and only while task-prep is on. It is an offer, not a gate: the
/// second button dismisses it for that text and the message sends exactly as
/// written.
///
/// Purely presentational — the screen owns when it shows and what the two
/// buttons do, the same split as [ChatResumeBanner].
class TaskWordingHintBar extends StatelessWidget {
  const TaskWordingHintBar({
    super.key,
    required this.onOpen,
    required this.onDismiss,
  });

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return AccentBanner(
      color: context.saqqar.brandCyan,
      icon: AppIcons.sparkles,
      title: tr.promptHintLong,
      action: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          PrimaryButton(
            label: tr.promptHintOpen,
            minHeight: AppControlSizes.buttonMin,
            onPressed: onOpen,
          ),
          // Secondary on purpose: continuing unchanged is the safe default,
          // and a second filled button would read as two competing asks.
          TextButton(onPressed: onDismiss, child: Text(tr.promptHintDismiss)),
        ],
      ),
    );
  }
}
