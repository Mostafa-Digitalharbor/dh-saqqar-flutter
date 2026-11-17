import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/fig/fig.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../conversations/view_model/conversations_state.dart';
import '../../conversations/widgets/conversation_action_handler.dart';
import '../../conversations/widgets/conversation_actions_sheet.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/format/plain_preview.dart';
import '../../../shared/widgets/auto_direction_text.dart';

/// Redesigned (figma-design / Light) "Chats" panel — sidebar drawer mounted on `Scaffold.drawer` of the chat
/// screen. Opens from the start side via the AppBar hamburger.
///
/// Carries the same quick-switch surface the desktop sidebar does:
///
///   • Saqqar wordmark (logo)
///   • "+ New conversation" pill
///   • Search field
///   • Conversation list grouped by Today / Earlier
///   • "Credential Vault" pill at the bottom (footer)
///
/// All actions delegate to callbacks so the chat screen owns navigation
/// (drawer closes itself + jumps to the picked route). Pure
/// presentational — no controller wiring inside.
class ChatSidebarDrawer extends StatefulWidget {
  const ChatSidebarDrawer({
    super.key,
    required this.currentConversationId,
    required this.onPickConversation,
    required this.onNewConversation,
    required this.onOpenVault,
    required this.onGoHome,
    required this.onClose,
  });

  final String currentConversationId;
  final ValueChanged<String> onPickConversation;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenVault;

  /// Fired when the user taps the Saqqar wordmark at the top of the
  /// drawer — the chat screen closes the drawer and jumps to /chats
  /// ("home"). Delegated like every other navigation action so the
  /// screen keeps sole ownership of routing.
  final VoidCallback onGoHome;

  /// Fired when the user taps the X button. The drawer lives inside
  /// the chat screen's Stack (NOT a route) so we can't `Navigator.pop`
  /// it — that would pop the chat route itself and bounce the user
  /// back to /chats. The chat screen flips its local `_sidebarOpen`
  /// flag instead, which triggers the slide-out animation.
  final VoidCallback onClose;

  @override
  State<ChatSidebarDrawer> createState() => _ChatSidebarDrawerState();
}

class _ChatSidebarDrawerState extends State<ChatSidebarDrawer> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Long-press on a drawer row opens the same Pin / Rename / Share /
  /// Archive / Delete sheet a long-press on a conversation card does, and
  /// routes the choice through the shared handler so the flows are identical
  /// (rename dialog, OS share sheet, delete confirm). The drawer stays open
  /// underneath — the sheet floats above it — so the user lands back on the
  /// list after acting. The list is BlocBuilder-driven, so a rename/archive
  /// reflects live without any manual refresh here.
  Future<void> _onRowLongPress(ConversationSummary c) async {
    final cubit = context.read<ConversationsCubit>();
    final action = await ConversationActionsSheet.show(
      context,
      conversation: c,
      isPinned: cubit.isPinned(c.id),
    );
    if (action == null || !mounted) return;
    await runConversationAction(context, cubit: cubit, c: c, action: action);
  }

  /// Filters by title / last-message preview — same shape the Chats
  /// list uses, so a search query that worked there still works inside
  /// this drawer. Reads from [ConversationsCubit] so the list reflects
  /// real server data (no demo seed). Archived rows are excluded — the
  /// drawer is a quick-switcher, not a full archive browser.
  List<ConversationSummary> _filtered(ConversationsState state) {
    final data = state.data.dataOrNull;
    if (data == null) return const [];
    final q = _search.text.trim().toLowerCase();
    final visible = data.ordered.where((c) => !c.isArchived);
    if (q.isEmpty) return visible.toList();
    return visible
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              c.lastMessagePreview.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // A light card hung from the start edge: rounded trailing corners, a soft
    // shadow, "Chats" + close, the search pill, the New Chat button and the
    // recent-conversations list.
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadiusDirectional.only(
            topEnd: Radius.circular(40),
            bottomEnd: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: Fig.drawerShadow,
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr.figChats,
                        style: Fig.t(
                          context,
                          size: 26,
                          weight: FontWeight.w700,
                          color: Fig.navy,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Tooltip(
                        message: context.tr.close,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Fig.hairline),
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: 19,
                            color: Fig.navy,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Fig.hairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.search,
                        size: 17,
                        color: Fig.muted,
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: Fig.t(context, size: 13, color: Fig.navy),
                          decoration: InputDecoration(
                            hintText:
                                context.tr.figSearchContactsOrConversations,
                            hintStyle: Fig.t(
                              context,
                              size: 13,
                              color: Fig.muted,
                            ),
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GestureDetector(
                  onTap: widget.onNewConversation,
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Fig.tintBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.squarePen,
                          size: 16,
                          color: Fig.blue,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            context.tr.figNewChat,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Fig.t(
                              context,
                              size: 14,
                              weight: FontWeight.w600,
                              color: Fig.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: BlocBuilder<ConversationsCubit, ConversationsState>(
                  builder: (context, state) {
                    final list = _filtered(state);
                    return _ConversationList(
                      conversations: list,
                      currentId: widget.currentConversationId,
                      onPick: widget.onPickConversation,
                      onLongPress: _onRowLongPress,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.currentId,
    required this.onPick,
    required this.onLongPress,
  });

  final List<ConversationSummary> conversations;
  final String currentId;
  final ValueChanged<String> onPick;
  final ValueChanged<ConversationSummary> onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.figRecentConversations,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(
                    context,
                    size: 11.5,
                    color: Fig.muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                context.tr.figChats2(conversations.length),
                style: Fig.t(context, size: 12, color: Fig.blue),
              ),
            ],
          ),
        ),
        if (conversations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Center(
              child: Text(
                context.tr.noMatches,
                style: Fig.t(context, size: 13, color: Fig.muted),
              ),
            ),
          ),
        for (final c in conversations)
          _ConversationRow(
            conversation: c,
            isActive: c.id == currentId,
            onTap: () => onPick(c.id),
            onLongPress: () => onLongPress(c),
          ),
      ],
    );
  }
}

const _avatarPalette = [
  Color(0xFF2A5598),
  Color(0xFF5B3E8B),
  Color(0xFF1F6B6B),
  Color(0xFF7A5230),
];

String _initials(String title) {
  final parts = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  final ConversationSummary conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final title = c.title.trim().isEmpty
        ? context.tr.untitledConversation
        : c.title;
    final color = _avatarPalette[c.id.hashCode.abs() % _avatarPalette.length];
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: isActive ? Fig.tintBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _initials(title),
                  style: Fig.t(
                    context,
                    size: 12,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(
                      context,
                      size: 15,
                      weight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: Fig.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  AutoDirectionText(
                    plainPreview(c.lastMessagePreview),
                    // Aligned with the title above, not with the preview's own script.
                    textAlign: Directionality.of(context) == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Fig.t(context, size: 12.5, color: Fig.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              AppDateFormat.relative(context, c.updatedAt),
              style: Fig.t(context, size: 11.5, color: Fig.muted),
            ),
          ],
        ),
      ),
    );
  }
}
