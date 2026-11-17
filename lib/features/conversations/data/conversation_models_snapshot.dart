part of 'conversation_models.dart';

/// Full response body for `GET /api/v1/conversations/<id>/` (and the
/// snapshot-returning variants of `…/messages/`, `…/pending-actions/dismiss/`).
///
/// Polling rules — REPLACE local copies of every list field here on every
/// snapshot, never merge (mobile API §4.3). Only [messages] is appended
/// (and only when `delta=true`).
/// Value-equal (see [props]): a poll that returns a snapshot identical to the
/// one already on screen compares equal, so `ChatCubit`'s `emit` is a no-op
/// and the chat screen does not rebuild. With a 1.5 s polling cadence that is
/// the difference between rebuilding the whole chat tree ~40×/min and
/// rebuilding it only when something actually changed — the single biggest
/// idle-CPU saving on low-end devices.
@immutable
class ConversationSnapshot extends Equatable {
  const ConversationSnapshot({
    required this.conversation,
    required this.messages,
    required this.delta,
    this.cursor,
    this.oldestCursor,
    this.hasMoreBefore = false,
    this.approvals = const [],
    this.artifacts = const [],
    this.availableCredentials = const [],
    this.disabledCredentials = const [],
    this.pendingActions = const [],
    this.quotaExceeded,
    this.carriesApprovals = true,
  });

  final Conversation conversation;
  final List<Message> messages;

  /// Set to the exceeded window (`day | week | month`) when the server
  /// blocked the run because the user is over a usage cap. `null` otherwise.
  /// The assistant message already carries the bilingual limit notice; this
  /// signal lets the UI add an upgrade CTA and block further sends (Gap B).
  final QuotaWindow? quotaExceeded;

  /// ISO timestamp of the latest message in the conversation. Pass back
  /// as `?since=` on the next poll. `null` when the conversation has no
  /// messages yet.
  final DateTime? cursor;

  /// `true` when the snapshot was filtered by `?since` (so [messages]
  /// only carries new rows). `false` for full snapshots.
  final bool delta;

  /// Opaque cursor pointing at the OLDEST message in this page, in the form
  /// `<iso-timestamp>|<message-id>`. Pass it back as `?before=` to fetch the
  /// page before this one.
  ///
  /// This is how backwards paging is meant to work, and it is the only way
  /// that scales: `?limit=` is capped at 500 server-side, so the client's old
  /// "ask for a bigger window each time" strategy could never reach past the
  /// most recent 500 messages of a conversation — on a 5,000-message chat
  /// that stranded most of the history. Verified against production
  /// 2026-07-25.
  final String? oldestCursor;

  /// Whether messages exist before [oldestCursor]. Server-authoritative, so
  /// the client no longer has to infer "is there more?" from whether a page
  /// came back full — an inference that broke exactly at the `limit` ceiling.
  final bool hasMoreBefore;

  final List<Approval> approvals;
  final List<Artifact> artifacts;
  final List<Credential> availableCredentials;
  final List<String> disabledCredentials;
  final List<PendingAction> pendingActions;

  /// Whether the payload this was decoded from actually CARRIED an
  /// `approvals` key — as opposed to sending `approvals: []`.
  ///
  /// The two are wire-identical after decoding and mean opposite things. An
  /// explicit empty list is the server saying "nothing is pending"; a missing
  /// key is the server not talking about approvals on this response at all,
  /// and [ChatCubit] must not read the second as the first. It did, and that
  /// is a way for an approval card to be *unable* to appear: the poll loop
  /// always asks with `?since=`, so if a delta response omits the key, every
  /// tick after the approval is raised wipes it again 1.5 s later and the one
  /// control that can unblock the run never survives long enough to be seen.
  ///
  /// Defaults to `true` so a hand-built snapshot (tests, the merge result)
  /// carries an authoritative list, and is deliberately **not** in [props]:
  /// it describes the transport, not the conversation, and the merge always
  /// resolves it to `true`, so no two states can differ by it alone.
  final bool carriesApprovals;

