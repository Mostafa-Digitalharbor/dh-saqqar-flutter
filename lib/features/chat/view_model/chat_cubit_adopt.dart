part of 'chat_cubit.dart';

/// Adopting a snapshot while keeping local state, and the approvals view of it.
extension _ChatAdopt on ChatCubit {
  /// Adopts [incoming] while keeping the transcript and the paging position
  /// this cubit already holds, then caches and emits it.
  ///
  /// Both "keep what we have" branches of [_mergeSnapshot] need the identical
  /// six preserved fields and differ only in which [messages] survive. They
  /// were written out twice, which is the exact hazard the first of them
  /// documents: a hand-rolled snapshot silently drops every field it does not
  /// happen to list, and that is how `quotaExceeded` was lost — the server
  /// blocked a send for being over cap, the quota banner painted, and 1.5 s
  /// later the first poll wiped the flag and re-enabled Send.
  ///
  /// `copyWith` on the INCOMING snapshot is what fixes that: a new snapshot
  /// field is carried by default and can only be lost deliberately. Writing
  /// the list once means the second branch cannot fall behind the first.
  void _adoptPreserving(
    ConversationSnapshot incoming,
    ConversationSnapshot current,
    List<Message> messages,
  ) {
    final preserved = incoming.copyWith(
      messages: messages,
      approvals: _approvalsFor(incoming, current),
      carriesApprovals: true,
      // Deliberately the OLD cursor even when rows were stitched in: it is the
      // low-water mark of what we have definitely seen, so the next delta
      // re-delivers anything the window missed. Duplicates are deduped on
      // append; a skipped row would never come back.
      cursor: current.cursor,
      delta: false,
      // A poll asks for the DEFAULT window, so its `oldest_cursor` points at
      // the newest page — adopting it would rewind our paging position and
      // make the next "load earlier" re-fetch history we already have. Ours
      // describes how far back the user has actually read.
      oldestCursor: current.oldestCursor,
      hasMoreBefore: current.hasMoreBefore,
    );
    _emit(state.copyWith(data: DataSuccess(preserved)));
    _repo.cacheSnapshot(conversationId, preserved);
  }

  /// The approvals a merge result should carry.
  ///
  /// §4.3 says every non-message list is REPLACED on every response, delta
  /// included, and that is still what happens whenever the response contains
  /// an `approvals` key — an explicit `[]` clears the card the instant the
  /// server says nothing is pending, so a decision made here, on the web, or
  /// by a batch scope drops off exactly as fast as it did before.
  ///
  /// The one case that changes is the response that never mentions approvals
  /// at all. Replacing there is not honouring the contract, it is inventing an
  /// answer the server did not give — and the answer it invents is "nothing is
  /// pending", which is the one that hides the card.
  ///
  /// That distinction is load-bearing rather than theoretical, because of how
  /// this screen polls. Every tick after the first asks with `?since=`, so a
  /// deployment whose delta response omits the key can raise an approval, have
  /// it land in one snapshot, and have the next tick 1.5 s later wipe it —
  /// forever, since the poll never asks for a full snapshot again. From the
  /// user's side the agent stops with no explanation and the approval card
  /// never appears; pull-to-refresh ([load]) is the only thing that shows it,
  /// and only until the next tick.
  List<Approval> _approvalsFor(
    ConversationSnapshot incoming,
    ConversationSnapshot current,
  ) => incoming.carriesApprovals ? incoming.approvals : current.approvals;

  /// Whether older history exists, straight from the server's
  /// `has_more_before`.
  ///
  /// This used to be inferred — "did the page come back as full as we asked?"
  /// — which is only a proxy, and it broke at the server's 500-row `limit`
  /// ceiling: a capped response looks identical to "that's the whole
  /// transcript", so paging reported *done* while thousands of messages
  /// remained. The server knows the answer; ask it.
  ///
  /// Falls back to the old heuristic only for a snapshot decoded from an
  /// on-disk cache written before this field existed.
  bool _hasMoreFrom(ConversationSnapshot snapshot) =>
      snapshot.oldestCursor != null
      ? snapshot.hasMoreBefore
      : snapshot.messages.length >= ChatCubit._initialLimit;
}
