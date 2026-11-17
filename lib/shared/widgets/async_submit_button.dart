import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ghost_button.dart';
import 'primary_button.dart';

/// A [PrimaryButton] / [GhostButton] that auto-binds to a Cubit's
/// "action in flight" flag — flips to a spinner + disables itself while
/// the cubit is mid-mutation, then re-enables on completion.
///
/// Saves every save/delete/submit call site from writing
/// `BlocSelector<XCubit, XState, bool>(selector: ..., builder: ...)`
/// around its button. Typical usage:
///
/// ```dart
/// AsyncSubmitButton<VaultCubit, VaultState>(
///   label: context.tr.save,
///   icon: AppIcons.save,
///   loadingSelector: (s) => s.actionInFlight,
///   onPressed: () => cubit.saveCredential(...),
/// )
/// ```
///
/// Use [AsyncSubmitButton.ghost] for the [GhostButton] variant (cancels,
/// secondary actions).
class AsyncSubmitButton<C extends StateStreamable<S>, S>
    extends StatelessWidget {
  const AsyncSubmitButton({
    super.key,
    required this.label,
    required this.loadingSelector,
    required this.onPressed,
    this.icon,
    this.expand = true,
  }) : _ghost = false,
       _ghostTone = GhostButtonTone.neutral;

  /// [GhostButton]-styled variant. Use for cancel buttons, secondary
  /// actions, and destructive-tone confirms.
  const AsyncSubmitButton.ghost({
    super.key,
    required this.label,
    required this.loadingSelector,
    required this.onPressed,
    this.icon,
    this.expand = true,
    GhostButtonTone tone = GhostButtonTone.neutral,
  }) : _ghost = true,
       _ghostTone = tone;

  final String label;
  final IconData? icon;
  final bool expand;

  /// Invoked on tap. Set to `null` to keep the button disabled even when
  /// the cubit is idle (useful for "save" when the form is invalid).
  final VoidCallback? onPressed;

  /// Reads the cubit's state and returns true when an action is in flight.
  /// For [VaultCubit] this is typically `(s) => s.actionInFlight`.
  final bool Function(S state) loadingSelector;

  // Variant flag — controls which Saqqar-styled button we wrap. Both
  // variants share the loading / disabled behavior; only the visual
  // chrome differs.
  final bool _ghost;
  final GhostButtonTone _ghostTone;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<C, S, bool>(
      selector: loadingSelector,
      builder: (context, busy) {
        if (_ghost) {
          return GhostButton(
            label: label,
            icon: icon,
            loading: busy,
            expand: expand,
            tone: _ghostTone,
            onPressed: busy ? null : onPressed,
          );
        }
        return PrimaryButton(
          label: label,
          icon: icon,
          loading: busy,
          expand: expand,
          onPressed: busy ? null : onPressed,
        );
      },
    );
  }
}
