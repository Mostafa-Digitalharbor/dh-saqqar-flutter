part of 'conversations_screen.dart';

/// Grouping the list into dated sections and building the rows.
extension _ConversationRows on _ConversationsScreenState {
  /// Bucket a conversation into "Today / Yesterday / Previous 7 days /
  /// Older". Replaces the demo's string-label heuristic with real
  /// DateTime math.
  String _dateGroupKey(BuildContext context, ConversationSummary c) {
    final now = DateTime.now();
    final updated = c.updatedAt;
    final today = DateTime(now.year, now.month, now.day);
    final convDay = DateTime(updated.year, updated.month, updated.day);
    final daysDelta = today.difference(convDay).inDays;
    if (c.isArchived) return context.tr.dateGroupOlder;
    if (daysDelta == 0) return context.tr.dateGroupToday;
    if (daysDelta == 1) return context.tr.dateGroupYesterday;
    if (daysDelta <= 7) return context.tr.dateGroupPrevious7;
    return context.tr.dateGroupOlder;
  }

  List<Widget> _buildGroupedRows(List<ConversationSummary> rows) {
    final widgets = <Widget>[];
    String? currentGroup;
    // Real per-conversation meta (pending approvals + files) from the loaded
    // data — passed into each card so the counts are never fabricated.
    final data = context.read<ConversationsCubit>().state.data.dataOrNull;
    // Physical-direction mapping for the swipe gestures. We want "swipe
    // right = archive, swipe left = delete" regardless of locale, so we
    // resolve Flutter's directional [DismissDirection] against the current
    // text direction: startToEnd is a physical-right drag in LTR but a
    // physical-left drag in RTL.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // In LTR the startToEnd (background) edge is the archive/right side; in
    // RTL that same edge is the delete/left side.
    final startToEndIsArchive = !rtl;
    for (final entry in rows.asMap().entries) {
      final c = entry.value;
      final group = _dateGroupKey(context, c);
      if (group != currentGroup) {
        if (currentGroup != null) {
          widgets.add(const SizedBox(height: AppSpacing.s16));
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            // A Builder: this extension runs on the State's context, which sits
            // ABOVE the light theme FigPage pins on its body. Read from there,
            // the heading took the device's dark theme and came out white on the
            // light page.
            child: Builder(
              builder: (ctx) => Text(
                group,
                style: ctx.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
        currentGroup = group;
      }
      widgets.add(
        // Per-row RepaintBoundary: rows live in a plain Column (one sliver
        // child), so without this they share one layer — every card's shadow
        // blur re-rasterizes together on any rebuild, and a poll landing
        // mid-scroll repaints the whole list. Keyed by row id so the boundary
        // element (and the FadeSlideIn under it) is reused across rebuilds,
        // keeping the intro-once behaviour and caching each card's raster.
        RepaintBoundary(
          key: ValueKey('row-${c.id}'),
          child: FadeSlideIn(
            // Two keys are nested here on purpose. The outer `ValueKey`
            // identifies the FadeSlideIn slot so the intro animation only
            // fires for genuinely new rows. The inner `Dismissible` needs its
            // OWN unique key because the Dismissible widget tracks gesture
            // state per-key and asserts on duplicates.
            key: ValueKey('fade-${c.id}'),
            index: entry.key,
            child: Dismissible(
              key: ValueKey('dismiss-${c.id}'),
              // Two distinct horizontal gestures (request 2026-07-06):
              //   • swipe RIGHT → archive / unarchive
              //   • swipe LEFT  → delete (guarded by the Yes/No confirm)
              // The backgrounds are laid out against the resolved text
              // direction so each edge shows the action it will actually
              // trigger.
              direction: DismissDirection.horizontal,
              background: startToEndIsArchive
                  ? SwipeArchiveBackground(
                      alignment: AlignmentDirectional.centerStart,
                      archived: c.isArchived,
                    )
                  : const SwipeDeleteBackground(
                      alignment: AlignmentDirectional.centerStart,
                    ),
              secondaryBackground: startToEndIsArchive
                  ? const SwipeDeleteBackground(
                      alignment: AlignmentDirectional.centerEnd,
                    )
                  : SwipeArchiveBackground(
                      alignment: AlignmentDirectional.centerEnd,
                      archived: c.isArchived,
                    ),
              // Return false so Dismissible never unmounts the row itself —
              // archive is driven by the cubit's optimistic update, and
              // delete only proceeds after the confirm dialog resolves.
              // Returning true would double-animate + trip a "key reused"
              // assert on the next emit. The routed action fires regardless.
              confirmDismiss: (direction) async {
                // Physical-right drag = archive; physical-left = delete.
                final swipedRight =
                    (direction == DismissDirection.startToEnd) != rtl;
                if (swipedRight) {
                  onRowActionFromBuild(c, ConversationAction.archive);
                } else {
                  // Route through the shared handler so the delete confirm
                  // dialog (red "Yes") is identical to the kebab-menu path.
                  onRowActionFromBuild(c, ConversationAction.delete);
                }
                return false;
              },
              child: ConversationCard(
                conversation: c,
                pendingApprovals: data?.pendingApprovalsFor(c.id) ?? 0,
                filesCount: data?.filesFor(c.id) ?? 0,
                onTap: () => context.go(RouteNames.chatPath(c.id)),
                onAction: (action) => _handleRowAction(c, action),
              ),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.s10));
    }
    return widgets;
  }
}
