import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'conversation_action.dart';

/// Overflow menu (kebab) on each conversation row: rename / share / archive /
/// delete. The "delete" entry is tinted danger to set expectations.
class ConversationRowMenu extends StatelessWidget {
  const ConversationRowMenu({super.key, required this.onAction});

  final ValueChanged<ConversationAction> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ConversationAction>(
      tooltip: context.tr.conversationActions,
      icon: Icon(AppIcons.more, color: context.saqqar.muted, size: 20),
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ConversationAction.rename,
          child: _MenuRow(icon: AppIcons.edit, label: context.tr.rename),
        ),
        PopupMenuItem(
          value: ConversationAction.share,
          child: _MenuRow(icon: AppIcons.share, label: context.tr.shareLink),
        ),
        PopupMenuItem(
          value: ConversationAction.archive,
          child: _MenuRow(icon: AppIcons.archive, label: context.tr.archive),
        ),
        PopupMenuItem(
          value: ConversationAction.delete,
          child: _MenuRow(
            icon: AppIcons.trash,
            label: context.tr.delete,
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.saqqar.danger : context.saqqar.text;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
