import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/plan_models.dart';

/// Holds the latest [PlanSnapshot] seen on any conversation snapshot so every
/// screen (account usage card, plan badge, feature gating, near-limit banner)
/// reads one source of truth — no need to thread the plan through each screen.
///
/// `ChatCubit` calls [update] whenever a fresh snapshot lands. State is
/// `null` until the first snapshot with a `plan` object arrives; consumers
/// treat `null` as "unknown" and fall back to permissive defaults (don't gate
/// a feature we haven't confirmed is locked).
///
/// Pure in-memory — a cold start re-fetches the snapshot anyway, and the
/// auth gate resets feature state on sign-out by closing the cubit.
class PlanCubit extends Cubit<PlanSnapshot?> {
  PlanCubit() : super(null);

  // NOTE: an earlier pass seeded this from `GET /api/v1/usage/` when no
  // conversation snapshot had supplied a plan. That was reverted, and the
  // reason is worth keeping so nobody re-adds it:
  //
  // `/usage/` returns `{ok, plan, windows}` — it carries the usage windows
  // but NOT `features` or `exempt`. Re-keying that into a `PlanSnapshot`
  // therefore produces `PlanFeatures` with every flag `false`, and
  // `feature(k)` is `exempt || features.enabled(k)`. Every feature gate in
  // the app reads `state?.feature(x) ?? true` — permissive while the plan is
  // unknown — so seeding a features-less plan flips those gates from
  // "unknown, allow" to "known, deny". Concretely: the mic disappears from
  // the composer until a chat snapshot lands.
  //
  // The snapshot's `plan` object is complete (verified against production
  // 2026-07-25: `day week month features exempt plan plan_name token_balance`)
  // and is the only source that can drive feature gates safely.

  /// Replace the held plan. Cheap no-op guard: skip the emit when the new
  /// snapshot is identical-by-identity to avoid spurious rebuilds on the
  /// 1.5 s polling cadence (the parser builds a fresh object each poll, so
  /// this mainly guards re-sets of the exact same instance).
  void update(PlanSnapshot? plan) {
    if (identical(plan, state)) return;
    emit(plan);
  }

  /// Clear on sign-out.
  ///
  /// The cubit is app-scoped and never closed, so without this the previous
  /// account's plan — and its feature gates — stay live across a sign-out.
  /// A Pro user signing out followed by a Free user signing in would leave
  /// the Free user on Pro gates until they happened to open a chat.
  void clear() => emit(null);
}
