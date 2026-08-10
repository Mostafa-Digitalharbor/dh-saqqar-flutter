import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/ui_strings.dart';

/// Global "Task prep" preference (NOT per-conversation), persisted via
/// SharedPreferences.
///
/// **This does not sync with the website, and cannot today.** The comment
/// here used to claim it was "the same shape the web keeps it in", which
/// implied parity it never had. Verified against production on 2026-08-10:
///
///   * The conversation snapshot carries `auto_approve` and `deep_think` as
///     real server-side fields, and `PATCH /conversations/<id>/` writes them
///     — which is exactly why the auto-approve switch DOES stay in step
///     across surfaces.
///   * There is **no `task_prep` field on the conversation**, and no
///     user-preferences endpoint at all (`/preferences/`, `/settings/`,
///     `/user/preferences/`, `/account/settings/` all 404 while `/usage/`
///     401s, so the routes genuinely do not exist).
///   * The only `task_prep` on the wire is inside `saqqar_features` on
///     `/usage/`, and that is a *capability* flag — "may this account use the
///     feature" — not the user's on/off choice.
///
/// So the server stores nothing: it reads `task_prep` off each message body
/// (`payload.get("task_prep", True)`) and forgets it. The app keeps its copy
/// here, the website keeps its own copy on its side, and the two have no
/// shared state to agree through. Flipping it in one place will never move
/// the other.
///
/// **Decided 2026-08-10: Task prep becomes per-conversation**, mirroring
/// `auto_approve`. The client half is already built and shipping — see
/// [Conversation.taskPrep]:
///
///   * while the server sends no `task_prep`, this cubit is the source of
///     truth, exactly as described above;
///   * the moment the field appears in the snapshot, the chat screen reads
///     the conversation instead and PATCHes on change.
///
/// So this class does not go away — it stays the fallback for any chat the
/// server has no opinion about, and the local write still happens in both
/// branches to keep that fallback warm. Backend side is one serializer field
/// plus one accepted PATCH key; see `docs/BACKEND_CURRENT_ISSUES.md` §1.
///
/// When enabled, the send flow attaches `task_prep: true` to the outgoing
/// message body and Saqqar asks 1–3 short clarifying questions before
/// building a vague task. Those questions come back as a `prompt_clarify`
/// interactive card in the chat stream.
///
/// **Defaults to `true`** to match the server, which reads the key as
/// `payload.get("task_prep", True)`. Seeding `false` here would silently
/// flip the behaviour for every existing user the first time they upgraded.
/// The server gates the feature on its own (coercing to `false` when the
/// caller's plan lacks it), so an "on" default is never a hard failure.
class TaskPrepCubit extends Cubit<bool> {
  TaskPrepCubit(this._prefs)
      : super(_prefs.getBool(UiStrings.taskPrepPreferenceKey) ?? true);

  final SharedPreferences _prefs;

  Future<void> set(bool value) async {
    // Idempotent — skip the SharedPreferences write + emit when the value
    // hasn't changed, so a rebuild-driven `set` never churns the prefs file.
    if (value == state) return;
    emit(value);
    await _prefs.setBool(UiStrings.taskPrepPreferenceKey, value);
  }

  Future<void> toggle() => set(!state);
}
