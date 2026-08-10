import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/colored_icon_box.dart';
import '../../../shared/widgets/dialog_actions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../data/delete_confirmation.dart';

/// Type-to-confirm gate in front of a destructive delete approval (web
/// parity — the web has required this since `renderDeleteApprovalCard`).
///
/// The user must type the localized phrase ("Delete 6" / "حذف 6") before the
/// approval is sent. Both locales' phrases are accepted whatever the UI
/// language, and Arabic-Indic digits are folded, so an Arabic keyboard's ٦
/// confirms just as well as a 6 — the failure mode this whole file exists to
/// avoid is an Arabic user who literally cannot type the required string.
///
/// Returns `true` only when the user typed a matching phrase and confirmed.
class DeleteApprovalConfirmDialog extends StatefulWidget {
  const DeleteApprovalConfirmDialog({
    super.key,
    required this.recordCount,
    this.serverPhrase,
  });

  final int recordCount;

  /// `Approval.confirmPhrase` when the server sent one.
  ///
  /// Accepted IN ADDITION to the two locale-built phrases, never instead of
  /// them. The server takes `delete N`, `حذف N` and `احذف N` interchangeably,
  /// so honouring only its canonical spelling would make the client stricter
  /// than the API for no gain — and would hand an Arabic user an English
  /// phrase to copy.
  final String? serverPhrase;

  static Future<bool> show(
    BuildContext context, {
    required int recordCount,
    String? serverPhrase,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => DeleteApprovalConfirmDialog(
        recordCount: recordCount,
        serverPhrase: serverPhrase,
      ),
    );
    return result ?? false;
  }

  @override
  State<DeleteApprovalConfirmDialog> createState() =>
      _DeleteApprovalConfirmDialogState();
}

class _DeleteApprovalConfirmDialogState
    extends State<DeleteApprovalConfirmDialog> {
  final _controller = TextEditingController();
  bool _showMismatch = false;

  /// Phrases accepted, in BOTH locales plus whatever the server named — see
  /// [confirmsDelete].
  List<String> get _accepted => [
        for (final locale in AppStrings.supported)
          AppStrings(locale).deleteConfirmPhrase(widget.recordCount),
        if (widget.serverPhrase case final p? when p.isNotEmpty) p,
      ];

  bool get _matches => confirmsDelete(_controller.text, _accepted);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final phrase = tr.deleteConfirmPhrase(widget.recordCount);

    return AppDialogShell(
      elevated: true,
      accent: AppDialogShell.dangerAccent(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ColoredIconBox(
                icon: AppIcons.trash,
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
              tr.deleteConfirmTitle,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr.deleteConfirmBody(widget.recordCount, phrase),
              style: context.text.bodyMedium?.copyWith(
                color: s.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _controller,
              hint: tr.deleteConfirmHint(phrase),
              autofocus: true,
              errorText: _showMismatch ? tr.deleteConfirmMismatch(phrase) : null,
              onChanged: (_) => setState(() => _showMismatch = false),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 20),
            DialogActions(
              cancel: GhostButton(
                label: tr.cancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              confirm: GhostButton(
                label: tr.approve,
                tone: GhostButtonTone.danger,
                // Stays live so a mistyped phrase gets an explanation
                // rather than a dead button the user has to guess about.
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    if (!_matches) {
      setState(() => _showMismatch = true);
      return;
    }
    Navigator.of(context).pop(true);
  }
}
