import 'package:flutter/material.dart';

import '../../core/theme/app_sizes.dart';

/// The cancel / confirm button pair every dialog ends with.
///
/// Exists because the layout is not optional. A `Row` gives its children
/// unbounded width, so two buttons sized by their own labels will happily
/// measure wider than the dialog and overflow — silently on a wide test
/// surface, visibly on a 320 px phone, and sooner in Arabic or at 1.3× text
/// where the same labels are longer.
///
/// [ConfirmDialog], [DeleteApprovalConfirmDialog] and [LiveEnvWarningDialog]
/// each had the correct `Expanded` + gap + `Expanded` by hand;
/// [RenameConversationDialog] did not, and overflowed by 14 px at 320×568
/// (found by `overlay_responsive_sweep_test.dart`, 2026-08-04). Four copies of
/// a layout rule is three chances to get it wrong, so it lives here now.
///
/// Both halves are equal-width on purpose: the confirm button is not visually
/// larger than cancel, which is what keeps a destructive action from being the
/// easy default.
class DialogActions extends StatelessWidget {
  const DialogActions({
    super.key,
    required this.cancel,
    required this.confirm,
    this.gap = AppSpacing.s10,
  });

  /// The dismissing action — rendered first (start side), so it is the one
  /// under the thumb's reach and not the one under the cursor after a tap.
  final Widget cancel;

  /// The committing action.
  final Widget confirm;

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: cancel),
        SizedBox(width: gap),
        Expanded(child: confirm),
      ],
    );
  }
}
