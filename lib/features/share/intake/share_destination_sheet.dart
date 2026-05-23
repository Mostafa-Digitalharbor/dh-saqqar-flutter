import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../chat/widgets/chat_sheet.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../conversations/view_model/conversations_state.dart';

/// Result returned by [ShareDestinationSheet.show]. Drives the bootstrap's
/// post-pick navigation:
///   * `id == null` → start a new chat (`/chats/<sentinel>`).
///   * `id != null` → push that existing conversation route.
/// The bottom sheet returns `null` (not a `ShareDestination`) when the
/// user dismisses without choosing — bootstrap clears the staged files
/// in that branch.
class ShareDestination {
  /// Sentinel for "create a fresh conversation when the user picks New chat".
  const ShareDestination.newChat() : id = null;

  /// Existing conversation pick.
  const ShareDestination.existing(String this.id);

  final String? id;
  bool get isNew => id == null;
}

/// Bottom sheet shown when the system share sheet hands files to Saqqar.
///
/// Lists active conversations (newest first) plus a prominent "Start a new
/// chat" row. The list itself comes from [ConversationsCubit]; if the cubit
/// hasn't loaded yet the sheet triggers a [ConversationsCubit.load] and
/// shows a small spinner so the user gets the list as soon as the request
/// returns.
class ShareDestinationSheet extends StatefulWidget {
  const ShareDestinationSheet({
    super.key,
    required this.fileCount,
  });

  /// Used in the subtitle ("3 files from another app") so the user can
  /// double-check they're attaching the right batch before picking.
  final int fileCount;

  static Future<ShareDestination?> show(
    BuildContext context, {
    required int fileCount,
  }) {
    return showModalBottomSheet<ShareDestination>(
      context: context,
      isScrollControlled: true,
      // Tapping the scrim is "cancel share" — the bootstrap treats a
      // null return as a deliberate decline and drops the staged files.
      isDismissible: true,
      builder: (_) => ShareDestinationSheet(fileCount: fileCount),
    );
  }

  @override
  State<ShareDestinationSheet> createState() => _ShareDestinationSheetState();
}

class _ShareDestinationSheetState extends State<ShareDestinationSheet> {
  @override
  void initState() {
    super.initState();
    // The Chats tab may not have been visited yet (e.g. user shared from
    // WhatsApp into a cold-started app), in which case the cubit is in
    // `DataIdle` and would render an empty list forever. Kick a load if
    // there's nothing to show yet.
    final cubit = context.read<ConversationsCubit>();
    if (cubit.state.data.dataOrNull == null && !cubit.state.actionInFlight) {
      cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final subtitle = widget.fileCount <= 1
        ? tr.shareCountFile
        : tr.shareCountFiles.replaceFirst(
            '{count}',
            widget.fileCount.toString(),
          );

    return ChatSheet(
      title: tr.shareSheetTitle,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
          child: Text(
            tr.shareSheetSubtitle,
            style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
          child: Text(
            subtitle,
            style: context.text.labelSmall?.copyWith(
              color: s.brandCyan,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        _NewChatRow(
          onTap: () => Navigator.of(context).pop(const ShareDestination.newChat()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: s.border, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            tr.shareExistingChats.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              fontSize: 10,
            ),
          ),
        ),
        BlocBuilder<ConversationsCubit, ConversationsState>(
          builder: (context, state) {
            final data = state.data.dataOrNull;
            if (data == null) {
              if (state.data.isLoading) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: s.brandCyan,
                      ),
                    ),
                  ),
                );
              }
              return _EmptyHint(text: tr.shareNoConversations);
            }
            final active = data.conversations
                .where((c) => !c.isArchived)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            if (active.isEmpty) {
              return _EmptyHint(text: tr.shareNoConversations);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final conv in active)
                  _ConversationRow(
                    conversation: conv,
                    onTap: () => Navigator.of(context).pop(
                      ShareDestination.existing(conv.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NewChatRow extends StatelessWidget {
  const _NewChatRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.brandCyan.withValues(alpha: 0.45)),
            color: s.brandCyan.withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.brandCyan.withValues(alpha: 0.18),
                ),
                child: Icon(AppIcons.plus, color: s.brandCyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr.shareNewChat,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(AppIcons.chevronRight, color: s.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final preview = conversation.lastMessagePreview;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.surface2,
                  border: Border.all(color: s.border),
                ),
                child: Icon(AppIcons.chats, size: 14, color: s.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conversation.title.isEmpty
                          ? context.tr.startConversation
                          : conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: s.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, color: s.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(color: s.muted, height: 1.4),
      ),
    );
  }
}
