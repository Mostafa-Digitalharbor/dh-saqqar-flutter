part of 'conversation_models.dart';

// NOTE: deliberately NOT `Equatable`. The Chats list renders a *relative*
// timestamp ("5 min ago") and a recency-derived `isLive` ring off
// [updatedAt], both of which are functions of the wall clock rather than of
// the row's fields. Value equality would make an unchanged poll a no-op emit
// and those labels would freeze until the server happened to change
// something. The chat snapshot path (which polls 10× faster and renders no
// clock-derived text) IS value-equal — see [ConversationSnapshot].
@immutable
class ConversationSummary {
  // Not `const` any more — see [_searchHaystack], which needs a `late final`
  // to memoize. Nothing constructed one as a const literal, so this costs
  // nothing at the call sites.
  ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.messageCount,
    this.lastMessagePreview = '',
    this.isRunning = false,
    this.projectName,
    this.environmentName,
    this.filesCount,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int messageCount;
  final String lastMessagePreview;

  /// Whether the agent is mid-run for this conversation on the SERVER — the
  /// Chats list uses it to show the live "Saqqar is working" indicator. Not
  /// persisted to the offline cache (ephemeral), so a cold start reads it as
  /// false until the first live fetch.
  ///
  /// Always false in practice today: `GET /conversations/` does NOT return
  /// `is_running` per row (verified against production 2026-07-25 — a row
  /// carries `created_at environment files_count id is_archived
  /// last_message_preview message_count project title updated_at`). The list
  /// therefore cannot show a running indicator for a conversation the user
  /// hasn't opened. See docs/MOBILE_BACKEND_GAPS_CORE.md §2.
  final bool isRunning;

  /// Real project / environment context.
  ///
  /// The list endpoint DOES carry both as of 2026-07-25 (verified against
  /// production: a row returns `project` and `environment` objects). This
  /// used to say the opposite, and that stale comment is what led the client
  /// to keep an N+1 enrichment pass — one snapshot fetch per row purely to
  /// recover these two strings — long after the backend had shipped them.
  ///
  /// Still nullable and still parsed defensively: a row for a conversation
  /// with no bound environment legitimately omits them, and the card must
  /// drop the project · environment line rather than invent a value.
  final String? projectName;
  final String? environmentName;

  /// Artifacts produced in THIS conversation, straight from the row.
  ///
  /// The client used to derive this by pulling the flat `/artifacts/` feed
  /// with `limit=100` and grouping by conversation. That feed is capped
  /// account-wide, so the derived number disagreed with the server's on
  /// **41 of 100 rows** on a real account (one row reports 188 artifacts; the
  /// truncated feed could only see 90). Measured 2026-07-25.
  ///
  /// Nullable so a deployment that doesn't send it renders no count rather
  /// than a wrong one.
  final int? filesCount;

  /// A conversation counts as "live" — green status ring on the card, and
  /// the `live` triage filter on the Chats screen — when it was last active
  /// within this window.
  ///
  /// Representative signal: the summary API carries no per-conversation
  /// live flag yet, so recency stands in for one.
  ///
  /// Lives on the model because the card and the screen each declared their
  /// own copy (`_kLiveWindow` and `kLiveWindow`) of the same two hours. The
  /// card's was deliberately private to keep it decoupled from the screen
  /// file — right instinct, wrong owner: the concept belongs to the data,
  /// so both can depend on it without depending on each other.
  static const liveWindow = Duration(hours: 2);

  bool get isLive => DateTime.now().difference(updatedAt) <= liveWindow;

  /// Lower-cased `title` + `lastMessagePreview`, the text the Chats search
  /// runs against — built **once per row**, on first use.
  ///
  /// The screen used to lower-case both fields inline, for every row, inside
  /// a filter it re-derived several times per build. With ~166 conversations
  /// and a preview that can run to a couple of hundred characters, a single
  /// keystroke in the search box allocated hundreds of throwaway strings and
  /// re-scanned the same rows. None of that input changes between builds, so
  /// none of it needed repeating: the row owns the text, so the row caches
  /// it.
  ///
  /// The two fields are joined by a newline rather than concatenated, so a
  /// query cannot match by straddling the boundary between a title and the
  /// preview underneath it — "invoice draft" must find a row that really
  /// says that, not one whose title ends in "invoice" above a preview
  /// starting with "draft".
  late final String _searchHaystack = '$title\n$lastMessagePreview'
      .toLowerCase();

  /// Whether this row matches [lowercaseQuery].
  ///
  /// Takes an **already lower-cased** query: the caller is looping over the
  /// whole list, so folding the needle once outside the loop is the point.
  /// An empty query matches everything, which is what "no search" means.
  bool matchesQuery(String lowercaseQuery) =>
      lowercaseQuery.isEmpty || _searchHaystack.contains(lowercaseQuery);

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      // Null-safe id — one malformed row must not throw and fail the WHOLE
      // Chats list (the app's home surface). Callers skip empty-id rows.
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      isArchived: json['is_archived'] as bool? ?? false,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      isRunning: json['is_running'] as bool? ?? false,
      projectName: _nameOf(json['project']) ?? json['project_name'] as String?,
      environmentName:
          _nameOf(json['environment']) ?? json['environment_name'] as String?,
      filesCount: (json['files_count'] as num?)?.toInt(),
    );
  }

  /// Serializes the row for the offline list cache (stale-while-revalidate
  /// on the Chats tab). Keeps the enriched `project` / `environment` names
  /// so a cold start paints the full row, tags included, before the live
  /// fetch lands. Round-trips through [fromJson] — the `*_name` keys are the
  /// flat shape that factory already reads.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_archived': isArchived,
    'message_count': messageCount,
    'last_message_preview': lastMessagePreview,
    if (projectName != null) 'project_name': projectName,
    if (environmentName != null) 'environment_name': environmentName,
    if (filesCount != null) 'files_count': filesCount,
  };

  /// The list endpoint doesn't carry project / environment, so the cubit
  /// enriches each row from its snapshot and rebuilds the summary with this.
  /// Only the two context fields are overridable — everything else is the
  /// server's list truth.
  ConversationSummary copyWith({
    String? projectName,
    String? environmentName,
    bool? isRunning,
  }) {
    return ConversationSummary(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived,
      messageCount: messageCount,
      lastMessagePreview: lastMessagePreview,
      isRunning: isRunning ?? this.isRunning,
      projectName: projectName ?? this.projectName,
      environmentName: environmentName ?? this.environmentName,
      filesCount: filesCount,
    );
  }
}

/// Pulls a human label out of a project / environment field, tolerating the
/// three shapes a backend might use: a bare string, a nested
/// `{id, name, …}` object, or `{slug, …}` when no display name is set.
/// Returns `null` when absent so the row omits the tag rather than ever
/// showing a fabricated value.
String? _nameOf(Object? value) {
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  if (value is Map) {
    final n = value['name'] ?? value['slug'];
    return n is String && n.trim().isNotEmpty ? n.trim() : null;
  }
  return null;
}
