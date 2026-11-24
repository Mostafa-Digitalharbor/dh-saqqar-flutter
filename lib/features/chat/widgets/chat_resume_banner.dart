import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/accent_banner.dart';
import '../../../shared/fig/fig.dart';

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
    this.failureMessage,
  });

  final VoidCallback onResume;
  final bool busy;

  /// Reason the last Resume attempt failed (e.g. "No internet connection"),
  /// or null when the last attempt succeeded or none has been made yet.
  /// Rendered as the banner's body line instead of a toast — this button
  /// is expected to be tapped again, so the reason should stay put and
  /// visible rather than flash past in a dismissable pop-up.
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return AccentBanner(
      color: context.saqqar.warning,
      icon: AppIcons.warning,
      title: tr.chatResumeBannerText,
      body: failureMessage,
      action: FigButton.compact(
        label: busy ? tr.chatResumeButtonWorking : tr.chatResumeButton,
        icon: AppIcons.refresh,
        height: AppControlSizes.buttonMin,
        loading: busy,
        onPressed: busy ? null : onResume,
      ),
    );
  }
}
