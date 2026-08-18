import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';
import 'app_dialog_shell.dart';
import 'colored_icon_box.dart';
import 'dialog_actions.dart';
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
      barrierColor: AppColors.scrimBase.withValues(alpha: AppAlphas.a55),
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

    return AppDialogShell(
      elevated: true,
      accent: destructive ? AppDialogShell.dangerAccent(context) : null,
      // Scrolls rather than overflows when the content can't fit the
      // height the inset leaves us — `body` carries user-supplied names
      // (project / environment) and Arabic at 1.4× is materially taller
      // than English. Mirrors `RenameConversationDialog`. The shell keeps
      // the gradient hairline pinned while only this scrolls; on a normal
      // device everything fits and no scrollbar shows.
      child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s22,
                      AppSpacing.s22,
                      AppSpacing.s22,
                      AppSpacing.s18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon case final iconData?) ...[
                          // Align is load-bearing, not decoration. The Column
                          // above is `CrossAxisAlignment.stretch` (the title,
                          // body and button row all want full width), which
                          // hands EVERY child a tight full-width constraint —
                          // and a tight parent constraint beats a child's own
                          // `width: 46`. Without this the 46×46 badge rendered
                          // as a 336px-wide bar with a lone icon floating in
                          // the middle. Align passes loose constraints down,
                          // so the box gets to be the size it asks for.
                          // `centerStart` keeps it edge-aligned with the
                          // left-aligned title beneath it (and mirrors in RTL).
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ColoredIconBox(
                              icon: iconData,
                              color: destructive ? s.danger : s.brandCyan,
                              size: AppIconSizes.dialogHero,
                              radius: AppRadius.input,
                              iconSize: AppIconSizes.boxGlyphLarge,
                              backgroundAlpha: 0.14,
                              borderAlpha: 0.28,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s14),
                        ],
                        Text(
                          title,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: AppLetterSpacing.heading,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          body,
                          style: context.text.bodyMedium?.copyWith(
                            color: s.muted,
                            height: AppLineHeights.body,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        DialogActions(
                          cancel: GhostButton(
                            label: cancelLabel ?? context.tr.cancel,
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          confirm: destructive
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
      ),
    );
  }
}
