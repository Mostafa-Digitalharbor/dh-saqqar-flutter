import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../extensions/context_extensions.dart';

/// The danger-tinted box every "this is about to do something destructive
/// or already went wrong" callout wears: a 6% danger fill, a 22%-alpha
/// danger hairline border, and a fixed padding — full width so it always
/// reads as a block, not an inline chip.
///
/// Extracted because the app-pulse error box (`PulseCardShell`'s
/// `_PulseError`) and the destructive-delete review list
/// (`ChatApprovalCard`'s `_DeleteRecordList`) built this exact decoration
/// twice, independently. Only their contents differ — one an icon + a
/// single message, the other a header plus a capped scroll list — so this
/// widget owns just the shell and takes [child] rather than assuming either
/// shape.
class DangerCallout extends StatelessWidget {
  const DangerCallout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: s.danger.withValues(alpha: AppAlphas.a06),
        borderRadius: AppRadius.smallR,
        border: Border.all(color: s.danger.withValues(alpha: AppAlphas.a22)),
      ),
      child: child,
    );
  }
}
