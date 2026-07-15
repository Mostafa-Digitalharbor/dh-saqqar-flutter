import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';

/// One-shot confirmation that fires the first time the user sends a message
/// to a `is_live: true` environment in a conversation. Wording matches the
/// web verbatim. Returns one of:
///  - `LiveAckResult.confirmOnce` → proceed, persist per-conversation ack
///  - `LiveAckResult.confirmGlobal` → proceed AND remember globally for env
///  - `LiveAckResult.cancel` → abort the send
enum LiveAckResult { cancel, confirmOnce, confirmGlobal }

class LiveEnvWarningDialog extends StatefulWidget {
  const LiveEnvWarningDialog({
    super.key,
    required this.environmentName,
    required this.projectName,
  });

  /// Source-agnostic — pass the real env's `name` (from `VaultData`) OR
  /// `demoEnvironmentLabel(demoEnv)` for the legacy demo path. The
  /// dialog only renders these as text; it doesn't need the typed
  /// models.
  final String environmentName;
  final String projectName;

  static Future<LiveAckResult> show(
    BuildContext context, {
    required String environmentName,
    required String projectName,
  }) async {
    final result = await showDialog<LiveAckResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => LiveEnvWarningDialog(
        environmentName: environmentName,
        projectName: projectName,
      ),
    );
    return result ?? LiveAckResult.cancel;
  }

  @override
  State<LiveEnvWarningDialog> createState() => _LiveEnvWarningDialogState();
}

class _LiveEnvWarningDialogState extends State<LiveEnvWarningDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Dialog(
      backgroundColor: Colors.transparent,
      // Both axes matter — `horizontal`-only leaves a 0 vertical inset, so
      // the dialog may claim the full viewport height and the column below
      // has nothing to push back against. This is the tallest dialog in the
      // app (env name in a titleLarge + env AND project name in the body +
      // a 48 px checkbox row), so it's the first to overflow in landscape.
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: s.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [s.danger, s.danger.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
                // Scrolls instead of overflowing once the inset-bounded
                // height can't hold the content — see `ConfirmDialog` for
                // the same guard. `Flexible` keeps the danger hairline
                // pinned while only the content scrolls.
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: s.danger.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(
                            AppIcons.warning,
                            color: s.danger,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.tr.liveWarningTitle(widget.environmentName),
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr.liveWarningBody(
                            widget.environmentName,
                            widget.projectName,
                          ),
                          style: context.text.bodyMedium?.copyWith(
                            color: s.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: AppRadius.buttonR,
                          onTap: () =>
                              setState(() => _dontAskAgain = !_dontAskAgain),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _dontAskAgain,
                                  onChanged: (v) => setState(
                                    () => _dontAskAgain = v ?? false,
                                  ),
                                  activeColor: s.brandCyan,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    context.tr.dontAskAgain,
                                    style: context.text.bodySmall?.copyWith(
                                      color: s.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: GhostButton(
                                label: context.tr.cancel,
                                onPressed: () => Navigator.of(
                                  context,
                                ).pop(LiveAckResult.cancel),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PrimaryButton(
                                label: context.tr.sendToLive,
                                icon: AppIcons.send,
                                onPressed: () => Navigator.of(context).pop(
                                  _dontAskAgain
                                      ? LiveAckResult.confirmGlobal
                                      : LiveAckResult.confirmOnce,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
