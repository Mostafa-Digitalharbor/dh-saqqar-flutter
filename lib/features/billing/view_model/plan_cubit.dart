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

  /// Replace the held plan. Cheap no-op guard: skip the emit when the new
  /// snapshot is identical-by-identity to avoid spurious rebuilds on the
  /// 1.5 s polling cadence (the parser builds a fresh object each poll, so
  /// this mainly guards re-sets of the exact same instance).
  void update(PlanSnapshot? plan) {
    if (identical(plan, state)) return;
    emit(plan);
  }

  /// Clear on sign-out so a different account doesn't briefly inherit the
  /// previous user's plan/feature gates.
  void clear() => emit(null);
}
