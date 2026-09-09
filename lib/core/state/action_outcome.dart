import 'package:flutter_bloc/flutter_bloc.dart';

/// A state that carries the one-shot outcome of a user-triggered mutation.
///
/// Three cubits — chat, conversations and vault — each hold the same pair:
/// a typed failure the view renders as an error toast, and a typed success
/// message it renders as a confirmation. Both are *one-shot*: the view's
/// `BlocListener` shows it once and then tells the cubit to drop it, so it
/// does not re-fire on the next unrelated emit.
typedef ActionOutcomeState = ({Object? actionFailure, Object? actionToast});

/// The consume half of that contract, in one place.
///
/// All three cubits had written these two methods by hand, identically. The
/// body is trivial, but the early return is not decoration: without it,
/// consuming an already-null outcome emits a state equal to the current one.
/// `Equatable` suppresses the rebuild, so the bug is invisible — until a
/// state grows a non-equatable field and every listener starts firing on
/// every dismissed toast. Centralising the guard means a new cubit inherits
/// it instead of having to know about it.
///
/// Mixed onto the cubit; the two `cleared…` hooks are the only thing a
/// subclass supplies, because each state's `copyWith` has its own signature.
///
/// ```dart
/// class VaultCubit extends Cubit<VaultState> with ActionOutcomeCubit<VaultState> {
///   @override
///   VaultState clearedActionFailure() => state.copyWith(clearActionFailure: true);
///   @override
///   VaultState clearedActionToast() => state.copyWith(clearActionToast: true);
/// }
/// ```
mixin ActionOutcomeCubit<S> on BlocBase<S> {
  /// The failure currently on [state], or null. Usually `state.actionFailure`.
  Object? get currentActionFailure;

  /// The success message currently on [state], or null. Usually
  /// `state.actionToast`.
  Object? get currentActionToast;

  /// [state] with the failure dropped.
  S clearedActionFailure();

  /// [state] with the success message dropped.
  S clearedActionToast();

  /// Call from the view's `BlocListener` after rendering the error, so it
  /// does not fire again on the next emit.
  void consumeActionFailure() {
    if (currentActionFailure == null) return;
    emit(clearedActionFailure());
  }

  /// Call from the view's `BlocListener` after rendering the confirmation.
  void consumeActionToast() {
    if (currentActionToast == null) return;
    emit(clearedActionToast());
  }
}
