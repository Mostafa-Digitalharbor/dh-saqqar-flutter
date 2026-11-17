import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/ui_strings.dart';

/// The device-wide **default** for Task prep — the value a chat uses until the
/// server has an opinion of its own. Persisted via SharedPreferences.
///
/// ## What this is, and what it is not
///
/// Since 2026-08-12 `task_prep` is a real per-conversation field: the snapshot
/// carries it and `PATCH /conversations/<id>/` writes it, exactly like
/// `auto_approve`. The chat screen reads
/// `conversation.taskPrep ?? <this cubit>` — so this is the **fallback**, and
/// the server is the source of truth wherever it has a value.
///
/// **Flipping the toggle in an existing chat must NOT write this.** That is
/// not a style preference, it is the fix for a reported bug: because the read
/// falls back to this value, writing it on every flip raised the default for
/// every conversation the server still had no opinion about — so turning Task
/// prep on in one chat turned it on in all of them. A per-conversation setting
/// that moves its neighbours is not per-conversation. `_setTaskPrep` therefore
/// writes here only for a chat that does not exist server-side yet, where
/// there is nothing to PATCH and this value is what the first send carries.
///
/// The backend keeps the field **nullable, defaulting to `null`** on purpose,
/// so a conversation nobody has touched inherits this default rather than
/// being forced to one. That is why the class stays.
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
