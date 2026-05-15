import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_gradients.dart';
import '../extensions/context_extensions.dart';
import 'ghost_button.dart';
import 'primary_button.dart';

/// Cardified confirmation dialog that matches the rest of Saqqar's UI
/// instead of falling back to Material's generic `AlertDialog`.
///
/// Top gradient strip + title + body + a Cancel ghost button next to a
/// confirm button. When [destructive] is true, the confirm button uses the
/// danger palette so the user reads the operation as risky.
///
/// Returns `true` if the user confirmed, `false` for cancel, `null` if
/// dismissed by tapping outside.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String? cancelLabel;
  final bool destructive;
  final IconData? icon;

  /// Helper that wraps the showDialog call so callers don't have to deal
  /// with the typed Future + barrier dismissable + builder boilerplate.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => ConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

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
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF020617).withValues(alpha: 0.55),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 3 px gradient hairline along the top — same accent used on
                // the chat bottom sheets so the visual family stays tight.
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: destructive
                        ? LinearGradient(
                            colors: [
                              s.danger,
                              s.danger.withValues(alpha: 0.7),
                            ],
                          )
                        : AppGradients.primaryCta,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (destructive ? s.danger : s.brandCyan)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (destructive ? s.danger : s.brandCyan)
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: destructive ? s.danger : s.brandCyan,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        title,
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: context.text.bodyMedium?.copyWith(
                          color: s.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GhostButton(
                              label: cancelLabel ?? context.tr.cancel,
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: destructive
                                ? GhostButton(
                                    label: confirmLabel,
                                    tone: GhostButtonTone.danger,
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                  )
                                : PrimaryButton(
                                    label: confirmLabel,
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
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
