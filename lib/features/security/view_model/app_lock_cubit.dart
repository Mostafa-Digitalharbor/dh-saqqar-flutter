import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/biometric_auth.dart';

/// App-lock state. [enabled] is the user's saved preference; [locked] is the
/// live "must authenticate now" flag; [available] reports whether the device
/// can authenticate at all (drives whether the toggle is offered).
class AppLockState extends Equatable {
  const AppLockState({
    this.enabled = false,
    this.locked = false,
    this.available = false,
    this.authenticating = false,
  });

  final bool enabled;
  final bool locked;
  final bool available;
  final bool authenticating;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? available,
    bool? authenticating,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      available: available ?? this.available,
      authenticating: authenticating ?? this.authenticating,
    );
  }

  @override
  List<Object?> get props => [enabled, locked, available, authenticating];
}

/// Owns the biometric / device-credential app lock.
///
/// The app holds the user's live Odoo credentials, so gating it behind the
/// OS authenticator is a meaningful security posture. The lock engages on
/// cold start and whenever the app returns from the background (the gate
/// widget calls [lock]); the user clears it via [unlock].
///
/// Pure device-level preference (SharedPreferences) — NOT cleared on
/// sign-out, since it protects the device, not a session.
class AppLockCubit extends Cubit<AppLockState> {
  AppLockCubit({required SharedPreferences prefs, required BiometricAuth auth})
    : _prefs = prefs,
      _auth = auth,
      super(
        AppLockState(
          enabled: prefs.getBool(_key) ?? false,
          // Engage the lock immediately on cold start when enabled.
          locked: prefs.getBool(_key) ?? false,
        ),
      ) {
    _probeAvailability();
  }

  static const _key = 'saqqar.app_lock.enabled';

  final SharedPreferences _prefs;
  final BiometricAuth _auth;

  Future<void> _probeAvailability() async {
    final available = await _auth.isAvailable();
    if (isClosed) return;
    emit(state.copyWith(available: available));
  }

  /// Turn the lock on/off. Turning ON first PROVES the user can authenticate
  /// (so they can never lock themselves out), using [reason] as the system
  /// dialog copy. Returns false if that proof failed (toggle stays off).
  Future<bool> setEnabled(bool value, {required String reason}) async {
    if (value) {
      final ok = await _authenticate(reason);
      if (!ok) return false;
    }
    await _prefs.setBool(_key, value);
    if (isClosed) return value;
    // Just toggled — don't immediately re-prompt; the lock engages on the
    // next background/cold-start cycle.
    emit(state.copyWith(enabled: value, locked: false));
    return value;
  }

  /// Engage the lock — called by the gate when the app returns from the
  /// background. No-op when disabled or already locked.
  void lock() {
    if (!state.enabled || state.locked) return;
    emit(state.copyWith(locked: true));
  }

  /// Prompt the authenticator to clear the lock. [reason] is the localized
  /// system-dialog copy. Returns true on success.
  Future<bool> unlock({required String reason}) async {
    if (state.authenticating) return false;
    final ok = await _authenticate(reason);
    if (ok && !isClosed) emit(state.copyWith(locked: false));
    return ok;
  }

  /// Re-prove identity before a sensitive, irreversible action — signing
  /// out, or deleting the account.
  ///
  /// Distinct from [unlock] on purpose: this does NOT touch
  /// [AppLockState.locked]. The app is unlocked while the user is looking at
  /// it, so borrowing `unlock` would work by accident today and quietly
  /// clear a real lock the day this is called from a locked surface.
  ///
  /// Returns `true` immediately when the lock is off. The gate exists to
  /// honour a protection the user switched on; an account with no app lock
  /// has not asked to be challenged, and prompting anyway would be a
  /// biometric prompt they cannot satisfy on a device with none enrolled.
  Future<bool> confirm({required String reason}) async {
    if (!state.enabled) return true;
    if (state.authenticating) return false;
    return _authenticate(reason);
  }

  Future<bool> _authenticate(String reason) async {
    emit(state.copyWith(authenticating: true));
    try {
      return await _auth.authenticate(reason);
    } finally {
      if (!isClosed) emit(state.copyWith(authenticating: false));
    }
  }
}
