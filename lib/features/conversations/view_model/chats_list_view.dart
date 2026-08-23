import 'package:flutter/foundation.dart';

import '../data/conversation_models.dart';
import 'conversations_state.dart';

/// Which slice of the Chats list the triage chips are showing.
enum ChatsFilterMode { all, pending, live }

/// The Chats list, already sliced for one `(data, query, mode)` triple.
///
/// **Why this is an object rather than three helper methods.** The screen used
/// to expose `_filter`, `_archived` and an inline pending count, and then pass
/// the first two DOWN into its body widget as callbacks. Both layers called
/// them: the outer builder filtered to get a row count for the subtitle, the
/// body filtered again to render, archived ran on top of that, and the
/// "needs approval" total was counted independently in each. Five full passes
/// over every conversation, per build — and a keystroke in the search box is
/// a build.
///
/// They are also three answers to ONE question, so deriving them separately
/// let them disagree: the subtitle's total and the rendered list each did
/// their own filtering, and only a reviewer reading both call sites could
/// tell they still matched.
///
/// [ChatsListView.of] walks the conversations **once** and returns every
/// slice the screen needs, so the numbers cannot drift from the rows and the
/// work happens once per build instead of five times.
@immutable
class ChatsListView {
  const ChatsListView({
    required this.active,
    required this.archived,
    required this.pendingCount,
  });

  /// Non-archived rows matching the query and the active triage chip — what
  /// the main list paginates and renders.
  final List<ConversationSummary> active;

  /// Archived rows matching the query. The search deliberately spans both
  /// buckets so "invoice" surfaces a match wherever it lives; the triage
  /// chip does NOT apply here — the archived card is its own shelf.
  final List<ConversationSummary> archived;

  /// Conversations with at least one pending approval, ignoring archived
  /// ones and ignoring the query.
  ///
  /// Deliberately **not** filtered by the search box: it is the badge on the
  /// "Needs approval" chip, i.e. how much work is waiting overall. Counting
  /// only matches would make the badge drop as the user typed, which reads
  /// as approvals disappearing.
  final int pendingCount;

  /// Derives every slice in a single pass.
  factory ChatsListView.of(
    ConversationsData data, {
    String query = '',
    ChatsFilterMode mode = ChatsFilterMode.all,
  }) {
    // Folded once, outside the loop — `matchesQuery` takes it pre-lowered.
    final needle = query.trim().toLowerCase();
    final active = <ConversationSummary>[];
    final archived = <ConversationSummary>[];
    var pending = 0;

    for (final c in data.ordered) {
      // The REAL needs-approval signal: at least one pending row for this
      // conversation in the flat `/approvals/?status=pending` feed. Read
      // once per conversation here and reused by both the count and the
      // filter below, rather than being looked up in two separate passes.
      final needsApproval = data.needsApproval(c.id);

      if (c.isArchived) {
        if (c.matchesQuery(needle)) archived.add(c);
        continue;
      }

      if (needsApproval) pending++;
      if (!c.matchesQuery(needle)) continue;

      final keep = switch (mode) {
        ChatsFilterMode.all => true,
        ChatsFilterMode.pending => needsApproval,
        ChatsFilterMode.live => c.isLive,
      };
      if (keep) active.add(c);
    }

    return ChatsListView(
      active: active,
      archived: archived,
      pendingCount: pending,
    );
  }

  /// The page at [pageIndex], [pageSize] rows long.
  List<ConversationSummary> page(int pageIndex, int pageSize) =>
      active.skip(pageIndex * pageSize).take(pageSize).toList();

  /// How many pages [active] spans at [pageSize]. Always at least one, so an
  /// empty list still renders a single (empty) page rather than zero pages.
  int pageCount(int pageSize) =>
      active.isEmpty ? 1 : (active.length + pageSize - 1) ~/ pageSize;
}
