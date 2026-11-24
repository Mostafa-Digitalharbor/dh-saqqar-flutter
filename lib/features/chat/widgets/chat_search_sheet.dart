import '../../../shared/fig/fig.dart' show showLightSheet;
import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/chat_view_models.dart';

/// The in-conversation search sheet — the design's header search affordance.
///
/// Filters the currently-loaded transcript by substring and lists the hits
/// newest-first. Deliberately separate from the message lane: it reads a
/// snapshot of the messages handed to it and touches none of the scroll,
/// paging or anchor state, which is what let it move out of
/// `_ChatScreenState` without carrying any of it along.
///
/// Searches what is LOADED, not what exists. A conversation pages its history
/// in as the user scrolls, so a term only present in messages that have never
/// been fetched will not be found — the alternative is a server-side search
/// endpoint, which the API does not offer.
class ChatSearchSheet {
  ChatSearchSheet._();

  /// Opens the sheet over [context] and returns when it closes.
  ///
  /// The controller is created and disposed HERE rather than inside the
  /// builder. An earlier revision built it inside `builder:` and never
  /// disposed it, leaking one `TextEditingController` per search-open for the
  /// lifetime of the app — the `finally` is what makes that impossible to
  /// repeat.
  static Future<void> show(
    BuildContext context, {
    required List<ChatMessage> messages,
  }) async {
    final s = context.saqqar;
    final controller = TextEditingController();
    try {
      await showLightSheet<void>(
        context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              // Scoped accessor — wholesale `MediaQuery.of` would rebuild this
              // sheet on every unrelated MediaQuery change (text scale,
              // brightness, padding) when only the keyboard inset matters.
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: AppFractions.searchSheetInitial,
              minChildSize: AppFractions.searchSheetMin,
              maxChildSize: AppFractions.searchSheetMax,
              expand: false,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setSheetState) {
                    final q = controller.text.trim().toLowerCase();
                    final hits = q.isEmpty
                        ? const <ChatMessage>[]
                        : messages
                              .where((m) => m.content.toLowerCase().contains(q))
                              .toList()
                              .reversed
                              .toList();
                    return Column(
                      children: [
                        const SizedBox(height: AppSpacing.s8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s16,
                            AppSpacing.s14,
                            AppSpacing.s16,
                            AppSpacing.s10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.search,
                                size: AppIconSizes.regular,
                                color: s.muted,
                              ),
                              const SizedBox(width: AppSpacing.s10),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  onChanged: (_) => setSheetState(() {}),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: context.tr.searchInConversation,
                                  ),
                                ),
                              ),
                              if (q.isNotEmpty)
                                Text(
                                  '${hits.length}',
                                  style: context.text.labelMedium?.copyWith(
                                    color: s.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Divider(
                          color: s.border,
                          height: AppBorderWidths.hairline,
                        ),
                        Expanded(
                          child: q.isEmpty
                              ? Center(
                                  child: Text(
                                    context.tr.searchMessagesHint,
                                    style: context.text.bodyMedium?.copyWith(
                                      color: s.muted,
                                    ),
                                  ),
                                )
                              : hits.isEmpty
                              ? Center(
                                  child: Text(
                                    context.tr.noResults,
                                    style: context.text.bodyMedium?.copyWith(
                                      color: s.muted,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.s8,
                                  ),
                                  itemCount: hits.length,
                                  separatorBuilder: (_, __) => Divider(
                                    color: s.border,
                                    height: AppBorderWidths.hairline,
                                    indent: AppSpacing.s16,
                                    endIndent: AppSpacing.s16,
                                  ),
                                  itemBuilder: (context, i) {
                                    final m = hits[i];
                                    return ListTile(
                                      leading: Icon(
                                        AppIcons.message,
                                        size: AppIconSizes.regular,
                                        color: s.brandCyan,
                                      ),
                                      title: Text(
                                        m.content.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.text.bodyMedium,
                                      ),
                                      subtitle: Text(
                                        m.time,
                                        style: context.text.labelSmall
                                            ?.copyWith(color: s.muted),
                                      ),
                                      onTap: () => Navigator.of(context).pop(),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}
