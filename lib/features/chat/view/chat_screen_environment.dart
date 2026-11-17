part of 'chat_screen.dart';

/// Environment binding: resolving, changing and defaulting the conversation database.
extension _ChatEnvironment on _ChatScreenState {
  /// Resolves the currently-bound environment for this chat.
  ///
  /// Resolution order:
  ///   1. **Existing chat** (non-new) → read from the snapshot's
  ///      `conversation.environment`. This is the SERVER's source of
  ///      truth — survives across sends, restarts, and re-routes. The
  ///      local `_environmentId` is irrelevant once a conversation
  ///      exists on the backend.
  ///   2. **New chat** (sentinel id) → look up the locally-selected
  ///      env (`_environmentId`) inside `VaultCubit.data`. Used until
  ///      the first send creates the conversation + binds the env
  ///      server-side, at which point the router pushes the user to
  ///      `/chats/<newId>` and resolution flips to path (1).
  ///   3. **Legacy demo fallback** — for the original seeded demo
  ///      conversations that still carry hardcoded env ids.
  ///
  /// Returns null only when truly no env is bound (rare — happens on a
  /// fresh "new chat" before the user picks one).
  _ResolvedEnv? _resolveEnv() {
    // 1) Snapshot-bound env wins for existing chats.
    if (!_isNewChat) {
      final snapshot = context.read<ChatCubit>().state.data.dataOrNull;
      final env = snapshot?.conversation.environment;
      if (env != null) {
        final project = snapshot?.conversation.project;
        return _ResolvedEnv(
          id: env.id,
          name: env.name,
          isLive: env.isLive,
          readOnly: env.readOnly,
          projectId: env.projectId,
          projectName: project?.name ?? '',
        );
      }
    }
    // 2) Vault lookup for the locally-picked env on new chats.
    final id = _environmentId;
    if (id == null) return null;
    final vault = context.read<VaultCubit>().state.data.dataOrNull;
    if (vault != null) {
      final env = vault.environmentById(id);
      if (env != null) {
        final project = vault.projectById(env.projectId);
        return _ResolvedEnv(
          id: env.id,
          name: env.name,
          isLive: env.isLive,
          readOnly: env.readOnly,
          projectId: env.projectId,
          projectName: project?.name ?? '',
        );
      }
    }
    // No bound env resolved from the snapshot or the vault → truly none.
    return null;
  }

  /// Currently-bound environment id reflected in the header dropdowns.
  ///
  /// For existing chats the source of truth is the server-side binding
  /// (snapshot.conversation.environment) — that way the dropdown stays
  /// correct after sends / restarts / navigations. For new chats the
  /// local picker selection wins until the first send creates the
  /// conversation and binds the env server-side.
  ///
  /// Uses `context.watch` so the screen rebuilds when the snapshot
  /// emits a new env (e.g. another device PATCHed the conversation).
  String? get _activeEnvironmentId {
    if (!_isNewChat) {
      final snapshot = context.watch<ChatCubit>().state.data.dataOrNull;
      final fromSnap = snapshot?.conversation.environment?.id;
      if (fromSnap != null) return fromSnap;
    }
    return _environmentId;
  }

