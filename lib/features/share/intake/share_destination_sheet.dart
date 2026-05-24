import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
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

/// Picker UI rendered as an **inline overlay** by [ShareIntentBootstrap].
///
/// Earlier revisions opened this as a bottom sheet, then as a fullscreen
/// `MaterialPageRoute`; both let the previously-open chat flash through
/// during the brief window between the share intent arriving and the
/// picker mounting (testers, 2026-05-24: "Saqqar opens on the chat I
/// was in"). The bootstrap now renders this widget directly inside a
/// `Stack` above `widget.child`, which makes the picker visible on the
/// SAME frame `ShareIntakeService.stage()` notifies its listeners —
/// no navigation, no route transition, no async window.
///
/// Callbacks instead of `Navigator.pop`:
///   * [onCancel] — user tapped the ✕ button (drops the staged batch).
///   * [onPick]   — user tapped a destination row (forwards to the
///                   bootstrap's deliver + navigate flow).
///
/// Layout:
///   * Title bar with the explicit Cancel button.
///   * Subtitle: "Pick a chat to attach N file(s) to".
///   * **Start a new chat** — cyan-tinted CTA row.
///   * **Existing chats** — full scrollable list, newest first.
///
/// The list comes from [ConversationsCubit]; if the cubit hasn't loaded
/// yet the page triggers a [ConversationsCubit.load] and shows a
/// spinner so the rows appear as soon as the fetch returns.
class ShareDestinationOverlayContent extends StatefulWidget {
  const ShareDestinationOverlayContent({
    super.key,
    required this.fileCount,
    required this.onCancel,
    required this.onPick,
  });

  /// Used in the subtitle ("3 files from another app") so the user can
  /// double-check they're attaching the right batch before picking.
  final int fileCount;

  /// Tapped on Cancel / system back. Bootstrap clears the staged files.
  final VoidCallback onCancel;

  /// Tapped on a row. Bootstrap forwards to `deliverTo()` + navigates.
  final ValueChanged<ShareDestination> onPick;

  @override
  State<ShareDestinationOverlayContent> createState() =>
      _ShareDestinationOverlayContentState();
}

class _ShareDestinationOverlayContentState
    extends State<ShareDestinationOverlayContent> {
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

    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(
        backgroundColor: s.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.close, color: s.text),
          tooltip: tr.cancel,
          onPressed: widget.onCancel,
        ),
        title: Text(
          tr.shareSheetTitle,
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  tr.shareSheetSubtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.45,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
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
                onTap: () =>
                    widget.onPick(const ShareDestination.newChat()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ConversationRow(
                            conversation: conv,
                            onTap: () => widget.onPick(
                              ShareDestination.existing(conv.id),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
