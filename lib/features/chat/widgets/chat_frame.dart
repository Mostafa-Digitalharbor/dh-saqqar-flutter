import 'package:flutter/material.dart';

import '../../../navigation/home_shell.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/fig/tools_sheet.dart';

/// Dark rounded chat panel (gradient glow) above the white strip that holds
/// the floating tab bar — the "Chat" frame of the design.
class ChatFrame extends StatelessWidget {
  const ChatFrame({
    super.key,
    required this.header,
    required this.child,
    required this.taskPrep,
    required this.autoApprove,
    required this.onTaskPrep,
    required this.onAutoApprove,
  });

  final Widget header;
  final Widget child;
  final bool taskPrep;
  final bool autoApprove;
  final ValueChanged<bool> onTaskPrep;
  final ValueChanged<bool> onAutoApprove;

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
                : const BorderRadius.vertical(bottom: Radius.circular(40)),
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
            color: Colors.white,
            padding: EdgeInsets.only(
              top: 11,
              bottom: (bottomInset - 10).clamp(12.0, 40.0),
            ),
            child: Center(
              child: FigNavBar(
                index: 1,
                onSelect: (i) {
                  if (i != 1) HomeShell.go(context, i);
                },
                onMore: () => showSaqqarTools(
                  context,
                  taskPrep: taskPrep,
                  autoApprove: autoApprove,
                  onTaskPrep: onTaskPrep,
                  onAutoApprove: onAutoApprove,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
