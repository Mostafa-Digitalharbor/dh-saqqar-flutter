import '../../../shared/fig/fig.dart' show FigButton, showLightSheet;
import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import 'chat_sheet.dart';

/// "Task wording" — where a rough note is handed over to be structured.
///
/// This replaced a sheet of four hardcoded starter prompts. Those were put
/// there on the reasoning that the backend had no saved-prompt catalogue;
/// `/api/v1/prompt-memory/` is that catalogue, and it also writes the draft,
/// so the app no longer has to invent anything.
///
/// The field opens pre-filled with whatever context already exists (what is
/// half-typed in the composer, else the last thing the user said) because the
/// common case is someone who has already written the messy version and wants
/// it cleaned — retyping it would be the app ignoring what it can see.
class TaskWordingSheet extends StatefulWidget {
  const TaskWordingSheet({super.key, this.initialQuery = ''});

  final String initialQuery;

  /// Resolves to the rough text to structure, or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    String initialQuery = '',
  }) {
    return showLightSheet<String>(
      context,
      isScrollControlled: true,
      builder: (_) => TaskWordingSheet(initialQuery: initialQuery),
    );
  }

  @override
  State<TaskWordingSheet> createState() => _TaskWordingSheetState();
}

class _TaskWordingSheetState extends State<TaskWordingSheet> {
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _query.text.trim();
    if (text.isEmpty) {
      // The web toasts and refocuses rather than closing — an empty submit
      // is a slip, not a decision to cancel.
      AppToast.show(context, message: context.tr.promptCardNeedText);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return ChatSheet(
      title: tr.promptBankTitle,
      children: [
        Text(
          tr.promptBankSubtext,
          style: context.text.bodySmall?.copyWith(color: context.saqqar.muted),
        ),
        const SizedBox(height: AppSpacing.s14),
        AppTextField(
          label: tr.promptBankAskLabel,
          hint: tr.promptBankAskPlaceholder,
          controller: _query,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: AppSpacing.s14),
        FigButton.compact(
          label: tr.promptBankAskButton,
          expand: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
