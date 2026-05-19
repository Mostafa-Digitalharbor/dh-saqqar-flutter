import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';

/// Single-field dialog used for renaming a conversation. Returns the
/// trimmed new title on Save, or null on Cancel / outside-tap. Empty
/// values close the dialog without a result so the caller treats it as
/// "no change".
///
/// Built on plain [Dialog] (not [AlertDialog]) because Saqqar's
/// PrimaryButton / GhostButton internally use `LayoutBuilder` for
/// responsive sizing, and `AlertDialog.actions` queries intrinsic
/// dimensions on its children — a combination Flutter explicitly
/// disallows ("LayoutBuilder does not support returning intrinsic
/// dimensions"). The custom Dialog body sidesteps the intrinsic-sizing
/// path entirely by using explicit constraints.
class RenameConversationDialog extends StatefulWidget {
  const RenameConversationDialog({super.key, required this.initial});

  final String initial;

  static Future<String?> show(
    BuildContext context, {
    required String initial,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => RenameConversationDialog(initial: initial),
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
    final s = context.saqqar;

    // Flutter's [Dialog] already adds `MediaQuery.viewInsets` to its
    // own padding when computing position — that floats the whole
    // dialog above the keyboard automatically. The old AnimatedPadding
    // here was duplicating that work by injecting `viewInsets.bottom`
    // INTO the dialog body, which stretched the card by the keyboard
    // height and made it look like a tall blank panel.
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalR),
      child: SizedBox(
        width: 360,
        // Wrap in a scroll view so the column never overflows when
        // the Arabic font + system text-scaling (1.25x+) pushes the
        // header/buttons past the dialog's max height. On a normal
        // device the content fits and no scrollbar is shown.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.brandCyan.withValues(alpha: 0.14),
                        borderRadius: AppRadius.buttonR,
                      ),
                      child: Icon(AppIcons.edit, color: s.brandCyan, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr.renameConversation,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _controller,
                  hint: context.tr.renameConversationHint,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GhostButton(
                      label: context.tr.cancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    PrimaryButton(
                      label: context.tr.save,
                      icon: AppIcons.save,
                      onPressed: _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }
}
