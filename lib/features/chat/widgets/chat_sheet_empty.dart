import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Empty-state block used inside chat sheets when there are no actions to
/// review (no pending approvals, no open requests).
class ChatSheetEmpty extends StatelessWidget {
  const ChatSheetEmpty({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: s.success.withValues(alpha: 0.24)),
            ),
            child: Icon(AppIcons.success, color: s.success, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: s.muted),
          ),
        ],
      ),
    );
  }
}
