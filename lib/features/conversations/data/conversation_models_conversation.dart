part of 'conversation_models.dart';

@immutable
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.autoApprove,
    this.taskPrep,
    required this.deepThink,
    required this.isRunning,
    required this.stopRequested,
    this.context = const {},
    this.runProgress,
    this.runError,
    this.activeCredential,
    this.environment,
    this.environments = const <Environment>[],
    this.project,
    this.isArchived = false,
    this.plan,
    this.needsEnvironment = false,
    this.needsResume = false,
  });

  final String id;
  final String title;

  /// Server-side scratchpad. The load-bearing keys are surfaced as
  /// top-level fields here ([activeCredential], etc.) — treat the rest
  /// as opaque.
  final Map<String, dynamic> context;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool autoApprove;

  /// Per-conversation "deep think" toggle. Nullable on purpose:
  ///   * `true` / `false` — the server returned an explicit value, use
  ///     it as the source of truth (the web persists it the same way).
  ///   * `null`           — the server didn't include the field at all
  ///     (older deployments where deep-think lives only client-side).
  ///     Callers fall back to the local [DeepThinkCubit] in that case
  ///     so the toggle still works inside the app even when no sync
  ///     channel exists.
  ///
  /// Read from the top-level `deep_think` field first (canonical),
  /// falls back to `context['deep_think']` for backwards compatibility.
  final bool? deepThink;

  /// Per-conversation "task prep" toggle, on exactly the terms as
  /// [deepThink] above:
  ///   * `true` / `false` — the server owns the setting; use it, and PATCH
  ///     it when the user flips the switch.
  ///   * `null`           — the server does not send the field, so it owns
  ///     nothing. Callers fall back to the device-local `TaskPrepCubit`,
  ///     which is exactly how the app behaves today.
  ///
  /// **Nullable so this ships BEFORE the backend field exists.** As of
  /// 2026-08-10 the conversation carries `auto_approve` and `deep_think` but
  /// no `task_prep`, which is why flipping the toggle in the app never
  /// reached the website and vice versa — there was no shared value to agree
  /// through, only two private copies. The product decision has been made:
  /// per-conversation, mirroring `auto_approve`.
  ///
  /// Reading it now, ahead of the server, is what removes a mobile release
  /// from that fix: the day the field appears in the snapshot the toggle
  /// starts syncing on builds already in users' hands. Until then `null`
  /// keeps today's behaviour precisely, so shipping this early costs
  /// nothing and cannot regress.
  final bool? taskPrep;

  final bool isArchived;

  /// `true` while the agent worker is processing this conversation.
  /// Drives the polling cadence (1.5 s vs 15 s) and disables Send.
  final bool isRunning;

  /// `true` after [ConversationsApi.stop] — the worker is exiting; UI may
  /// show "Stopping…".
  final bool stopRequested;

  final RunProgress? runProgress;
  final String? runError;

  /// Legacy single-credential pointer (slug). New conversations use
  /// [environment] binding instead.
  final String? activeCredential;

  final Environment? environment;

  /// All environments bound to this conversation (web allows several).
  /// [environment] is the primary; this is the full set. Empty when none.
  final List<Environment> environments;

  final Project? project;

  /// Plan / quota / feature snapshot for the calling user. Carried on every
  /// conversation snapshot; surfaced app-wide via `PlanCubit`. `null` only
  /// on older snapshots that predate the field.
  final PlanSnapshot? plan;

  /// `true` when this conversation has no environment bound yet — drives the
  /// "Use My Database" env-hint banner (Gap H).
  final bool needsEnvironment;

  /// `true` when a run ended without finishing and without anything waiting
  /// on the user — the server has already excluded every legitimate pause
  /// (a pending approval, an open question, a credential request, a quota
  /// stop), so this is only ever true for a genuine dead end. Drives the
  /// Resume banner. The server also owns the rate limit on how many times a
  /// conversation may be resumed and flips this back to `false` once the cap
  /// is reached — the client adds no counter of its own.
  final bool needsResume;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final env = json['environment'];
    final proj = json['project'];
    final rp = json['run_progress'];
    final ctx = (json['context'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Deep-think persistence shape isn't pinned yet — try the top-level
    // canonical key first, then fall back to `context.deep_think` for
    // older snapshots. STAYS null when neither is present so callers
    // can fall back to the local DeepThinkCubit instead of defaulting
    // to false (which used to clobber the user's local toggle the
    // moment the next poll landed).
    final deepThinkRaw = json['deep_think'] ?? ctx['deep_think'];
    return Conversation(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      context: ctx,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      autoApprove: json['auto_approve'] as bool? ?? false,
      deepThink: deepThinkRaw is bool ? deepThinkRaw : null,
      // `is bool`, not `as bool?`: a non-bool would throw and take the whole
      // snapshot with it. Anything that is not a boolean reads as "the server
      // said nothing", which falls back to the local preference.
      taskPrep: json['task_prep'] is bool ? json['task_prep'] as bool : null,
      isArchived: json['is_archived'] as bool? ?? false,
      isRunning: json['is_running'] as bool? ?? false,
      stopRequested: json['stop_requested'] as bool? ?? false,
      runProgress: rp is Map<String, dynamic> && rp.isNotEmpty
          ? RunProgress.fromJson(rp)
          : null,
      runError: json['run_error'] as String?,
      activeCredential: json['active_credential'] as String?,
      environment: env is Map<String, dynamic>
          ? Environment.fromJson(env)
          : null,
      // ALL bound environments (web supports binding several to one chat).
      // `environment` above is the primary; this is the full set.
      environments: (json['environments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Environment.fromJson)
          .toList(),
      project: proj is Map<String, dynamic>
          ? Project.fromJson({
              ...proj,
              'environments': const <Map<String, dynamic>>[],
            })
          : null,
      plan: json['plan'] is Map<String, dynamic>
          ? PlanSnapshot.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      needsEnvironment: json['needs_environment'] as bool? ?? false,
      needsResume: json['needs_resume'] as bool? ?? false,
    );
  }

  /// Returns a copy with selected fields overridden. Used by ChatCubit
  /// to flip per-conversation toggles (auto_approve / deep_think)
  /// optimistically before the server round-trip lands.
  Conversation copyWith({
    String? title,
    Map<String, dynamic>? context,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? autoApprove,
    bool? deepThink,
    bool? taskPrep,
    bool? isArchived,
    bool? isRunning,
    bool? stopRequested,
    RunProgress? runProgress,
    String? runError,
    String? activeCredential,
    Environment? environment,
    Project? project,
    PlanSnapshot? plan,
    bool? needsEnvironment,
    bool? needsResume,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      context: context ?? this.context,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      autoApprove: autoApprove ?? this.autoApprove,
      deepThink: deepThink ?? this.deepThink,
      taskPrep: taskPrep ?? this.taskPrep,
      isArchived: isArchived ?? this.isArchived,
      isRunning: isRunning ?? this.isRunning,
      stopRequested: stopRequested ?? this.stopRequested,
      runProgress: runProgress ?? this.runProgress,
      runError: runError ?? this.runError,
      activeCredential: activeCredential ?? this.activeCredential,
      environment: environment ?? this.environment,
      // Server-driven — preserved across optimistic copyWith flips.
      environments: environments,
      project: project ?? this.project,
      plan: plan ?? this.plan,
      needsEnvironment: needsEnvironment ?? this.needsEnvironment,
      needsResume: needsResume ?? this.needsResume,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    context,
    createdAt,
    updatedAt,
    autoApprove,
    deepThink,
    taskPrep,
    isArchived,
    isRunning,
    stopRequested,
    runProgress,
    runError,
    activeCredential,
    environment,
    environments,
    project,
    plan,
    needsEnvironment,
    needsResume,
  ];
}
