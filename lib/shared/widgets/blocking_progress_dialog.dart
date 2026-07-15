import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Compact, undismissable "work in progress" pill — a thin indeterminate
/// bar in a small centred card.
///
/// Used for short irreversible flows (sign-out, account deletion) where the
/// user must not be able to interact with the tree mid-flight: [PopScope]
/// with `canPop: false` blocks the system back gesture, and callers pair it
/// with `barrierDismissible: false`.
///
/// Deliberately has no label. These flows finish in well under a second on
/// a normal connection, and a caption that flashes for 200 ms reads as a
/// glitch rather than information.
class BlockingProgressDialog extends StatelessWidget {
  const BlockingProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Cap at 220 but never exceed 80% of the viewport so the pill keeps a
    // margin on very narrow phones (≤280 px) instead of touching the edges.
    final screenW = MediaQuery.sizeOf(context).width;
    final dialogW = screenW * 0.8 < 220 ? screenW * 0.8 : 220.0;
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: dialogW,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: s.surface,
            borderRadius: AppRadius.inputR,
            border: Border.all(color: s.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.pillR,
            child: SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                backgroundColor: s.border.withValues(alpha: 0.35),
                valueColor: AlwaysStoppedAnimation<Color>(s.brandCyanStrong),
                minHeight: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