  factory ConversationSnapshot.fromJson(Map<String, dynamic> json) {
    // The `conversation` object is required. Guard it so a snapshot missing
    // the key surfaces a clear "couldn't load this conversation" failure
    // upstream instead of an opaque TypeError.
    final conv = json['conversation'];
    if (conv is! Map<String, dynamic>) {
      throw const FormatException('snapshot missing "conversation" object');
    }
    return ConversationSnapshot(
      conversation: Conversation.fromJson(conv),
      // Every list below goes through [_parseRows], which skips a bad element
      // instead of aborting the parse of the ENTIRE snapshot.
      //
      // This block used to claim that protection and not have it. `whereType`
      // only filters elements that aren't maps; a row that IS a map but whose
      // fields are the wrong shape — an `id` the server sent as a number, or
      // omitted — throws out of `fromJson`, and the throw travels all the way
      // up through `getSnapshot`. On the poll path `_pollOnce` catches that
      // and logs a warning nobody sees, so ONE malformed approval row silently
      // froze the whole chat: no approval card, no new messages, and no error
      // to explain it, on every tick for as long as the row was pending.
      messages: _parseRows(json['messages'], Message.fromJson, 'message'),
      cursor: _parseDate(json['cursor']),
      // Kept as a raw string, never parsed: it is an opaque
      // `<iso-timestamp>|<message-id>` pair that goes straight back to the
      // server as `?before=`. Splitting it would invite reformatting it.
      oldestCursor: (json['oldest_cursor'] as String?)?.trim(),
      hasMoreBefore: json['has_more_before'] as bool? ?? false,
      delta: json['delta'] as bool? ?? false,
      approvals: _parseRows(json['approvals'], Approval.fromJson, 'approval'),
      // Absent key ≠ empty list. See [carriesApprovals].
      carriesApprovals: json.containsKey('approvals'),
      artifacts: _parseRows(json['artifacts'], Artifact.fromJson, 'artifact'),
      availableCredentials: _parseRows(
        json['available_credentials'],
        Credential.fromJson,
        'credential',
      ),
      disabledCredentials: (json['disabled_credentials'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      pendingActions: _parseRows(
        json['pending_actions'],
        PendingAction.fromJson,
        'pending action',
      ),
      // Read from `conversation.quota.kind` FIRST, with the top-level
      // `quota_exceeded` kept only as a fallback.
      //
      // The top level is where this used to look, and production does not
      // send it — verified 2026-07-25, the snapshot has no `quota_exceeded`
      // key at all. What it does send is
      // `conversation.quota = {kind, token_balance}`, `kind` being null while
      // the user is under their cap. So the over-quota banner and the
      // send-blocking it drives have never once been able to fire.
      //
      // `fromWire` returns null for anything it doesn't recognise, so if
      // `kind` turns out to use different strings than day/week/month this
      // degrades to exactly today's behaviour rather than misfiring.
      quotaExceeded: QuotaWindow.fromWire(
        _quotaKind(conv) ?? json['quota_exceeded'] as String?,
      ),
    );
  }

  /// Returns a copy with selected fields overridden. Used by ChatCubit
  /// to swap the inner [Conversation] when an optimistic flag flip
  /// needs to land in the snapshot without re-fetching the full body.
  ConversationSnapshot copyWith({
    Conversation? conversation,
    List<Message>? messages,
    DateTime? cursor,
    String? oldestCursor,
    bool? hasMoreBefore,
    bool? delta,
    List<Approval>? approvals,
    List<Artifact>? artifacts,
    List<Credential>? availableCredentials,
    List<String>? disabledCredentials,
    List<PendingAction>? pendingActions,
    QuotaWindow? quotaExceeded,
    bool? carriesApprovals,
  }) {
    return ConversationSnapshot(
      carriesApprovals: carriesApprovals ?? this.carriesApprovals,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      cursor: cursor ?? this.cursor,
      oldestCursor: oldestCursor ?? this.oldestCursor,
      hasMoreBefore: hasMoreBefore ?? this.hasMoreBefore,
      delta: delta ?? this.delta,
      approvals: approvals ?? this.approvals,
      artifacts: artifacts ?? this.artifacts,
      availableCredentials: availableCredentials ?? this.availableCredentials,
      disabledCredentials: disabledCredentials ?? this.disabledCredentials,
      pendingActions: pendingActions ?? this.pendingActions,
      quotaExceeded: quotaExceeded ?? this.quotaExceeded,
    );
  }

  @override
  List<Object?> get props => [
    conversation,
    messages,
    quotaExceeded,
    cursor,
    oldestCursor,
    hasMoreBefore,
    delta,
    approvals,
    artifacts,
    availableCredentials,
    disabledCredentials,
    pendingActions,
  ];
}
