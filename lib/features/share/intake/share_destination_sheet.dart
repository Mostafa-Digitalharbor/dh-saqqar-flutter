import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../conversations/data/conversation_models.dart';
import '../../conversations/view_model/conversations_cubit.dart';
import '../../conversations/view_model/conversations_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/tappable_surface.dart';

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
    final subtitle = tr.shareCountFiles(widget.fileCount);

    return Scaffold(
      backgroundColor: s.bg,
      appBar: AppBar(
        backgroundColor: s.bg,
        elevation: AppElevations.none,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              AppSpacing.s24,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                child: Text(
                  tr.shareSheetSubtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: AppLineHeights.reading,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                child: Text(
                  subtitle,
                  style: context.text.labelSmall?.copyWith(
                    color: s.brandCyan,
                    fontWeight: FontWeight.w700,
                    letterSpacing: AppLetterSpacing.snug,
                  ),
                ),
              ),
              _NewChatRow(
                onTap: () =>
                    widget.onPick(const ShareDestination.newChat()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s18,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                child: Text(
                  tr.shareExistingChats.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: s.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: AppLetterSpacing.microCaps,
                    fontSize: AppFontSizes.chipLabel,
                  ),
                ),
              ),
              BlocBuilder<ConversationsCubit, ConversationsState>(
                builder: (context, state) {
                  final data = state.data.dataOrNull;
                  if (data == null) {
                    if (state.data.isLoading) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                        child: Center(
                          child: SizedBox(
                            width: AppControlSizes.spinnerMedium,
                            height: AppControlSizes.spinnerMedium,
                            child: CircularProgressIndicator(
                              strokeWidth: AppStrokeWidths.spinnerRegular,
                              color: s.brandCyan,
                            ),
                          ),
                        ),
                      );
                    }
                    // A FAILED load must not render "no conversations".
                    // That states as fact something we never found out,
                    // and it hides the retry — the user assumes an empty
                    // account and gives up on sharing.
                    final failure = state.data;
                    if (failure is DataFailure<ConversationsData>) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                        child: AppErrorState(
                          message: ApiErrorMapper.message(
                            context,
                            failure.error,
                          ),
                          onRetry: () =>
                              context.read<ConversationsCubit>().load(),
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
                          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
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
    return TappableSurface(
      radius: AppRadius.inputR,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s12,
          AppSpacing.s12,
          AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.inputR,
          border: Border.all(color: s.brandCyan.withValues(alpha: AppAlphas.a45)),
          color: s.brandCyan.withValues(alpha: AppAlphas.a08),
        ),
        child: Row(
          children: [
            Container(
              width: AppBoxSizes.headerControl,
              height: AppBoxSizes.headerControl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.brandCyan.withValues(alpha: AppAlphas.a18),
              ),
              child: Icon(AppIcons.plus, color: s.brandCyan, size: AppIconSizes.regular),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                context.tr.shareNewChat,
                style: context.text.titleSmall?.copyWith(
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

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final preview = conversation.lastMessagePreview;
    return TappableSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s10,
          AppSpacing.s12,
          AppSpacing.s10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppBoxSizes.destinationMark,
              height: AppBoxSizes.destinationMark,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.surface2,
                border: Border.all(color: s.border),
              ),
              child: Icon(AppIcons.chats, size: AppIconSizes.compact, color: s.muted),
            ),
            const SizedBox(width: AppSpacing.s12),
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
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: s.muted,
                        fontSize: AppFontSizes.footnote,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Icon(AppIcons.chevronRight, color: s.muted, size: AppIconSizes.small),
          ],
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
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s18,
        horizontal: AppSpacing.s4,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(color: s.muted, height: AppLineHeights.compact),
      ),
    );
  }
}
