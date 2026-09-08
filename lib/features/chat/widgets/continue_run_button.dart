import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/widgets/ghost_button.dart';

/// "Continue" — one tap to restart a run that stopped at the agent's ceiling
/// on tool rounds.
///
/// Sits under the newest assistant reply, and only when the server flagged
/// `tool_payload.continue_available` on it. That is a different dead end from
/// the one the resume banner covers: there the run stopped saying nothing at
/// all, here it stopped having explained itself and is waiting to be told to
/// carry on. Before this the only way forward on a phone was to type
/// something and hope the agent read it as "keep going".
///
/// Stateful for one reason: the tap has to stick. Sending sets the
/// conversation running, which removes this button on the next build — but
/// "the next build" is a network round-trip away, and a second tap in that
/// window would send the same sentence twice. It disables itself first, the
/// way the web's handler does.
class ContinueRunButton extends StatefulWidget {
  const ContinueRunButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<ContinueRunButton> createState() => _ContinueRunButtonState();
}

class _ContinueRunButtonState extends State<ContinueRunButton> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.s2),
      child: GhostButton(
        label: context.tr.continueRun,
        icon: AppIcons.arrowRight,
        onPressed: _sent
            ? null
            : () {
                setState(() => _sent = true);
                HapticFeedback.mediumImpact();
                widget.onPressed();
              },
      ),
    );
  }
}
