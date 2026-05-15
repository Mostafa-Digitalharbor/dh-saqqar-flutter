import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';

/// A single tappable row used inside the chat "more" sheet (rename, share,
/// archive, delete, plus the three top entry points: action center, approvals,
/// artifacts). Optional [color] tints both icon and label.
class ChatSheetItem extends StatelessWidget {
  const ChatSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final c = color ?? s.text;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 28, child: Icon(icon, size: 19, color: c)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.text.bodyMedium?.copyWith(
                    color: c,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