  /// Handler for the environment multi-select pill.
  ///
  /// Receives the full set of checked environment ids from
  /// [EnvironmentMultiSelectSheet]. An empty list clears all bindings.
  ///
  /// A "primary" env is still needed — it drives project coherence and the
  /// send-gate ([_activeEnvironmentId]). We keep the current primary if it's
  /// still in the set, otherwise fall back to the first selected env.
  ///
  /// New chat → stash locally; the first send creates the conv with this set
  /// bound. Existing chat → PATCH `environment_id` (primary) +
  /// `environment_ids` (full set); the snapshot refresh reconciles.
  Future<void> _handleEnvironmentsChanged(List<String> ids) async {
    final vault = context.read<VaultCubit>().state.data.dataOrNull;
    // Read (never watch) the current primary here — this runs from a tap
    // handler, outside build, where `context.watch` throws. Mirrors the
    // snapshot-then-local fallback of [_activeEnvironmentId].
    String? currentPrimary;
    if (!_isNewChat) {
      currentPrimary = context
          .read<ChatCubit>()
          .state
          .data
          .dataOrNull
          ?.conversation
          .environment
          ?.id;
    }
    currentPrimary ??= _environmentId;
    final String primary = ids.isEmpty
        ? ''
        : (currentPrimary != null && ids.contains(currentPrimary)
              ? currentPrimary
              : ids.first);
    final primaryEnv = primary.isEmpty ? null : vault?.environmentById(primary);

    void applyLocal() {
      _update(() {
        _environmentIds = List<String>.from(ids);
        _environmentId = primary.isEmpty ? null : primary;
        if (primaryEnv != null) {
          if (primaryEnv.autoApprove) _autoApprove = true;
        }
      });
    }

    if (_isNewChat) {
      applyLocal();
      if (ids.isNotEmpty) _toast(context.tr.envMultiUpdated);
      return;
    }
    // Existing chat — reflect locally for instant feedback, then PATCH the
    // server. The snapshot refresh reconciles if the server rejected.
    applyLocal();
    try {
      await context.read<ConversationsRepository>().patch(
        id: widget.conversationId,
        environmentId: primary,
        environmentIds: ids,
      );
      if (!mounted) return;
      await context.read<ChatCubit>().refresh();
      if (!mounted) return;
      _toast(context.tr.envMultiUpdated);
    } catch (e) {
      if (!mounted) return;
      _toast(ApiErrorMapper.message(context, e));
    }
  }

  /// Previously opened a bottom-sheet env picker fed by demo data. The
  /// header dropdowns (Project + Environment) are now the single
  /// source of truth — sourced from `VaultCubit.data` (real API) for
  /// existing chats, and snapshot-bound on the server for sends. The
  /// sheet's demo data was confusing users (it showed envs they didn't
  /// own).
  ///
  /// This stub stays so the existing call sites
  /// (`onCredentialTap`, send-with-no-env) compile without a wider
  /// refactor — it just nudges the user to the dropdowns instead of
  /// popping the demo sheet.
  Future<void> _openEnvironmentPicker() async {
    _toast(context.tr.pickEnvironmentToStart);
  }

  /// Gap H — "Use My Database" one-click. Ensures a default project +
  /// production environment exist server-side, binds the env to this
  /// conversation, then refreshes the snapshot so the hint banner clears.
  /// Prompts for credentials when the new env can't reach Odoo yet.
  Future<void> _useMyDatabase() async {
    if (_isNewChat || _bindingDefaultEnv) return;
    _update(() => _bindingDefaultEnv = true);
    try {
      final env = await context.read<ProjectsApi>().defaultProject();
      if (!mounted) return;
      await context.read<ConversationsRepository>().patch(
        id: widget.conversationId,
        environmentId: env.id,
      );
      if (!mounted) return;
      await _refreshSnapshot();
      if (!mounted) return;
      _toast(
        env.hasXmlrpc
            ? context.tr.envHintBound
            : context.tr.envHintNeedsCredentials,
      );
    } catch (_) {
      if (!mounted) return;
      _toast(context.tr.envHintFailed);
    } finally {
      if (mounted) _update(() => _bindingDefaultEnv = false);
    }
  }
}

/// Source-agnostic env reference resolved by [_ChatScreenState._resolveEnv].
///
/// Built from a real [Environment] looked up via `VaultCubit`. It used to
/// have a second source — a `DemoEnvironment` for legacy seeded chats
/// carrying hardcoded ids — but no such chat exists any more and that type
/// was deleted; every id now comes from the vault or the snapshot.
///
/// Kept as a flat record-shaped class so the send flow doesn't have to
/// import either source-of-truth type.
class _ResolvedEnv {
  const _ResolvedEnv({
    required this.id,
    required this.name,
    required this.isLive,
    required this.readOnly,
    required this.projectId,
    required this.projectName,
  });

  final String id;
  final String name;
  final bool isLive;
  final bool readOnly;
  final String projectId;
  final String projectName;
}
