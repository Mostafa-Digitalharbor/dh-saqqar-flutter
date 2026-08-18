import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import '../../../shared/widgets/title_trailing_row.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../conversations/view_model/conversations_state.dart';
import '../../conversations/widgets/conversation_action_handler.dart';
import '../../conversations/widgets/conversation_actions_sheet.dart';
import '../../../shared/widgets/tappable_surface.dart';

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
    await runConversationAction(
      context,
      cubit: cubit,
      c: c,
      action: action,
    );
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
      elevation: AppElevations.drawer,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s18,
                AppSpacing.s14,
                AppSpacing.s12,
                AppSpacing.s10,
              ),
              child: Row(
                children: [
                  // Tapping the wordmark goes home (/chats). Wrapped in a
                  // borderless InkWell so it reads as tappable without
                  // adding chrome around the logo.
                  InkWell(
                    onTap: widget.onGoHome,
                    borderRadius: AppRadius.buttonR,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                        vertical: AppSpacing.s4,
                      ),
                      child: SaqqarLogo(height: AppLogoSizes.drawer),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr.close,
                    icon: Icon(AppIcons.close, color: s.muted, size: AppIconSizes.action),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // ── New conversation CTA ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s4,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: _NewConversationButton(onTap: widget.onNewConversation),
            ),
            // ── Search ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s6,
                AppSpacing.s16,
                AppSpacing.s10,
              ),
              child: _DrawerSearchField(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
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
                    onLongPress: _onRowLongPress,
                  );
                },
              ),
            ),
            // ── Vault footer pill ─────────────────────────────────────
            Container(
              height: AppBorderWidths.hairline,
              color: s.cardBorder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s10,
                AppSpacing.s16,
                AppSpacing.s14,
              ),
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
    return TappableSurface(
      onTap: onTap,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: AppGradients.primaryCta,
          borderRadius: AppRadius.buttonR,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.plus, color: AppColors.onBrand, size: AppIconSizes.regular),
            const SizedBox(width: AppSpacing.s8),
            // Flexible: the drawer is `min(screenW * 0.86, 320)` wide, so on
            // a 320 px phone this button gets ~240 px and a bare `Text` here
            // is laid out unbounded — it overflowed by 38 px in English at
            // 1.0x, before Arabic or a larger text scale even came into it.
            Flexible(
              child: Text(
                context.tr.newConversation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onBrand,
                  fontSize: AppFontSizes.body,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppLetterSpacing.tight,
                ),
              ),
            ),
          ],
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
        color: s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.panel)),
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
          prefixIcon: Icon(AppIcons.search, size: AppIconSizes.small, color: s.muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: AppControlSizes.rowMin, minHeight: AppControlSizes.rowMin),
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
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
    required this.onLongPress,
  });

  final List<ConversationSummary> conversations;
  final String currentId;
  final ValueChanged<String> onPick;
  final ValueChanged<ConversationSummary> onLongPress;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s8,
        0,
        AppSpacing.s8,
        AppSpacing.s16,
      ),
      cacheExtent: AppScrollTuning.cacheExtent,
      children: [
        if (today.isNotEmpty) ...[
          _GroupLabel(text: context.tr.today),
          for (final c in today)
            _DrawerConversationRow(
              conversation: c,
              isActive: c.id == currentId,
              onTap: () => onPick(c.id),
              onLongPress: () => onLongPress(c),
            ),
        ],
        if (earlier.isNotEmpty) ...[
          _GroupLabel(text: context.tr.older),
          for (final c in earlier)
            _DrawerConversationRow(
              conversation: c,
              isActive: c.id == currentId,
              onTap: () => onPick(c.id),
              onLongPress: () => onLongPress(c),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s10,
        AppSpacing.s12,
        AppSpacing.s10,
        AppSpacing.s6,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: s.muted,
          fontWeight: FontWeight.w900,
          fontSize: AppFontSizes.chipLabel,
          letterSpacing: AppLetterSpacing.microCapsWide,
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
    required this.onLongPress,
  });

  final ConversationSummary conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TappableSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s10,
          AppSpacing.s9,
          AppSpacing.s10,
          AppSpacing.s9,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? s.brandCyan.withValues(alpha: AppAlphas.a12)
              : Colors.transparent,
          borderRadius: AppRadius.buttonR,
          border: Border.all(
            color: isActive
                ? s.brandCyan.withValues(alpha: AppAlphas.a40)
                : Colors.transparent,
          ),
        ),
        child: TitleTrailingRow.stamp(
          gap: 6,
          title: Column(
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
                  color: s.text,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                conversation.lastMessagePreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontSize: AppFontSizes.caption,
                ),
              ),
            ],
          ),
          // Locale-aware relative timestamp ("5 m ago" / "Yesterday" /
          // "May 8"), driven off the server's real `updatedAt` instead of
          // the demo's pre-baked string label.
          stamp: AppDateFormat.relative(context, conversation.updatedAt),
          stampStyle: context.text.labelSmall?.copyWith(
            color: s.muted,
            fontSize: AppFontSizes.chipLabel,
            fontWeight: FontWeight.w600,
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
    return TappableSurface(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: s.surface2.withValues(alpha: context.alpha(AppAlphaPairs.panel)),
          borderRadius: AppRadius.buttonR,
          border: Border.all(color: s.cardBorder),
        ),
        child: Row(
          children: [
            Icon(AppIcons.shield, color: s.brandCyan, size: AppIconSizes.regular),
            const SizedBox(width: AppSpacing.s10),
            // `Expanded` in place of `Text` + `Spacer`. The Spacer already
            // pushed the chevron to the end, but it could only claim space the
            // bare `Text` had not already taken — and at 1.4× text the label
            // takes more than the 275 px drawer has, overflowing by 9 px.
            // Expanding the label does the same job and lets it ellipsize.
            Expanded(
              child: Text(
                context.tr.credentialVault,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(AppIcons.chevronRight, color: s.muted, size: AppIconSizes.regular),
          ],
        ),
      ),
    );
  }
}
