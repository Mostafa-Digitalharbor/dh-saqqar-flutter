import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_actions.dart';

/// Single-field dialog used for renaming a conversation. Returns the
/// trimmed new title on Save, or null on Cancel / outside-tap. Empty
/// values close the dialog without a result so the caller treats it as
/// "no change".
///
/// Built on plain [Dialog] (not [AlertDialog]) because Saqqar's
/// FigButton / FigButton internally use `LayoutBuilder` for
/// responsive sizing, and `AlertDialog.actions` queries intrinsic
/// dimensions on its children — a combination Flutter explicitly
/// disallows ("LayoutBuilder does not support returning intrinsic
/// dimensions"). The custom Dialog body sidesteps the intrinsic-sizing
/// path entirely by using explicit constraints.
class RenameConversationDialog extends StatefulWidget {
  const RenameConversationDialog({
    super.key,
    required this.initial,
    this.title,
    this.hint,
  });

  final String initial;

  /// Heading and field hint; they say "conversation" unless the caller renames
  /// something else (a company, from the context sheet).
  final String? title;
  final String? hint;

  static Future<String?> show(
    BuildContext context, {
    required String initial,
    String? title,
    String? hint,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.scrimBase.withValues(alpha: AppAlphas.a55),
      builder: (_) =>
          RenameConversationDialog(initial: initial, title: title, hint: hint),
    );
  }

  @override
  State<RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<RenameConversationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initial.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final next = _controller.text.trim();
    Navigator.of(context).pop(next.isEmpty ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // Flutter's [Dialog] already lifts itself above the keyboard, so nothing
    // here pads for it. The column scrolls rather than overflows at large
    // Arabic text scales.
    return AppDialogShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s22,
          AppSpacing.s22,
          AppSpacing.s22,
          AppSpacing.s18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title ?? tr.renameConversation,
              style: Fig.t(
                context,
                size: FigMetrics.fontFig23,
                weight: FontWeight.w600,
                color: Fig.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppTextField(
              controller: _controller,
              hint: widget.hint ?? tr.renameConversationHint,
              textInputAction: TextInputAction.done,
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.s20),
            DialogActions(
              cancel: FigButton(
                label: tr.cancel,
                secondary: true,
                height: FigMetrics.size46,
                fontSize: AppFontSizes.dense,
                onPressed: () => Navigator.of(context).pop(),
              ),
              // Save stays disabled until the title is non-empty AND
              // actually different from the current one — renaming to the
              // same value is a wasted PATCH.
              confirm: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final next = value.text.trim();
                  final canSave =
                      next.isNotEmpty && next != widget.initial.trim();
                  return FigButton(
                    label: tr.save,
                    height: FigMetrics.size46,
                    fontSize: AppFontSizes.dense,
                    weight: FontWeight.w600,
                    onPressed: canSave ? _save : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
