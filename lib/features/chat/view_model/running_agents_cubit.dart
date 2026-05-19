import 'package:flutter_bloc/flutter_bloc.dart';

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
/// matching backend reality). Views select the boolean form via
/// `BlocSelector<RunningAgentsCubit, Set<String>, bool>` so they only
/// rebuild on the idle ↔ running transition.
class RunningAgentsCubit extends Cubit<Set<String>> {
  RunningAgentsCubit() : super(const <String>{});

  void markRunning(String conversationId) {
    if (state.contains(conversationId)) return;
    emit({...state, conversationId});
  }

  void markIdle(String conversationId) {
    if (!state.contains(conversationId)) return;
    emit({...state}..remove(conversationId));
  }
}
