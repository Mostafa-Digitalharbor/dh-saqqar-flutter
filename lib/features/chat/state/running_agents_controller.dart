import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which conversations currently have the agent mid-run.
///
/// Each chat screen pushes its own conversation id into the set when it
/// starts a turn and removes it when the turn finishes (or the user taps
/// Stop). The brand bar watches the set to decide whether to render the
/// cross-tab "agent working" pulse dot — so a user who triggered an
/// Excel export, switched to Account, can still see at a glance that
/// Saqqar is still doing work for them somewhere.
///
/// Pure in-memory state; no persistence (a hot restart clears it,
/// matching backend reality).
class RunningAgentsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markRunning(String conversationId) {
    if (state.contains(conversationId)) return;
    state = {...state, conversationId};
  }

  void markIdle(String conversationId) {
    if (!state.contains(conversationId)) return;
    state = {...state}..remove(conversationId);
  }
}

final runningAgentsControllerProvider =
    NotifierProvider<RunningAgentsController, Set<String>>(
  RunningAgentsController.new,
);

/// Convenience: true when at least one conversation is currently
/// running. The brand bar dot watches this so it only rebuilds on the
/// transition between idle ↔ running, not on every set mutation.
final hasAnyAgentRunningProvider = Provider<bool>(
  (ref) => ref.watch(runningAgentsControllerProvider).isNotEmpty,
);
