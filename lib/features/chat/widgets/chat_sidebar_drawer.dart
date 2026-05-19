import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../conversations/view_model/conversations_state.dart';

/// Brief §4.2 — sidebar drawer mounted on `Scaffold.drawer` of the chat
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
    required this.onClose,
  });

  final String currentConversationId;
  final ValueChanged<String> onPickConversation;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenVault;

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
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.lastMessagePreview.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Spec §10.2 — the drawer is no longer a Material `Drawer` widget;
    // it lives inside the chat's Stack as a plain Material+Container so
    // we control the slide animation + scrim ourselves (see chat_screen).
    return Material(
      color: s.surface,
      elevation: 8,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  const SaqqarLogo(height: 24),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr.close,
                    icon: Icon(AppIcons.close, color: s.muted, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // ── New conversation CTA ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _NewConversationButton(onTap: widget.onNewConversation),
            ),
            // ── Search ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: _DrawerSearchField(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 4),
            // ── Conversation list (scrollable) ────────────────────────
            // Subscribe to ConversationsCubit so the drawer reflects
            // live server state — new/renamed/deleted chats appear
            // without remount. The cubit's `load()` is fired once by
            // ConversationsScreen; opening the drawer doesn't re-fetch.
            Expanded(
              child: BlocBuilder<ConversationsCubit, ConversationsState>(
                builder: (context, state) {
                  return _ConversationGroupedList(
                    conversations: _filtered(state),
                    currentId: widget.currentConversationId,
                    onPick: widget.onPickConversation,
                  );
                },
              ),
            ),
            // ── Vault footer pill ─────────────────────────────────────
            Container(
              height: 1,
              color: s.cardBorder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _VaultFooterButton(onTap: widget.onOpenVault),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewConversationButton extends StatelessWidget {
  const _NewConversationButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonR,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: AppGradients.primaryCta,
            borderRadius: AppRadius.buttonR,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.plus, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                context.tr.newConversation,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSearchField extends StatelessWidget {
  const _DrawerSearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: s.cardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: context.text.bodySmall,
        decoration: InputDecoration(
          hintText: context.tr.searchConversations,
          hintStyle: context.text.bodySmall?.copyWith(color: s.muted),
          prefixIcon: Icon(AppIcons.search, size: 16, color: s.muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _ConversationGroupedList extends StatelessWidget {
  const _ConversationGroupedList({
    required this.conversations,
    required this.currentId,
    required this.onPick,
  });

  final List<ConversationSummary> conversations;
  final String currentId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.tr.noMatches,
            style: context.text.bodySmall?.copyWith(color: context.saqqar.muted),
          ),
        ),
      );
    }

    // Group into Today / Earlier via real DateTime math on
    // `updatedAt` — replaces the demo's string-label heuristic.
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final today = <ConversationSummary>[];
    final earlier = <ConversationSummary>[];
    for (final c in conversations) {
      if (!c.updatedAt.isBefore(startOfToday)) {
        today.add(c);
      } else {
        earlier.add(c);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        if (today.isNotEmpty) ...[
          _GroupLabel(text: context.tr.today),
          for (final c in today)
            _DrawerConversationRow(
              conversation: c,
              isActive: c.id == currentId,
              onTap: () => onPick(c.id),
            ),
        ],
        if (earlier.isNotEmpty) ...[
          _GroupLabel(text: context.tr.older),
          for (final c in earlier)
            _DrawerConversationRow(
              conversation: c,
              isActive: c.id == currentId,
              onTap: () => onPick(c.id),
            ),
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: s.muted,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerConversationRow extends StatelessWidget {
  const _DrawerConversationRow({
    required this.conversation,
    required this.isActive,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonR,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: isActive
                ? s.brandCyan.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: AppRadius.buttonR,
            border: Border.all(
              color: isActive
                  ? s.brandCyan.withValues(alpha: 0.40)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conversation.title.trim().isEmpty
                          ? context.tr.untitledConversation
                          : conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: isActive ? s.text : s.text,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.lastMessagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: s.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                // Locale-aware relative timestamp ("5 m ago" / "Yesterday"
                // / "May 8"), driven off the server's real `updatedAt`
                // instead of the demo's pre-baked string label.
                AppDateFormat.relative(context, conversation.updatedAt),
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultFooterButton extends StatelessWidget {
  const _VaultFooterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonR,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
            borderRadius: AppRadius.buttonR,
            border: Border.all(color: s.cardBorder),
          ),
          child: Row(
            children: [
              Icon(AppIcons.shield, color: s.brandCyan, size: 18),
              const SizedBox(width: 10),
              Text(
                context.tr.credentialVault,
                style: context.text.bodyMedium?.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: s.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
