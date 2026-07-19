import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/app_dialog_shell.dart';

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
    // This is the tallest dialog in the app (env name in a titleLarge +
    // env AND project name in the body + a 48 px checkbox row), so it is
    // the first to overflow in landscape — the shell's vertical inset and
    // this scroll view are both load-bearing here.
    return AppDialogShell(
      accent: AppDialogShell.dangerAccent(context),
      child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Align, not decoration — the Column is
                        // `CrossAxisAlignment.stretch`, whose tight
                        // full-width constraint overrides the box's own
                        // `size: 46` and renders it as a wide bar. Same fix
                        // and same reason as `ConfirmDialog`.
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ColoredIconBox(
                            icon: AppIcons.warning,
                            color: s.danger,
                            size: 46,
                            radius: 14,
                            iconSize: 22,
                            backgroundAlpha: 0.14,
                            borderAlpha: 0.28,
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
    );
  }
}
