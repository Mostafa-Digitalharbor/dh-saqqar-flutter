import 'package:flutter/material.dart';

import '../../../navigation/home_shell.dart';
import '../../../shared/fig/fig.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../core/theme/app_colors.dart';

/// Dark rounded chat panel (gradient glow) above the white strip that holds
/// the floating tab bar — the "Chat" frame of the design.
class ChatFrame extends StatelessWidget {
  const ChatFrame({
    super.key,
    required this.header,
    required this.child,
    required this.onMore,
  });

  final Widget header;
  final Widget child;

  /// Opens the chat's own tools sheet — the same one the composer's tools
  /// button opens, so the ⋮ pill and that button never disagree.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    final bottomInset = mq.padding.bottom;
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: keyboard
                ? BorderRadius.zero
                : const BorderRadius.vertical(bottom: Radius.circular(FigMetrics.radFig40)),
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: FigBackdrop(
                dark: true,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      header,
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!keyboard)
          Container(
            color: AppColors.figWhite,
            padding: EdgeInsets.only(
              top: AppSpacing.s11,
              bottom: (bottomInset - AppSpacing.s10).clamp(12.0, 40.0),
            ),
            child: Center(
              child: FigNavBar(
                index: 1,
                onSelect: (i) {
                  if (i != 1) HomeShell.go(context, i);
                },
                onMore: onMore,
              ),
            ),
          ),
      ],
    );
  }
}
