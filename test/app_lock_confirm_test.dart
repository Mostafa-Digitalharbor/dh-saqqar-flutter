// The app lock used to guard exactly one moment: returning to a cold or
// backgrounded app. Everything after that was open, including the two
// actions that end the session for good.
//
// That leaves the obvious hole. Someone holding an unlocked phone can sign
// the owner out — wiping the local session — or delete the account outright,
// taking every stored Odoo credential with it. Both are irreversible from
// the phone, and neither asked the owner to prove anything.
//
// `confirm()` closes it. The subtleties worth pinning:
//
//   * It must NOT clear `locked`. Borrowing `unlock()` would work today
//     (the app is unlocked while you look at it) and silently disarm a real
//     lock the first time it is called from a locked surface.
//   * It must pass through when the lock is OFF. A user who never enabled
//     biometrics has not asked to be challenged, and on a device with none
//     enrolled the prompt cannot be satisfied at all — it would brick
//     sign-out.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/security/data/biometric_auth.dart';
import 'package:saqqar_app/features/security/view_model/app_lock_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements BiometricAuth {
  _Auth({this.available = true, this.succeeds = true});

  final bool available;
  bool succeeds;

  final reasons = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return succeeds;
  }
}

Future<AppLockCubit> _cubit(_Auth auth, {required bool enabled}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (enabled) 'saqqar.app_lock.enabled': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return AppLockCubit(prefs: prefs, auth: auth);
}

void main() {
  group('the lock is ON', () {
    test('confirm prompts and passes when the user authenticates', () async {
      final auth = _Auth();
      final cubit = await _cubit(auth, enabled: true);

      final ok = await cubit.confirm(reason: 'Confirm to sign out');

      expect(ok, isTrue);
      expect(auth.reasons, ['Confirm to sign out']);
    });

    test('confirm REFUSES when authentication fails', () async {
      // A failed or cancelled prompt must stop the action. Returning true
      // here would make the whole gate decorative.
      final auth = _Auth(succeeds: false);
      final cubit = await _cubit(auth, enabled: true);

      expect(await cubit.confirm(reason: 'r'), isFalse);
    });

    test('confirm does NOT unlock the app', () async {
      // The regression this exists to prevent: reusing `unlock()` as the
      // gate. A cold start engages the lock; confirming an action must not
      // be a way past the lock screen.
      final auth = _Auth();
      final cubit = await _cubit(auth, enabled: true);
      expect(cubit.state.locked, isTrue, reason: 'engaged on cold start');

      await cubit.confirm(reason: 'r');

      expect(
        cubit.state.locked,
        isTrue,
        reason: 'confirm must authorize an action, not clear the lock',
      );
    });

    test('unlock still clears the lock — the two are different', () async {
      final auth = _Auth();
      final cubit = await _cubit(auth, enabled: true);

      await cubit.unlock(reason: 'r');

      expect(cubit.state.locked, isFalse);
    });

    test('a failed confirm leaves authenticating false', () async {
      // A stuck `authenticating` flag would make every later confirm return
      // false immediately — one cancelled prompt would permanently block
      // sign-out.
      final auth = _Auth(succeeds: false);
      final cubit = await _cubit(auth, enabled: true);

      await cubit.confirm(reason: 'r');

      expect(cubit.state.authenticating, isFalse);
      auth.succeeds = true;
      expect(await cubit.confirm(reason: 'r'), isTrue);
    });
  });

  group('the lock is OFF', () {
    test('confirm passes WITHOUT prompting', () async {
      // Critical: on a device with no enrolled biometric, prompting anyway
      // would be a dialog the user cannot satisfy — sign-out would become
      // impossible.
      final auth = _Auth(available: false);
      final cubit = await _cubit(auth, enabled: false);

      final ok = await cubit.confirm(reason: 'r');

      expect(ok, isTrue);
      expect(auth.reasons, isEmpty, reason: 'nothing to prove');
    });

    test('and the app is not locked', () async {
      final cubit = await _cubit(_Auth(), enabled: false);

      expect(cubit.state.locked, isFalse);
    });
  });

  group('the reason copy names the action', () {
    test('sign-out and delete carry different, non-generic reasons', () async {
      // The system dialog is the only place the user is told WHY they are
      // being asked. "Unlock Saqqar" on a delete-account prompt is worse
      // than no prompt, because it reads as routine.
      final auth = _Auth();
      final cubit = await _cubit(auth, enabled: true);

      await cubit.confirm(reason: 'Confirm it is you to sign out');
      await cubit.confirm(reason: 'Confirm it is you to delete your account');

      expect(auth.reasons, hasLength(2));
      expect(auth.reasons[0], isNot(auth.reasons[1]));
      for (final r in auth.reasons) {
        expect(r, isNot('Unlock Saqqar'));
      }
    });
  });
}
