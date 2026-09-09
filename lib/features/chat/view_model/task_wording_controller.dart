import 'package:flutter/foundation.dart';

import '../data/prompt_memory_api.dart';
import '../data/task_wording_intent.dart';

/// What one trip to the prompt bank produced, from the caller's point of
/// view.
///
/// Sealed rather than a bool, because the three cases need three different
/// things from the screen and only one of them is an error: a stale answer
/// must produce **no** user-visible reaction at all, and folding it in with
/// success is how a request the user cancelled ends up toasting at them
/// several seconds later.
sealed class TaskWordingOutcome {
  const TaskWordingOutcome();
}

/// The draft is on the card and ready to read.
class TaskWordingReady extends TaskWordingOutcome {
  const TaskWordingReady();
}

/// A newer request started, or the card was closed, while this one was in
/// flight. The answer belongs to a question nobody is asking any more.
class TaskWordingStale extends TaskWordingOutcome {
  const TaskWordingStale();
}

/// The request failed. [error] is raw, for `ApiErrorMapper` to turn into
/// something the user can read in their own language — which is why this
/// class does not do it here.
class TaskWordingFailed extends TaskWordingOutcome {
  const TaskWordingFailed(this.error);
  final Object error;
}

/// The "shall I structure this before you run it?" offer, and the docked card
/// it opens.
///
/// ## Why this is not in the chat screen
///
/// Six mutable fields near the top of `_ChatScreenState` and five methods 1,400
/// lines below them, with an int sequence number tying the two together. The
/// sequence guard is the part that matters and the part nothing tested: a
/// rewrite takes seconds, during which the user can type again, close the
/// card, or leave — and each of those has to make the in-flight answer land
/// nowhere. Getting it wrong reopens a card the user dismissed, or fills it
/// with the answer to their previous sentence, both of which read as the app
/// doing something on its own.
///
/// Nothing here touches a `BuildContext`. The screen keeps what needs one:
/// the toast wording, the error mapping, and putting text in the composer.
class TaskWordingController extends ChangeNotifier {
  TaskWordingController({required PromptMemoryApi Function() api}) : _api = api;

  /// Resolved per call: the API comes out of the widget tree, and that lookup
  /// is only valid while the screen is mounted.
  final PromptMemoryApi Function() _api;

  /// The rough text the docked card is structuring, or null when no card is
  /// open. Kept separate from [draft] so the card can render its loading
  /// state before any draft exists.
  String? query;

  /// The structured rewrite, or the rough text when the server returned no
  /// draft — which is not a failure, so the user still has something to edit.
  String draft = '';

  /// Whether the card is waiting on the rewrite.
  bool loading = false;

  /// Text currently being offered for structuring, or null when the hint bar
  /// is hidden.
  String? hint;

  /// Guards against a slow request finishing after a newer one started, or
  /// after the card was closed.
  int _seq = 0;

  /// The hint key the user last dismissed. Dismissing is per-text, not
  /// forever: rewriting the message brings the offer back, which is what the
  /// web does and what makes the bar an offer rather than a nag.
  String _dismissed = '';

  bool _disposed = false;

  /// Whether the docked card is open.
  bool get isCardOpen => query != null;

  /// Opens the dock card immediately in its loading state, then fills in the
  /// draft.
  ///
  /// Opening first is deliberate: the rewrite takes seconds, and a tap that
  /// produces nothing visible reads as a tap that missed.
  ///
  /// Returns [TaskWordingStale] — and leaves every field alone — when the
  /// answer arrives after the question stopped mattering.
  Future<TaskWordingOutcome> prepare(
    String rough, {
    required String lang,
    String? conversationId,
  }) async {
    final text = rough.trim();
    if (text.isEmpty) return const TaskWordingStale();

    // Dismiss the hint for this text — it has been acted on.
    _dismissed = taskWordingHintKey(text);
    hint = null;
    query = text;
    draft = '';
    loading = true;
    notifyListeners();

    final seq = ++_seq;

    try {
      final result = await _api().fetch(
        lang: lang,
        query: text,
        conversationId: conversationId,
      );
      // A second request started while this one was in flight, or the card
      // was closed — either way this answer is stale.
      if (_disposed || seq != _seq || query == null) {
        return const TaskWordingStale();
      }
      // No draft is not a failure: the card falls back to the rough text so
      // the user still has something to edit and send.
      draft = result.draft?.promptTemplate ?? text;
      loading = false;
      notifyListeners();
      return const TaskWordingReady();
    } catch (e) {
      if (_disposed || seq != _seq) return const TaskWordingStale();
      query = null;
      loading = false;
      notifyListeners();
      return TaskWordingFailed(e);
    }
  }

  /// Closes the docked card.
  ///
  /// Bumps the sequence, so an in-flight fetch cannot re-open what the user
  /// just dismissed.
  void close() {
    query = null;
    draft = '';
    loading = false;
    _seq++;
    notifyListeners();
  }

  /// Records that [text] has been acted on, so the hint bar does not offer it
  /// again until the user rewrites the message.
  ///
  /// Silent: the hint is already gone by every path that calls this, and a
  /// notify here would be a rebuild for a field nothing reads directly.
  void markActedOn(String text) => _dismissed = taskWordingHintKey(text);

  /// Hides the hint bar for [text] — the user said "not this one".
  void dismissHint(String text) {
    _dismissed = taskWordingHintKey(text);
    hint = null;
    notifyListeners();
  }

  /// Re-evaluates the offer as the user types.
  ///
  /// [enabled] is the task-prep setting. The offer belongs to the same "help
  /// me phrase this before running it" toggle, exactly like the web: someone
  /// who turned that off has said they do not want to be asked.
  void refreshHint(String text, {required bool enabled}) {
    if (!enabled) {
      if (hint == null) return;
      hint = null;
      notifyListeners();
      return;
    }
    final key = taskWordingHintKey(text);
    final show = query == null &&
        looksLikeLongTaskPrompt(text) &&
        key.isNotEmpty &&
        key != _dismissed;
    final next = show ? text.trim() : null;
    if (next == hint) return;
    hint = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
