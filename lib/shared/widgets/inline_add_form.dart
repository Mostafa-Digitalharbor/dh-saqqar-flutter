import 'package:flutter/material.dart';

import '../extensions/responsive_breakpoints.dart';
import 'app_text_field.dart';
import 'primary_button.dart';
import '../../core/theme/app_sizes.dart';

/// A one-field "add another" form: a text field and the button that submits
/// it, laid out side by side — and stacked when they no longer fit.
///
/// Vault's two sheets each had their own copy of this, structurally
/// identical down to the 10 px gap and the `ValueListenableBuilder` that
/// disables the button until something is typed. Both copies were also
/// wrong in the same way, which is what two copies buys you: the row was
/// `Expanded(field) + PrimaryButton`, and `PrimaryButton` sizes to its
/// label, so on a 320 px screen "Add environment" left the field less than
/// its minimum width and the row overflowed by 12 px. Neither sheet was in
/// the responsive sweep, so neither overflow had ever been rendered by a
/// test.
///
/// Stacking below [Breakpoint.tiny] is the fix rather than shrinking the
/// button: ellipsising a two-word action label ("Add environ…") loses the
/// only thing that says what the button does, and the field is already at
/// its floor. `responsive_breakpoints.dart` names this tier for exactly
/// this case — "two-column rows should stack".
class InlineAddForm extends StatelessWidget {
  const InlineAddForm({
    super.key,
    required this.controller,
    required this.hint,
    required this.buttonLabel,
    required this.onSubmit,
    this.enabled = true,
  });

  /// Drives both the field and the button's enabled state — the button
  /// listens to it directly, so the host does not have to rebuild on
  /// every keystroke.
  final TextEditingController controller;

  final String hint;
  final String buttonLabel;

  /// Called by the button and by the keyboard's "done" action, so the form
  /// can be completed without leaving the keyboard.
  final VoidCallback onSubmit;

  /// False while a write is already in flight. Gates the button only — the
  /// field stays editable so the user can keep typing the next name.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final field = AppTextField(
      hint: hint,
      controller: controller,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmit(),
    );

    // Rebuilds on each keystroke so the button enables the moment the field
    // stops being blank. Scoped to the button alone: a `setState` on the
    // host would rebuild the whole sheet, list included, per character.
    Widget button({required bool expand}) =>
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => PrimaryButton(
            label: buttonLabel,
            expand: expand,
            onPressed: enabled && value.text.trim().isNotEmpty
                ? onSubmit
                : null,
          ),
        );

    // Measured against the width this form ACTUALLY gets, not the device's.
    // Both call sites live inside a `Dialog`, which on a 320 px screen keeps
    // 40 px of inset on each side and hands its child ~240 px — so
    // `context.isTinyScreen`, which reads the window, answered "compact" for
    // a form that had a tiny screen's room. `responsive_breakpoints.dart`
    // names this case: prefer `breakpointForWidth` on the constraint when
    // the surrounding chrome may be narrower than the screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Larger text needs the room as much as a narrow screen does.
        final stack =
            breakpointForWidth(constraints.maxWidth).isTinyOrBelow ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2;
        if (!stack) {
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: AppSpacing.s10),
              button(expand: false),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            const SizedBox(height: AppSpacing.s10),
            // Full-width when stacked: a button sized to its label, alone
            // on a row, reads as floating rather than as this field's
            // action.
            button(expand: true),
          ],
        );
      },
    );
  }
}
