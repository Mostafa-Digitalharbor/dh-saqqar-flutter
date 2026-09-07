import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/accent_banner.dart';
import '../../../shared/widgets/primary_button.dart';

/// Shown above the composer when `conversation.needs_resume == true &&
/// !is_running` — a run that ended without finishing and without anything
/// else waiting on the user (a pending approval, an open question, a
/// credential request and a quota stop are all excluded server-side, so this
/// is only ever a genuine dead end). Tapping Resume restarts the run;
/// the banner disappears on its own once the server stops offering it.
///
/// Purely presentational, same split as [ChatEnvHintBanner]: the chat screen
/// owns the async work and passes [busy] so the button can disable + relabel
/// itself while the round-trip is in flight.
class ChatResumeBanner extends StatelessWidget {
  const ChatResumeBanner({
    super.key,
    required this.onResume,
    this.busy = false,
  });

  final VoidCallback onResume;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return AccentBanner(
      color: context.saqqar.warning,
      icon: AppIcons.warning,
      title: tr.chatResumeBannerText,
      action: PrimaryButton(
        label: busy ? tr.chatResumeButtonWorking : tr.chatResumeButton,
        icon: AppIcons.refresh,
        minHeight: AppControlSizes.buttonMin,
        loading: busy,
        onPressed: busy ? null : onResume,
      ),
    );
  }
}
