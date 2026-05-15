import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';

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
    required this.environment,
    required this.project,
  });

  final DemoEnvironment environment;
  final DemoProject project;

  static Future<LiveAckResult> show(
    BuildContext context, {
    required DemoEnvironment environment,
    required DemoProject project,
  }) async {
    final result = await showDialog<LiveAckResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => LiveEnvWarningDialog(
        environment: environment,
        project: project,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
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
                Padding(
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
                        child: Icon(AppIcons.warning, color: s.danger, size: 22),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr.liveWarningTitle(widget.environment.name),
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr.liveWarningBody(
                          widget.environment.name,
                          widget.project.name,
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
                              onPressed: () => Navigator.of(context).pop(
                                LiveAckResult.cancel,
                              ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
